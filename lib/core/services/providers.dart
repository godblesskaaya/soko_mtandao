import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_service.dart';
import 'user_service.dart';
import 'auth_notifier.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final userServiceProvider = Provider<UserService>((ref) => UserService());

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final auth = ref.read(authServiceProvider);
  final userSvc = ref.read(userServiceProvider);
  final notifier = AuthNotifier(auth, userSvc);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

final locationProvider = FutureProvider<Position>((ref) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    throw Exception('Location permissions are denied');
  } else if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied, we cannot request permissions.');
  }

  return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
});
