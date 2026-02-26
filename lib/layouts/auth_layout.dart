import 'package:flutter/material.dart';

/// AuthLayout: pass-through wrapper for auth pages.
class AuthLayout extends StatelessWidget {
  final Widget child;
  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
