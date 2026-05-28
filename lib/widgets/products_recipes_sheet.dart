import 'package:flutter/material.dart';

import '../services/food_diary_service.dart';
import '../services/products_recipe_service.dart';

Future<void> showProductsRecipesSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> products,
  required String goal,
  required String mealCategory,
  required VoidCallback onProductsTap,
  required Future<void> Function() onDiarySaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProductsRecipesSheet(
      products: products,
      goal: goal,
      mealCategory: mealCategory,
      onProductsTap: onProductsTap,
      onDiarySaved: onDiarySaved,
    ),
  );
}

class _ProductsRecipesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String goal;
  final String mealCategory;
  final VoidCallback onProductsTap;
  final Future<void> Function() onDiarySaved;

  const _ProductsRecipesSheet({
    required this.products,
    required this.goal,
    required this.mealCategory,
    required this.onProductsTap,
    required this.onDiarySaved,
  });

  @override
  State<_ProductsRecipesSheet> createState() => _ProductsRecipesSheetState();
}

class _ProductsRecipesSheetState extends State<_ProductsRecipesSheet> {
  final ProductsRecipeService _service = ProductsRecipeService();
  final FoodDiaryService _diary = FoodDiaryService.instance;

  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  ProductTotals get _totals => _service.calculateTotals(widget.products);

  Future<void> _loadSuggestions() async {
    if (widget.products.isEmpty) {
      setState(() => _error = 'Сначала добавьте продукты (по фото или вручную)');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _suggestions = [];
    });

    try {
      final recipes = await _service.suggestRecipesFromProducts(
        products: widget.products,
        goal: widget.goal,
        mealCategory: widget.mealCategory,
      );
      if (!mounted) return;
      setState(() => _suggestions = recipes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToDiary(Map<String, dynamic> recipe) {
    final id = recipe['id'].hashCode;
    if (_diary.isRecipeAdded(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${recipe['title']}» уже в дневнике')),
      );
      return;
    }

    _diary.addRecipeToDiary(
      id: id,
      title: recipe['title']?.toString() ?? 'Рецепт',
      category: widget.mealCategory,
      calories: recipe['calories']?.toString() ?? '0',
      proteins: recipe['proteins']?.toString() ?? '0',
      fats: recipe['fats']?.toString() ?? '0',
      carbs: recipe['carbs']?.toString() ?? '0',
      description: recipe['description']?.toString() ?? '',
      ingredients: recipe['ingredients']?.toString() ?? '',
      instructions: recipe['instructions']?.toString() ?? '',
    );

    widget.onDiarySaved();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${recipe['title']}» добавлено в дневник')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F5E6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Рецепты из ваших продуктов',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.products.isEmpty)
                        Text(
                          'Нет продуктов. Добавьте их по фото — ИИ посчитает КБЖУ и предложит рецепты.',
                          style: TextStyle(color: Colors.grey.shade700),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Всего продуктов: ${_totals.count}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Сумма: ${_totals.calories.round()} ккал • '
                                'Б:${_totals.proteins.round()} '
                                'Ж:${_totals.fats.round()} '
                                'У:${_totals.carbs.round()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...widget.products.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '• ${p['name']} (${p['quantity']} ${p['unit']}) — '
                              '${p['calories']} ккал',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onProductsTap();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить продукт'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loadSuggestions,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isLoading
                              ? 'Подбираю рецепты...'
                              : 'Подобрать рецепты (ИИ)',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ],
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Предложения',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._suggestions.map((recipe) {
                          final inDiary =
                              _diary.isRecipeAdded(recipe['id'].hashCode);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe['title']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if ((recipe['description'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(recipe['description'].toString()),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ингредиенты: ${recipe['ingredients']}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${recipe['calories']} ккал • '
                                    'Б:${recipe['proteins']} '
                                    'Ж:${recipe['fats']} '
                                    'У:${recipe['carbs']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: inDiary
                                          ? null
                                          : () => _addToDiary(recipe),
                                      child: Text(
                                        inDiary
                                            ? 'В дневнике'
                                            : 'Добавить в дневник',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
