import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:soko_mtandao/core/config/map_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wqmarlzyzukreiwibwjs.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxbWFybHp5enVrcmVpd2lid2pzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM3Njk1MTksImV4cCI6MjA2OTM0NTUxOX0.4vlxDetKBOC8xIh4alJVoj0vOWw64YEWHb6uAqDWxG8',
  );

  MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final stack = details.stack ?? StackTrace.current;
    ErrorReporter.report(details.exception, stack, source: 'flutter_error');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(error, stack, source: 'platform_dispatcher');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'An unexpected error occurred.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: MyApp())),
    (error, stack) {
      ErrorReporter.report(error, stack, source: 'zone');
    },
  );
}
