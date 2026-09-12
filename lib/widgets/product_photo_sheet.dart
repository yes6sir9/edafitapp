import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_analysis_result.dart';
import '../services/ai_service.dart';

Future<void> showProductPhotoSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> currentProducts,
  required Future<void> Function(List<Map<String, dynamic>> products) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProductPhotoSheet(
      currentProducts: currentProducts,
      onSave: onSave,
    ),
  );
}

class _ProductPhotoSheet extends StatefulWidget {
  final List<Map<String, dynamic>> currentProducts;
  final Future<void> Function(List<Map<String, dynamic>> products) onSave;

  const _ProductPhotoSheet({
    required this.currentProducts,
    required this.onSave,
  });

  @override
  State<_ProductPhotoSheet> createState() => _ProductPhotoSheetState();
}

class _ProductPhotoSheetState extends State<_ProductPhotoSheet> {
  final AIService _aiService = AIService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageMimeType;
  List<FoodAnalysisResult> _results = [];
  String? _error;
  bool _isAnalyzing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 65,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageMimeType = _mimeFromPath(file.path);
        _results = [];
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
    return 'image/jpeg';
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) return;
    setState(() {
      _isAnalyzing = true;
      _error = null;
      _results = [];
    });

    try {
      final results = await _aiService.analyzeProductImage(
        _imageBytes!,
        mimeType: _imageMimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _error = 'Не удалось разобрать ответ Gemini.';
        }
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _aiService.formatUserError(e));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Map<String, dynamic> _productMap(FoodAnalysisResult r) => {
        'name': r.name,
        'quantity': r.quantity,
        'unit': r.unit,
        'calories': r.calories.round().toString(),
        'proteins': r.proteins.round().toString(),
        'fats': r.fats.round().toString(),
        'carbs': r.carbs.round().toString(),
        'source': 'photo_ai',
      };

  Future<void> _saveAllProducts() async {
    if (_results.isEmpty) return;

    final updated = [
      ...widget.currentProducts,
      ..._results.map(_productMap),
    ];

    await widget.onSave(updated);
    if (!mounted) return;
    Navigator.pop(context);
    final count = _results.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Продукт «${_results.first.name}» добавлен'
              : 'Добавлено продуктов: $count',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
              children: [
                const Text(
                  'Продукты по фото',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gemini распознает все продукты на фото и КБЖУ',
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
                    child: Image.memory(_imageBytes!, height: 160, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyze,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isAnalyzing ? 'Анализ...' : 'Распознать'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ],
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Найдено: ${_results.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._results.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${r.quantity} ${r.unit} • '
                                '${r.calories.round()} ккал • '
                                'Б:${r.proteins.round()} '
                                'Ж:${r.fats.round()} '
                                'У:${r.carbs.round()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAllProducts,
                      child: Text(
                        _results.length == 1
                            ? 'Добавить в мои продукты'
                            : 'Добавить все (${_results.length})',
                      ),
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
