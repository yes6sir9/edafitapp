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
          final unit = p['unit'] ?? 'г';
          return '- $name: $qty $unit — ${p['calories']} ккал, '
              'Б:${p['proteins']} Ж:${p['fats']} У:${p['carbs']}';
        })
        .join('\n');

    return '''
Ты профессиональный повар и диетолог.

Продукты пользователя (используй ТОЛЬКО их, часть можно не использовать):
$productLines

Сумма всех продуктов: ${totals.calories.round()} ккал, белки ${totals.proteins.round()} г, жиры ${totals.fats.round()} г, углеводы ${totals.carbs.round()} г.
Цель: $goal
Приём пищи: $mealCategory

Составь РОВНО 3 РАЗНЫХ рецепта — разные блюда, не вариации одного и того же.

Требования к каждому рецепту:
1. title — конкретное аппетитное название блюда (не «Блюдо из продуктов»).
2. description — одно предложение о вкусе и подаче.
3. ingredients — каждый продукт с точным весом в г, мл или шт, через точку с запятой. Пример: «Помидоры черри — 80 г; Брокколи — 150 г; Оливковое масло — 10 мл».
4. instructions — 5–8 пронумерованных шагов: нарезка, сковорода/духовка, температура, время, порядок действий.
5. calories, proteins, fats, carbs — числа без «ккал» и «г», сумма по использованным продуктам.

Верни ТОЛЬКО JSON-массив из 3 объектов без markdown и комментариев:
[{"title":"","description":"","ingredients":"","instructions":"","calories":0,"proteins":0,"fats":0,"carbs":0}]
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

    try {
      final response = await _aiService.generateJson(prompt);
      if (response != null && response.isNotEmpty) {
        final parsed = parseRecipesFromAiResponse(response);
        if (parsed.length >= 2) return parsed.take(3).toList();
        if (parsed.isNotEmpty) {
          return _mergeWithFallback(parsed, products, totals, mealCategory);
        }
      }
    } catch (_) {
      // Используем локальные варианты, если ИИ недоступен.
    }

    return _fallbackRecipes(products, totals, mealCategory);
  }

  List<Map<String, dynamic>> _mergeWithFallback(
    List<Map<String, dynamic>> aiRecipes,
    List<Map<String, dynamic>> products,
    ProductTotals totals,
    String mealCategory,
  ) {
    final fallback = _fallbackRecipes(products, totals, mealCategory);
    final seenTitles = aiRecipes
        .map((r) => r['title']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();

    final merged = [...aiRecipes];
    for (final recipe in fallback) {
      if (merged.length >= 3) break;
      final title = recipe['title']?.toString().toLowerCase().trim() ?? '';
      if (title.isEmpty || seenTitles.contains(title)) continue;
      merged.add(recipe);
      seenTitles.add(title);
    }
    return merged;
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
    return list
        .map<Map<String, dynamic>>((item) {
          if (item is! Map) return {};
          final map = Map<String, dynamic>.from(item);
          final title = map['title']?.toString().trim() ?? '';
          if (title.isEmpty) return {};

          return {
            'id':
                'ai_${title.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            'title': title,
            'description': map['description']?.toString() ?? '',
            'ingredients': map['ingredients']?.toString() ?? '',
            'instructions': map['instructions']?.toString() ?? '',
            'calories': map['calories']?.toString() ?? '0',
            'proteins': map['proteins']?.toString() ?? '0',
            'fats': map['fats']?.toString() ?? '0',
            'carbs': map['carbs']?.toString() ?? '0',
          };
        })
        .where((r) => r.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _fallbackRecipes(
    List<Map<String, dynamic>> products,
    ProductTotals totals,
    String mealCategory,
  ) {
    final lowerNames = products
        .map((p) => p['name']?.toString().toLowerCase() ?? '')
        .toList();

    bool hasAny(List<String> keys) => lowerNames.any(
          (name) => keys.any((key) => name.contains(key)),
        );

    List<Map<String, dynamic>> pick(List<String> keys) {
      return products.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        return keys.any((key) => name.contains(key));
      }).toList();
    }

    final variants = <Map<String, dynamic>>[];

    if (hasAny(['салат', 'айсберг', 'руккол', 'укроп', 'зелен'])) {
      variants.add(
        _buildRecipeVariant(
          id: 'fallback_salad',
          title: 'Овощной салат с зеленью',
          description:
              'Свежий хрустящий салат с заправкой из оливкового масла.',
          selected: pick([
            'салат',
            'айсберг',
            'помидор',
            'черри',
            'перец',
            'огур',
            'лук',
            'укроп',
            'масло',
            'соль',
          ]),
          products: products,
          instructions: '''
