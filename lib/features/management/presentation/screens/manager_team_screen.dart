import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/widgets/entity_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerTeamScreen extends ConsumerStatefulWidget {
  const ManagerTeamScreen({super.key});

  @override
  ConsumerState<ManagerTeamScreen> createState() => _ManagerTeamScreenState();
}

class _ManagerTeamScreenState extends ConsumerState<ManagerTeamScreen> {
  final _inviteEmailCtrl = TextEditingController();
  final _inviteRoleCtrl = TextEditingController(text: 'front_desk');

  bool _isLoading = true;
  String? _hotelId;
  List<Map<String, dynamic>> _staff = const [];
  List<Map<String, dynamic>> _invites = const [];
  List<Map<String, dynamic>> _requests = const [];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _hotelId = ref.read(selectedManagerHotelIdProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureHotelAndLoad());
  }

  Future<List<ManagerHotel>> _fetchHotels() async {
    final managerUserId = ref.read(authServiceProvider).currentUser?.id;
    if (managerUserId == null || managerUserId.isEmpty) return [];
    return ref.read(managerHotelsProvider(managerUserId).future);
  }

  Future<void> _ensureHotelAndLoad() async {
    if (_hotelId == null || _hotelId!.isEmpty) {
      final selectedHotel = await showEntityPicker<ManagerHotel>(
        context: context,
        title: 'Select a hotel team',
        fetchItems: _fetchHotels,
        display: (hotel) => hotel.name,
      );
      if (selectedHotel == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _hotelId = selectedHotel.id;
      ref.read(selectedManagerHotelIdProvider.notifier).state = selectedHotel.id;
    }
    await _load();
  }

  Future<void> _load() async {
    final hotelId = _hotelId;
    if (hotelId == null || hotelId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final staffRows = await _client
          .from('staff')
          .select('id,name,email,phone,role,is_active')
          .eq('hotel_id', hotelId)
          .order('created_at', ascending: false);
      final inviteRows = await _client
          .from('staff_invites')
          .select('id,email,staff_title,status,invite_token,expires_at,created_at')
          .eq('hotel_id', hotelId)
          .order('created_at', ascending: false);
      final requestRows = await _client
          .from('staff_join_requests')
          .select('id,user_id,staff_title,note,status,created_at')
          .eq('hotel_id', hotelId)
          .order('created_at', ascending: false);

      _staff = List<Map<String, dynamic>>.from(
        (staffRows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      _invites = List<Map<String, dynamic>>.from(
        (inviteRows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      _requests = List<Map<String, dynamic>>.from(
        (requestRows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team access updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(error))),
      );
    }
  }

  @override
  void dispose() {
    _inviteEmailCtrl.dispose();
    _inviteRoleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Access'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite staff by email',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _inviteEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _inviteRoleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Staff title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _run(
                            () => _client.rpc('create_staff_invite', params: {
                              'p_hotel_id': _hotelId,
                              'p_email': _inviteEmailCtrl.text.trim(),
                              'p_staff_title': _inviteRoleCtrl.text.trim(),
                            }),
                          ),
                          icon: const Icon(Icons.mark_email_read_outlined),
                          label: const Text('Create Invite'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Pending join requests',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_requests.isEmpty)
                  const Text('No join requests for this hotel.')
                else
                  ..._requests.map(
                    (row) => Card(
                      child: ListTile(
                        title: Text(row['user_id']?.toString() ?? ''),
                        subtitle: Text(
                          '${row['staff_title'] ?? 'front_desk'}\n${row['note'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: row['status'] == 'pending'
                                  ? () => _run(
                                        () => _client.rpc(
                                          'review_staff_join_request',
                                          params: {
                                            'p_request_id': row['id'],
                                            'p_status': 'rejected',
                                          },
                                        ),
                                      )
                                  : null,
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: row['status'] == 'pending'
                                  ? () => _run(
                                        () => _client.rpc(
                                          'review_staff_join_request',
                                          params: {
                                            'p_request_id': row['id'],
                                            'p_status': 'approved',
                                          },
                                        ),
                                      )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Active staff',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_staff.isEmpty)
                  const Text('No active staff records yet.')
                else
                  ..._staff.map(
                    (row) => Card(
                      child: ListTile(
                        title: Text(row['name']?.toString() ?? 'Staff member'),
                        subtitle: Text(
                          '${row['email'] ?? '-'}\nRole: ${row['role'] ?? '-'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Recent invites',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_invites.isEmpty)
                  const Text('No invites yet.')
                else
                  ..._invites.map(
                    (row) => Card(
                      child: ListTile(
                        title: Text(row['email']?.toString() ?? ''),
                        subtitle: Text(
                          'Role: ${row['staff_title'] ?? '-'}\nToken: ${row['invite_token'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Text((row['status'] ?? '').toString()),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
