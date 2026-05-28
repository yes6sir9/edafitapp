import 'ai_service.dart';
import 'recipe_rag_service.dart';

class ChatService {
  final AIService aiService = AIService();
  final RecipeRagService ragService = RecipeRagService();

  Future<Map<String, dynamic>> processMessage({
    required String message,
    required List<Map<String, dynamic>> allRecipes,
    required String goal,
    required double mealCalories,
    required double mealProtein,
  }) async {
    
    // 🔍 1. Получаем рецепты
    final recipes = ragService.retrieveRecipes(
      recipes: allRecipes,
      query: message,
      goal: goal,
      mealTargetCalories: mealCalories,
      minProtein: mealProtein,
    );

    final topRecipes = recipes.take(5).toList();

    // 🧠 2. Формируем prompt
    final prompt = _buildPrompt(message, topRecipes);

    final aiResponse = await aiService.generate(prompt);

    return {
      "text": aiResponse,
      "recipes": topRecipes,
    };
  }

  String _buildPrompt(String userMessage, List recipes) {
    final recipeText = recipes.map((r) {
      return """
Название: ${r['title']}
Калории: ${r['calories']}
Белки: ${r['protein']}
Жиры: ${r['fat']}
Углеводы: ${r['carbs']}
""";
    }).join("\n");

    return """
Ты — диетолог.

Пользователь написал:
"$userMessage"

Вот рецепты (используй только их):
$recipeText

Задача:
- Выбери лучшие
- Объясни почему
- НЕ придумывай новые рецепты
- Если нет подходящих — скажи

Ответ краткий.
""";
  }
}