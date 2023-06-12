import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:health_metrics_observers/health_metrics_observers.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _message = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    if (!mounted) return;
    final resultMessage =
        await testFnThatRequiresPermissions(testGetStepsCountByInterval);
    setState(() {
      _message = resultMessage;
    });
  }

  Future<String> testGetStepsCountByInterval() async {
    final now = DateTime.now();
    DateTime startDay = now.subtract(Duration(
        hours: now.hour,
        minutes: now.minute,
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond));
    DateTime startDate = startDay.add(const Duration(hours: 6, minutes: 00));
    final endDate = startDate.add(const Duration(minutes: 180));
    const interval = TimeInterval.hour;
    String resultMessage;
    try {
      final results = await HealthMetricsObservers.getStepsCountByIntervals(
          startDate, endDate, interval);
      resultMessage = results.toString();
    } catch (e) {
      resultMessage = e.toString();
    }
    return resultMessage;
  }

  Future<void> testLastSaved() async {
    String resultMessage;
    try {
      final nowTime = DateTime.now();
      await HealthMetricsObservers.updateLastDateSaved(
          newDateInMilliseconds: nowTime.millisecondsSinceEpoch,
          metricType: "SLEEP");
      await HealthMetricsObservers.updateLastDateSaved(
          newDateInMilliseconds:
              nowTime.subtract(Duration(hours: 6)).millisecondsSinceEpoch,
          metricType: "STEP");
      final lastSavedStep =
          await HealthMetricsObservers.getLastDateSaved(metricType: "STEP");
      final lastSavedStepDate =
          DateTime.fromMillisecondsSinceEpoch(lastSavedStep ?? 0);

      final lastSavedSleep =
          await HealthMetricsObservers.getLastDateSaved(metricType: "SLEEP");
      final lastSavedSleepDate =
          DateTime.fromMillisecondsSinceEpoch(lastSavedSleep ?? 0);

      resultMessage = "sleep: $lastSavedSleepDate step: $lastSavedStepDate";
    } catch (exception) {
      resultMessage = 'Failed to create observer.';
    }
    setState(() {
      _message = resultMessage;
    });
  }

  Future<void> testObserver() async {
    String resultMessage;
    try {
      final permissionsGranted = await requestPermissionsForSteps();
      if (permissionsGranted) {
        //await HealthMetricsObservers.updateLastDateSaved(DateTime.now().millisecondsSinceEpoch);
        await HealthMetricsObservers.createStepCountObserver(
            apiUrl: "https://api.stage.trysinapsis.com",
            endpoint: "/api/profile/public/metrics",
            userId: Platform.isIOS
                ? "ccbbbd98-a9a2-435e-a694-3e3004a71e73"
                : "ccbbbd98-a9a2-435e-a694-3e3004a71e73",
            userApiKey: Platform.isIOS
                ? "791e033d-4134-4b27-99f7-955e4624ba67"
                : "791e033d-4134-4b27-99f7-955e4624ba67",
            xApiKey: "F0mHuKprUe6OCJLIi5u1P1sZWD8TNaDu7scEw9r3");
        resultMessage = "success created observer";
      } else {
        resultMessage = 'permissions not granted.';
      }
    } catch (exception) {
      resultMessage = 'Failed to create observer.';
    }
    setState(() {
      _message = resultMessage;
    });
  }

  Future<String> testFnThatRequiresPermissions(
      Future<String> Function() fn) async {
    String resultMessage;
    try {
      final permissionsGranted = await requestPermissionsForSteps();
      if (permissionsGranted) {
        resultMessage = await fn();
      } else {
        resultMessage = 'permissions not granted.';
      }
    } catch (exception) {
      resultMessage = 'Failed to create observer.';
    }
    return resultMessage;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text(_message),
        ),
      ),
    );
  }

  static Future<bool> requestPermissionsForSteps() async {
    bool accessWasGranted = false;
    bool permissionsStillGranted = false;
    bool activityPermission = true;
    bool appInstalled = true;

    if (Platform.isAndroid) {
      final activityPermissionResult =
          await Permission.activityRecognition.request();
      activityPermission = activityPermissionResult.isGranted;
      //const appId = 'com.google.android.apps.fitness';
      //appInstalled = await LaunchApp.isAppInstalled(androidPackageName: appId);
    }

    if (activityPermission) {
      List<HealthDataType> types = [HealthDataType.STEPS];
      List<HealthDataAccess> dataPermissions = [HealthDataAccess.READ];
      accessWasGranted = await HealthFactory()
          .requestAuthorization(types, permissions: dataPermissions);
      permissionsStillGranted =
          accessWasGranted && Platform.isAndroid ? true : false;

      if (Platform.isIOS && accessWasGranted) {
        DateTime endDate = DateTime.now();
        final weekStepsCount = await getHealthStepsCount(
          endDate.subtract(const Duration(days: 7)),
          endDate,
        );
        // we still have permissions if there is data more than a week
        permissionsStillGranted = weekStepsCount > 0;
      }
    }
    return accessWasGranted && permissionsStillGranted;
  }

  static Future<int> getHealthStepsCount(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final steps =
          await HealthFactory().getTotalStepsInInterval(startDate, endDate);
      return steps ?? 0;
    } catch (exception, stack) {
      return 0;
    }
  }
}
