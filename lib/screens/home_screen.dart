import 'package:flutter/material.dart';
import 'package:edafitapp/services/auth_service.dart';
import 'package:edafitapp/services/food_diary_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDailyDiaryFromUser();
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
    final now = DateTime.now();
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
    return '${now.day} ${months[now.month - 1]} ${now.year} г.';
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
    if (mounted) setState(() {});
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
                                Text(
                                  _formatDate(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
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
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 150,
                                height: 150,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: (_getTotalCalories() / 1800).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      strokeWidth: 12,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.orange.shade400,
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${_getTotalCalories()}",
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          "ккал",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // БЖУ (Белки, Жиры, Углеводы)
              Row(
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
