import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:edafitapp/services/ai_service.dart';
import 'package:edafitapp/services/auth_service.dart';
import 'package:edafitapp/services/food_diary_service.dart';

class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProductsScreen({
    super.key,
    required this.userData,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Map<String, dynamic>> _myProducts = [];
  final List<Map<String, dynamic>> _possibleRecipes = [];
  final FoodDiaryService _diaryService = FoodDiaryService.instance;
  final AIService _aiService = AIService();
  final AuthService _authService = AuthService();

  late TextEditingController _productNameController;
  late TextEditingController _quantityController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinsController;
  late TextEditingController _fatsController;
  late TextEditingController _carbsController;

  String _selectedUnit = "шт";
  final List<String> _units = ["шт", "г", "кг", "л", "мл"];

  @override
  void initState() {
    super.initState();
    _productNameController = TextEditingController();
    _quantityController = TextEditingController();
    _caloriesController = TextEditingController();
    _proteinsController = TextEditingController();
    _fatsController = TextEditingController();
    _carbsController = TextEditingController();
    _loadProductsFromUserData();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _caloriesController.dispose();
    _proteinsController.dispose();
    _fatsController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  void _showAddProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Добавить продукт", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(hintText: "Название продукта"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "Количество"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedUnit,
                        decoration: const InputDecoration(hintText: "Ед."),
                        items: _units.map((unit) {
                          return DropdownMenuItem(value: unit, child: Text(unit));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedUnit = value ?? _selectedUnit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: "Калории (ккал)"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _proteinsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "Белки (г)"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fatsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "Жиры (г)"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _carbsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "Углеводы (г)"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Отмена"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addProduct,
                        child: const Text("Добавить"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addProduct() {
    if (_productNameController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _caloriesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название, количество и калории')),
      );
      return;
    }

    setState(() {
      _myProducts.add({
        'name': _productNameController.text.trim(),
        'quantity': _quantityController.text.trim(),
        'unit': _selectedUnit,
        'calories': _caloriesController.text.trim(),
        'proteins': _proteinsController.text.trim().isEmpty ? '0' : _proteinsController.text.trim(),
        'fats': _fatsController.text.trim().isEmpty ? '0' : _fatsController.text.trim(),
        'carbs': _carbsController.text.trim().isEmpty ? '0' : _carbsController.text.trim(),
      });
    });

    Navigator.pop(context);
    _productNameController.clear();
    _quantityController.clear();
    _caloriesController.clear();
    _proteinsController.clear();
    _fatsController.clear();
    _carbsController.clear();

    _saveProductsToFirestore();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Продукт добавлен в список')),
    );
  }

  void _loadProductsFromUserData() {
    final dynamic productsData = widget.userData['products'];
    if (productsData is List) {
      _myProducts.clear();
      _myProducts.addAll(productsData.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((item) => item.isNotEmpty));
    }
  }

  Future<void> _saveProductsToFirestore() async {
    await _authService.saveUserProducts(_myProducts);
  }

  List<Map<String, dynamic>> _generateRecipeSuggestions() {
    final lowerNames = _myProducts.map((product) => product['name'].toString().toLowerCase()).toList();
    final totalCalories = _myProducts.fold<double>(0.0, (sum, item) => sum + _parseNumber(item['calories']));
    final totalProteins = _myProducts.fold<double>(0.0, (sum, item) => sum + _parseNumber(item['proteins']));
    final totalFats = _myProducts.fold<double>(0.0, (sum, item) => sum + _parseNumber(item['fats']));
    final totalCarbs = _myProducts.fold<double>(0.0, (sum, item) => sum + _parseNumber(item['carbs']));

    final ingredients = _myProducts.map((item) => item['name']).join(', ');
    final hasChicken = lowerNames.any((name) => name.contains('куриц') || name.contains('курин'));
    final hasFish = lowerNames.any((name) => name.contains('рыб') || name.contains('лосос') || name.contains('тунец'));
    final hasEggs = lowerNames.any((name) => name.contains('яиц') || name.contains('яйц') || name.contains('яйцо'));
    final hasVegetables = lowerNames.any((name) => name.contains('овощ') || name.contains('салат') || name.contains('брокколи') || name.contains('помидор') || name.contains('огурец'));

    final baseCalories = (totalCalories * 1.05).clamp(120.0, 1200.0);
    final baseProteins = (totalProteins * 1.1).clamp(5.0, 120.0);
    final baseFats = (totalFats * 1.0).clamp(3.0, 100.0);
    final baseCarbs = (totalCarbs * 1.05).clamp(10.0, 180.0);

    final commonRecipe = {
      'id': 'mixed_${totalCalories.round()}',
      'title': 'Смешанный рецепт из ваших продуктов',
      'description': 'ИИ собрал рецепт на основе имеющихся продуктов.',
      'ingredients': ingredients,
      'calories': baseCalories.round(),
      'proteins': baseProteins.round(),
      'fats': baseFats.round(),
      'carbs': baseCarbs.round(),
    };

    final recipes = <Map<String, dynamic>>[];

    if (hasChicken) {
      recipes.add({
        'id': 'chicken_${totalCalories.round()}',
        'title': 'Куриный салат с овощами',
        'description': 'Легкий рецепт из курицы и овощей, адаптированный под ваши продукты.',
        'ingredients': ingredients,
        'calories': (baseCalories + 40).round(),
        'proteins': (baseProteins + 10).round(),
        'fats': (baseFats + 4).round(),
        'carbs': (baseCarbs + 5).round(),
      });
    }

    if (hasFish) {
      recipes.add({
        'id': 'fish_${totalCalories.round()}',
        'title': 'Запеченная рыба с гарниром',
        'description': 'Питательный рецепт из рыбы и овощей для сытного ужина.',
        'ingredients': ingredients,
        'calories': (baseCalories + 60).round(),
        'proteins': (baseProteins + 8).round(),
        'fats': (baseFats + 5).round(),
        'carbs': (baseCarbs + 8).round(),
      });
    }

    if (hasEggs || hasVegetables) {
      recipes.add({
        'id': 'omelet_${totalCalories.round()}',
        'title': 'Овощной омлет с зеленью',
        'description': 'Быстрый и вкусный омлет на основе ваших продуктов.',
        'ingredients': ingredients,
        'calories': (baseCalories - 20).round(),
        'proteins': (baseProteins + 7).round(),
        'fats': baseFats.round(),
        'carbs': (baseCarbs + 3).round(),
      });
    }

    if (recipes.isEmpty) {
      recipes.add(commonRecipe);
    } else if (recipes.length == 1) {
      recipes.add(commonRecipe);
    }

    return recipes;
  }

  Future<List<Map<String, dynamic>>> _generateRecipeSuggestionsFromAi() async {
    if (_myProducts.isEmpty) {
      return [];
    }

    final ingredients = _myProducts.map((item) => item['name']).join(', ');
    final goal = widget.userData['goal'] ?? 'Здоровое питание';
    final prompt = '''
Предложи 2-3 рецепта на основе продуктов: $ingredients.
Укажи цель: $goal.
Верни ответ только в формате JSON-массива.
Каждый объект должен содержать поля:
- id
- title
- description
- ingredients
- instructions
- calories
- proteins
- fats
- carbs
Инструкции приготовления должны быть подробными и понятными.
''';

    final response = await _aiService.generate(prompt);

    try {
      final decoded = jsonDecode(response);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((item) {
          return {
            'id': item['id'].toString(),
            'title': item['title']?.toString() ?? 'Рецепт',
            'description': item['description']?.toString() ?? '',
            'ingredients': item['ingredients']?.toString() ?? ingredients,
            'instructions': item['instructions']?.toString() ?? '',
            'calories': item['calories']?.toString() ?? '0',
            'proteins': item['proteins']?.toString() ?? '0',
            'fats': item['fats']?.toString() ?? '0',
            'carbs': item['carbs']?.toString() ?? '0',
          };
        }).toList();
      }
    } catch (_) {
      // ignore parse error, fallback below
    }

    return _generateRecipeSuggestions();
  }

  Future<void> _showAiRecipeSuggestions() async {
    final suggestions = await _generateRecipeSuggestionsFromAi();
    if (!mounted) return;

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
              const Text('ИИ предлагает рецепты', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                _myProducts.isEmpty
                    ? 'Добавьте продукты, чтобы ИИ смог подобрать рецепты.'
                    : 'На основе продуктов: ${_myProducts.map((item) => item['name']).join(', ')}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              if (suggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Добавьте продукты, чтобы получить рекомендации.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                )
              else ...suggestions.map((recipe) {
                final alreadySaved = _possibleRecipes.any((item) => item['id'] == recipe['id']);
                final alreadyInDiary = _diaryService.isRecipeAdded(recipe['id'].hashCode);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(recipe['description'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Text('Ингредиенты: ${recipe['ingredients']}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        Text('Приготовление:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(recipe['instructions'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 12),
                        Text('Калории: ${recipe['calories']} ккал • Б:${recipe['proteins']} г • Ж:${recipe['fats']} г • У:${recipe['carbs']} г', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: alreadySaved
                                    ? null
                                    : () {
                                        setState(() {
                                          _possibleRecipes.add(recipe);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Рецепт "${recipe['title']}" добавлен в возможные рецепты.')),
                                        );
                                      },
                                child: Text(alreadySaved ? 'Уже добавлено' : 'Добавить в список'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: alreadyInDiary ? null : () => _addRecipeToDiary(recipe),
                                child: Text(alreadyInDiary ? 'Уже в дневнике' : 'Добавить в дневник'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _addRecipeToDiary(Map<String, dynamic> recipe) {
    final recipeId = recipe['id'].hashCode;
    if (_diaryService.isRecipeAdded(recipeId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Рецепт "${recipe['title']}" уже есть в дневнике.')),
      );
      return;
    }

    _diaryService.addRecipeToDiary(
      id: recipeId,
      title: recipe['title']?.toString() ?? 'Рецепт',
      category: 'Перекус',
      calories: recipe['calories']?.toString() ?? '0',
      proteins: recipe['proteins']?.toString() ?? '0',
      fats: recipe['fats']?.toString() ?? '0',
      carbs: recipe['carbs']?.toString() ?? '0',
      description: recipe['description']?.toString() ?? '',
      ingredients: recipe['ingredients']?.toString() ?? '',
      instructions: recipe['instructions']?.toString() ?? '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Рецепт "${recipe['title']}" добавлен в дневник питания.')),
    );
    setState(() {});
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  Widget _buildProductInventory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Список продуктов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_myProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Добавьте продукты с КБЖУ, чтобы ИИ подобрал рецепты из имеющихся ингредиентов.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            )
          else ..._myProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product['name']} • ${product['quantity']}${product['unit']}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Калории: ${product['calories']} ккал • Б:${product['proteins']} г • Ж:${product['fats']} г • У:${product['carbs']} г',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _myProducts.removeAt(index);
                        });
                        _saveProductsToFirestore();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPossibleRecipesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Возможные рецепты', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_possibleRecipes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Рецепты, которые вы сохранили из подборок ИИ, появятся здесь.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            )
          else ..._possibleRecipes.map((recipe) {
            final alreadyInDiary = _diaryService.isRecipeAdded(recipe['id'].hashCode);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(recipe['description'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text('Приготовление:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(recipe['instructions'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 10),
                    Text('Калории: ${recipe['calories']} ккал • Б:${recipe['proteins']} г • Ж:${recipe['fats']} г • У:${recipe['carbs']} г', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: alreadyInDiary ? null : () => _addRecipeToDiary(recipe),
                        child: Text(alreadyInDiary ? 'Уже в дневнике' : 'Добавить в дневник'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF7D9DE), Color(0xFFE9F2D3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Мои продукты", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text("Управляйте продуктами и покупками", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Добавить"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAiRecipeSuggestions,
                    icon: const Icon(Icons.restaurant_menu_outlined, color: Color(0xFF2A2A2A)),
                    label: const Text("Можно приготовить", style: TextStyle(color: Color(0xFF2A2A2A))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildProductInventory(),
            const SizedBox(height: 16),
            _buildPossibleRecipesSection(),
          ],
        ),
      ),
    );
  }
}
