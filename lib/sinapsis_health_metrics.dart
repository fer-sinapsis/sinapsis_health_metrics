import 'dart:async';

import 'package:flutter/services.dart';

class SinapsisHealthMetrics {
  static const MethodChannel _channel =
      MethodChannel('co.sinapsis.sinapsis_health_metrics');

  static Future<bool> createStepCountObserver({
    required String apiUrl,
    required String endpoint,
    required String userId,
    required String userApiKey,
    required String xApiKey,
  }) async {
    bool created = await _channel.invokeMethod('createStepCountObserver', {
      "apiUrl": apiUrl,
      "endpoint": endpoint,
      "userId": userId,
      "userApiKey": userApiKey,
      "xApiKey": xApiKey,
    });
    return created;
  }

  static Future<int?> getLastDateSaved({required String metricType}) async {
    final result = await _channel
        .invokeMethod('getLastDateSaved', {"metricType": metricType});
    return result;
  }

  static Future<Map> getObserverStatus() async {
    final observerStatus = await _channel.invokeMethod('getObserverStatus');
    return observerStatus;
  }

  static Future<void> updateLastDateSaved(
      {required int newDateInMilliseconds, required String metricType}) async {
    await _channel.invokeMethod('updateLastDateSaved', {
      "newDateInMilliseconds": newDateInMilliseconds,
      "metricType": metricType
    });
  }

  static Future<bool> isObserverSyncing() async {
    final syncing = (await _channel.invokeMethod('isObserverSyncing'));
    return syncing;
  }
}
