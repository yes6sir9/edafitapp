import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Ключ: https://aistudio.google.com/apikey
/// Положите в `.env` (см. `.env.example`) или `--dart-define=GEMINI_API_KEY=...`
class GeminiConfig {
  GeminiConfig._();

  /// 2.0-flash на бесплатном тарифе часто даёт limit: 0 — не используем.
  /// gemini-1.5-flash снят с API v1beta.
  static const primaryModel = 'gemini-2.5-flash';
  static const fallbackModels = [
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];

  static List<String> get modelsToTry => [primaryModel, ...fallbackModels];

  static String? get apiKey {
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromDotenv = dotenv.maybeGet('GEMINI_API_KEY');
    if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
      return fromDotenv.trim();
    }
    return null;
  }

  static bool get isConfigured => apiKey != null;

  static String get missingKeyMessage =>
      'Укажите GEMINI_API_KEY в файле .env (скопируйте из .env.example) '
      'или запустите с --dart-define=GEMINI_API_KEY=ваш_ключ';
}
