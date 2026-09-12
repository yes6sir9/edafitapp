import 'package:flutter/material.dart';
import 'package:edafitapp/services/auth_service.dart';
import 'package:edafitapp/services/health_sync_service.dart';
import 'package:edafitapp/services/nutrition_service.dart';

class StatisticsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final ValueChanged<Map<String, dynamic>>? onUserDataUpdated;

  const StatisticsScreen({
    super.key,
    required this.userData,
    this.onUserDataUpdated,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedTab = 0; // 0 = Вес, 1 = Активность
  List<Map<String, dynamic>> _workouts = [];
  int _totalSteps = 0;
  int _currentWeight = 70;
  int _targetWeight = 60;
  final AuthService _authService = AuthService();
  final HealthSyncService _healthSyncService = HealthSyncService();
  bool _watchConnected = false;
  String _watchPlatform = '';
  double _watchActiveCalories = 0;
  DateTime? _lastHealthSyncAt;
  bool _isSyncingHealth = false;
  NutritionPlan? _nutritionPlan;
  late TextEditingController _currentWeightController;
  late TextEditingController _targetWeightController;

  @override
  void initState() {
    super.initState();
    _currentWeightController = TextEditingController();
    _targetWeightController = TextEditingController();
    _loadWorkoutsFromUserData();
    _loadWeightFromUserData();
    _applyHealthIntegrationFromUserData();
    _calculateNutritionPlan();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData != widget.userData) {
      _loadWorkoutsFromUserData();
      _loadWeightFromUserData();
      _applyHealthIntegrationFromUserData();
      _calculateNutritionPlan();
      setState(() {});
    }
  }

  int get _workoutCalories => _workouts.fold<int>(
    0,
    (sum, w) => sum + ((w['calories'] as num?)?.toInt() ?? 0),
  );

  int get _stepsCalories {
    if (_watchConnected && _watchActiveCalories > 0) {
      return _watchActiveCalories.round();
    }
    return (_totalSteps * 0.04).round();
  }

  String get _activityCaloriesLabel =>
      _watchConnected ? 'От смарт-часов' : 'От шагов';

  int get _baseCalories {
    final weight = _currentWeight.toDouble();
    final height = (widget.userData['height'] as num?)?.toDouble() ?? 175;
    final age = (widget.userData['age'] as num?)?.toDouble() ?? 25;
    final gender =
        (widget.userData['gender']?.toString().toLowerCase() ?? 'мужской');
    final s = gender.contains('жен') ? -161 : 5;
    return (9.99 * weight + 6.25 * height - 4.92 * age + s).round();
  }

  int get _totalActivityCalories =>
      _baseCalories + _stepsCalories + _workoutCalories;

  int get _goalCaloriesToBurn {
    final goal =
        widget.userData['goal']?.toString().toLowerCase() ?? 'похудение';
    final diff = _currentWeight - _targetWeight;
    if (goal.contains('похуд')) {
      return diff > 0 ? (diff * 7700).round() : 0;
    }
    return 0;
  }

  int get _dailyCaloriesToBurn {
    if (_goalCaloriesToBurn <= 0) return 0;
    return (_goalCaloriesToBurn / 7).round();
  }

  String _buildGoalCalorieText() {
    final goal = widget.userData['goal']?.toString() ?? 'Похудение';
    if (_goalCaloriesToBurn > 0) {
      return 'Для достижения цели "$goal" нужно дополнительно сжечь $_goalCaloriesToBurn ккал. Это примерно $_dailyCaloriesToBurn ккал в день.';
    }
    return 'Цель "$goal" либо уже достигнута, либо требует другого подхода для расчета калорий.';
  }

  Future<void> _showAddStepsDialog() async {
    final controller = TextEditingController(text: _totalSteps.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Обновить шаги'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Введите количество шагов',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim()) ?? _totalSteps;
              setState(() {
                _totalSteps = value.clamp(0, 150000);
              });
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _loadWorkoutsFromUserData() {
    final workoutsData = widget.userData['workouts'];
    if (workoutsData is List) {
      _workouts = workoutsData
          .map<Map<String, dynamic>>((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }
  }

  void _loadWeightFromUserData() {
    _currentWeight =
        (widget.userData['weight'] as num?)?.toInt() ?? _currentWeight;
    _targetWeight =
        (widget.userData['targetWeight'] as num?)?.toInt() ?? _targetWeight;
    _currentWeightController.text = _currentWeight.toString();
    _targetWeightController.text = _targetWeight.toString();
  }

  void _applyHealthIntegrationFromUserData() {
    final integration = widget.userData['healthIntegration'];
    if (integration is! Map) {
      _watchConnected = false;
      _watchPlatform = '';
      _watchActiveCalories = 0;
      _lastHealthSyncAt = null;
      return;
    }
    final data = Map<String, dynamic>.from(integration);
    final syncedAtRaw = data['syncedAt']?.toString();
    final connected = data['connected'] == true;

    _watchConnected = connected;
    _watchPlatform = (data['platform'] ?? '').toString();
    _watchActiveCalories =
        (data['activeCaloriesToday'] as num?)?.toDouble() ?? 0;
    _lastHealthSyncAt =
        syncedAtRaw == null ? null : DateTime.tryParse(syncedAtRaw);
    if (connected) {
      _totalSteps = (data['stepsToday'] as num?)?.toInt() ?? _totalSteps;
    }
  }

  Future<void> _syncSmartWatch() async {
    setState(() => _isSyncingHealth = true);
    try {
      final result = await _healthSyncService.connectAndSyncToday();
      final integration = result.toMap();
      await _authService.saveHealthIntegration(integration);
      if (!mounted) return;

      setState(() {
        _watchConnected = result.connected;
        _watchPlatform = result.platform;
        _watchActiveCalories = result.activeCaloriesToday;
        _lastHealthSyncAt = result.syncedAt;
        _totalSteps = result.stepsToday;
      });
      widget.onUserDataUpdated?.call({'healthIntegration': integration});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Смарт-часы: ${result.stepsToday} шагов, ${result.activeCaloriesToday.round()} ккал',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Синхронизация не удалась: ${_healthSyncService.formatUserError(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingHealth = false);
    }
  }

  void _calculateNutritionPlan() {
    _nutritionPlan = NutritionService.calculatePlan(widget.userData, _workouts);
  }

  @override
  void dispose() {
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkoutsToFirestore() async {
    await _authService.saveUserWorkouts(_workouts);
  }

  Future<void> _saveWeightToFirestore() async {
    await _authService.updateUserData(_authService.currentUser!.uid, {
      'weight': _currentWeight,
      'targetWeight': _targetWeight,
    });
  }

  List<Map<String, dynamic>> _getRecommendedWorkouts() {
    String goal = widget.userData['goal'] ?? 'Похудение';

    if (goal == 'Похудение') {
      return [
        {
          'name': 'Кардио (30 мин)',
          'calories': 300,
          'description': 'Бег, ходьба',
        },
        {
          'name': 'HIIT тренировка',
          'calories': 400,
          'description': 'Высокоинтенсивная',
        },
        {
          'name': 'Эллиптический тренажер',
          'calories': 250,
          'description': '30-40 мин',
        },
        {
          'name': 'Йога',
          'calories': 150,
          'description': 'Гибкость и расслабление',
        },
      ];
    } else if (goal == 'Набор мышц') {
      return [
        {
          'name': 'Силовая тренировка',
          'calories': 400,
          'description': 'Работа с весами',
        },
        {
          'name': 'Жим штанги',
          'calories': 350,
          'description': 'Верхняя часть тела',
        },
        {
          'name': 'Приседания',
          'calories': 380,
          'description': 'Ноги и ягодицы',
        },
        {
          'name': 'Тяга в наклоне',
          'calories': 320,
          'description': 'Спина и бицепсы',
        },
      ];
    } else {
      return [
        {'name': 'Умеренный бег', 'calories': 350, 'description': '20-30 мин'},
        {'name': 'Плавание', 'calories': 400, 'description': 'Полное давление'},
        {'name': 'Велосипед', 'calories': 300, 'description': '30-40 мин'},
        {
          'name': 'Легкая школьная тренировка',
          'calories': 280,
          'description': '40-60 мин',
        },
      ];
    }
  }

  void _showAddWorkoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Рекомендуемые тренировки',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._getRecommendedWorkouts().map((workout) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _workouts.add(workout);
                        _calculateNutritionPlan();
                      });
                      _saveWorkoutsToFirestore();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${workout['name']} добавлено!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(workout['description']!),
                              Text(
                                '${workout['calories']} ккал',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8DCE0), Color(0xFFEAF2D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Text(
                  "Статистика",
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
                ),
              ),
              // Вкладки Вес и Активность
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? const Color(0xFFA5C75D)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "Вес",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 0
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? const Color(0xFFA5C75D)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "Активность",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 1
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_selectedTab == 0) ...[
                // Вкладка Вес
                _buildWeightTab(),
              ] else ...[
                // Вкладка Активность
                _buildActivityTab(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightTab() {
    final weight = _currentWeight;
    final targetWeight = _targetWeight;
    final height = (widget.userData['height'] as num?)?.toInt() ?? 175;
    final goal = widget.userData['goal'] ?? 'Похудение';
    final age = (widget.userData['age'] as num?)?.toInt() ?? 25;

    // Расчет прогресса
    final totalWeightDifference = (weight - targetWeight).abs();
    final progressPercentage = totalWeightDifference > 0
        ? ((weight - targetWeight).abs() / totalWeightDifference * 100).clamp(
            0,
            100,
          )
        : 0;

    // Расчет ИМТ
    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);

    String getBmiCategory(double bmi) {
      if (bmi < 18.5) return 'Недостаточный вес';
      if (bmi < 25) return 'Нормальный вес';
      if (bmi < 30) return 'Избыточный вес';
      return 'Ожирение';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ваши данные
        const Text(
          "Ваши данные",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Текущий вес",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "$weight кг",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Целевой вес", style: TextStyle(fontSize: 14)),
                  Text(
                    "$targetWeight кг",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Необходимо изменить",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    "$totalWeightDifference кг",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: goal == 'Похудение' ? Colors.red : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Рост",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    "$height см",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Возраст",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    "$age лет",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Цель",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: goal == 'Похудение'
                          ? Colors.red.shade100
                          : goal == 'Набор мышц'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      goal,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: goal == 'Похудение'
                            ? Colors.red
                            : goal == 'Набор мышц'
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _currentWeightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Текущий вес',
                              suffixText: 'кг',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _targetWeightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Целевой вес',
                              suffixText: 'кг',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final currentValue = int.tryParse(
                            _currentWeightController.text.trim(),
                          );
                          final targetValue = int.tryParse(
                            _targetWeightController.text.trim(),
                          );
                          if (currentValue == null || targetValue == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Введите корректные значения веса',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _currentWeight = currentValue;
                            _targetWeight = targetValue;
                            _calculateNutritionPlan();
                          });
                          await _saveWeightToFirestore();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Вес сохранён')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Сохранить вес'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ИМТ (Индекс массы тела)",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        getBmiCategory(bmi),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Прогресс веса
        const Text(
          "Прогресс к цели",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.lightGreen.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.lightGreen.shade200),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 150,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progressPercentage / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(
                            goal == 'Похудение'
                                ? Colors.red.shade400
                                : goal == 'Набор мышц'
                                ? Colors.orange.shade400
                                : Colors.blue.shade400,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$totalWeightDifference кг",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: goal == 'Похудение'
                                  ? Colors.red.shade600
                                  : goal == 'Набор мышц'
                                  ? Colors.orange.shade600
                                  : Colors.blue.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal == 'Похудение' ? 'Осталось' : 'Нужно набрать',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.lightGreen.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "$totalWeightDifference кг",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Остаток",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.lightGreen.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "$targetWeight кг",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Целевой вес",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // BMI
        const Text(
          "Индекс массы тела (BMI)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Text(
                "22.9",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Нормальный вес",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildBMIRange("Недостаточный вес", "< 18.5", Colors.blue, false),
              const SizedBox(height: 8),
              _buildBMIRange(
                "Нормальный вес",
                "18.5 - 24.9",
                Colors.green,
                true,
              ),
              const SizedBox(height: 8),
              _buildBMIRange(
                "Избыточный вес",
                "25 - 29.9",
                Colors.orange,
                false,
              ),
              const SizedBox(height: 8),
              _buildBMIRange("Ожирение", "> 30", Colors.red, false),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActivityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_watchConnected) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.watch, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _watchPlatform.isEmpty
                            ? 'Смарт-часы подключены'
                            : _watchPlatform,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lastHealthSyncAt != null)
                        Text(
                          'Обновлено: ${_lastHealthSyncAt!.hour.toString().padLeft(2, '0')}:${_lastHealthSyncAt!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isSyncingHealth ? null : _syncSmartWatch,
                  child: Text(_isSyncingHealth ? 'Синхр...' : 'Обновить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Калории",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "$_totalActivityCalories",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Сожжено",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_nutritionPlan != null) ...[
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
                Row(
                  children: [
                    Icon(
                      Icons.auto_graph,
                      size: 18,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "План питания",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Поддержание: ${_nutritionPlan!.maintenanceCalories.toStringAsFixed(0)} ккал",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Цель: ${_nutritionPlan!.targetCalories.toStringAsFixed(0)} ккал",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  "Б: ${_nutritionPlan!.proteinGrams.toStringAsFixed(0)} г, "
                  "Ж: ${_nutritionPlan!.fatGrams.toStringAsFixed(0)} г, "
                  "У: ${_nutritionPlan!.carbGrams.toStringAsFixed(0)} г",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  _nutritionPlan!.activityExplanation,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Рекомендации по активности",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Рекомендуется ${_nutritionPlan!.recommendedWeeklyTrainings} тренировок в неделю.',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                ..._nutritionPlan!.trainingRecommendations.map((text) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '- $text',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Тренировки
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
              Row(
                children: [
                  Icon(
                    Icons.sports_gymnastics,
                    size: 18,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Тренировки",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${_workouts.length}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Кнопка добавления тренировки
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _showAddWorkoutDialog();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "Добавить тренировку",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Список добавленных тренировок
        if (_workouts.isNotEmpty) ...[
          const Text(
            'Ваши тренировки',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._workouts.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> workout = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${workout['calories']} ккал',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _workouts.removeAt(index);
                          _calculateNutritionPlan();
                        });
                        _saveWorkoutsToFirestore();
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],

        // Шаги за день
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _watchConnected
                            ? Icons.watch
                            : Icons.directions_walk,
                        size: 18,
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _watchConnected ? "Шаги со смарт-часов" : "Шаги за день",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_watchConnected)
                        IconButton(
                          icon: Icon(
                            Icons.sync,
                            color: Colors.blue.shade400,
                            size: 24,
                          ),
                          tooltip: 'Подключить смарт-часы',
                          onPressed:
                              _isSyncingHealth ? null : _syncSmartWatch,
                        ),
                      if (_watchConnected)
                        IconButton(
                          icon: Icon(
                            Icons.sync,
                            color: Colors.blue.shade400,
                            size: 24,
                          ),
                          tooltip: 'Обновить данные',
                          onPressed:
                              _isSyncingHealth ? null : _syncSmartWatch,
                        ),
                      if (!_watchConnected)
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Colors.green.shade400,
                            size: 24,
                          ),
                          onPressed: _showAddStepsDialog,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _watchConnected
                    ? "Синхронизировано с ${_watchPlatform.isEmpty ? 'часами' : _watchPlatform}"
                    : "Количество шагов",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                "$_totalSteps шагов",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_watchConnected && _watchActiveCalories > 0) ...[
                const SizedBox(height: 6),
                Text(
                  "${_watchActiveCalories.round()} ккал активности",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Общий расход калорий
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.lightGreen.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.lightGreen.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Общий расход калорий",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCalorieRow(
                "Базовый обмен",
                "${_nutritionPlan?.bmr.toStringAsFixed(0) ?? _baseCalories} ккал",
                Colors.green,
              ),
              const SizedBox(height: 8),
              _buildCalorieRow(
                _activityCaloriesLabel,
                "${_stepsCalories} ккал",
                Colors.grey,
              ),
              const SizedBox(height: 8),
              _buildCalorieRow(
                "От тренировок",
                "${_workoutCalories} ккал",
                Colors.grey,
              ),
              if (_nutritionPlan != null) ...[
                const SizedBox(height: 8),
                _buildCalorieRow(
                  "Поддержание",
                  "${_nutritionPlan!.maintenanceCalories.toStringAsFixed(0)} ккал",
                  Colors.green.shade700,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Итого",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${_nutritionPlan?.dailyEnergyBudget.toStringAsFixed(0) ?? _totalActivityCalories} ккал",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCalorieRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDayLabel(String day) {
    return Text(
      day,
      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
    );
  }

  Widget _buildBMIRange(
    String label,
    String range,
    Color color,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            range,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isActive ? color : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
