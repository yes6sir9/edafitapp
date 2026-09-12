import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_analysis_result.dart';
import '../services/ai_service.dart';

Future<Map<String, dynamic>?> showAddCustomRecipeSheet(
  BuildContext context, {
  String defaultCategory = 'Обед',
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddCustomRecipeSheet(defaultCategory: defaultCategory),
  );
}

class _AddCustomRecipeSheet extends StatefulWidget {
  final String defaultCategory;

  const _AddCustomRecipeSheet({required this.defaultCategory});

  @override
  State<_AddCustomRecipeSheet> createState() => _AddCustomRecipeSheetState();
}

class _AddCustomRecipeSheetState extends State<_AddCustomRecipeSheet> {
  final AIService _aiService = AIService();
  final ImagePicker _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _carbsController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();

  final _categories = ['Завтрак', 'Обед', 'Ужин', 'Перекус'];
  late String _category;
  bool _isAnalyzingPhoto = false;

  @override
  void initState() {
    super.initState();
    _category = widget.defaultCategory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _proteinsController.dispose();
    _fatsController.dispose();
    _carbsController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _fillFromAnalysis(FoodAnalysisResult r) {
    _titleController.text = r.name;
    _caloriesController.text = r.calories.round().toString();
    _proteinsController.text = r.proteins.round().toString();
    _fatsController.text = r.fats.round().toString();
    _carbsController.text = r.carbs.round().toString();
    if (r.description.isNotEmpty) {
      _instructionsController.text = r.description;
    }
    if (r.portion.isNotEmpty) {
      _ingredientsController.text = 'Порция: ${r.portion}';
    }
  }

  Future<void> _fillFromPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 65,
    );
    if (file == null) return;

    setState(() => _isAnalyzingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = file.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final result = await _aiService.analyzeFoodImage(bytes, mimeType: mime);
      if (result != null && mounted) {
        setState(() => _fillFromAnalysis(result));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные заполнены по фото')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_aiService.formatUserError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingPhoto = false);
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название рецепта')),
      );
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch;
    Navigator.pop(context, {
      'id': id,
      'title': _titleController.text.trim(),
      'category': _category,
      'calories': _caloriesController.text.trim().isEmpty
          ? '0'
          : _caloriesController.text.trim(),
      'proteins': _proteinsController.text.trim().isEmpty
          ? '0'
          : _proteinsController.text.trim(),
      'fats':
          _fatsController.text.trim().isEmpty ? '0' : _fatsController.text.trim(),
      'carbs': _carbsController.text.trim().isEmpty
          ? '0'
          : _carbsController.text.trim(),
      'ingredients': _ingredientsController.text.trim(),
      'instructions': _instructionsController.text.trim(),
      'description': _instructionsController.text.trim(),
      'isCustom': true,
    });
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Свой рецепт',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isAnalyzingPhoto ? null : _fillFromPhoto,
                  icon: _isAnalyzingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: const Text('Заполнить по фото (ИИ)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Приём пищи',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _category,
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Калории',
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
                          labelText: 'Белки',
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
                          labelText: 'Жиры',
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
                          labelText: 'Углеводы',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ingredientsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ингредиенты',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _instructionsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Приготовление',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Сохранить рецепт'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
