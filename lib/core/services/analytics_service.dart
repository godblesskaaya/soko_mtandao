import 'dart:convert';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  void track(
    String event, {
    Map<String, dynamic>? params,
  }) {
    final payload = <String, dynamic>{
      'event': event,
      'params': params ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    debugPrint('[analytics] ${jsonEncode(payload)}');
  }
}
