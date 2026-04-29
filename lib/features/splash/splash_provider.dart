import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';

final splashRedirectProvider = FutureProvider<String>((ref) async {
  await Future.delayed(const Duration(seconds: 2));

  final authNotifier = ref.read(authNotifierProvider);
  final isLoggedIn = authNotifier.isLoggedIn;

  if (isLoggedIn) {
    var attempts = 0;
    while (!authNotifier.isRoleResolved && attempts < 25) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  if (!isLoggedIn) {
    return RouteNames.guestHome;
  }

  return authNotifier.preferredHomeRoute;
});
