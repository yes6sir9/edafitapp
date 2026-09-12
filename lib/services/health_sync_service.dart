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

  String formatUserError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('null') && message.contains('string')) {
      return 'Не удалось подключить источник здоровья. Обновите приложение Health Connect и повторите.';
    }
    if (message.contains('health connect')) {
      return 'Установите/обновите Health Connect и повторите подключение.';
    }
    if (message.contains('not provided') || message.contains('not granted')) {
      return 'Доступ к данным здоровья не предоставлен. Разрешите доступ в системном окне.';
    }
    if (message.startsWith('exception: ')) {
      return error.toString().substring('Exception: '.length);
    }
    return 'Не удалось подключить здоровье. Проверьте разрешения и повторите.';
  }

  Future<HealthSyncResult> connectAndSyncToday() async {
    try {
      await _health.configure();
    } catch (e) {
      throw Exception(formatUserError(e));
    }

    if (Platform.isAndroid) {
      final recognitionStatus = await Permission.activityRecognition.request();
      if (!recognitionStatus.isGranted) {
        throw Exception('Разрешите доступ к активности (шагам) в настройках Android.');
      }

      HealthConnectSdkStatus? status;
      try {
        status = await _health.getHealthConnectSdkStatus();
      } catch (e) {
        throw Exception(formatUserError(e));
      }
      if (status == null || status != HealthConnectSdkStatus.sdkAvailable) {
        try {
          await _health.installHealthConnect();
        } catch (_) {
          // Best effort: still show actionable message below.
        }
        throw Exception(
          'Установите/обновите Health Connect и повторите подключение.',
        );
      }
    }

    final permissions = List<HealthDataAccess>.filled(
      _types.length,
      HealthDataAccess.READ,
    );

    final bool authorized;
    try {
      authorized = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
    } catch (e) {
      throw Exception(formatUserError(e));
    }
    if (!authorized) {
      throw Exception(
        'Доступ к данным здоровья не предоставлен. Разрешите доступ в системном окне.',
      );
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;

    final int steps;
    try {
      steps =
          await _health.getTotalStepsInInterval(start, end, includeManualEntry: true) ?? 0;
    } catch (e) {
      throw Exception(formatUserError(e));
    }

    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
    } catch (e) {
      throw Exception(formatUserError(e));
    }

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
