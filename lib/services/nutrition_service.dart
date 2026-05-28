class NutritionPlan {
  final String goal;
  final double bmr;
  final double activityFactor;
  final String activityExplanation;
  final double maintenanceCalories;
  final double exerciseCalories;
  final double dailyEnergyBudget;
  final double targetCalories;
  final double proteinGrams;
  final double fatGrams;
  final double carbGrams;
  final double proteinPerKg;
  final double fatRatio;
  final Map<String, double> mealCalories;
  final Map<String, double> mealProtein;
  final Map<String, double> mealFat;
  final Map<String, double> mealCarbs;
  final List<String> trainingRecommendations;
  final List<String> recipeFilters;
  final int recommendedWeeklyTrainings;
  final int currentWeeklyWorkouts;
  final int dailyBurnGoal;
  final String goalExplanation;

  NutritionPlan({
    required this.goal,
    required this.bmr,
    required this.activityFactor,
    required this.activityExplanation,
    required this.maintenanceCalories,
    required this.exerciseCalories,
    required this.dailyEnergyBudget,
    required this.targetCalories,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbGrams,
    required this.proteinPerKg,
    required this.fatRatio,
    required this.mealCalories,
    required this.mealProtein,
    required this.mealFat,
    required this.mealCarbs,
    required this.trainingRecommendations,
    required this.recipeFilters,
    required this.recommendedWeeklyTrainings,
    required this.currentWeeklyWorkouts,
    required this.dailyBurnGoal,
    required this.goalExplanation,
  });
}

