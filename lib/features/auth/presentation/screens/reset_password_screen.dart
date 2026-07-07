import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/services/providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }

    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await ref.read(authServiceProvider).updatePassword(password);

      if (res.user == null) {
        _showError('Unable to reset password. Please request a new link.');
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );

      context.goNamed('splash');
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'ui.reset_password');
      if (mounted) {
        _showError(userMessageForError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Create a new password for your account',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}
