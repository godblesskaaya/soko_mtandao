import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffOnboardingScreen extends ConsumerStatefulWidget {
  const StaffOnboardingScreen({super.key});

  @override
  ConsumerState<StaffOnboardingScreen> createState() =>
      _StaffOnboardingScreenState();
}

class _StaffOnboardingScreenState extends ConsumerState<StaffOnboardingScreen> {
  final _inviteTokenCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  static const _staffRoles = <String>[
    'front_desk',
    'housekeeping',
    'accounting',
    'maintenance',
    'manager',
  ];

  String _staffRole = 'front_desk';

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedHotelId;
  List<Map<String, dynamic>> _hotels = const <Map<String, dynamic>>[];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _client
          .from('hotels')
          .select('id,name,city,region')
          .order('name', ascending: true)
          .limit(100);

      _hotels = List<Map<String, dynamic>>.from(
        (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
      await ref.read(authNotifierProvider).refreshAccessProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff onboarding updated.')),
      );
      context.go(RouteNames.pendingAccess);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _inviteTokenCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join A Hotel Team'),
        actions: [
          TextButton(
            onPressed:
                _isSubmitting ? null : () => context.push(RouteNames.pendingAccess),
            child: const Text('Status'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'If your manager shared an invite token, you can activate staff access right away. Otherwise send a join request and keep using customer mode while it is reviewed.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteTokenCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Invite token',
                      hintText: 'Paste the invite token from your manager',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _runAction(
                              () => ref
                                  .read(userServiceProvider)
                                  .acceptStaffInvite(_inviteTokenCtrl.text.trim()),
                            ),
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: const Text('Accept Invite'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No invite yet?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedHotelId,
                    items: _hotels
                        .map(
                          (hotel) => DropdownMenuItem<String>(
                            value: hotel['id']?.toString(),
                            child: Text(
                              '${hotel['name']} - ${hotel['city'] ?? hotel['region'] ?? ''}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged:
                        _isSubmitting ? null : (value) => setState(() => _selectedHotelId = value),
                    decoration:
                        const InputDecoration(labelText: 'Select the hotel'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _staffRole,
                    decoration: const InputDecoration(
                      labelText: 'Preferred team role',
                    ),
                    items: _staffRoles
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: role,
                            child: Text(_formatRole(role)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(
                              () => _staffRole = value ?? 'front_desk',
                            ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Short note for the manager',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting || _selectedHotelId == null
                        ? null
                        : () => _runAction(
                              () => ref
                                  .read(userServiceProvider)
                                  .submitStaffJoinRequest(
                                    hotelId: _selectedHotelId!,
                                    staffTitle: _staffRole,
                                    note: _noteCtrl.text.trim(),
                                  ),
                            ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send Join Request'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRole(String role) {
    return role
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
