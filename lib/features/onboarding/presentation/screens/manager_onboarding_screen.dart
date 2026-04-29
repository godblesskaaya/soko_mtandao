import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerOnboardingScreen extends ConsumerStatefulWidget {
  const ManagerOnboardingScreen({super.key});

  @override
  ConsumerState<ManagerOnboardingScreen> createState() =>
      _ManagerOnboardingScreenState();
}

class _ManagerOnboardingScreenState
    extends ConsumerState<ManagerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController(text: '0');

  bool _isLoading = true;
  bool _isSaving = false;
  String _kycStatus = 'pending';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser;
      final userId = user?.id;
      if (userId == null) return;

      final draft = await _client
          .from('hotel_onboarding_drafts')
          .select('hotel_payload')
          .eq('user_id', userId)
          .maybeSingle();

      final kyc = await _client
          .from('kyc_profiles')
          .select('status')
          .eq('user_id', userId)
          .maybeSingle();

      _kycStatus = (kyc?['status'] ?? 'pending').toString();

      final rawPayload = draft?['hotel_payload'];
      final payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const <String, dynamic>{};

      _nameCtrl.text = (payload['name'] ?? '').toString();
      _addressCtrl.text = (payload['address'] ?? '').toString();
      _descriptionCtrl.text = (payload['description'] ?? '').toString();
      _regionCtrl.text = (payload['region'] ?? '').toString();
      _countryCtrl.text = (payload['country'] ?? '').toString();
      _cityCtrl.text = (payload['city'] ?? '').toString();
      _phoneCtrl.text = (payload['phoneNumber'] ?? '').toString();
      _emailCtrl.text = (payload['email'] ?? user?.email ?? '').toString();
      _websiteCtrl.text = (payload['website'] ?? '').toString();
      _latCtrl.text = (payload['lat'] ?? '').toString();
      _lngCtrl.text = (payload['lng'] ?? '').toString();
      _roomsCtrl.text = (payload['totalRooms'] ?? 0).toString();
    } catch (_) {
      // The screen can still render an empty draft state.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _payload() {
    return {
      'name': _nameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'region': _regionCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'lat': double.tryParse(_latCtrl.text.trim()) ?? 0,
      'lng': double.tryParse(_lngCtrl.text.trim()) ?? 0,
      'totalRooms': int.tryParse(_roomsCtrl.text.trim()) ?? 0,
      'images': const <String>[],
    };
  }

  Future<void> _runSubmission(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    try {
      await action();
      await ref.read(authNotifierProvider).refreshAccessProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manager onboarding updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl,
      _addressCtrl,
      _descriptionCtrl,
      _regionCtrl,
      _countryCtrl,
      _cityCtrl,
      _phoneCtrl,
      _emailCtrl,
      _websiteCtrl,
      _latCtrl,
      _lngCtrl,
      _roomsCtrl,
    ]) {
      ctrl.dispose();
    }
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
        title: const Text('Manager Onboarding'),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () => context.push(RouteNames.pendingAccess),
            child: const Text('Status'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before we can approve hotel management access, complete your personal profile and submit KYC.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  await context.pushNamed('editManagerProfile');
                                  if (mounted) await _loadDraft();
                                },
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Edit Profile'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  await context.pushNamed('managerKyc');
                                  if (mounted) await _loadDraft();
                                },
                          icon: const Icon(Icons.verified_user_outlined),
                          label: Text('KYC: ${_kycStatus.toUpperCase()}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Hotel name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(labelText: 'Region'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countryCtrl,
              decoration: const InputDecoration(labelText: 'Country'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(labelText: 'City'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Hotel phone'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Hotel email'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _roomsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total rooms'),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _runSubmission(
                            () => ref
                                .read(userServiceProvider)
                                .saveManagerApplicationDraft(_payload()),
                          ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Draft'),
                ),
                FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          _runSubmission(
                            () => ref
                                .read(userServiceProvider)
                                .submitManagerApplication(_payload()),
                          );
                        },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Submit For Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}
