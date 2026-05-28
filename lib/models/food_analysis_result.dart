import 'dart:convert';

class FoodAnalysisResult {
  final String name;
  final double calories;
  final double proteins;
  final double fats;
  final double carbs;
  final String portion;
  final String description;
  final String quantity;
  final String unit;

  const FoodAnalysisResult({
    required this.name,
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
    this.portion = '',
    this.description = '',
    this.quantity = '1',
    this.unit = 'порция',
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] ?? '').toString().trim();
    final unit = (json['unit'] ?? 'г').toString().trim();
    final portion = (json['portion'] ?? '').toString();

    return FoodAnalysisResult(
      name: (json['name'] ?? json['title'] ?? 'Блюдо').toString(),
      calories: _toDouble(json['calories']),
      proteins: _toDouble(json['proteins'] ?? json['protein']),
      fats: _toDouble(json['fats'] ?? json['fat']),
      carbs: _toDouble(json['carbs'] ?? json['carbohydrates']),
      portion: portion.isNotEmpty ? portion : (qty.isNotEmpty ? '$qty $unit' : ''),
      description: (json['description'] ?? '').toString(),
      quantity: qty.isNotEmpty ? qty : '1',
      unit: unit.isNotEmpty ? unit : 'порция',
    );
  }

  static FoodAnalysisResult? tryParseFromAiResponse(String response) {
    final list = tryParseListFromAiResponse(response);
    if (list.isEmpty) return null;
    return list.first;
  }

  static List<FoodAnalysisResult> tryParseListFromAiResponse(String response) {
    final trimmed = _stripMarkdownFences(response);
    if (trimmed.isEmpty) return [];

    final fromDecoded = _listFromDecoded(_tryJsonDecode(trimmed));
    if (fromDecoded.isNotEmpty) return fromDecoded;

    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(trimmed);
    if (arrayMatch != null) {
      final fromArray = _listFromDecoded(_tryJsonDecode(arrayMatch.group(0)!));
      if (fromArray.isNotEmpty) return fromArray;
    }

    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
    if (objectMatch != null) {
      return _listFromDecoded(_tryJsonDecode(objectMatch.group(0)!));
    }

    return [];
  }

  static String _stripMarkdownFences(String text) {
    var t = text.trim();
    if (!t.startsWith('```')) return t;
    t = t.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    if (t.endsWith('```')) {
      t = t.substring(0, t.length - 3).trimRight();
    }
    return t.trim();
  }

  static dynamic _tryJsonDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  static List<FoodAnalysisResult> _listFromDecoded(dynamic decoded) {
    if (decoded == null) return [];

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => FoodAnalysisResult.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.name.isNotEmpty && r.name != 'Не распознано')
          .toList();
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final products = map['products'];
      if (products is List) {
        return products
            .whereType<Map>()
            .map((e) => FoodAnalysisResult.fromJson(Map<String, dynamic>.from(e)))
            .where((r) => r.name.isNotEmpty && r.name != 'Не распознано')
            .toList();
      }
      if (map.containsKey('name')) {
        final one = FoodAnalysisResult.fromJson(map);
        if (one.name.isNotEmpty && one.name != 'Не распознано') {
          return [one];
        }
      }
    }

    return [];
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final text = value.toString().replaceAll(',', '.');
    return double.tryParse(RegExp(r'[\d.]+').stringMatch(text) ?? '') ?? 0;
  }
}
