# 📚 Импорт рецептов из CSV в Firebase Firestore

Этот документ описывает как импортировать рецепты из файла `Recepts.csv` в Firestore коллекцию `recipes`.

## 📋 Содержание

1. [Структура данных](#структура-данных)
2. [Способы импорта](#способы-импорта)
3. [Использование в приложении](#использование-в-приложении)
4. [Структура коллекции](#структура-коллекции)

## 📊 Структура данных

CSV файл `Recepts.csv` содержит 19 рецептов со следующими полями:

| Колонка | Тип | Описание |
|---------|-----|---------|
| Название | String | Название рецепта |
| Тип | String | Тип блюда (Завтрак, Обед, Ужин, Перекус) |
| Продукты | String | Список ингредиентов |
| Килакалории | String | Калорийность в ккал |
| Подробное описание приготовление | String | Пошаговая инструкция |
| БЖУ | String | Белки, жиры, углеводы |

## 🚀 Способы импорта

### Способ 1: Через приложение Flutter (Рекомендуется)

Самый простой способ для пользователей приложения:

```dart
// В вашем виджете или экране используйте:
import 'package:edafitapp/services/recipe_service.dart';

final recipeService = RecipeService();
final importedCount = await recipeService.importRecipesFromJson(
  'assets/recipes-data.json',
);
```

Или откройте экран импорта:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const ImportRecipesScreen(),
  ),
);
```

### Способ 2: Программный импорт

```dart
import 'package:edafitapp/services/recipe_service.dart';
import 'dart:convert';

// Загружаем данные
final jsonString = await rootBundle.loadString('assets/recipes-data.json');
final List<dynamic> recipes = jsonDecode(jsonString);

// Конвертируем в список
final recipeList = recipes.cast<Map<String, dynamic>>();

// Импортируем
final recipeService = RecipeService();
final count = await recipeService.importRecipes(recipeList);
print('Импортировано $count рецептов');
```

### Способ 3: Через Node.js скрипт

Для локальной разработки:

```bash
cd functions
npm install  # Установить зависимости
npm run import  # Подготовить данные
```

Этот скрипт создает файл `recipes-data.json` с готовыми данными.

## 📱 Использование в приложении

### 1. Добавьте зависимости

Уже добавлены в `pubspec.yaml`:
- `cloud_firestore: ^5.0.0`
- `firebase_core: ^3.0.0`

### 2. Используйте RecipeService

```dart
import 'package:edafitapp/services/recipe_service.dart';

class MyRecipeWidget extends StatefulWidget {
  @override
  _MyRecipeWidgetState createState() => _MyRecipeWidgetState();
}

class _MyRecipeWidgetState extends State<MyRecipeWidget> {
  final RecipeService _recipeService = RecipeService();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      // Импортируем при первом запуске
      final count = await _recipeService.importRecipesFromJson(
        'assets/recipes-data.json',
      );
      print('Импортировано $count рецептов');

      // Получаем все рецепты
      final recipes = await _recipeService.getRecipes();
      setState(() {
        // Обновляем UI
      });
    } catch (e) {
      print('Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ваш UI код
    return Container();
  }
}
```

### 3. Методы RecipeService

#### Импорт

```dart
// Импорт из JSON файла
final count = await recipeService.importRecipesFromJson('assets/recipes-data.json');

// Импорт из списка
final count = await recipeService.importRecipes([
  {
    'title': 'Рецепт 1',
    'type': 'Завтрак',
    'products': '...',
    'calories': '250 ккал',
    'instructions': '...',
    'macros': {
      'protein': '10',
      'fat': '5',
      'carbs': '35'
    }
  }
]);
```

#### Получение данных

```dart
// Получить все рецепты
final recipes = await recipeService.getRecipes();

// Получить рецепт по ID
final recipe = await recipeService.getRecipeById('recipe_id');

// Получить рецепты по типу
final breakfasts = await recipeService.getRecipesByType('Завтрак');
```

#### Удаление

```dart
// Удалить все рецепты (для тестирования)
await recipeService.clearRecipes();
```

## 📚 Структура коллекции Firestore

Коллекция `recipes` содержит документы со следующей структурой:

```json
{
  "id": 1,
  "title": "Тост с глазуньей и рукколой",
  "type": "Завтрак",
  "products": "Помидоры черри (60 г), руккола (10 г), яйцо (1 шт.), ...",
  "calories": "252 ккал",
  "instructions": "Обжарить тостовый хлеб...",
  "macros": {
    "protein": "11",
    "fat": "13",
    "carbs": "22"
  },
  "createdAt": "2024-01-01T12:00:00Z",
  "updatedAt": "2024-01-01T12:00:00Z"
}
```

**ID документа**: Нормализованное название рецепта
- Пример: `tost_s_glazunej_i_rukkoloj`

## 🔧 Устранение проблем

### Проблема: "Could not load default credentials"

**Решение**: Firebase Auth уже настроена в приложении. Используйте импорт через приложение.

### Проблема: Рецепты не появляются после импорта

**Решение**:
1. Проверьте, что Firebase инициализирован в `main.dart`
2. Проверьте правила безопасности Firestore в Firebase Console
3. Убедитесь, что коллекция `recipes` создана

### Проблема: Файл assets не найден

**Решение**: 
1. Проверьте, что файл находится в `assets/recipes-data.json`
2. Проверьте, что в `pubspec.yaml` указана эта папка:
```yaml
flutter:
  assets:
    - assets/recipes-data.json
```
3. Запустите `flutter pub get`

## 📝 Примеры кода

### Пример 1: Импорт при первом запуске

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edafitapp/services/recipe_service.dart';

Future<void> initializeApp() async {
  final prefs = await SharedPreferences.getInstance();
  final isRecipesImported = prefs.getBool('recipes_imported') ?? false;

  if (!isRecipesImported) {
    final recipeService = RecipeService();
    await recipeService.importRecipesFromJson('assets/recipes-data.json');
    await prefs.setBool('recipes_imported', true);
    print('✅ Рецепты импортированы');
  }
}
```

### Пример 2: Отображение рецептов по типам

```dart
import 'package:edafitapp/services/recipe_service.dart';

class RecipesByCategoryScreen extends StatefulWidget {
  final String category;
  
  const RecipesByCategoryScreen({required this.category});

  @override
  _RecipesByCategoryScreenState createState() => _RecipesByCategoryScreenState();
}

class _RecipesByCategoryScreenState extends State<RecipesByCategoryScreen> {
  final RecipeService _recipeService = RecipeService();
  late Future<List<Map<String, dynamic>>> _recipes;

  @override
  void initState() {
    super.initState();
    _recipes = _recipeService.getRecipesByType(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _recipes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        
        final recipes = snapshot.data ?? [];
        
        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return ListTile(
              title: Text(recipe['title'] ?? ''),
              subtitle: Text(recipe['calories'] ?? ''),
            );
          },
        );
      },
    );
  }
}
```

## ✅ Чек-лист

- [x] CSV файл `Recepts.csv` содержит 19 рецептов
- [x] Создана коллекция `recipes` в Firestore
- [x] Создан `RecipeService` для работы с данными
- [x] Добавлены assets в `pubspec.yaml`
- [x] Создан `ImportRecipesScreen` для пользовательского импорта
- [x] Документация подготовлена

## 📞 Поддержка

Если у вас возникли вопросы или проблемы:

1. Проверьте консоль Firebase для ошибок безопасности
2. Убедитесь, что Firebase инициализирован правильно
3. Проверьте правила Firestore в Firebase Console

```yaml
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /recipes/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Удачи с импортом! 🎉
