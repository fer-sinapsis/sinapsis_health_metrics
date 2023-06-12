import 'dart:async';

import 'package:flutter/services.dart';

class HealthMetricsObservers {
  static const MethodChannel _channel =
      MethodChannel('health_metrics_observers');

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
    final result = await _channel.invokeMethod('getLastDateSaved', {"metricType": metricType});
    return result;
  }

  static Future<Map> getObserverStatus() async {
    final observerStatus = await _channel.invokeMethod('getObserverStatus');
    return observerStatus;
  }

  static Future<void> updateLastDateSaved({ required int newDateInMilliseconds, required String metricType}) async {
    await _channel.invokeMethod('updateLastDateSaved', {"newDateInMilliseconds": newDateInMilliseconds, "metricType": metricType});
  }

  static Future<bool> isObserverSyncing() async {
    final syncing = (await _channel.invokeMethod('isObserverSyncing'));
    return syncing;
  }

  static Future<List<Map<String, dynamic>>> getStepsCountByIntervals(DateTime startDate, DateTime endDate, TimeInterval interval) async {
    final args = {
      'startDateMillisecs': startDate.millisecondsSinceEpoch,
      'endDateMillisecs': endDate.millisecondsSinceEpoch,
      'interval': interval.name
    };
    final result = await _channel.invokeListMethod<Map?>('getStepsCountByIntervals', args);
    if(result != null) {
      final nonNull = result.where((e) => e != null).toList();
      return nonNull.map((e) => Map<String, dynamic>.from(e!)).toList();
    } else {
      return [];
    }
  }
}

enum TimeInterval {
  hour,
  day,
  week
}