import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:soko_mtandao/core/config/map_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    await Supabase.initialize(
    url: 'https://wqmarlzyzukreiwibwjs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxbWFybHp5enVrcmVpd2lid2pzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM3Njk1MTksImV4cCI6MjA2OTM0NTUxOX0.4vlxDetKBOC8xIh4alJVoj0vOWw64YEWHb6uAqDWxG8',
  );

   MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);

  runApp(const ProviderScope(child: MyApp()));
}