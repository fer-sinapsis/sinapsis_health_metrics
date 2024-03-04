import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class HealthMetricsObservers {
  static const MethodChannel _channel =
      MethodChannel('health_metrics_observers');

  static void newWorkoutsNotificationHandler(Function(Map<String, dynamic> data) handler) async {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == "workout_local_notification_tapped" && call.arguments != null) {
       final notificationData = Map<String, dynamic>.from(call.arguments);
       if (notificationData != null) {
         handler(notificationData);
       }
      }
    });
  }

  static Future<String?> getExternalWorkoutsNotificationData() async {
    String? data  = await _channel.invokeMethod('getExternalWorkoutsNotificationData');
    return data;
  }

  static void currentWorkoutsDataUpdatesiOS(Function(Map<String, dynamic> data) handler) async {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == "current_workout_data_update") {
        var dataMap = Map<String, dynamic>.from(call.arguments);
        if (dataMap != null) {
          handler(dataMap);
        }
      }
    });
  }

  static Future<bool> createObserverWithServerSync({
    required String apiUrl,
    required String endpoint,
    required String userId,
    required String userApiKey,
    required String xApiKey,
    required String metricType,
  }) async {
    bool created = await _channel.invokeMethod('createObserver', {
      "apiUrl": apiUrl,
      "endpoint": endpoint,
      "userId": userId,
      "userApiKey": userApiKey,
      "xApiKey": xApiKey,
      "metricType": metricType,
      "shouldSyncToServer": true,
    });
    return created;
  }

  static Future<bool> createObserverNoServerSync({
    required String metricType,
    String? metadata,
  }) async {
    var args = {
      "metricType": metricType,
      "shouldSyncToServer": false
    };
    if (metadata != null) {
      args["metadata"] = metadata;
    }
    bool created = await _channel.invokeMethod('createObserver', args);
    return created;
  }

  static Future<List<Map<String, dynamic>>> getValidExternalWorkouts(DateTime startDate, DateTime endDate) async {
    final startDateInSecs = startDate.millisecondsSinceEpoch/1000;
    final endDateInSecs = endDate.millisecondsSinceEpoch/1000;
    final result = await _channel.invokeListMethod<Map?>(
        'getValidExternalWorkouts',
        {"startDateInSecs": startDateInSecs, "endDateInSecs": endDateInSecs}
    );
    if(result != null) {
      final nonNull = result.where((e) => e != null).toList();
      return nonNull.map((e) => Map<String, dynamic>.from(e!)).toList();
    } else {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getWorkoutsInInterval(DateTime startDate, DateTime endDate) async {
    final startDateInSecs = startDate.millisecondsSinceEpoch/1000;
    final endDateInSecs = endDate.millisecondsSinceEpoch/1000;
    final result = await _channel.invokeListMethod<Map?>(
        'getWorkoutsInInterval',
        {"startDateInSecs": startDateInSecs, "endDateInSecs": endDateInSecs}
    );
    if(result != null) {
      final nonNull = result.where((e) => e != null).toList();
      return nonNull.map((e) => Map<String, dynamic>.from(e!)).toList();
    } else {
      return [];
    }
  }

  static Future<void> createWorkout({
    required DateTime startDate,
    required DateTime endDate,
    required String activityPlatformId,
    required String metricsSupported,
    required String activitySegmentString,
  }) async {
    final startDateInSecs = startDate.millisecondsSinceEpoch/1000;
    final endDateInSecs = endDate.millisecondsSinceEpoch/1000;
    final params = {
      "startDateInSecs": startDateInSecs,
      "endDateInSecs": endDateInSecs,
      "activityPlatformId": activityPlatformId,
      "metricsSupported": metricsSupported,
      "activitySegments": activitySegmentString,
    };
    await _channel.invokeMethod('createWorkout', params);
  }

  static Future<Map<String, dynamic>?> getDataForWorkoutInProgress({required String activitySegmentsString, required metricsSupported}) async {
    final params =  {"activitySegments": activitySegmentsString, "metricsSupported": metricsSupported};
    final result = await _channel.invokeMethod<Map>('getDataForWorkoutInProgress', params);
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  static Future<void> requestPermissionsForWorkouts() async {
    await _channel.invokeMethod('requestPermissionsForWorkouts');
  }

  static Future<bool> validatePermissionsForWorkouts() async {
    return (await _channel.invokeMethod<bool>('validatePermissionsForWorkouts')) ?? false;
  }

  static Future<void> startWorkoutObserversiOS({
    required String activityPlatformId,
    required metricsSupported,
    required name,
    required imageUrl,
  }) async {
    if (Platform.isIOS) {
      final params = {
        "activityPlatformId": activityPlatformId,
        "metricsSupported": metricsSupported,
        "name": name,
        "imageUrl": imageUrl,
      };
      await _channel.invokeMethod('startWorkoutObservers', params);
    }
  }

  static Future<void> pauseWorkoutObserversiOS({required String activitySegmentString}) async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('pauseWorkoutObservers', {"activitySegments": activitySegmentString});
    }
  }

  static Future<void> resumeWorkoutObserversiOS({required String activitySegmentString}) async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('resumeWorkoutObservers', {"activitySegments": activitySegmentString});
    }
  }

  static Future<void> stopWorkoutObserversiOS() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('stopWorkoutObservers');
    }
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

  static Future<void> updateApiUrl(String apiUrl) async {
    await _channel.invokeMethod('updateApiUrl', {"newApiUrl": apiUrl});
  }

  static Future<bool> isObserverSyncing() async {
    final syncing = (await _channel.invokeMethod('isObserverSyncing'));
    return syncing;
  }
}