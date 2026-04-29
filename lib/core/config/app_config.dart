import 'env_config.dart';

// Toggle mock vs real data at runtime
enum MockState { loading, success, error }

class AppConfig {
  static const bool useMockData = false; // flip to false for real backend

  // Pick the global mock behavior when useMockData = true
  static const MockState globalMockState = MockState.success;

  static const Duration paymentPollInterval = Duration(seconds: 5);

  static var paybillNumber = '123456';

  static var accountName = 'Soko Mtandao Company Ltd';

  static String get appBaseUrl => EnvConfig.appBaseUrl;
  static String get supabaseFunctionsBaseUrl =>
      '${EnvConfig.supabaseUrl}/functions/v1';

  static String get privacyPolicyUrl => EnvConfig.privacyPolicyUrl;
  static String get supportEmail => EnvConfig.supportEmail;
  static String get supportPhone => EnvConfig.supportPhone;
  static String get supportAddress => EnvConfig.supportAddress;
}