class NutritionService {
  static const Map<String, double> _baseActivityFactors = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.9,
  };

  static NutritionPlan calculatePlan(
    Map<String, dynamic> userData,
    List<Map<String, dynamic>> workouts,
  ) {
    final weight = (userData['weight'] as num?)?.toDouble() ?? 70.0;
    final height = (userData['height'] as num?)?.toDouble() ?? 170.0;
    final age = (userData['age'] as num?)?.toInt() ?? 30;
    final gender = (userData['gender'] as String?) ?? 'мужской';
    final goal = _normalizeGoal((userData['goal'] as String?) ?? 'Поддержание');
    final activityData =
        userData['activityLevel'] ?? userData['activityFactor'];
    final baseKfa = _resolveActivityFactor(activityData, workouts);
    final goalAdjustment = _goalActivityAdjustment(goal, workouts);
    final trainingAdjustment = _trainingActivityAdjustment(goal, workouts);
    final activityFactor = (baseKfa * goalAdjustment * trainingAdjustment)
        .clamp(1.15, 2.0);

    final bmr = _calculateBMR(weight, height, age, gender);
    final maintenanceCalories = bmr * activityFactor;
    final exerciseCalories = _weeklyWorkoutCalories(workouts) / 7.0;
    final dailyEnergyBudget = maintenanceCalories + exerciseCalories;
    final targetCalories = _targetCaloriesByGoal(goal, dailyEnergyBudget);
    final proteinPerKg = _proteinPerKg(goal);
    final fatRatio = _fatRatio(goal);
    final double proteinGrams =
        (weight * proteinPerKg).clamp(0.0, double.infinity) as double;
    final proteinCalories = proteinGrams * 4.0;
    final fatCalories = targetCalories * fatRatio;
    final fatGrams = fatCalories / 9.0;
    final carbCalories = (targetCalories - proteinCalories - fatCalories).clamp(
      0.0,
      double.infinity,
    );
    final carbGrams = carbCalories / 4.0;

    final mealShares = _mealDistribution(goal);
    final mealCalories = {
      'Завтрак': targetCalories * mealShares['breakfast']!,
      'Обед': targetCalories * mealShares['lunch']!,
      'Ужин': targetCalories * mealShares['dinner']!,
      'Перекус': targetCalories * mealShares['snacks']!,
    };
    final mealProtein = {
      'Завтрак': proteinGrams * mealShares['breakfast']!,
      'Обед': proteinGrams * mealShares['lunch']!,
      'Ужин': proteinGrams * mealShares['dinner']!,
      'Перекус': proteinGrams * mealShares['snacks']!,
    };
    final mealFat = {
      'Завтрак': fatGrams * mealShares['breakfast']!,
      'Обед': fatGrams * mealShares['lunch']!,
      'Ужин': fatGrams * mealShares['dinner']!,
      'Перекус': fatGrams * mealShares['snacks']!,
    };
    final mealCarbs =
        {
          'Завтрак':
              mealCalories['Завтрак']! -
              mealProtein['Завтрак']! * 4 -
              mealFat['Завтрак']! * 9,
          'Обед':
              mealCalories['Обед']! -
              mealProtein['Обед']! * 4 -
              mealFat['Обед']! * 9,
          'Ужин':
              mealCalories['Ужин']! -
              mealProtein['Ужин']! * 4 -
              mealFat['Ужин']! * 9,
          'Перекус':
              mealCalories['Перекус']! -
              mealProtein['Перекус']! * 4 -
              mealFat['Перекус']! * 9,
        }.map(
          (key, value) =>
              MapEntry(key, (value / 4.0).clamp(0.0, double.infinity)),
        );

    final currentWeeklyWorkouts = workouts.length;
    final recommendedWeeklyTrainings = _recommendedWeeklyWorkouts(goal);
    final dailyBurnGoal = _dailyCaloriesBurnGoal(userData, weight, goal);

    return NutritionPlan(
      goal: goal,
      bmr: bmr,
      activityFactor: activityFactor,
      activityExplanation: _buildActivityExplanation(
        baseKfa,
        goalAdjustment,
        trainingAdjustment,
      ),
      maintenanceCalories: maintenanceCalories,
      exerciseCalories: exerciseCalories,
      dailyEnergyBudget: dailyEnergyBudget,
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbGrams: carbGrams,
      proteinPerKg: proteinPerKg,
      fatRatio: fatRatio,
      mealCalories: mealCalories,
      mealProtein: mealProtein,
      mealFat: mealFat,
      mealCarbs: mealCarbs,
      trainingRecommendations: _trainingRecommendations(goal),
      recipeFilters: _recipeFilters(goal),
      recommendedWeeklyTrainings: recommendedWeeklyTrainings,
      currentWeeklyWorkouts: currentWeeklyWorkouts,
      dailyBurnGoal: dailyBurnGoal,
      goalExplanation: _goalExplanation(goal),
    );
  }

  static double _calculateBMR(
    double weight,
    double height,
    int age,
    String gender,
  ) {
    final normalizedGender = gender.toString().toLowerCase();
    final s = (normalizedGender == 'female' || normalizedGender.contains('жен'))
        ? -161
        : 5;
    return 10 * weight + 6.25 * height - 5 * age + s;
  }

  static String _normalizeGoal(String goalRaw) {
    final value = goalRaw.toLowerCase().trim();
    if (value.contains('похуд')) return 'lose_weight';
    if (value.contains('набор') || value.contains('мышц')) return 'gain_weight';
    return 'maintain';
  }

  static double _resolveActivityFactor(
    dynamic activityData,
    List<Map<String, dynamic>> workouts,
  ) {
    if (activityData != null) {
      if (activityData is num) {
        final value = activityData.toDouble();
        if (value >= 1.2 && value <= 2.0) return value;
      }
      if (activityData is String) {
        final value = activityData.toLowerCase().trim();
        if (value.contains('сидяч')) return 1.2;
        if (value.contains('легк') || value.contains('низк')) return 1.375;
        if (value.contains('умерен')) return 1.55;
        if (value.contains('высок') && !value.contains('очень')) return 1.725;
        if (value.contains('очень')) return 1.9;
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null && parsed >= 1.2 && parsed <= 2.0) return parsed;
      }
    }

    final weeklyCount = workouts.length;
    if (weeklyCount <= 1) return 1.2;
    if (weeklyCount <= 3) return 1.375;
    if (weeklyCount <= 5) return 1.55;
    if (weeklyCount <= 7) return 1.725;
    return 1.9;
  }

  static double _goalActivityAdjustment(
    String goal,
    List<Map<String, dynamic>> workouts,
  ) {
    if (goal == 'lose_weight') return 1.03;
    if (goal == 'gain_weight') {
      final strengthCount = workouts.where((w) {
        final name = (w['name'] as String?)?.toLowerCase() ?? '';
        return name.contains('сил') ||
            name.contains('тяж') ||
            name.contains('спина') ||
            name.contains('груд');
      }).length;
      return strengthCount >= 2 ? 1.08 : 1.05;
    }
    return 1.0;
  }

  static double _trainingActivityAdjustment(
    String goal,
    List<Map<String, dynamic>> workouts,
  ) {
    final totalCalories = _weeklyWorkoutCalories(workouts);
    if (totalCalories >= 2000) return 1.08;
    if (totalCalories >= 1200) return 1.05;
    return 1.0;
  }

  static double _weeklyWorkoutCalories(List<Map<String, dynamic>> workouts) {
    return workouts.fold<double>(0.0, (sum, w) {
      return sum + ((w['calories'] as num?)?.toDouble() ?? 0.0);
    });
  }

  static double _targetCaloriesByGoal(String goal, double budget) {
    if (goal == 'lose_weight') return budget * 0.84;
    if (goal == 'gain_weight') return budget * 1.13;
    return budget;
  }

  static double _proteinPerKg(String goal) {
    if (goal == 'lose_weight') return 1.8;
    if (goal == 'gain_weight') return 1.8;
    return 1.4;
  }

  static double _fatRatio(String goal) {
    if (goal == 'lose_weight') return 0.27;
    if (goal == 'gain_weight') return 0.25;
    return 0.28;
  }

  static Map<String, double> _mealDistribution(String goal) {
    if (goal == 'gain_weight') {
      return {'breakfast': 0.22, 'lunch': 0.30, 'dinner': 0.30, 'snacks': 0.18};
    }
    if (goal == 'lose_weight') {
      return {'breakfast': 0.30, 'lunch': 0.36, 'dinner': 0.25, 'snacks': 0.09};
    }
    return {'breakfast': 0.25, 'lunch': 0.30, 'dinner': 0.30, 'snacks': 0.15};
  }

  static int _recommendedWeeklyWorkouts(String goal) {
    if (goal == 'lose_weight') return 4;
    if (goal == 'gain_weight') return 3;
    return 3;
  }

  static List<String> _trainingRecommendations(String goal) {
    if (goal == 'lose_weight') {
      return [
        '3-5 тренировок в неделю, в том числе 2-3 силовые.',
        'Чередуйте кардио и силовые для поддержания мышц.',
        'Стабильный дефицит калорий важнее резких ограничений.',
      ];
    }
    if (goal == 'gain_weight') {
      return [
        '3-4 силовые тренировки в неделю.',
        'Добавьте 1-2 дня активного восстановления.',
        'Контроль прогресса по силе и объему тренировки.',
      ];
    }
    return [
      '2-3 тренировки в неделю для поддержания формы.',
      'Сбалансируйте кардио и силовые нагрузки.',
      'Следите за стабильностью калорий на уровне поддержки.',
    ];
  }

  static List<String> _recipeFilters(String goal) {
    if (goal == 'lose_weight') {
      return [
        'низкий или умеренный калораж',
        'высокий белок',
        'добавьте клетчатку и овощи',
      ];
    }
    if (goal == 'gain_weight') {
      return [
        'средний или высокий калораж',
        'высокий белок и углеводы',
        'сбалансированный прием жиров',
      ];
    }
    return [
      'средний калораж',
      'сбалансированные БЖУ',
      'удобство для ежедневного питания',
    ];
  }

  static String _goalExplanation(String goal) {
    if (goal == 'lose_weight') {
      return 'Цель — дефицит калорий с сохранением мышечной массы.';
    }
    if (goal == 'gain_weight') {
      return 'Цель — профицит калорий и поддержка силовой нагрузки.';
    }
    return 'Цель — стабильное поддержание текущей массы тела.';
  }

  static int _dailyCaloriesBurnGoal(
    Map<String, dynamic> userData,
    double weight,
    String goal,
  ) {
    if (goal != 'lose_weight') return 0;
    final currentWeight = (userData['weight'] as num?)?.toDouble() ?? weight;
    final targetWeight =
        (userData['targetWeight'] as num?)?.toDouble() ?? currentWeight;
    final diff = currentWeight - targetWeight;
    if (diff <= 0) return 0;
    final totalDeficit = diff * 7700;
    return (totalDeficit / 7).round();
  }

  static String _buildActivityExplanation(
    double baseKfa,
    double goalAdjustment,
    double trainingAdjustment,
  ) {
    final parts = <String>[];
    parts.add('Базовый КФА $baseKfa');
    if (goalAdjustment != 1.0) {
      parts.add('корректировка цели ${goalAdjustment.toStringAsFixed(2)}');
    }
    if (trainingAdjustment != 1.0) {
      parts.add('учет тренировок ${trainingAdjustment.toStringAsFixed(2)}');
    }
    return parts.join(', ');
  }
}
