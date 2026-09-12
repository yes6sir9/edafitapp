import 'dart:async';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';
import '../models/food_analysis_result.dart';
import 'gemini_http_client.dart';

class AIService {
  static final http.Client _httpClient = createGeminiHttpClient();
  static const Duration _requestTimeout = Duration(seconds: 120);
  static const Duration _retryDelay = Duration(seconds: 2);

  GenerativeModel _createModel(
    String modelName, {
    int maxOutputTokens = 1024,
    bool jsonResponse = false,
  }) {
    return GenerativeModel(
      model: modelName,
      apiKey: _requireApiKey(),
      httpClient: _httpClient,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: maxOutputTokens,
        responseMimeType: jsonResponse ? 'application/json' : null,
      ),
    );
  }

  String _requireApiKey() {
    final key = GeminiConfig.apiKey;
    if (key == null) {
      throw StateError(GeminiConfig.missingKeyMessage);
    }
    return key;
  }

  bool _shouldTryNextModel(Object e) {
    final msg = e.toString().toLowerCase();
    final isServiceBusy = msg.contains('503') ||
        msg.contains('unavailable') ||
        msg.contains('high demand') ||
        msg.contains('try again later');
    return msg.contains('quota') ||
        msg.contains('429') ||
        isServiceBusy ||
        msg.contains('limit: 0') ||
        msg.contains('not found') ||
        msg.contains('not supported') ||
        msg.contains('timeout') ||
        msg.contains('semaphore') ||
        msg.contains('timed out') ||
        msg.contains('socket') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection');
  }

  String formatUserError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('503') ||
        msg.contains('unavailable') ||
        msg.contains('high demand') ||
        msg.contains('try again later')) {
      return 'Сервис Gemini сейчас перегружен. Повторите через 30-60 секунд.';
    }
    if (msg.contains('429') || msg.contains('quota') || msg.contains('limit')) {
      return 'Превышен лимит Gemini API. Проверьте квоту и попробуйте позже.';
    }
    if (msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('socket') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection')) {
      return 'Проблема с сетью при обращении к Gemini. Проверьте интернет и повторите.';
    }
    if (error is StateError) {
      return error.message;
    }

    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return 'Не удалось получить ответ Gemini. Повторите попытку позже.';
  }

  Future<String?> _generateContentText(
    String modelName,
    List<Content> contents, {
    int maxOutputTokens = 1024,
    bool jsonResponse = false,
  }) async {
    final model = _createModel(
      modelName,
      maxOutputTokens: maxOutputTokens,
      jsonResponse: jsonResponse,
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await model
            .generateContent(contents)
            .timeout(_requestTimeout);
        return response.text?.trim();
      } on TimeoutException {
        if (attempt == 0) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        rethrow;
      } catch (e) {
        if (attempt == 0 && _shouldTryNextModel(e)) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  Future<String> generateDailyNutritionTip({
    required String goal,
    required String dateLabel,
    required int eatenCalories,
    required double eatenProteins,
    required double eatenFats,
    required double eatenCarbs,
    required int targetCalories,
    required double targetProteins,
    required double targetFats,
    required double targetCarbs,
    required List<Map<String, dynamic>> meals,
  }) async {
    if (!GeminiConfig.isConfigured) {
      return 'Подключите Gemini API в настройках, чтобы получать персональные советы.';
    }

    final mealsSummary = meals.isEmpty
        ? 'Пока ничего не съедено.'
        : meals
            .map(
              (meal) =>
                  '- ${meal['title'] ?? meal['name'] ?? 'Блюдо'}: ${meal['calories']} ккал',
            )
            .join('\n');

    final remaining = targetCalories - eatenCalories;

    final prompt = '''
Ты диетолог. Дай один короткий совет на русском (максимум 2 предложения, до 140 символов).
Цель: $goal
День: $dateLabel
Съедено: $eatenCalories ккал (белки ${eatenProteins.round()} г, жиры ${eatenFats.round()} г, углеводы ${eatenCarbs.round()} г)
Цель на день: $targetCalories ккал (белки ${targetProteins.round()} г, жиры ${targetFats.round()} г, углеводы ${targetCarbs.round()} г)
Остаток калорий: $remaining ккал
Блюда:
$mealsSummary

Без markdown, без списков и кавычек — только текст совета.
''';

    return generate(prompt);
  }

  Future<String> generate(String prompt) async {
    if (!GeminiConfig.isConfigured) {
      return GeminiConfig.missingKeyMessage;
    }

    Object? lastError;
    for (final modelName in GeminiConfig.modelsToTry) {
      try {
        final text = await _generateContentText(
          modelName,
          [Content.text(prompt)],
        );
        if (text != null && text.isNotEmpty) return text;
        return 'Пустой ответ от Gemini ($modelName)';
      } catch (e) {
        lastError = e;
        if (_shouldTryNextModel(e)) continue;
        return formatUserError(e);
      }
    }

    if (lastError != null) {
      return formatUserError(lastError);
    }
    return 'Не удалось получить ответ Gemini. Повторите попытку позже.';
  }

  Future<String?> generateJson(
    String prompt, {
    int maxOutputTokens = 4096,
  }) async {
    if (!GeminiConfig.isConfigured) {
      return null;
    }

    Object? lastError;
    for (final modelName in GeminiConfig.modelsToTry) {
      try {
        final text = await _generateContentText(
          modelName,
          [Content.text(prompt)],
          maxOutputTokens: maxOutputTokens,
          jsonResponse: true,
        );
        if (text != null && text.isNotEmpty) return text;
      } catch (e) {
        lastError = e;
        if (_shouldTryNextModel(e)) continue;
        rethrow;
      }
    }

    if (lastError != null) {
      throw Exception(formatUserError(lastError!));
    }
    return null;
  }

  Future<FoodAnalysisResult?> _analyzeImage(
    Uint8List imageBytes,
    String mimeType,
    String prompt,
    String notRecognizedMessage,
  ) async {
    final contents = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, imageBytes),
      ]),
    ];

    return _analyzeImageWithModels(
      contents,
      notRecognizedMessage,
      parse: FoodAnalysisResult.tryParseFromAiResponse,
      onSuccess: (parsed) =>
          parsed != null && parsed.name != 'Не распознано' ? parsed : null,
      onNotRecognized: (parsed) => parsed?.name == 'Не распознано',
    );
  }

  Future<T?> _analyzeImageWithModels<T>(
    List<Content> contents,
    String notRecognizedMessage, {
    required T? Function(String text) parse,
    required T? Function(T? parsed) onSuccess,
    required bool Function(T? parsed) onNotRecognized,
  }) async {
    const maxOutputTokens = 4096;
    Object? lastError;
    final tried = <String>[];

    for (final modelName in GeminiConfig.modelsToTry) {
      tried.add(modelName);
      try {
        final text = await _generateContentText(
          modelName,
          contents,
          maxOutputTokens: maxOutputTokens,
          jsonResponse: true,
        );
        if (text == null || text.isEmpty) {
          lastError = 'Пустой ответ ($modelName)';
          continue;
        }

        final parsed = parse(text);
        if (onNotRecognized(parsed)) {
          throw Exception(notRecognizedMessage);
        }
        final result = onSuccess(parsed);
        if (result != null) return result;
        lastError = 'Не удалось разобрать JSON ($modelName)';
      } catch (e) {
        lastError = e;
        if (_shouldTryNextModel(e)) continue;
        throw Exception(formatUserError(e));
      }
    }

    final reason = lastError != null
        ? formatUserError(lastError!)
        : 'Не удалось получить ответ Gemini.';
    throw Exception('$reason (${tried.join(' → ')})');
  }

  Future<FoodAnalysisResult?> analyzeFoodImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!GeminiConfig.isConfigured) {
      throw StateError(GeminiConfig.missingKeyMessage);
    }

    const prompt = '''
Ты диетолог. По фото определи блюдо и оцени пищевую ценность одной порции на фото.
Верни ТОЛЬКО валидный JSON без markdown:
{"name":"название","calories":0,"proteins":0,"fats":0,"carbs":0,"portion":"размер порции","description":"кратко что на фото"}
Числа — целые или с одним знаком после запятой. Если не еда — name: "Не распознано", calories: 0.
''';

    return _analyzeImage(
      imageBytes,
      mimeType,
      prompt,
      'На фото не удалось распознать еду.',
    );
  }

  Future<List<FoodAnalysisResult>> analyzeProductImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!GeminiConfig.isConfigured) {
      throw StateError(GeminiConfig.missingKeyMessage);
    }

    const prompt = '''
Ты нутриционист. На фото может быть много разных продуктов питания (овощи, фрукты, яйца и т.д.), не готовое блюдо.
Найди КАЖДЫЙ отдельный тип продукта, который виден на фото. Не объединяй разные продукты в одну запись.
Для каждого продукта оцени КБЖУ для примерного количества, видимого на фото.
Верни ТОЛЬКО JSON без markdown:
{"products":[{"name":"название","calories":0,"proteins":0,"fats":0,"carbs":0,"quantity":"100","unit":"г","description":""}]}
Числа — целые или с одним знаком после запятой. Если продуктов нет — {"products":[]}.
''';

    return _analyzeImageForProducts(
      imageBytes,
      mimeType,
      prompt,
      'На фото не удалось распознать продукты.',
    );
  }

  Future<List<FoodAnalysisResult>> _analyzeImageForProducts(
    Uint8List imageBytes,
    String mimeType,
    String prompt,
    String notRecognizedMessage,
  ) async {
    const maxOutputTokens = 4096;
    final contents = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, imageBytes),
      ]),
    ];

    Object? lastError;
    final tried = <String>[];

    for (final modelName in GeminiConfig.modelsToTry) {
      tried.add(modelName);
      try {
        final text = await _generateContentText(
          modelName,
          contents,
          maxOutputTokens: maxOutputTokens,
          jsonResponse: true,
        );
        if (text == null || text.isEmpty) {
          lastError = 'Пустой ответ ($modelName)';
          continue;
        }

        final parsed = FoodAnalysisResult.tryParseListFromAiResponse(text);
        if (parsed.isNotEmpty) return parsed;
        lastError = 'Не удалось разобрать JSON ($modelName)';
      } catch (e) {
        lastError = e;
        if (_shouldTryNextModel(e)) continue;
        throw Exception(formatUserError(e));
      }
    }

    if (notRecognizedMessage.isNotEmpty) {
      throw Exception(notRecognizedMessage);
    }
    final reason = lastError != null
        ? formatUserError(lastError!)
        : 'Не удалось получить ответ Gemini.';
    throw Exception('$reason (${tried.join(' → ')})');
  }
}
