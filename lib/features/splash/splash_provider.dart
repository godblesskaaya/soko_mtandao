import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';

final splashRedirectProvider = FutureProvider<String>((ref) async {
  await Future.delayed(const Duration(seconds: 2));

  final authNotifier = ref.read(authNotifierProvider);
  var attempts = 0;
  while (!authNotifier.isInitialized && attempts < 25) {
    await Future.delayed(const Duration(milliseconds: 100));
    attempts++;
  }

  if (authNotifier.isLoggedIn) {
    attempts = 0;
    while (!authNotifier.isRoleResolved && attempts < 25) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  if (!authNotifier.isLoggedIn) {
    return RouteNames.guestHome;
  }

  return authNotifier.preferredHomeRoute;
});
