import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/config/env_config.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Please enter a valid email address');
      return;
    }

    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(
            email: email,
            redirectTo: EnvConfig.passwordResetRedirectUrl,
          );

      if (!mounted) return;

      _showMessage(
        'If an account exists for this email, a password reset link has been sent.',
      );

      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        context.go(RouteNames.login);
      }
    } catch (e) {
      _showMessage('Unable to send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we’ll send you a link to reset your password.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendResetEmail,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Send Reset Link'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go(RouteNames.guestHome),
                child: const Text('Continue to Explore'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