1. Промойте и обсушите салат, нарежьте крупными листьями.
2. Помидоры черри разрежьте пополам, перец — тонкой соломкой, лук — полукольцами.
3. Смешайте овощи в миске, добавьте укроп.
4. Заправьте оливковым маслом, посолите и аккуратно перемешайте.
5. Подавайте сразу, пока салат остаётся свежим.''',
        ),
      );
    }

    if (hasAny(['брокколи', 'перец', 'лук', 'помидор', 'черри'])) {
      variants.add(
        _buildRecipeVariant(
          id: 'fallback_warm',
          title: 'Тёплые овощи на сковороде',
          description: 'Лёгкое тёплое блюдо с хрустящими овощами.',
          selected: pick([
            'брокколи',
            'перец',
            'лук',
            'помидор',
            'черри',
            'масло',
            'соль',
          ]),
          products: products,
          instructions: '''
1. Брокколи разделите на соцветия, перец нарежьте полосками, лук — полукольцами.
2. Разогрейте сковороду на среднем огне, добавьте 1 ст. л. оливкового масла.
3. Обжарьте лук 2 минуты до мягкости.
4. Добавьте брокколи и перец, готовьте 5–6 минут, помешивая.
5. В конце добавьте помидоры черри, посолите и прогрейте ещё 1 минуту.
6. Подавайте горячим.''',
        ),
      );
    }

    if (hasAny(['хлеб', 'булоч', 'сыр', 'помидор', 'черри'])) {
      variants.add(
        _buildRecipeVariant(
          id: 'fallback_bruschetta',
          title: 'Брускетта с сыром и помидорами',
          description: 'Хрустящий хлеб с сыром и свежими помидорами.',
          selected: pick([
            'хлеб',
            'булоч',
            'сыр',
            'помидор',
            'черри',
            'укроп',
            'масло',
            'соль',
          ]),
          products: products,
          instructions: '''
1. Хлеб нарежьте ломтиками толщиной 1 см.
2. Обжарьте на сухой сковороде по 1–2 минуты с каждой стороны до золотистой корочки.
3. Сыр натрите или нарежьте тонкими ломтиками.
4. Помидоры черри разрежьте пополам.
5. Выложите сыр на хлеб, добавьте помидоры, сбрызните маслом и посыпьте укропом.
6. Подавайте сразу после сборки.''',
        ),
      );
    }

    if (hasAny(['яйц', 'яиц'])) {
      variants.add(
        _buildRecipeVariant(
          id: 'fallback_omelet',
          title: 'Овощной омлет',
          description: 'Сытный омлет с овощами из вашего холодильника.',
          selected: pick([
            'яйц',
            'яиц',
            'перец',
            'лук',
            'помидор',
            'брокколи',
            'сыр',
            'масло',
            'соль',
          ]),
          products: products,
          instructions: '''
1. Яйца взбейте с щепоткой соли.
2. Овощи мелко нарежьте, обжарьте на масле 3–4 минуты.
3. Влейте яйца, готовьте на среднем огне 3–4 минуты.
4. Добавьте сыр, накройте крышкой и готовьте ещё 2 минуты.
5. Подавайте горячим.''',
        ),
      );
    }

    if (variants.length < 3) {
      variants.add(
        _buildRecipeVariant(
          id: 'fallback_mix_${mealCategory.toLowerCase()}',
          title: 'Смешанное блюдо на $mealCategory',
          description: 'Сбалансированное блюдо из доступных продуктов.',
          selected: products.take(products.length.clamp(3, 6)).toList(),
          products: products,
          instructions: '''
