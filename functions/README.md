# Edafitapp Firebase Cloud Functions

Backend функции для приложения Edafitapp, развернутые на Firebase Cloud Functions.

## Установка

1. Установите зависимости:
```bash
npm install
```

2. Создайте файл `.env` на основе `.env.example`:
```bash
cp .env.example .env
```

3. Заполните `OPENAI_API_KEY` вашим API ключом от OpenAI.

## Функции

### `askAi`
Облачная функция для взаимодействия с OpenAI API.

**Параметры:**
- `prompt` (string): Текст вопроса/промпта для GPT

**Возвращает:**
```json
{
  "text": "Ответ от GPT",
  "success": true
}
```

**Пример использования в Flutter:**
```dart
final functions = FirebaseFunctions.instance;
final result = await functions.httpsCallable('askAi').call({
  'prompt': 'Что такое вегетарианство?',
});
print(result.data['text']);
```

### `health`
Проверка здоровья сервиса.

## Локальное тестирование

```bash
npm start
```

Затем в другом терминале:
```bash
firebase functions:shell
> askAi({prompt: "Привет!"})
```

## Развертывание

```bash
firebase deploy --only functions
```

## Ссылки

- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [OpenAI API Documentation](https://platform.openai.com/docs)
