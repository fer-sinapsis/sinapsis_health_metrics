import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_metrics_observers/health_metrics_observers.dart';

void main() {
  const MethodChannel channel = MethodChannel('health_metrics_observers');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });
  
}
