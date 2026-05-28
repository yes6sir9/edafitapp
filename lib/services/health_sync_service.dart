import 'dart:io' show Platform;

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthSyncResult {
  final bool connected;
  final String platform;
  final int stepsToday;
  final double activeCaloriesToday;
  final DateTime syncedAt;

  const HealthSyncResult({
    required this.connected,
    required this.platform,
    required this.stepsToday,
    required this.activeCaloriesToday,
    required this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
        'connected': connected,
        'platform': platform,
        'stepsToday': stepsToday,
        'activeCaloriesToday': activeCaloriesToday,
        'syncedAt': syncedAt.toIso8601String(),
      };
}

class HealthSyncService {
  final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<HealthSyncResult> connectAndSyncToday() async {
    await _health.configure();

    if (Platform.isAndroid) {
      final recognitionStatus = await Permission.activityRecognition.request();
      if (!recognitionStatus.isGranted) {
        throw Exception('Разрешите доступ к активности (шагам) в настройках Android.');
      }

      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _health.installHealthConnect();
        throw Exception(
          'Установите/обновите Health Connect и повторите подключение.',
        );
      }
    }

    final permissions = List<HealthDataAccess>.filled(
      _types.length,
      HealthDataAccess.READ,
    );

    final authorized = await _health.requestAuthorization(
      _types,
      permissions: permissions,
    );
    if (!authorized) {
      throw Exception(
        'Доступ к данным здоровья не предоставлен. Разрешите доступ в системном окне.',
      );
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;

    final steps =
        await _health.getTotalStepsInInterval(start, end, includeManualEntry: true) ?? 0;

    final points = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
    );

    final calories = _sumNumericValues(points);

    return HealthSyncResult(
      connected: true,
      platform: Platform.isIOS ? 'Apple Health' : 'Google Health Connect',
      stepsToday: steps,
      activeCaloriesToday: calories,
      syncedAt: now,
    );
  }

  double _sumNumericValues(List<HealthDataPoint> points) {
    var sum = 0.0;
    for (final point in points) {
      final value = point.value;
      if (value is NumericHealthValue) {
        sum += value.numericValue.toDouble();
      }
    }
    return sum;
  }
}
