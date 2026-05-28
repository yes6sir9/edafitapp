import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/health_sync_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final ValueChanged<Map<String, dynamic>>? onUserDataUpdated;

  const ProfileScreen({
    super.key,
    required this.userData,
    this.onUserDataUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final HealthSyncService _healthSyncService = HealthSyncService();
  bool _isWatchConnected = false;
  String _watchPlatform = '';
  int _todaySteps = 0;
  double _todayActiveCalories = 0;
  DateTime? _lastHealthSyncAt;
  bool _isSyncingHealth = false;

  @override
  void initState() {
    super.initState();
    _applyHealthIntegrationFromUserData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData != widget.userData) {
      _applyHealthIntegrationFromUserData();
    }
  }

  void _applyHealthIntegrationFromUserData() {
    final integration = widget.userData['healthIntegration'];
    if (integration is! Map) return;
    final data = Map<String, dynamic>.from(integration);
    final syncedAtRaw = data['syncedAt']?.toString();

    setState(() {
      _isWatchConnected = data['connected'] == true;
      _watchPlatform = (data['platform'] ?? '').toString();
      _todaySteps = (data['stepsToday'] as num?)?.toInt() ?? 0;
      _todayActiveCalories = (data['activeCaloriesToday'] as num?)?.toDouble() ?? 0;
      _lastHealthSyncAt = syncedAtRaw == null ? null : DateTime.tryParse(syncedAtRaw);
    });
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы вышли из аккаунта')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выхода: $e')),
      );
    }
  }

  Future<void> _connectSmartWatch() async {
    setState(() => _isSyncingHealth = true);
    try {
      final result = await _healthSyncService.connectAndSyncToday();
      if (!mounted) return;

      final integration = result.toMap();
      await _authService.saveHealthIntegration(integration);
      if (!mounted) return;

      setState(() {
        _isWatchConnected = result.connected;
        _watchPlatform = result.platform;
        _todaySteps = result.stepsToday;
        _todayActiveCalories = result.activeCaloriesToday;
        _lastHealthSyncAt = result.syncedAt;
      });

      widget.onUserDataUpdated?.call({'healthIntegration': integration});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Синхронизация завершена: $_todaySteps шагов, ${_todayActiveCalories.round()} ккал',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось подключить: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSyncingHealth = false);
    }
  }

  Future<void> _disconnectSmartWatch() async {
    final oldWatch = _watchPlatform;
    final integration = <String, dynamic>{
      'connected': false,
      'platform': '',
      'stepsToday': 0,
      'activeCaloriesToday': 0.0,
      'syncedAt': DateTime.now().toIso8601String(),
    };

    await _authService.saveHealthIntegration(integration);
    if (!mounted) return;
    widget.onUserDataUpdated?.call({'healthIntegration': integration});
    setState(() {
      _isWatchConnected = false;
      _watchPlatform = '';
      _todaySteps = 0;
      _todayActiveCalories = 0;
      _lastHealthSyncAt = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          oldWatch.isEmpty ? 'Смарт-часы отключены' : '$oldWatch отключены',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.userData['name'] ?? 'Гость';
    final String email = widget.userData['email'] ?? 'Не задан';
    final String goal = widget.userData['goal'] ?? 'Не указано';
    final String gender = widget.userData['gender'] ?? 'Не указано';
    final String weight = widget.userData['weight'] != null ? '${widget.userData['weight']}' : '-';
    final String height = widget.userData['height'] != null ? '${widget.userData['height']}' : '-';
    final String targetWeight = widget.userData['targetWeight'] != null ? '${widget.userData['targetWeight']}' : '-';
    final int workoutsCount = (widget.userData['workouts'] as List?)?.length ?? 0;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7D9DE), Color(0xFFE9F2D3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(name, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),
              // Заголовок с пользователем
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Параметры (Цель, Вес, Рост)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Цель",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      goal,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Вес (кг)",
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "$weight кг",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Рост (см)",
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "$height см",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Тренировки",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$workoutsCount",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Целевой вес
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lightGreen.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.lightGreen.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Целевой вес",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Ваша цель:",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "$targetWeight кг",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Аватар и ID
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Информация
              const Text(
                "Информация",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _buildInformationField("Имя", name),
              const SizedBox(height: 12),
              _buildInformationField("Email", email),
              const SizedBox(height: 12),
              _buildInformationField("Цель", goal),
              const SizedBox(height: 12),
              _buildInformationField("Пол", gender),
              const SizedBox(height: 12),
              _buildInformationField("Вес", "$weight кг"),
              const SizedBox(height: 12),
              _buildInformationField("Рост", "$height см"),
              const SizedBox(height: 12),
              _buildInformationField("Целевой вес", "$targetWeight кг"),
              const SizedBox(height: 32),

              const Text(
                "Устройства",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.watch,
                      color: _isWatchConnected
                          ? Colors.green.shade600
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Смарт-часы",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isWatchConnected
                                ? 'Подключены: ${_watchPlatform.isEmpty ? "Сервис здоровья" : _watchPlatform}'
                                : 'Не подключены',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isWatchConnected
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (_isWatchConnected) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Сегодня: $_todaySteps шагов • ${_todayActiveCalories.round()} ккал',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (_lastHealthSyncAt != null)
                              Text(
                                'Обновлено: ${_lastHealthSyncAt!.hour.toString().padLeft(2, '0')}:${_lastHealthSyncAt!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _isSyncingHealth
                          ? null
                          : _isWatchConnected
                          ? _disconnectSmartWatch
                          : _connectSmartWatch,
                      child: Text(
                        _isSyncingHealth
                            ? 'Синхр...'
                            : _isWatchConnected
                                ? 'Отключить'
                                : 'Добавить',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    "Выйти из аккаунта",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.yellow.shade100),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
