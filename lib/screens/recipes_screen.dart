import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:edafitapp/services/ai_service.dart';
import 'package:edafitapp/services/recipe_service.dart';
import 'package:edafitapp/services/recipe_rag_service.dart';
import 'package:edafitapp/services/food_diary_service.dart';
import 'package:edafitapp/services/auth_service.dart';
import 'package:edafitapp/services/nutrition_service.dart';
import 'package:edafitapp/widgets/product_photo_sheet.dart';
import 'package:edafitapp/widgets/add_custom_recipe_sheet.dart';
import 'package:edafitapp/widgets/products_recipes_sheet.dart';
import 'package:edafitapp/services/products_recipe_service.dart';

class RecipesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RecipesScreen({super.key, required this.userData});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  int _selectedTab = 0;
  int _selectedView = 0;
  Set<int> _favoriteRecipes = {};
  List<Recipe> _recipes = [];
  final AIService _aiService = AIService();
  final RecipeService _recipeService = RecipeService();
  final RecipeRagService _ragService = RecipeRagService();
  final ProductsRecipeService _productsRecipeService = ProductsRecipeService();
  final FoodDiaryService _diaryService = FoodDiaryService.instance;
  final AuthService _authService = AuthService();
  final List<Map<String, String>> _aiChatMessages = [];
  final TextEditingController _aiPromptController = TextEditingController();
  bool _aiIsLoading = false;
  bool _recipesLoading = true;
  String? _recipesError;
  List<Recipe> _aiRecommendedRecipes = [];
  bool _showAiRecommendationsPanel = false;
  List<Map<String, dynamic>> _myProducts = [];
  List<Map<String, dynamic>> _customRecipeMaps = [];

  final List<String> _categories = ["Завтрак", "Обед", "Ужин", "Перекус"];

  NutritionPlan? _nutritionPlan;
  double _targetCalories = 0;
  double _maintenanceCalories = 0;
  double _bmr = 0;
  double _activityFactor = 1.4;
  double _targetProtein = 0;
  double _targetFat = 0;
  double _targetCarbs = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProductsAndCustomRecipes();
    _initializePersonalizedRecipes();
    _loadDiaryFromUserData();
  }

  void _loadUserProductsAndCustomRecipes() {
    final productsData = widget.userData['products'];
    if (productsData is List) {
      _myProducts = productsData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final customData = widget.userData['customRecipes'];
    if (customData is List) {
      _customRecipeMaps = customData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  void _loadDiaryFromUserData() {
    _diaryService.resetActiveDateToToday();
    final dailyDiaryData = widget.userData['dailyDiary'];
    if (dailyDiaryData is Map<String, dynamic>) {
      _diaryService.loadDailyDiary(dailyDiaryData);
    } else if (dailyDiaryData is Map) {
      _diaryService.loadDailyDiary(Map<String, dynamic>.from(dailyDiaryData));
    } else {
      _diaryService.loadDailyDiary(null);
    }
  }

  @override
  void didUpdateWidget(covariant RecipesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData['products'] != widget.userData['products']) {
      _loadUserProductsAndCustomRecipes();
    }
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    super.dispose();
  }

  ProductTotals get _productTotals =>
      _productsRecipeService.calculateTotals(_myProducts);

  Future<void> _openProductsRecipesSheet() async {
    final goal =
        (widget.userData['goal'] as String?) ?? 'Поддержание веса';
    await showProductsRecipesSheet(
      context,
      products: _myProducts,
      goal: goal,
      mealCategory: _categories[_selectedTab],
      onProductsChanged: _saveProducts,
      onDiarySaved: _saveCurrentDayDiary,
    );
    if (mounted) setState(() {});
  }

  List<Recipe> _getFilteredRecipes() {
    final selectedCategory = _categories[_selectedTab];
    final goal =
        _nutritionPlan?.goal ??
        _normalizeGoal((widget.userData['goal'] as String?) ?? 'Поддержание');
    final mealCalories =
        _nutritionPlan?.mealCalories[selectedCategory] ??
        _targetCalories * _getMealCalorieShare(goal, selectedCategory);
    final mealProtein =
        _nutritionPlan?.mealProtein[selectedCategory] ??
        _targetProtein * _getMealCalorieShare(goal, selectedCategory);

    final filtered = _recipes.where((recipe) {
      if (recipe.category != selectedCategory) return false;
      if (recipe.isCustom) return true;
      return _isRecipeMatchingTargets(
        recipe: recipe,
        goal: goal,
        targetCalories: mealCalories,
        targetProtein: mealProtein,
      );
    }).toList();

    // Если фильтрация слишком строгая, показываем рецепты выбранной категории.
    if (filtered.isEmpty) {
      final fallback = _recipes
          .where((recipe) => recipe.category == selectedCategory)
          .toList();
      fallback.sort((a, b) {
        final scoreB = _recipePriorityScore(
          recipe: b,
          goal: goal,
          mealCalories: mealCalories,
        );
        final scoreA = _recipePriorityScore(
          recipe: a,
          goal: goal,
          mealCalories: mealCalories,
        );
        return scoreB.compareTo(scoreA);
      });
      return fallback;
    }

    filtered.sort((a, b) {
      final scoreB = _recipePriorityScore(
        recipe: b,
        goal: goal,
        mealCalories: mealCalories,
      );
      final scoreA = _recipePriorityScore(
        recipe: a,
        goal: goal,
        mealCalories: mealCalories,
      );
      return scoreB.compareTo(scoreA);
    });

    return filtered;
  }

  List<Recipe> _getDisplayedRecipes() {
    if (_selectedView == 1) {
      return _recipes.where((recipe) => _favoriteRecipes.contains(recipe.id)).toList();
    }
    return _getFilteredRecipes();
  }

  Widget _buildViewToggle(String title, int index) {
    final isSelected = _selectedView == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedView = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA5C75D) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Future<void> _initializePersonalizedRecipes() async {
    _loadFavoritesFromUserData();
    _calculateUserTargets();
    await _loadRecipesFromFirestore();
  }

  void _loadFavoritesFromUserData() {
    final favoritesData = widget.userData['favorites'];
    if (favoritesData is List) {
      _favoriteRecipes = favoritesData
          .whereType<num>()
          .map((item) => item.toInt())
          .toSet();
    }
  }

  Future<void> _saveFavoritesToFirestore() async {
    final favorites = _favoriteRecipes.toList();
    widget.userData['favorites'] = favorites;
    await _authService.saveUserFavorites(favorites);
  }

  Future<void> _saveCurrentDayDiary() async {
    final existingDiary = (widget.userData['dailyDiary'] as Map<String, dynamic>?) ?? {};
    final todayKey = DateTime.now().toIso8601String().split('T').first;
    final payload = Map<String, dynamic>.from(existingDiary);

    payload[todayKey] = {
      'entries': _diaryService.eatenRecipes.value,
      'totals': {
        'calories': _diaryService.getTotalCalories(),
        'proteins': _diaryService.getTotalProteins(),
        'fats': _diaryService.getTotalFats(),
        'carbs': _diaryService.getTotalCarbs(),
      },
    };

    widget.userData['dailyDiary'] = payload;
    await _authService.saveUserDailyDiary(payload);
  }

  void _calculateUserTargets() {
    final workoutsData = widget.userData['workouts'];
    final workouts = <Map<String, dynamic>>[];
    if (workoutsData is List) {
      workouts.addAll(workoutsData.whereType<Map<String, dynamic>>());
    }

    _nutritionPlan = NutritionService.calculatePlan(widget.userData, workouts);
    _bmr = _nutritionPlan?.bmr ?? 0;
    _activityFactor = _nutritionPlan?.activityFactor ?? 1.4;
    _maintenanceCalories = _nutritionPlan?.maintenanceCalories ?? 0;
    _targetCalories = _nutritionPlan?.targetCalories ?? 0;
    _targetProtein = _nutritionPlan?.proteinGrams ?? 0;
    _targetFat = _nutritionPlan?.fatGrams ?? 0;
    _targetCarbs = _nutritionPlan?.carbGrams ?? 0;
  }

  Future<void> _loadRecipesFromFirestore() async {
    setState(() {
      _recipesLoading = true;
      _recipesError = null;
    });

    try {
      final firestoreRecipes = await _recipeService.getRecipes();
      final mappedFirestore = firestoreRecipes
          .map(_mapFirestoreRecipe)
          .toList();
      final mappedLocal = await _loadRecipesFromLocalJson();
      final mapped = [...mappedFirestore, ...mappedLocal];

      final custom = _customRecipeMaps.map(_recipeFromCustomMap).toList();
      if (!mounted) return;
      setState(() {
        _recipes = [...custom, ...mapped];
        _recipesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recipesError = 'Не удалось загрузить рецепты: $e';
        _recipesLoading = false;
      });
    }
  }

  Future<List<Recipe>> _loadRecipesFromLocalJson() async {
    try {
      final jsonString = await rootBundle.loadString('Recepts.json');
      final data = jsonDecode(jsonString) as List<dynamic>;
      final List<Recipe> localRecipes = [];

      for (int i = 0; i < data.length; i++) {
        final item = data[i] as Map<String, dynamic>;
        final title = item['Название']?.toString().trim() ?? '';
        if (title.isEmpty) continue;

        final category = _normalizeCategory(item['Тип']?.toString() ?? '');
        final calories = (item['Килакалории']?.toString() ?? '0').trim();
        final bjuText = item['БЖУ']?.toString() ?? '';

        localRecipes.add(
          Recipe(
            id: 500000 + i,
            title: title,
            calories: _extractMacroValue(bjuText, 'calories', calories),
            proteins: _extractMacroValue(bjuText, 'protein', '0'),
            fats: _extractMacroValue(bjuText, 'fat', '0'),
            carbs: _extractMacroValue(bjuText, 'carbs', '0'),
            category: category,
            instructions:
                item['Подробное описание приготовление']?.toString() ?? '',
            ingredients: item['Продукты']?.toString() ?? '',
          ),
        );
      }

      return localRecipes;
    } catch (_) {
      return [];
    }
  }

  String _extractMacroValue(String bju, String kind, String fallback) {
    if (kind == 'calories') {
      final match = RegExp(r'[\d.,]+').firstMatch(fallback);
      return (match?.group(0) ?? '0').replaceAll(',', '.');
    }

    final regexMap = {
      'protein': RegExp(r'Белки:\s*([\d.,]+)'),
      'fat': RegExp(r'Жиры:\s*([\d.,]+)'),
      'carbs': RegExp(r'Углеводы:\s*([\d.,]+)'),
    };

    final match = regexMap[kind]?.firstMatch(bju);
    return (match?.group(1) ?? '0').replaceAll(',', '.');
  }

  Recipe _recipeFromCustomMap(Map<String, dynamic> data) {
    final rawId = data['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ??
            (900000000 + _customRecipeMaps.indexOf(data));

    return Recipe(
      id: id,
      title: data['title']?.toString() ?? 'Мой рецепт',
      calories: data['calories']?.toString() ?? '0',
      proteins: data['proteins']?.toString() ?? '0',
      fats: data['fats']?.toString() ?? '0',
      carbs: data['carbs']?.toString() ?? '0',
      category: _normalizeCategory(data['category']?.toString() ?? 'Обед'),
      description: data['description']?.toString() ?? '',
      instructions: data['instructions']?.toString() ??
          data['description']?.toString() ??
          '',
      ingredients: data['ingredients']?.toString() ?? '',
      isCustom: true,
    );
  }

  Future<void> _saveProducts(List<Map<String, dynamic>> products) async {
    _myProducts = products;
    widget.userData['products'] = products;
    await _authService.saveUserProducts(products);
    if (mounted) setState(() {});
  }

  Future<void> _saveCustomRecipes() async {
    widget.userData['customRecipes'] = _customRecipeMaps;
    await _authService.saveUserCustomRecipes(_customRecipeMaps);
  }

  Future<void> _openProductPhotoSheet() async {
    await showProductPhotoSheet(
      context,
      currentProducts: _myProducts,
      onSave: _saveProducts,
    );
  }

  Future<void> _openAddRecipeSheet() async {
    final data = await showAddCustomRecipeSheet(
      context,
      defaultCategory: _categories[_selectedTab],
    );
    if (data == null) return;

    setState(() {
      _customRecipeMaps = [data, ..._customRecipeMaps];
      _recipes = [_recipeFromCustomMap(data), ..._recipes];
    });
    await _saveCustomRecipes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ваш рецепт добавлен')),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFA5C75D)),
              title: const Text('Продукты по фото'),
              subtitle: Text('Мои продукты: ${_myProducts.length}'),
              onTap: () {
                Navigator.pop(context);
                _openProductPhotoSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: Color(0xFFA5C75D)),
              title: const Text('Свой рецепт'),
              subtitle: const Text('Вручную или заполнить по фото'),
              onTap: () {
                Navigator.pop(context);
                _openAddRecipeSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.soup_kitchen, color: Color(0xFFA5C75D)),
              title: const Text('Рецепты из продуктов'),
              subtitle: Text(
                _myProducts.isEmpty
                    ? 'Сначала добавьте продукты'
                    : 'ИИ учтёт ${_myProducts.length} продуктов и КБЖУ',
              ),
              onTap: () {
                Navigator.pop(context);
                _openProductsRecipesSheet();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Recipe _mapFirestoreRecipe(Map<String, dynamic> data) {
    final macros = (data['macros'] as Map<String, dynamic>? ?? {});
    final recipeType = (data['type']?.toString() ?? '').trim();

    return Recipe(
      id: (data['id'] as num?)?.toInt() ?? 0,
      title: data['title']?.toString() ?? 'Без названия',
      calories: data['calories']?.toString() ?? '0',
      proteins: macros['protein']?.toString() ?? '0',
      fats: macros['fat']?.toString() ?? '0',
      carbs: macros['carbs']?.toString() ?? '0',
      category: _normalizeCategory(recipeType),
      instructions: data['instructions']?.toString() ?? '',
      ingredients: data['products']?.toString() ?? '',
    );
  }

  String _normalizeCategory(String category) {
    final value = category.toLowerCase().trim();
    if (value.contains('/')) {
      final first = value.split('/').first.trim();
      return _normalizeCategory(first);
    }
    if (value == 'завтрак') return 'Завтрак';
    if (value == 'обед') return 'Обед';
    if (value == 'ужин') return 'Ужин';
    if (value == 'перекус') return 'Перекус';
    if (value == 'десерт') return 'Перекус';
    if (value == 'салат') return 'Перекус';
    return 'Обед';
  }

  Future<void> _addRecipeToDiary(Recipe recipe) async {
    if (_diaryService.isRecipeAdded(recipe.id)) {
      return;
    }

    _diaryService.addRecipeToDiary(
      id: recipe.id,
      title: recipe.title,
      category: recipe.category,
      calories: recipe.calories,
      proteins: recipe.proteins,
      fats: recipe.fats,
      carbs: recipe.carbs,
      description: recipe.description,
      ingredients: recipe.ingredients,
      instructions: recipe.cookingInstructions,
    );

    setState(() {});
    await _saveCurrentDayDiary();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Рецепт "${recipe.title}" добавлен в дневник питания.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isRecipeMatchingTargets({
    required Recipe recipe,
    required String goal,
    required double targetCalories,
    required double targetProtein,
  }) {
    final cal = _extractNumber(recipe.calories);
    final protein = _extractNumber(recipe.proteins);

    // Набор массы: высокий калораж + достаточно белка.
    if (goal == 'gain_weight') {
      final caloriesHigh = cal >= targetCalories * 0.95;
      final proteinEnough = protein >= targetProtein * 0.75;
      return caloriesHigh && proteinEnough;
    }

    // Поддержание: средний калораж и средний/достаточный белок.
    if (goal == 'maintain') {
      final caloriesMedium =
          cal >= targetCalories * 0.85 && cal <= targetCalories * 1.15;
      final proteinMedium = protein >= targetProtein * 0.65;
      return caloriesMedium && proteinMedium;
    }

    // Похудение: низкий калораж и высокий белок.
    final caloriesLow =
        cal <= targetCalories * 0.95 && cal >= targetCalories * 0.55;
    final proteinHigh = protein >= targetProtein * 0.9;
    return caloriesLow && proteinHigh;
  }

  double _recipePriorityScore({
    required Recipe recipe,
    required String goal,
    required double mealCalories,
  }) {
    final calories = _extractNumber(recipe.calories);
    final protein = _extractNumber(recipe.proteins);
    final carbs = _extractNumber(recipe.carbs);
    final ingredients = recipe.ingredients.toLowerCase();

    final calorieDistanceScore = (100 - (calories - mealCalories).abs())
        .clamp(0, 100)
        .toDouble();
    final proteinScore = protein * 2.5;
    final carbsScore = carbs * 1.6;
    final lowerCalorieBonus = (600 - calories).clamp(0, 600).toDouble() / 10;

    final hasFiber =
        ingredients.contains('овощ') ||
        ingredients.contains('брокколи') ||
        ingredients.contains('зелень') ||
        ingredients.contains('салат');
    final hasComplexCarbs =
        ingredients.contains('рис') ||
        ingredients.contains('греч') ||
        ingredients.contains('киноа') ||
        ingredients.contains('паста') ||
        ingredients.contains('овся');

    if (goal == 'gain_weight') {
      return calorieDistanceScore +
          proteinScore +
          carbsScore +
          (hasComplexCarbs ? 25 : 0) +
          (hasFiber ? 5 : 0);
    }

    if (goal == 'lose_weight') {
      return calorieDistanceScore +
          proteinScore * 1.2 +
          lowerCalorieBonus +
          (hasFiber ? 25 : 0) +
          (hasComplexCarbs ? 10 : 0);
    }

    return calorieDistanceScore +
        proteinScore +
        carbsScore * 0.8 +
        (hasFiber ? 10 : 0);
  }

  double _extractNumber(String value) {
    final normalized = value.replaceAll(',', '.');
    final match = RegExp(r'[\d.]+').firstMatch(normalized);
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  double calculateBMR({
    required double weight,
    required double height,
    required int age,
    required String gender,
  }) {
    final normalizedGender = gender.toLowerCase();
    final s = (normalizedGender == 'male' || normalizedGender == 'мужской')
        ? 5
        : -161;
    return 9.99 * weight + 6.25 * height - 4.92 * age + s;
  }

  double adjustCalories(double maintenanceCalories, String goal) {
    if (goal == 'lose_weight') {
      return maintenanceCalories * 0.85;
    }
    if (goal == 'gain_weight') {
      return maintenanceCalories * 1.125;
    }
    return maintenanceCalories;
  }

  Map<String, double> calculateMacros({
    required double weight,
    required double calories,
    required String goal,
  }) {
    double proteinPerKg;
    double fatPercent;
    if (goal == 'lose_weight') {
      proteinPerKg = 1.6;
      fatPercent = 0.275;
    } else if (goal == 'gain_weight') {
      proteinPerKg = 1.9;
      fatPercent = 0.225;
    } else {
      proteinPerKg = 1.4;
      fatPercent = 0.275;
    }

    final protein = weight * proteinPerKg;
    final fatByPercent = (calories * fatPercent) / 9;
    final fat = goal == 'gain_weight'
        ? ((weight * 1.0) + fatByPercent) / 2
        : fatByPercent;

    final proteinCalories = protein * 4;
    final fatCalories = fat * 9;
    final carbsCalories = (calories - (proteinCalories + fatCalories)).clamp(
      0,
      calories,
    );
    final carbs = carbsCalories / 4;

    return {"protein": protein, "fat": fat, "carbs": carbs};
  }

  String _normalizeGoal(String goalRaw) {
    final goal = goalRaw.toLowerCase().trim();
    if (goal == 'похудение' || goal == 'lose_weight') return 'lose_weight';
    if (goal == 'набор мышц' || goal == 'gain_weight') return 'gain_weight';
    return 'maintain';
  }

  double _resolveActivityFactor(dynamic activityData) {
    if (activityData is num) {
      final value = activityData.toDouble();
      if (value >= 1.2 && value <= 2.0) return value;
    }
    if (activityData is String) {
      final value = activityData.toLowerCase().trim();
      if (value.contains('низк')) return 1.375;
      if (value.contains('умерен')) return 1.55;
      if (value.contains('высок')) return 1.725;
      if (value.contains('очень')) return 1.9;
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null && parsed >= 1.2 && parsed <= 2.0) return parsed;
    }
    return 1.4;
  }

  double _getMealCalorieShare(String goal, String mealType) {
    if (goal == 'gain_weight') {
      switch (mealType) {
        case 'Завтрак':
          return 0.22;
        case 'Обед':
          return 0.33;
        case 'Ужин':
          return 0.25;
        case 'Перекус':
          return 0.20;
      }
    }
    if (goal == 'lose_weight') {
      switch (mealType) {
        case 'Завтрак':
          return 0.30;
        case 'Обед':
          return 0.40;
        case 'Ужин':
          return 0.25;
        case 'Перекус':
          return 0.05;
      }
    }
    switch (mealType) {
      case 'Завтрак':
        return 0.25;
      case 'Обед':
        return 0.35;
      case 'Ужин':
        return 0.30;
      case 'Перекус':
        return 0.10;
    }
    return 0.25;
  }

  double _currentMealTargetCalories() {
    final category = _categories[_selectedTab];
    return _nutritionPlan?.mealCalories[category] ??
        (_targetCalories *
            _getMealCalorieShare(
              _normalizeGoal(
                (widget.userData['goal'] as String?) ?? 'Поддержание',
              ),
              category,
            ));
  }

  double _currentMealTargetProtein() {
    final category = _categories[_selectedTab];
    return _nutritionPlan?.mealProtein[category] ??
        (_targetProtein *
            _getMealCalorieShare(
              _normalizeGoal(
                (widget.userData['goal'] as String?) ?? 'Поддержание',
              ),
              category,
            ));
  }

  /// Отправляет запрос в ИИ и получает рекомендацию рецепта
  Future<void> _askAiForRecipe() async {
    final promptText = _aiPromptController.text.trim();
    if (promptText.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _aiChatMessages.add({'role': 'user', 'content': promptText});
      _aiIsLoading = true;
    });

    _aiPromptController.clear();

    try {
      setState(() {
        _aiRecommendedRecipes = [];
        _showAiRecommendationsPanel = false;
      });

      final goal = _normalizeGoal(
        (widget.userData['goal'] as String?) ?? 'Поддержание',
      );

      final selectedCategory = _categories[_selectedTab];

      final mealCalories =
          _targetCalories * _getMealCalorieShare(goal, selectedCategory);

      final mealProtein =
          _targetProtein * _getMealCalorieShare(goal, selectedCategory);

      /// 🔥 1. Берём только релевантные рецепты
      final currentPool = _getFilteredRecipes();

      /// 🔥 2. Преобразуем в формат для RAG
      final ragInput = currentPool.map(_recipeToRagMap).toList();

      /// 🔥 3. Сортируем через RAG
      final retrieved = _ragService.retrieveRecipes(
        recipes: ragInput,
        query: promptText,
        goal: goal,
        mealTargetCalories: mealCalories,
        minProtein: mealProtein,
      );

      /// 🔥 4. Берём топ 5
      final topRecipes = retrieved.take(5).toList();

      /// 🔥 5. Формируем prompt
      final aiPrompt = _buildAiPrompt(
        userMessage: promptText,
        recipes: topRecipes,
        goal: goal,
      );

      final response = await _aiService.generate(aiPrompt);

      /// 🔥 7. Преобразуем обратно в Recipe
      final recommended = currentPool.where((recipe) {
        return topRecipes.any((r) => r['title'] == recipe.title);
      }).toList();

      if (!mounted) return;
      setState(() {
        _aiChatMessages.add({'role': 'assistant', 'content': response});
        _aiRecommendedRecipes = recommended;
        _showAiRecommendationsPanel = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiChatMessages.add({'role': 'error', 'content': 'Ошибка AI: $e'});
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiIsLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _recipeToRagMap(Recipe recipe) {
    return {
      'title': recipe.title,
      'type': recipe.category,
      'calories': _extractNumber(recipe.calories),
      'protein': _extractNumber(recipe.proteins),
      'fat': _extractNumber(recipe.fats),
      'carbs': _extractNumber(recipe.carbs),
      'ingredients': recipe.ingredients,
    };
  }

  /// Показывает диалог с ИИ чатом
  void _showAiChatDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'AI Помощник',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // История чата
              Expanded(
                child: _aiChatMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Опишите нужный рецепт',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _aiChatMessages.length,
                        itemBuilder: (context, index) {
                          final message = _aiChatMessages[index];
                          final isUser = message['role'] == 'user';
                          final isError = message['role'] == 'error';

                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isError
                                    ? Colors.red[100]
                                    : isUser
                                    ? Colors.blue[500]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                message['content'] ?? '',
                                style: TextStyle(
                                  color: isError || isUser
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Рекомендованные рецепты
              if (_aiRecommendedRecipes.isNotEmpty)
                Material(
                  color: Colors.green.shade50,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showAiRecommendationsPanel = !_showAiRecommendationsPanel;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border(
                          top: BorderSide(color: Colors.green.shade200),
                          bottom: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Рекомендованные рецепты',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _showAiRecommendationsPanel
                                    ? 'Нажмите, чтобы скрыть список'
                                    : 'Нажмите, чтобы открыть список',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _showAiRecommendationsPanel
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showAiRecommendationsPanel
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border(
                              top: BorderSide(color: Colors.green.shade200),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              ..._aiRecommendedRecipes.map((recipe) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GestureDetector(
                                    onTap: () => _showRecipeDetailDialog(recipe),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  recipe.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  '${recipe.calories} ккал',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: _diaryService.isRecipeAdded(recipe.id)
                                                ? null
                                                : () => _addRecipeToDiary(recipe),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _diaryService.isRecipeAdded(recipe.id)
                                                  ? Colors.grey.shade400
                                                  : Colors.green.shade400,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                            ),
                                            child: Text(
                                              _diaryService.isRecipeAdded(recipe.id)
                                                  ? 'Добавлено'
                                                  : 'Добавить',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              // Поле ввода
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiPromptController,
                        decoration: InputDecoration(
                          hintText: 'Что ты ищешь?',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        enabled: !_aiIsLoading,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.green.shade400,
                      onPressed: _aiIsLoading
                          ? null
                          : () async {
                              await _askAiForRecipe();
                              setDialogState(() {});
                            },
                      child: _aiIsLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedRecipes = _getDisplayedRecipes();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Рецепты",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Выберите блюда для дневника питания",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showAddMenu,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Добавить',
                ),
                IconButton(
                  onPressed: _showAiChatDialog,
                  icon: const Icon(Icons.smart_toy_outlined),
                  tooltip: 'ИИ помощник',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: _myProducts.isEmpty
                  ? _openProductPhotoSheet
                  : _openProductsRecipesSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _myProducts.isEmpty
                                ? 'Добавьте продукты по фото → ИИ предложит рецепты'
                                : 'Мои продукты: ${_myProducts.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                    if (_myProducts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Итого: ${_productTotals.calories.round()} ккал • '
                        'Б:${_productTotals.proteins.round()} '
                        'Ж:${_productTotals.fats.round()} '
                        'У:${_productTotals.carbs.round()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Нажмите — подобрать рецепты из этих продуктов',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Цель: ${_targetCalories.toStringAsFixed(0)} ккал',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'Поддержание: ${_maintenanceCalories.toStringAsFixed(0)} ккал',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Б: ${_targetProtein.toStringAsFixed(0)} г   Ж: ${_targetFat.toStringAsFixed(0)} г   У: ${_targetCarbs.toStringAsFixed(0)} г',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (_selectedView == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_categories[_selectedTab]}: ${_currentMealTargetCalories().toStringAsFixed(0)} ккал | белок ≈ ${_currentMealTargetProtein().toStringAsFixed(0)} г',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildViewToggle('Все', 0),
                const SizedBox(width: 10),
                _buildViewToggle('Избранное', 1),
              ],
            ),
          ),

          if (_selectedView == 0)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    for (int i = 0; i < _categories.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: i < _categories.length - 1 ? 12 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTab = i;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedTab == i
                                  ? const Color(0xFFA5C75D)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _categories[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == i
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Список рецептов
          Expanded(
            child: _recipesLoading
                ? const Center(child: CircularProgressIndicator())
                : _recipesError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_recipesError!, textAlign: TextAlign.center),
                        ),
                      )
                    : displayedRecipes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedView == 1
                                      ? "Нет избранных рецептов"
                                      : "Нет подходящих рецептов",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedView == 1
                                      ? "Отметьте понравившиеся рецепты сердечком"
                                      : "Попробуйте другую категорию или измените данные профиля",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: displayedRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = displayedRecipes[index];
                              final isFavorite = _favoriteRecipes.contains(recipe.id);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildRecipeCard(recipe, isFavorite),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe, bool isFavorite) {
    final isAddedToDiary = _diaryService.isRecipeAdded(recipe.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и сердечко
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              recipe.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (recipe.isCustom) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Мой',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    setState(() {
                      if (isFavorite) {
                        _favoriteRecipes.remove(recipe.id);
                      } else {
                        _favoriteRecipes.add(recipe.id);
                      }
                    });
                    await _saveFavoritesToFirestore();
                  },
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Калорийность
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.lightGreen.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Калории",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  "${recipe.calories} ккал",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // БЖУ детально
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailedMacro("Белки", recipe.proteins),
                _buildDetailedMacro("Жиры", recipe.fats),
                _buildDetailedMacro("Углеводы", recipe.carbs),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Как готовить
          if (recipe.cookingInstructions.isNotEmpty) ...[
            _buildCookingStepsSection(recipe.cookingInstructions),
            const SizedBox(height: 12),
          ],

          // Ингредиенты
          if (recipe.ingredients.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ингредиенты",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.ingredients,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Микроэлементы
          if (recipe.micronutrients.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Микроэлементы",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recipe.micronutrients.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          "${entry.key}: ${entry.value}",
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Витамины
          if (recipe.vitamins.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Витамины",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recipe.vitamins.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          "${entry.key}: ${entry.value}",
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Кнопки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAddedToDiary
                          ? Colors.grey.shade400
                          : Colors.green.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isAddedToDiary
                        ? null
                        : () {
                            _addRecipeToDiary(recipe);
                          },
                    child: Text(
                      isAddedToDiary ? "Добавлено" : "Добавить в дневник",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRecipeDetailDialog(Recipe recipe) {
    final isAdded = _diaryService.isRecipeAdded(recipe.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${recipe.calories} ккал · ${recipe.category}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailedMacro('Белки', recipe.proteins),
                  const SizedBox(width: 8),
                  _buildDetailedMacro('Жиры', recipe.fats),
                  const SizedBox(width: 8),
                  _buildDetailedMacro('Углеводы', recipe.carbs),
                ],
              ),
              if (recipe.cookingInstructions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Как готовить',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ..._parseCookingSteps(recipe.cookingInstructions).map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(step, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              if (recipe.ingredients.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Ингредиенты',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(recipe.ingredients),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: isAdded
                ? null
                : () {
                    _addRecipeToDiary(recipe);
                    Navigator.pop(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAdded ? Colors.grey.shade400 : Colors.green.shade400,
            ),
            child: Text(
              isAdded ? 'Добавлено' : 'Добавить в дневник',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseCookingSteps(String text) {
    if (text.trim().isEmpty) return [];

    final rawSteps = text
        .split(RegExp(r'\s+(?=\d+\.\s)'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();

    return rawSteps.asMap().entries.map((entry) {
      final cleaned = entry.value.replaceFirst(RegExp(r'^\d+\.\s*'), '');
      return '${entry.key + 1}. $cleaned';
    }).toList();
  }

  Widget _buildCookingStepsSection(String instructions) {
    final steps = _parseCookingSteps(instructions);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Как готовить',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(step, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMacro(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value.isNotEmpty ? value : "0",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class Recipe {
  final int id;
  final String title;
  final String calories;
  final String proteins;
  final String fats;
  final String carbs;
  final String category;
  final String description;
  final String instructions;
  final String ingredients;
  final Map<String, String> micronutrients;
  final Map<String, String> vitamins;
  final bool isCustom;

  String get cookingInstructions =>
      instructions.isNotEmpty ? instructions : description;

  Recipe({
    required this.id,
    required this.title,
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
    required this.category,
    this.description = '',
    this.instructions = '',
    this.ingredients = '',
    this.micronutrients = const {},
    this.vitamins = const {},
    this.isCustom = false,
  });
}

String _buildAiPrompt({
  required String userMessage,
  required List recipes,
  required String goal,
}) {
  final recipeText = recipes
      .map((r) {
        return """
Название: ${r['title']}
Калории: ${r['calories']}
Белки: ${r['protein']}
Жиры: ${r['fat']}
Углеводы: ${r['carbs']}
""";
      })
      .join("\n");

  return """
Ты — профессиональный диетолог.

Цель пользователя: $goal

Запрос:
"$userMessage"

Вот доступные рецепты (используй только их):
$recipeText

Задача:
- Выбери 2-3 лучших рецепта
- Объясни почему они подходят
- НЕ придумывай новые рецепты
- Если нет подходящих — скажи честно

Ответ короткий и понятный.
""";
}
