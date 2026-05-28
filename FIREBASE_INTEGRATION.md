# Интеграция Firebase Functions с Flutter

## Установка пакетов

Пакеты уже добавлены в `pubspec.yaml`:
- `firebase_core: ^3.0.0` - основная библиотека Firebase
- `cloud_functions: ^5.0.0` - для работы с Cloud Functions

```bash
flutter pub get
```

## Структура проекта

```
lib/
  services/
    ai_service.dart      # Сервис для работы с Firebase Functions
  screens/
    ai_chat_screen.dart  # Пример экрана с AI чатом
```

## Использование

### 1. Инициализация Firebase (в main.dart)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### 2. Использование AiService

```dart
import 'package:edafitapp/services/ai_service.dart';

final aiService = AiService();

// Отправка промпта
final response = await aiService.ask('Что такое вегетарианство?');
print(response); // Ответ от GPT

// Проверка здоровья сервиса
final isHealthy = await aiService.checkHealth();
```

### 3. Интеграция в виджет

Смотрите `lib/screens/ai_chat_screen.dart` для полного примера:

```dart
import 'package:edafitapp/services/ai_service.dart';

class MyWidget extends StatelessWidget {
  final AiService _aiService = AiService();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          final response = await _aiService.ask('Ваш вопрос');
          print(response);
        } catch (e) {
          print('Ошибка: $e');
        }
      },
      child: const Text('Спросить AI'),
    );
  }
}
```

## Конфигурация Firebase

1. Откройте [Firebase Console](https://console.firebase.google.com/)
2. Перейдите в **Cloud Functions**
3. Убедитесь, что функции развернуты
4. Проверьте, что функции доступны и правильно настроены

## Обработка ошибок

`AiService` обрабатывает два типа ошибок:

- `FirebaseFunctionsException` - ошибки от Firebase Functions
- Общие исключения - проблемы с сетью или другие проблемы

```dart
try {
  final response = await aiService.ask('Вопрос');
} catch (e) {
  print('Ошибка: $e');
}
```

## Тестирование локально

```bash
# В папке functions
npm start

# В другом терминале
firebase emulator:start
```

Затем в Flutter используйте локальный эмулятор (обновите firebase.json):

```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  },
  "emulators": {
    "functions": {
      "host": "127.0.0.1",
      "port": 5001
    }
  }
}
```

## Ссылки

- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [Cloud Functions Package](https://pub.dev/packages/cloud_functions)
- [Firebase Console](https://console.firebase.google.com/)
