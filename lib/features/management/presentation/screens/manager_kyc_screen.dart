import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
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
  final _businessRegistrationCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _beneficialOwnerNameCtrl = TextEditingController();
  final _beneficialOwnerIdCtrl = TextEditingController();
  final _compliancePhoneCtrl = TextEditingController();
  final _complianceEmailCtrl = TextEditingController();

  bool _phoneVerified = false;
  bool _payoutTermsAccepted = false;
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
              'legal_name,national_id,date_of_birth,physical_address,phone_verified,status,updated_at,business_registration_number,tax_identification_number,business_type,beneficial_owner_name,beneficial_owner_national_id,compliance_contact_phone,compliance_contact_email,payout_terms_accepted_at')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row != null) {
        _legalNameCtrl.text = (row['legal_name'] ?? '').toString();
        _nationalIdCtrl.text = (row['national_id'] ?? '').toString();
        final dob = (row['date_of_birth'] ?? '').toString();
        _dobCtrl.text = dob.isEmpty ? '' : dob.substring(0, 10);
        _addressCtrl.text = (row['physical_address'] ?? '').toString();
        _businessRegistrationCtrl.text =
            (row['business_registration_number'] ?? '').toString();
        _taxIdCtrl.text = (row['tax_identification_number'] ?? '').toString();
        _businessTypeCtrl.text = (row['business_type'] ?? '').toString();
        _beneficialOwnerNameCtrl.text =
            (row['beneficial_owner_name'] ?? '').toString();
        _beneficialOwnerIdCtrl.text =
            (row['beneficial_owner_national_id'] ?? '').toString();
        _compliancePhoneCtrl.text =
            (row['compliance_contact_phone'] ?? '').toString();
        _complianceEmailCtrl.text =
            (row['compliance_contact_email'] ?? '').toString();
        _phoneVerified = row['phone_verified'] == true;
        _payoutTermsAccepted = row['payout_terms_accepted_at'] != null;
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
      if (!_payoutTermsAccepted) {
        throw Exception('Accept the payout compliance terms before submitting.');
      }

      await _client.rpc('submit_kyc_profile', params: {
        'p_legal_name': _legalNameCtrl.text.trim(),
        'p_national_id': _nationalIdCtrl.text.trim(),
        'p_date_of_birth': dob.toIso8601String().substring(0, 10),
        'p_physical_address': _addressCtrl.text.trim(),
        'p_phone_verified': false,
        'p_document_url': _documentUrlCtrl.text.trim().isEmpty
            ? null
            : _documentUrlCtrl.text.trim(),
        'p_business_registration_number':
            _businessRegistrationCtrl.text.trim().isEmpty
                ? null
                : _businessRegistrationCtrl.text.trim(),
        'p_tax_identification_number': _taxIdCtrl.text.trim().isEmpty
            ? null
            : _taxIdCtrl.text.trim(),
        'p_business_type': _businessTypeCtrl.text.trim(),
        'p_beneficial_owner_name': _beneficialOwnerNameCtrl.text.trim(),
        'p_beneficial_owner_national_id': _beneficialOwnerIdCtrl.text.trim(),
        'p_compliance_contact_phone': _compliancePhoneCtrl.text.trim(),
        'p_compliance_contact_email': _complianceEmailCtrl.text.trim(),
        'p_payout_terms_accepted': _payoutTermsAccepted,
        'p_payout_terms_version': 'azampay-payouts-v1',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC submitted for compliance review.')),
      );
      await _loadKyc();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(e))),
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
    _businessRegistrationCtrl.dispose();
    _taxIdCtrl.dispose();
    _businessTypeCtrl.dispose();
    _beneficialOwnerNameCtrl.dispose();
    _beneficialOwnerIdCtrl.dispose();
    _compliancePhoneCtrl.dispose();
    _complianceEmailCtrl.dispose();
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
                    const Divider(height: 32),
                    const Text(
                      'Business & Payout Compliance',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Business Type',
                        hintText: 'Sole proprietor, company, partnership',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessRegistrationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Business Registration Number (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxIdCtrl,
                      decoration:
                          const InputDecoration(labelText: 'TIN (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _beneficialOwnerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Beneficial Owner Full Name',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _beneficialOwnerIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Beneficial Owner National ID / NIDA',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _compliancePhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Compliance Contact Phone',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _complianceEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Compliance Contact Email',
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Required';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _phoneVerified
                            ? Icons.verified_user_outlined
                            : Icons.pending_actions_outlined,
                      ),
                      title: const Text('Phone verification'),
                      subtitle: Text(
                        _phoneVerified
                            ? 'Verified and recorded by compliance.'
                            : 'Pending compliance verification. Managers cannot self-verify this field.',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _payoutTermsAccepted,
                      title: const Text(
                        'I confirm this information is accurate and may be used for payout compliance review.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(
                        () => _payoutTermsAccepted = v ?? false,
                      ),
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
