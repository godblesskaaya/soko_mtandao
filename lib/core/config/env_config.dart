class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static const String appBaseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: 'soko_mtandao://',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@sokomtandao.co.tz',
  );

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://sites.google.com/view/sokomtandaocompany-privacy',
  );

  static void validate() {
    final missing = <String>[
      if (supabaseUrl.trim().isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
      if (mapboxAccessToken.trim().isEmpty) 'MAPBOX_ACCESS_TOKEN',
    ];

    if (missing.isEmpty) return;

    throw StateError(
      'Missing required environment variables: ${missing.join(', ')}. '
      'Provide them using --dart-define or --dart-define-from-file.',
    );
  }
}
