import 'package:flutter/material.dart';
import 'package:edafitapp/services/recipe_service.dart';

class ImportRecipesScreen extends StatefulWidget {
  const ImportRecipesScreen({Key? key}) : super(key: key);

  @override
  State<ImportRecipesScreen> createState() => _ImportRecipesScreenState();
}

class _ImportRecipesScreenState extends State<ImportRecipesScreen> {
  final RecipeService _recipeService = RecipeService();
  bool _isImporting = false;
  String _status = '';
  int _importedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт рецептов'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Импорт рецептов',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Нажмите кнопку ниже, чтобы импортировать 19 рецептов из файла Recepts.csv в базу данных Firestore.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    if (_status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _importedCount > 0
                              ? Colors.green[50]
                              : Colors.blue[50],
                          border: Border.all(
                            color: _importedCount > 0
                                ? Colors.green
                                : Colors.blue,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _importedCount > 0
                                ? Colors.green[700]
                                : Colors.blue[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _importRecipes,
              icon: _isImporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                _isImporting ? 'Импортирование...' : 'Начать импорт',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_importedCount > 0) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _viewRecipes,
                icon: const Icon(Icons.list),
                label: const Text('Просмотреть рецепты'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importRecipes() async {
    setState(() {
      _isImporting = true;
      _status = '⏳ Импорт начинается...';
    });

    try {
      final count = await _recipeService.importRecipesFromJson(
        'assets/recipes-data.json',
      );

      setState(() {
        _importedCount = count;
        _status = _importedCount > 0
            ? '✅ Успешно импортировано $_importedCount рецептов!'
            : '⚠️  Не удалось импортировать рецепты\n\n⚠️ Проверьте правила безопасности Firestore:\n1. Откройте Firebase Console\n2. Перейдите в Firestore Database → Rules\n3. Разрешите запись в коллекцию recipes\n\nСм. FIRESTORE_RULES_SETUP.md для подробных инструкций';
        _isImporting = false;
      });

      if (mounted && _importedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $_importedCount рецептов импортировано!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      final errorMessage = e.toString();
      print('❌ Ошибка импорта: $errorMessage');
      
      setState(() {
        _status = '❌ Ошибка импорта:\n$errorMessage\n\n📖 Решение:\nПроверьте правила безопасности Firestore (FIRESTORE_RULES_SETUP.md)';
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _viewRecipes() async {
    try {
      final recipes = await _recipeService.getRecipes();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Рецепты (${recipes.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return ListTile(
                      title: Text(recipe['title'] ?? 'Без названия'),
                      subtitle: Text(recipe['type'] ?? 'Без типа'),
                      trailing: Text(
                        recipe['calories'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        _showRecipeDetails(recipe);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при загрузке рецептов: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRecipeDetails(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['title'] ?? 'Рецепт'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Тип', recipe['type'] ?? '—'),
              _buildDetailRow('Калории', recipe['calories'] ?? '—'),
              const SizedBox(height: 12),
              const Text(
                'Ингредиенты:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(recipe['products'] ?? '—'),
              const SizedBox(height: 12),
              const Text(
                'Приготовление:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(recipe['instructions'] ?? '—'),
              const SizedBox(height: 12),
              const Text(
                'БЖУ:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildMacros(recipe['macros'] ?? {}),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMacros(Map<String, dynamic> macros) {
    return Text(
      'Белки: ${macros['protein'] ?? '—'}, Жиры: ${macros['fat'] ?? '—'}, Углеводы: ${macros['carbs'] ?? '—'}',
    );
  }
}
