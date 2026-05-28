class RecipeRagService {
  List<Map<String, dynamic>> retrieveRecipes({
    required List<Map<String, dynamic>> recipes,
    required String query,
    required String goal,
    required double mealTargetCalories,
    required double minProtein,
  }) {
    List<Map<String, dynamic>> scored = [];

    for (var r in recipes) {
      double calories = (r['calories'] ?? 0).toDouble();
      double protein = (r['protein'] ?? 0).toDouble();

      // 🎯 1. Калории (нормализованный скор)
      double caloriesDiff = (calories - mealTargetCalories).abs();
      double caloriesScore =
          (1 - (caloriesDiff / mealTargetCalories)).clamp(0, 1) * 100;

      // 🥩 2. Белок
      double proteinScore =
          (protein / minProtein).clamp(0, 1) * 100;

      // 🎯 3. Цель
      double goalScore = 0;

      if (goal == "lose_weight") {
        goalScore += (calories < mealTargetCalories ? 30 : 0);
      } else if (goal == "gain_weight") {
        goalScore += (calories > mealTargetCalories ? 30 : 0);
      }

      // 💬 4. Простой поиск по тексту
      double textScore = 0;
      if (r['title'].toLowerCase().contains(query.toLowerCase())) {
        textScore = 20;
      }

      double totalScore =
          caloriesScore * 0.4 +
          proteinScore * 0.4 +
          goalScore +
          textScore;

      scored.add({
        ...r,
        "score": totalScore,
      });
    }

    // сортировка
    scored.sort((a, b) => b['score'].compareTo(a['score']));

    return scored;
  }
}