1. Подготовьте все продукты: промойте, обсушите и нарежьте удобным способом.
2. Разогрейте сковороду или сотейник на среднем огне, добавьте масло при необходимости.
3. Сначала обжарьте твёрдые овощи 4–5 минут.
4. Добавьте мягкие ингредиенты и прогрейте ещё 2–3 минуты.
5. Посолите, перемешайте и подавайте горячим или холодным — по типу блюда.''',
        ),
      );
    }

    while (variants.length < 3 && products.length > 1) {
      final index = variants.length;
      final sliceStart = (index * 2) % products.length;
      final selected = <Map<String, dynamic>>[];
      for (var i = 0; i < products.length && selected.length < 4; i++) {
        final product = products[(sliceStart + i) % products.length];
        if (!selected.contains(product)) {
          selected.add(product);
        }
      }

      variants.add(
        _buildRecipeVariant(
          id: 'fallback_variant_$index',
          title: 'Вариант ${index + 1}: ${_variantTitle(selected)}',
          description: 'Альтернативный рецепт из ваших продуктов.',
          selected: selected,
          products: products,
          instructions: '''
1. Подготовьте: ${_ingredientNames(selected)}.
2. Нарежьте продукты одинакового размера для равномерного приготовления.
3. Смешайте в миске или обжарьте на сковороде 5–7 минут на среднем огне.
4. Добавьте масло и соль по вкусу, перемешайте.
5. Подавайте сразу после приготовления.''',
        ),
      );
    }

    return variants.take(3).toList();
  }

  Map<String, dynamic> _buildRecipeVariant({
    required String id,
    required String title,
    required String description,
    required List<Map<String, dynamic>> selected,
    required List<Map<String, dynamic>> products,
    required String instructions,
  }) {
    final used = selected.isNotEmpty ? selected : products;
    final macros = _sumProductMacros(used);

    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': formatIngredientsList(used),
      'instructions': instructions.trim(),
      'calories': macros.calories.round().toString(),
      'proteins': macros.proteins.round().toString(),
      'fats': macros.fats.round().toString(),
      'carbs': macros.carbs.round().toString(),
    };
  }

  String formatIngredientsList(List<Map<String, dynamic>> products) {
    return products.map(formatIngredientLine).join('; ');
  }

  String formatIngredientLine(Map<String, dynamic> product) {
    final name = product['name']?.toString().trim() ?? 'Продукт';
    final qty = product['quantity']?.toString().trim() ?? '';
    final unit = product['unit']?.toString().trim() ?? 'г';
    if (qty.isEmpty) return name;
    return '$name — $qty $unit';
  }

  static List<String> parseCookingSteps(String text) {
    if (text.trim().isEmpty) return [];

    final rawSteps = text
        .split(RegExp(r'\s+(?=\d+\.\s)|\n+(?=\d+\.)'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();

    return rawSteps.asMap().entries.map((entry) {
      final cleaned = entry.value.replaceFirst(RegExp(r'^\d+\.\s*'), '');
      return '${entry.key + 1}. $cleaned';
    }).toList();
  }

  static List<String> parseIngredientItems(String ingredients) {
    if (ingredients.trim().isEmpty) return [];
    return ingredients
        .split(RegExp(r'[;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  ProductTotals _sumProductMacros(List<Map<String, dynamic>> products) {
    return calculateTotals(products);
  }

  String _variantTitle(List<Map<String, dynamic>> products) {
    final names = products
        .take(2)
        .map((p) => p['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'микс продуктов';
    if (names.length == 1) return names.first;
    return '${names.first} и ${names.last}';
  }

  String _ingredientNames(List<Map<String, dynamic>> products) {
    return products
        .map((p) => p['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }
}
