import 'package:flutter/material.dart';

/// AuthLayout: simple layout for auth pages like login/signup
class AuthLayout extends StatelessWidget {
  final Widget child;
  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(child: child),
    );
  }
}