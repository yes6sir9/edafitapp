import 'dart:convert';

import 'ai_service.dart';

class ProductTotals {
  final double calories;
  final double proteins;
  final double fats;
  final double carbs;
  final int count;

  const ProductTotals({
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
    required this.count,
  });
}

class ProductsRecipeService {
  final AIService _aiService = AIService();

  ProductTotals calculateTotals(List<Map<String, dynamic>> products) {
    var calories = 0.0;
    var proteins = 0.0;
    var fats = 0.0;
    var carbs = 0.0;

    for (final product in products) {
      calories += _parseNumber(product['calories']);
      proteins += _parseNumber(product['proteins']);
      fats += _parseNumber(product['fats']);
      carbs += _parseNumber(product['carbs']);
    }

    return ProductTotals(
      calories: calories,
      proteins: proteins,
      fats: fats,
      carbs: carbs,
      count: products.length,
    );
  }

  String buildRecipePrompt({
    required List<Map<String, dynamic>> products,
    required ProductTotals totals,
    required String goal,
    required String mealCategory,
  }) {
    final productLines = products
        .map((p) {
          final name = p['name'] ?? '';
          final qty = p['quantity'] ?? '';
          final unit = p['unit'] ?? '';
          return '- $name ($qty $unit): ${p['calories']} ккал, '
              'Б:${p['proteins']} Ж:${p['fats']} У:${p['carbs']}';
        })
        .join('\n');

    return '''
Ты диетолог. У пользователя в холодильнике такие продукты:
$productLines

СУММА всех продуктов: ${totals.calories.round()} ккал, белки ${totals.proteins.round()} г, жиры ${totals.fats.round()} г, углеводы ${totals.carbs.round()} г.

Цель: $goal
Приём пищи: $mealCategory

Составь 3 рецепта, используя ТОЛЬКО эти продукты (часть можно не использовать).
Калории каждого рецепта должны быть разумны для приёма $mealCategory.
Верни ТОЛЬКО JSON-массив без markdown:
[{"title":"название","description":"кратко","ingredients":"список","instructions":"шаги","calories":0,"proteins":0,"fats":0,"carbs":0}]
''';
  }

  Future<List<Map<String, dynamic>>> suggestRecipesFromProducts({
    required List<Map<String, dynamic>> products,
    required String goal,
    required String mealCategory,
  }) async {
    if (products.isEmpty) return [];

    final totals = calculateTotals(products);
    final prompt = buildRecipePrompt(
      products: products,
      totals: totals,
      goal: goal,
      mealCategory: mealCategory,
    );

    final response = await _aiService.generate(prompt);
    final parsed = parseRecipesFromAiResponse(response);
    if (parsed.isNotEmpty) return parsed;

    return _fallbackRecipes(products, totals);
  }

  List<Map<String, dynamic>> parseRecipesFromAiResponse(String response) {
    final trimmed = response.trim();
    if (trimmed.isEmpty) return [];

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return _mapRecipeList(decoded);
      }
    } catch (_) {}

    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(trimmed);
    if (arrayMatch != null) {
      try {
        final decoded = jsonDecode(arrayMatch.group(0)!);
        if (decoded is List) {
          return _mapRecipeList(decoded);
        }
      } catch (_) {}
    }

    return [];
  }

  List<Map<String, dynamic>> _mapRecipeList(List<dynamic> list) {
    return list.map<Map<String, dynamic>>((item) {
      if (item is! Map) return {};
      final map = Map<String, dynamic>.from(item);
      return {
        'id': 'ai_${map['title']?.toString().hashCode ?? DateTime.now().millisecondsSinceEpoch}',
        'title': map['title']?.toString() ?? 'Рецепт',
        'description': map['description']?.toString() ?? '',
        'ingredients': map['ingredients']?.toString() ?? '',
        'instructions': map['instructions']?.toString() ?? '',
        'calories': map['calories']?.toString() ?? '0',
        'proteins': map['proteins']?.toString() ?? '0',
        'fats': map['fats']?.toString() ?? '0',
        'carbs': map['carbs']?.toString() ?? '0',
      };
    }).where((r) => r.isNotEmpty).toList();
  }

  List<Map<String, dynamic>> _fallbackRecipes(
    List<Map<String, dynamic>> products,
    ProductTotals totals,
  ) {
    final ingredients = products.map((p) => p['name']).join(', ');
    return [
      {
        'id': 'fallback_mix',
        'title': 'Блюдо из ваших продуктов',
        'description': 'Смешанный рецепт на основе всех продуктов.',
        'ingredients': ingredients,
        'instructions': 'Смешайте и приготовьте продукты из списка.',
        'calories': totals.calories.round().toString(),
        'proteins': totals.proteins.round().toString(),
        'fats': totals.fats.round().toString(),
        'carbs': totals.carbs.round().toString(),
      },
    ];
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }
}
