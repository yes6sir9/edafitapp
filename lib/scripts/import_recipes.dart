import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../firebase_options.dart';

void main() async {
  // Инициализируем Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🚀 Начинаем импорт рецептов...');
  
  try {
    // Читаем CSV файл
    final csvFile = File('Recepts.csv');
    final lines = await csvFile.readAsLines();
    
    // Пропускаем заголовок
    final recipes = lines.sublist(1);
    print('📋 Найдено ${recipes.length} рецептов');
    
    final db = FirebaseFirestore.instance;
    int successCount = 0;
    int errorCount = 0;

    for (int i = 0; i < recipes.length; i++) {
      try {
        final parts = _parseCSVLine(recipes[i]);
        
        if (parts.length < 6) {
          print('⚠️  Некорректная строка ${i + 2}: недостаточно полей');
          continue;
        }

        final title = parts[0].trim();
        final type = parts[1].trim();
        final products = parts[2].trim();
        final calories = parts[3].trim();
        final instructions = parts[4].trim();
        final macrosText = parts[5].trim();
        
        final macros = _parseMacros(macrosText);
        
        final recipeData = {
          'id': i + 1,
          'title': title,
          'type': type,
          'products': products,
          'calories': calories,
          'instructions': instructions,
          'macros': macros,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Используем заголовок как ID документа (с нормализацией)
        final docId = title
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^\w_а-яё]'), '');

        await db.collection('recipes').doc(docId).set(recipeData);
        
        print('✅ Рецепт ${i + 1}/${recipes.length}: "$title" добавлен');
        successCount++;
      } catch (e) {
        print('❌ Ошибка при добавлении рецепта ${i + 2}: $e');
        errorCount++;
      }
    }

    print('\n📊 Результаты импорта:');
    print('✅ Успешно: $successCount');
    print('❌ Ошибок: $errorCount');
    print('🎉 Импорт завершен!');
    
  } catch (e) {
    print('💥 Критическая ошибка: $e');
  }
  
  exit(0);
}

/// Парсим строку CSV с поддержкой кавычек
List<String> _parseCSVLine(String line) {
  final parts = <String>[];
  String current = '';
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      parts.add(current);
      current = '';
    } else {
      current += char;
    }
  }
  
  if (current.isNotEmpty) {
    parts.add(current);
  }

  // Убираем кавычки из результатов
  return parts.map((p) => p.replaceAll('"', '')).toList();
}

/// Парсим БЖУ из строки типа "Белки: 28 г, Жиры: 8 г, Углеводы: 42 г"
Map<String, String> _parseMacros(String macrosText) {
  final macros = {
    'protein': '',
    'fat': '',
    'carbs': '',
  };

  final proteinRegex = RegExp(r'Белки:\s*([\d.,]+)\s*г');
  final fatRegex = RegExp(r'Жиры:\s*([\d.,]+)\s*г');
  final carbsRegex = RegExp(r'Углеводы:\s*([\d.,]+)\s*г');

  final proteinMatch = proteinRegex.firstMatch(macrosText);
  final fatMatch = fatRegex.firstMatch(macrosText);
  final carbsMatch = carbsRegex.firstMatch(macrosText);

  if (proteinMatch != null) macros['protein'] = proteinMatch.group(1) ?? '';
  if (fatMatch != null) macros['fat'] = fatMatch.group(1) ?? '';
  if (carbsMatch != null) macros['carbs'] = carbsMatch.group(1) ?? '';

  return macros;
}
