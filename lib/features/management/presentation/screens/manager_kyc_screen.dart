import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerKycScreen extends StatefulWidget {
  const ManagerKycScreen({super.key});

  @override
  State<ManagerKycScreen> createState() => _ManagerKycScreenState();
}

class _ManagerKycScreenState extends State<ManagerKycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _documentUrlCtrl = TextEditingController();

  bool _phoneVerified = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _status = 'pending';
  String? _lastUpdated;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final row = await _client
          .from('kyc_profiles')
          .select(
              'legal_name,national_id,date_of_birth,physical_address,phone_verified,status,updated_at')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row != null) {
        _legalNameCtrl.text = (row['legal_name'] ?? '').toString();
        _nationalIdCtrl.text = (row['national_id'] ?? '').toString();
        final dob = (row['date_of_birth'] ?? '').toString();
        _dobCtrl.text = dob.isEmpty ? '' : dob.substring(0, 10);
        _addressCtrl.text = (row['physical_address'] ?? '').toString();
        _phoneVerified = row['phone_verified'] == true;
        _status = (row['status'] ?? 'pending').toString();
        _lastUpdated = row['updated_at']?.toString();
      }
    } catch (_) {
      // Surface via snackbars on submit to keep this screen simple.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final dob = DateTime.tryParse(_dobCtrl.text.trim());
      if (dob == null) {
        throw Exception('Invalid date of birth. Use YYYY-MM-DD.');
      }

      await _client.rpc('submit_kyc_profile', params: {
        'p_legal_name': _legalNameCtrl.text.trim(),
        'p_national_id': _nationalIdCtrl.text.trim(),
        'p_date_of_birth': dob.toIso8601String().substring(0, 10),
        'p_physical_address': _addressCtrl.text.trim(),
        'p_phone_verified': _phoneVerified,
        'p_document_url': _documentUrlCtrl.text.trim().isEmpty
            ? null
            : _documentUrlCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC submitted for compliance review.')),
      );
      await _loadKyc();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _legalNameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _documentUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager KYC')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text('Status: ${_status.toUpperCase()}'),
                        ),
                        if (_lastUpdated != null)
                          Chip(
                            label: Text(
                                'Updated: ${_lastUpdated!.substring(0, 10)}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _legalNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Legal Name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nationalIdCtrl,
                      decoration: const InputDecoration(
                          labelText: 'National ID / NIDA'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Date of Birth (YYYY-MM-DD)'),
                      validator: (v) =>
                          v == null || DateTime.tryParse(v.trim()) == null
                              ? 'Use YYYY-MM-DD'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Physical Address'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _documentUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Encrypted Document URL (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Phone Number Verified (OTP)'),
                      value: _phoneVerified,
                      onChanged: (v) => setState(() => _phoneVerified = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit KYC for Review'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
