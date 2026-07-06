import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/router/route_names.dart';

/// AuthLayout: pass-through wrapper for auth pages.
class AuthLayout extends StatelessWidget {
  final Widget child;
  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }

        context.go(RouteNames.guestHome);
      },
      child: child,
    );
  }
}
