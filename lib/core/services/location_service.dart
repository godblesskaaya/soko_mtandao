import 'package:geolocator/geolocator.dart';

class LocationService {
  static const _fallbackLat = -6.7924; // Dar es Salaam CBD
  static const _fallbackLng = 39.2083;

  Future<({double lat, double lng})> getCurrentPositionOrFallback() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (lat: _fallbackLat, lng: _fallbackLng);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (lat: _fallbackLat, lng: _fallbackLng);
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return (lat: pos.latitude, lng: pos.longitude);
  }
}
