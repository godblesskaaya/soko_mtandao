import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

class ManagerProfileEditScreen extends ConsumerStatefulWidget {
  const ManagerProfileEditScreen({super.key});

  @override
  ConsumerState<ManagerProfileEditScreen> createState() =>
      _ManagerProfileEditScreenState();
}

class _ManagerProfileEditScreenState
    extends ConsumerState<ManagerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String _email = '';

  @override
  void initState() {
    super.initState();
    _seedInitialValues();
  }

  void _seedInitialValues() {
    final user = ref.read(authServiceProvider).currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};

    var firstName = (metadata['firstName'] ?? '').toString().trim();
    var lastName = (metadata['lastName'] ?? '').toString().trim();

    if (firstName.isEmpty && lastName.isEmpty) {
      final fullName = (metadata['fullName'] ?? '').toString().trim();
      if (fullName.isNotEmpty) {
        final parts = fullName.split(RegExp(r'\s+'));
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    _firstNameCtrl.text = firstName;
    _lastNameCtrl.text = lastName;
    _phoneCtrl.text =
        (user?.phone ?? metadata['phone'] ?? '').toString().trim();
    _titleCtrl.text = (metadata['managerTitle'] ?? '').toString().trim();
    _bioCtrl.text = (metadata['bio'] ?? '').toString().trim();
    _email = user?.email ?? '';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _titleCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(managerProfileUpdateProvider.notifier).update(
            ManagerProfileUpdateInput(
              firstName: _firstNameCtrl.text.trim(),
              lastName: _lastNameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              bio: _bioCtrl.text.trim(),
            ),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(managerProfileUpdateProvider);
    final isSubmitting = updateState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Manager Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep your manager profile clear and current.',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This information is used across hotel operations and support communications.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText:
                      'Email changes are managed through auth settings.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+255700000000',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                  if (!phoneRegex.hasMatch(value.trim())) {
                    return 'Use a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Professional title',
                  hintText: 'e.g., Operations Manager',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                minLines: 3,
                maxLines: 5,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Short profile bio',
                  hintText:
                      'Share your management focus, experience, or responsibilities.',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
