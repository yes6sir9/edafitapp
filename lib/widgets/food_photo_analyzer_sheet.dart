import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_analysis_result.dart';
import '../services/ai_service.dart';
import '../services/food_diary_service.dart';

Future<void> showFoodPhotoAnalyzerSheet(
  BuildContext context, {
  required Future<void> Function() onDiarySaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FoodPhotoAnalyzerSheet(onDiarySaved: onDiarySaved),
  );
}

class _FoodPhotoAnalyzerSheet extends StatefulWidget {
  final Future<void> Function() onDiarySaved;

  const _FoodPhotoAnalyzerSheet({required this.onDiarySaved});

  @override
  State<_FoodPhotoAnalyzerSheet> createState() => _FoodPhotoAnalyzerSheetState();
}

class _FoodPhotoAnalyzerSheetState extends State<_FoodPhotoAnalyzerSheet> {
  final AIService _aiService = AIService();
  final ImagePicker _picker = ImagePicker();
  final List<String> _mealCategories = [
    'Завтрак',
    'Обед',
    'Ужин',
    'Перекус',
  ];

  Uint8List? _imageBytes;
  String? _imageMimeType;
  FoodAnalysisResult? _result;
  String? _error;
  bool _isAnalyzing = false;
  String _selectedCategory = 'Обед';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 65,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = _mimeFromPath(file.path);

      setState(() {
        _imageBytes = bytes;
        _imageMimeType = mime;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Не удалось выбрать фото: $e');
    }
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _analyzePhoto() async {
    if (_imageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _aiService.analyzeFoodImage(
        _imageBytes!,
        mimeType: _imageMimeType ?? 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        if (result == null) {
          _error =
              'Не удалось разобрать ответ Gemini. Проверьте GEMINI_API_KEY в .env';
        }
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _aiService.formatUserError(e));
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _addToDiary() async {
    final result = _result;
    if (result == null) return;

    FoodDiaryService.instance.addRecipeToDiary(
      id: DateTime.now().millisecondsSinceEpoch,
      title: result.name,
      category: _selectedCategory,
      calories: result.calories.round().toString(),
      proteins: result.proteins.round().toString(),
      fats: result.fats.round().toString(),
      carbs: result.carbs.round().toString(),
      description: [
        if (result.portion.isNotEmpty) 'Порция: ${result.portion}',
        if (result.description.isNotEmpty) result.description,
        'Добавлено по фото (ИИ)',
      ].join('\n'),
    );

    await widget.onDiarySaved();

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${result.name}» добавлено в дневник')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F5E6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ИИ по фото еды',
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
                const SizedBox(height: 8),
                Text(
                  'Сфотографируйте блюдо — Gemini оценит калории и БЖУ.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Камера'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Галерея'),
                      ),
                    ),
                  ],
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _imageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
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
                        value: _selectedCategory,
                        items: _mealCategories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: _isAnalyzing
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _selectedCategory = value);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzePhoto,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isAnalyzing ? 'Анализирую...' : 'Распознать еду',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _result!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_result!.portion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _result!.portion,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          '${_result!.calories.round()} ккал • '
                          'Б:${_result!.proteins.round()} '
                          'Ж:${_result!.fats.round()} '
                          'У:${_result!.carbs.round()}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_result!.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _result!.description,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addToDiary,
                            child: const Text('Добавить в дневник'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
