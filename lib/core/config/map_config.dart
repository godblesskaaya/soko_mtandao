import 'env_config.dart';

class MapConfig {
  static String get mapboxAccessToken => EnvConfig.mapboxAccessToken;
  static const double minZoomForData = 10.5; // below this, pause data fetching
}
