// Toggle mock vs real data at runtime
enum MockState { loading, success, error }

class AppConfig {
  static const bool useMockData = false; // flip to false for real backend

  // Pick the global mock behavior when useMockData = true
  static const MockState globalMockState = MockState.success;

  static const Duration paymentPollInterval = Duration(seconds: 60);

  static var paybillNumber = '123456';

  static var accountName = 'Soko Mtandao Company Ltd';

  static var appBaseUrl = 'soko_mtandao://';
  static var supabaseFunctionsBaseUrl = 'https://wqmarlzyzukreiwibwjs.supabase.co/functions/v1';
}
