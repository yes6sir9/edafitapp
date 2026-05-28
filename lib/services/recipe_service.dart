import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'recipes';

  /// Импортирует рецепты из JSON файла в Firestore
  /// Возвращает количество успешно импортированных рецептов
  Future<int> importRecipesFromJson(String jsonPath) async {
    try {
      print('🚀 Начинаем импорт рецептов из файла...');
      
      // Загружаем JSON файл
      final jsonString = await rootBundle.loadString(jsonPath);
      final List<dynamic> recipesJson = jsonDecode(jsonString);

      if (recipesJson.isEmpty) {
        print('⚠️  Файл не содержит рецептов');
        return 0;
      }

      print('📋 Найдено ${recipesJson.length} рецептов');

      int successCount = 0;
      int errorCount = 0;

      // Использует батч для пакетного добавления
      final batch = _firestore.batch();
      int batchSize = 0;
      const maxBatchSize = 500; // Максимум операций в одном батче

      for (int i = 0; i < recipesJson.length; i++) {
        try {
          final recipeJson = recipesJson[i];
          
          final title = recipeJson['title']?.toString() ?? '';
          final type = recipeJson['type']?.toString() ?? '';
          final products = recipeJson['products']?.toString() ?? '';
          final calories = recipeJson['calories']?.toString() ?? '';
          final instructions = recipeJson['instructions']?.toString() ?? '';
          
          // Парсим БЖУ
          final macros = {
            'protein': recipeJson['macros']?['protein']?.toString() ?? '',
            'fat': recipeJson['macros']?['fat']?.toString() ?? '',
            'carbs': recipeJson['macros']?['carbs']?.toString() ?? '',
          };

          // Генерируем ID документа из заголовка
          final docId = title
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), '_')
              .replaceAll(RegExp(r'[^\w_а-яё]'), '');

          if (docId.isEmpty) {
            print('⚠️  Рецепт ${i + 1}: пустое название, пропускаем');
            errorCount++;
            continue;
          }

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

          final docRef = _firestore.collection(_collectionName).doc(docId);
          batch.set(docRef, recipeData);
          batchSize++;
          successCount++;

          print('✅ Рецепт ${i + 1}/${recipesJson.length}: "$title" подготовлен');

          // Коммитим батч если достигнут максимум
          if (batchSize >= maxBatchSize) {
            await batch.commit();
            print('💾 Батч ${(i ~/ maxBatchSize) + 1} коммичен (${batchSize} рецептов)');
            batchSize = 0;
          }
        } catch (e) {
          print('❌ Ошибка при обработке рецепта ${i + 1}: $e');
          errorCount++;
        }
      }

      // Коммитим оставшиеся рецепты
      if (batchSize > 0) {
        await batch.commit();
        print('💾 Финальный батч коммичен ($batchSize рецептов)');
      }

      print('\n📊 Результаты импорта:');
      print('✅ Успешно: $successCount');
      print('❌ Ошибок: $errorCount');
      print('🎉 Импорт завершен!');

      return successCount;
    } catch (e) {
      print('💥 Критическая ошибка при импорте: $e');
      print('📌 Тип ошибки: ${e.runtimeType}');
      print('📝 Полное сообщение: $e');
      rethrow;
    }
  }

  /// Импортирует рецепты из списка объектов
  Future<int> importRecipes(List<Map<String, dynamic>> recipes) async {
    try {
      print('🚀 Начинаем импорт ${recipes.length} рецептов...');

      int successCount = 0;
      int errorCount = 0;

      // Использует батч
      final batch = _firestore.batch();
      int batchSize = 0;
      const maxBatchSize = 500;

      for (int i = 0; i < recipes.length; i++) {
        try {
          final recipe = recipes[i];
          
          final title = recipe['title']?.toString() ?? '';
          final docId = title
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), '_')
              .replaceAll(RegExp(r'[^\w_а-яё]'), '');

          if (docId.isEmpty) {
            errorCount++;
            continue;
          }

          final recipeData = {
            'id': i + 1,
            'title': recipe['title'] ?? '',
            'type': recipe['type'] ?? '',
            'products': recipe['products'] ?? '',
            'calories': recipe['calories'] ?? '',
            'instructions': recipe['instructions'] ?? '',
            'macros': recipe['macros'] ?? {
              'protein': '',
              'fat': '',
              'carbs': '',
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          final docRef = _firestore.collection(_collectionName).doc(docId);
          batch.set(docRef, recipeData);
          batchSize++;
          successCount++;

          print('✅ Рецепт ${i + 1}/${recipes.length}: "${recipe['title']}" подготовлен');

          if (batchSize >= maxBatchSize) {
            await batch.commit();
            print('💾 Батч коммичен ($batchSize рецептов)');
            batchSize = 0;
          }
        } catch (e) {
          print('❌ Ошибка при обработке рецепта ${i + 1}: $e');
          errorCount++;
        }
      }

      if (batchSize > 0) {
        await batch.commit();
        print('💾 Финальный батч коммичен ($batchSize рецептов)');
      }

      print('\n📊 Результаты импорта:');
      print('✅ Успешно: $successCount');
      print('❌ Ошибок: $errorCount');

      return successCount;
    } catch (e) {
      print('💥 Критическая ошибка при импорте: $e');
      print('📌 Тип ошибки: ${e.runtimeType}');
      print('📝 Полное сообщение: $e');
      rethrow;
    }
  }

  /// Получает все рецепты из Firestore
  Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs
          .map((doc) => {...doc.data(), 'docId': doc.id})
          .toList();
    } catch (e) {
      print('❌ Ошибка при получении рецептов: $e');
      rethrow;
    }
  }

  /// Получает рецепт по ID
  Future<Map<String, dynamic>?> getRecipeById(String docId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(docId).get();
      if (doc.exists) {
        return {...doc.data() ?? {}, 'docId': doc.id};
      }
      return null;
    } catch (e) {
      print('❌ Ошибка при получении рецепта: $e');
      rethrow;
    }
  }

  /// Получает рецепты по типу (завтрак, обед, ужин и т.д.)
  Future<List<Map<String, dynamic>>> getRecipesByType(String type) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('type', isEqualTo: type)
          .get();
      return snapshot.docs
          .map((doc) => {...doc.data(), 'docId': doc.id})
          .toList();
    } catch (e) {
      print('❌ Ошибка при получении рецептов по типу: $e');
      rethrow;
    }
  }

  /// Удаляет все рецепты из коллекции (для тестирования)
  Future<void> clearRecipes() async {
    try {
      print('🗑️  Удаляем все рецепты...');
      final snapshot = await _firestore.collection(_collectionName).get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ Все рецепты удалены');
    } catch (e) {
      print('❌ Ошибка при удалении рецептов: $e');
      rethrow;
    }
  }
}
