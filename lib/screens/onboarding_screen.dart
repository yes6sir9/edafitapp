import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Добро пожаловать в EdFit!",
      description:
          "EdFit помогает отслеживать питание, анализировать рацион и достичь целей здоровья. Давайте познакомимся с приложением!",
      icon: Icons.apple,
      iconColor: const Color(0xFFA5C75D),
    ),
    OnboardingPage(
      title: "Дневник питания",
      description:
          "Здесь вы можете добавлять блюда, отслеживать калории и контролировать баланс БЖУ. Ведите дневник каждый день для достижения целей!",
      icon: Icons.book,
      iconColor: const Color(0xFFA5C75D),
      features: [
        "Добавляйте приемы пищи",
        "Отслеживайте калории",
        "Контролируйте БЖУ",
        "Смотрите дневной прогресс",
      ],
    ),
    OnboardingPage(
      title: "Рецепты",
      description:
          "Находите рецепты, подходящие под вашу цель питания. Смотрите калории, витамины и минералы каждого блюда.",
      icon: Icons.restaurant_menu_outlined,
      iconColor: const Color(0xFFA5C75D),
      features: [
        "Рецепты по целям питания",
        "Информация о витаминах",
        "Добавляйте в избранное",
        "Готовьте полезные блюда",
      ],
    ),
    OnboardingPage(
      title: "Статистика",
      description:
          "Расширьте сvo свой рациона с коллекцией полезных рецептов. Каждый рецепт содержит полную информацию о питательности.",
      icon: Icons.bar_chart_outlined,
      iconColor: const Color(0xFFA5C75D),
      features: [
        "Прогресс веса",
        "Анализ питания",
        "Динамика витаминов",
        "Графики изменений",
      ],
    ),
    OnboardingPage(
      title: "Персональный профиль",
      description:
          "Установите ваши параметры: вес, рост, возраст и целевой вес. Это поможет рассчитать персональные нормы калорий.",
      icon: Icons.person,
      iconColor: const Color(0xFFA5C75D),
      features: [
        "Ваши параметры",
        "Целевой вес",
        "Расчет калорий",
        "Предпочтения",
      ],
    ),
    OnboardingPage(
      title: "Достижения и награды",
      description:
          "Получайте опыт (XP) за каждое действие и поднимайте уровень. Наслаждайтесь системой достижений и мотивирующимися наградами!",
      icon: Icons.star,
      iconColor: const Color(0xFFA5C75D),
      features: [
        "Система уровней",
        "XP за активность",
        "Достижения",
        "Лидерборд",
      ],
    ),
    OnboardingPage(
      title: "Готово к старту!",
      description:
          "Теперь вы готовы начать свой путь к здоровому образу жизни. Нажмите 'Начать' и добавьте первый прием пищи!",
      icon: Icons.rocket_launch,
      iconColor: const Color(0xFFA5C75D),
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _completeTutorial() {
    Navigator.of(context).pop(true);
  }

  void _skipTutorial() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0x99000000),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 760),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5E8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index], index),
              ),
              Positioned(
                top: 18,
                right: 14,
                child: IconButton(
                  onPressed: _skipTutorial,
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ),
              Positioned(
                top: 20,
                left: 14,
                child: Text(
                  "Шаг ${_currentPage + 1} из ${_pages.length}",
                  style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 420;
    final titleSize = isCompact ? 28.0 : 34.0;
    final descSize = isCompact ? 18.0 : 22.0;
    final featureSize = isCompact ? 14.0 : 16.0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5E8),
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 50, 0, 0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentPage + 1) / _pages.length,
                minHeight: 4,
                backgroundColor: const Color(0xFFE7EDD8),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFA5C75D)),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFF9E6E8), const Color(0xFFEFF6DF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        Icon(page.icon, size: 64, color: page.iconColor),
                        const SizedBox(height: 20),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          maxLines: isCompact ? 4 : 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: descSize, color: Colors.grey.shade700, height: 1.35),
                        ),
                        if (page.features != null && page.features!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F6F8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: page.features!.map((feature) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(color: Color(0xFFD4E7A2), shape: BoxShape.circle),
                                        child: const Icon(Icons.check, size: 15, color: Color(0xFF769F35)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          feature,
                                          style: TextStyle(fontSize: featureSize),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                color: const Color(0xFFF2F2F3),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _skipTutorial, child: const Text("Пропустить")),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _onNextPage,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(page.isLast ? "Начать" : "Далее"),
                            if (!page.isLast) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final List<String>? features;
  final bool isLast;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.features,
    this.isLast = false,
  });
}
