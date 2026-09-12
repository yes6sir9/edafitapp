import 'package:flutter/material.dart';

import '../services/food_diary_service.dart';
import '../services/products_recipe_service.dart';
import 'product_photo_sheet.dart';

Future<void> showProductsRecipesSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> products,
  required String goal,
  required String mealCategory,
  required Future<void> Function(List<Map<String, dynamic>> products)
      onProductsChanged,
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
      onProductsChanged: onProductsChanged,
      onDiarySaved: onDiarySaved,
    ),
  );
}

class _ProductsRecipesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String goal;
  final String mealCategory;
  final Future<void> Function(List<Map<String, dynamic>> products)
      onProductsChanged;
  final Future<void> Function() onDiarySaved;

  const _ProductsRecipesSheet({
    required this.products,
    required this.goal,
    required this.mealCategory,
    required this.onProductsChanged,
    required this.onDiarySaved,
  });

  @override
  State<_ProductsRecipesSheet> createState() => _ProductsRecipesSheetState();
}

class _ProductsRecipesSheetState extends State<_ProductsRecipesSheet> {
  final ProductsRecipeService _service = ProductsRecipeService();
  final FoodDiaryService _diary = FoodDiaryService.instance;

  late List<Map<String, dynamic>> _products;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _products = widget.products
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  ProductTotals get _totals => _service.calculateTotals(_products);

  Future<void> _persistProducts() async {
    await widget.onProductsChanged(_products);
  }

  Future<void> _removeProduct(int index) async {
    final name = _products[index]['name']?.toString() ?? 'Продукт';
    setState(() {
      _products.removeAt(index);
      _suggestions = [];
      _error = null;
    });
    await _persistProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«$name» удалён')),
    );
  }

  Future<void> _addByPhoto() async {
    await showProductPhotoSheet(
      context,
      currentProducts: _products,
      onSave: (products) async {
        setState(() {
          _products = products
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _suggestions = [];
          _error = null;
        });
        await _persistProducts();
      },
    );
  }

  Future<void> _addManually() async {
    final product = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ManualProductAddSheet(),
    );
    if (product == null) return;

    setState(() {
      _products.add(product);
      _suggestions = [];
      _error = null;
    });
    await _persistProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${product['name']}» добавлен')),
    );
  }

  Future<void> _loadSuggestions() async {
    if (_products.isEmpty) {
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
        products: _products,
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
                      if (_products.isEmpty)
                        Text(
                          'Нет продуктов. Добавьте их по фото или вручную — ИИ предложит рецепты.',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Мои продукты',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'Нажмите ✕, чтобы удалить',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._products.asMap().entries.map((entry) {
                          final index = entry.key;
                          final product = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${product['name']} '
                                    '(${product['quantity']} ${product['unit']}) — '
                                    '${product['calories']} ккал',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.red.shade400,
                                  ),
                                  tooltip: 'Удалить',
                                  onPressed: () => _removeProduct(index),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addByPhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('По фото'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addManually,
                              icon: const Icon(Icons.edit),
                              label: const Text('Вручную'),
                            ),
                          ),
                        ],
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
                                  if ((recipe['instructions'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Как готовить',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...ProductsRecipeService.parseCookingSteps(
                                      recipe['instructions'].toString(),
                                    ).map(
                                      (step) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          step,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Ингредиенты',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...ProductsRecipeService.parseIngredientItems(
                                    recipe['ingredients']?.toString() ?? '',
                                  ).map(
                                    (item) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        '• $item',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
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

class _ManualProductAddSheet extends StatefulWidget {
  const _ManualProductAddSheet();

  @override
  State<_ManualProductAddSheet> createState() => _ManualProductAddSheetState();
}

class _ManualProductAddSheetState extends State<_ManualProductAddSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _carbsController = TextEditingController();

  String _selectedUnit = 'г';
  final _units = ['г', 'мл', 'шт', 'кг', 'л'];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _caloriesController.dispose();
    _proteinsController.dispose();
    _fatsController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty ||
        _quantityController.text.trim().isEmpty ||
        _caloriesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните название, количество и калории'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'unit': _selectedUnit,
      'calories': _caloriesController.text.trim(),
      'proteins': _proteinsController.text.trim().isEmpty
          ? '0'
          : _proteinsController.text.trim(),
      'fats': _fatsController.text.trim().isEmpty
          ? '0'
          : _fatsController.text.trim(),
      'carbs': _carbsController.text.trim().isEmpty
          ? '0'
          : _carbsController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F5E6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Добавить продукт',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Количество',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Ед.',
                        border: OutlineInputBorder(),
                      ),
                      items: _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedUnit = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Калории (ккал)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _proteinsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Белки (г)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fatsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Жиры (г)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Углеводы (г)',
                        border: OutlineInputBorder(),
                      ),
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
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
