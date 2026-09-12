import 'package:flutter/material.dart';
import 'package:edafitapp/services/auth_service.dart';
import 'package:edafitapp/services/food_diary_service.dart';
import 'package:edafitapp/services/ai_service.dart';
import 'package:edafitapp/services/nutrition_service.dart';
import 'package:edafitapp/widgets/food_photo_analyzer_sheet.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FoodDiaryService _diaryService = FoodDiaryService.instance;
  final AuthService _authService = AuthService();
  final AIService _aiService = AIService();

  late DateTime _selectedDate;
  NutritionPlan? _nutritionPlan;
  String? _aiAdvice;
  bool _aiAdviceLoading = false;
  final Map<String, String> _aiAdviceCache = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _diaryService.setActiveDate(_selectedDate);
    _loadDailyDiaryFromUser();
    _calculateNutritionPlan();
    _fetchAiAdvice();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData['dailyDiary'] != widget.userData['dailyDiary']) {
      _loadDailyDiaryFromUser();
    }
  }

  void _loadDailyDiaryFromUser() {
    final dailyDiaryData = widget.userData['dailyDiary'];
    if (dailyDiaryData is Map<String, dynamic>) {
      _diaryService.loadDailyDiary(dailyDiaryData);
    } else if (dailyDiaryData is Map) {
      _diaryService.loadDailyDiary(Map<String, dynamic>.from(dailyDiaryData));
    } else {
      _diaryService.loadDailyDiary(null);
    }
  }

  Future<void> _saveDailyDiaryToFirestore() async {
    final existingDiary = widget.userData['dailyDiary'];
    final diaryMap = existingDiary is Map<String, dynamic>
        ? existingDiary
        : existingDiary is Map
        ? Map<String, dynamic>.from(existingDiary)
        : null;

    final dailyDiary = _diaryService.buildDailyDiaryPayload(diaryMap);
    widget.userData['dailyDiary'] = dailyDiary;
    await _authService.saveUserDailyDiary(dailyDiary);
  }

  String _formatDate() {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year} г.';
  }

  String _formatSelectedDateLabel() {
    final today = DateTime.now();
    if (_isSameDay(_selectedDate, today)) return 'Сегодня';
    if (_isSameDay(
      _selectedDate,
      today.subtract(const Duration(days: 1)),
    )) {
      return 'Вчера';
    }
    return _formatDate();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _canGoForward => !_isSameDay(_selectedDate, _todayDate);

  void _calculateNutritionPlan() {
    final workoutsData = widget.userData['workouts'];
    final workouts = <Map<String, dynamic>>[];
    if (workoutsData is List) {
      for (final workout in workoutsData) {
        if (workout is Map<String, dynamic>) {
          workouts.add(workout);
        } else if (workout is Map) {
          workouts.add(Map<String, dynamic>.from(workout));
        }
      }
    }
    _nutritionPlan = NutritionService.calculatePlan(widget.userData, workouts);
  }

  int _getTargetCalories() {
    return (_nutritionPlan?.targetCalories ?? 1800).round();
  }

  Future<void> _shiftDay(int delta) async {
    final current = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final newDate = current.add(Duration(days: delta));
    if (newDate.isAfter(_todayDate)) return;

    await _saveDailyDiaryToFirestore();

    setState(() {
      _selectedDate = newDate;
      _diaryService.setActiveDate(_selectedDate);
    });
    _loadDailyDiaryFromUser();
    await _fetchAiAdvice();
  }

  Future<void> _fetchAiAdvice({bool forceRefresh = false}) async {
    final dateKey = FoodDiaryService.dateKey(_selectedDate);
    if (!forceRefresh && _aiAdviceCache.containsKey(dateKey)) {
      setState(() {
        _aiAdvice = _aiAdviceCache[dateKey];
        _aiAdviceLoading = false;
      });
      return;
    }

    setState(() {
      _aiAdviceLoading = true;
      if (forceRefresh) _aiAdvice = null;
    });

    _calculateNutritionPlan();
    final plan = _nutritionPlan;
    if (plan == null) {
      if (mounted) {
        setState(() => _aiAdviceLoading = false);
      }
      return;
    }

    final advice = await _aiService.generateDailyNutritionTip(
      goal: plan.goal,
      dateLabel: _formatSelectedDateLabel(),
      eatenCalories: _getTotalCalories(),
      eatenProteins: _diaryService.getTotalProteins(),
      eatenFats: _diaryService.getTotalFats(),
      eatenCarbs: _diaryService.getTotalCarbs(),
      targetCalories: plan.targetCalories.round(),
      targetProteins: plan.proteinGrams,
      targetFats: plan.fatGrams,
      targetCarbs: plan.carbGrams,
      meals: _diaryService.eatenRecipes.value,
    );

    if (!mounted) return;

    _aiAdviceCache[dateKey] = advice;
    setState(() {
      _aiAdvice = advice;
      _aiAdviceLoading = false;
    });
  }

  Widget _buildAiAdviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE6CF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFA5C75D).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF6B8F3D),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Совет дня',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF24292E),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Обновить совет',
                onPressed: _aiAdviceLoading
                    ? null
                    : () => _fetchAiAdvice(forceRefresh: true),
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: _aiAdviceLoading ? Colors.grey : const Color(0xFF6B8F3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_aiAdviceLoading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Готовлю персональный совет...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            )
          else
            Text(
              _aiAdvice ?? 'Совет появится после загрузки.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF4A4A4A),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSwitcher() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _shiftDay(-1),
          icon: const Icon(Icons.chevron_left, size: 28),
          color: const Color(0xFF24292E),
        ),
        Column(
          children: [
            Text(
              _formatSelectedDateLabel(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isSameDay(_selectedDate, _todayDate))
              Text(
                _formatDate(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _canGoForward ? () => _shiftDay(1) : null,
          icon: const Icon(Icons.chevron_right, size: 28),
          color: _canGoForward
              ? const Color(0xFF24292E)
              : Colors.grey.shade400,
        ),
      ],
    );
  }

  int _getTotalCalories() {
    return _diaryService.getTotalCalories().round();
  }

  int _getTotalProteins() {
    return _diaryService.getTotalProteins().round();
  }

  int _getTotalFats() {
    return _diaryService.getTotalFats().round();
  }

  int _getTotalCarbs() {
    return _diaryService.getTotalCarbs().round();
  }

  List<Widget> _buildMealGroups(List<Map<String, dynamic>> eatenRecipes) {
    final mealLabels = {
      'Завтрак': '🌅 Завтрак',
      'Обед': '☀️ Обед',
      'Ужин': '🌙 Ужин',
      'Перекус': '🍎 Перекус',
      'Другие': '🍽️ Другие',
    };

    final groupedMeals = <String, List<Map<String, dynamic>>>{};
    for (final dish in eatenRecipes) {
      final categoryValue = dish['category']?.toString().trim();
      final category =
          categoryValue != null && categoryValue.isNotEmpty ? categoryValue : 'Другие';

      groupedMeals.putIfAbsent(category, () => []).add(dish);
    }

    if (groupedMeals.isEmpty) return [];

    final orderedCategories = [
      'Завтрак',
      'Обед',
      'Ужин',
      'Перекус',
      ...groupedMeals.keys.where(
        (category) => !['Завтрак', 'Обед', 'Ужин', 'Перекус'].contains(category),
      ),
    ];

    return orderedCategories
        .where((category) => groupedMeals[category]?.isNotEmpty ?? false)
        .map((category) {
          final dishesForMeal = groupedMeals[category]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealLabels[category] ?? category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...dishesForMeal.map((dish) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                                  dish['title'] ?? dish['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${dish['calories']} ккал • Б:${dish['proteins']} Ж:${dish['fats']} У:${dish['carbs']}',
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
                            onPressed: () async {
                              setState(() {
                                _diaryService.removeDiaryEntry(
                                  dish['entryId'] as String,
                                );
                              });
                              await _saveDailyDiaryToFirestore();
                              _aiAdviceCache.remove(
                                FoodDiaryService.dateKey(_selectedDate),
                              );
                              await _fetchAiAdvice(forceRefresh: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        })
        .toList();
  }

  Future<void> _openFoodPhotoAnalyzer() async {
    await showFoodPhotoAnalyzerSheet(
      context,
      onDiarySaved: _saveDailyDiaryToFirestore,
    );
    if (!mounted) return;
    setState(() {});
    _aiAdviceCache.remove(FoodDiaryService.dateKey(_selectedDate));
    await _fetchAiAdvice(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFoodPhotoAnalyzer,
        backgroundColor: const Color(0xFFA5C75D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Фото еды'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _diaryService.eatenRecipes,
                builder: (context, eatenRecipes, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Дата и калории
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.pink.shade100, Colors.yellow.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Дневник питания",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDateSwitcher(),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    color: Color(0xFFE94D70),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${_getTotalCalories()}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Калории круговой граф
                      Center(
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: (_getTotalCalories() /
                                          _getTargetCalories())
                                      .clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  strokeWidth: 14,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: const Color(0xFFE8E8E8),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFFFA726),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${_getTotalCalories()}",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF24292E),
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "ккал",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF999999),
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _getTotalCalories() >= _getTargetCalories()
                              ? 'Перебор на ${_getTotalCalories() - _getTargetCalories()} ккал'
                              : 'Осталось ${_getTargetCalories() - _getTotalCalories()} ккал из ${_getTargetCalories()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _getTotalCalories() > _getTargetCalories()
                                ? Colors.red.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAiAdviceCard(),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // БЖУ (Белки, Жиры, Углеводы)
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _diaryService.eatenRecipes,
                builder: (context, eatenRecipes, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMacroCard(
                        "Белки",
                        "${_getTotalProteins()}г",
                        const Color(0xFFDDE6CF),
                      ),
                      _buildMacroCard(
                        "Жиры",
                        "${_getTotalFats()}г",
                        const Color(0xFFF0E8E8),
                      ),
                      _buildMacroCard(
                        "Углеводы",
                        "${_getTotalCarbs()}г",
                        const Color(0xFFDDE6CF),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              const Text(
                "Ваш дневник питания",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _diaryService.eatenRecipes,
                builder: (context, eatenRecipes, child) {
                  if (eatenRecipes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Text(
                        'Пока нет съеденных рецептов. Перейдите во вкладку Рецепты и добавьте блюда в дневник.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Всего рецептов: ${eatenRecipes.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildMealGroups(eatenRecipes),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
