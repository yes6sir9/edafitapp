import 'package:flutter/material.dart';

class FoodDiaryService {
  FoodDiaryService._();

  static final FoodDiaryService instance = FoodDiaryService._();

  final ValueNotifier<List<Map<String, dynamic>>> eatenRecipes = ValueNotifier(
    [],
  );

  String get currentDateKey => DateTime.now().toIso8601String().split('T').first;

  void loadDailyDiary(Map<String, dynamic>? dailyDiary) {
    if (dailyDiary == null) {
      eatenRecipes.value = [];
      return;
    }

    final todayData = dailyDiary[currentDateKey];
    if (todayData is Map<String, dynamic>) {
      final entries = (todayData['entries'] as List<dynamic>?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          [];
      eatenRecipes.value = entries;
    } else {
      eatenRecipes.value = [];
    }
  }

  Map<String, dynamic> buildDailyDiaryPayload(Map<String, dynamic>? existingDiary) {
    final payload = existingDiary != null
        ? Map<String, dynamic>.from(existingDiary)
        : <String, dynamic>{};

    payload[currentDateKey] = {
      'entries': eatenRecipes.value,
      'totals': {
        'calories': getTotalCalories(),
        'proteins': getTotalProteins(),
        'fats': getTotalFats(),
        'carbs': getTotalCarbs(),
      },
    };

    return payload;
  }

  void addRecipeToDiary({
    required int id,
    required String title,
    required String category,
    required String calories,
    required String proteins,
    required String fats,
    required String carbs,
    String description = '',
    String ingredients = '',
    String instructions = '',
  }) {
    final newEntry = {
      'entryId': '${id}_${DateTime.now().millisecondsSinceEpoch}',
      'id': id,
      'title': title,
      'category': category,
      'calories': calories,
      'proteins': proteins,
      'fats': fats,
      'carbs': carbs,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'eatenAt': DateTime.now().toIso8601String(),
    };

    eatenRecipes.value = [...eatenRecipes.value, newEntry];
  }

  void removeDiaryEntry(String entryId) {
    eatenRecipes.value = eatenRecipes.value
        .where((entry) => entry['entryId'] != entryId)
        .toList();
  }

  bool isRecipeAdded(int recipeId) {
    return eatenRecipes.value.any((entry) => entry['id'] == recipeId);
  }

  double getTotalCalories() {
    return eatenRecipes.value.fold(
      0.0,
      (sum, entry) => sum + _parseNumber(entry['calories']),
    );
  }

  double getTotalProteins() {
    return eatenRecipes.value.fold(
      0.0,
      (sum, entry) => sum + _parseNumber(entry['proteins']),
    );
  }

  double getTotalFats() {
    return eatenRecipes.value.fold(
      0.0,
      (sum, entry) => sum + _parseNumber(entry['fats']),
    );
  }

  double getTotalCarbs() {
    return eatenRecipes.value.fold(
      0.0,
      (sum, entry) => sum + _parseNumber(entry['carbs']),
    );
  }

  List<Map<String, dynamic>> getEntriesByCategory(String category) {
    return eatenRecipes.value
        .where((entry) => entry['category'] == category)
        .toList();
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final text = value.toString().replaceAll(',', '.').trim();
    return double.tryParse(text) ?? 0.0;
  }
}
