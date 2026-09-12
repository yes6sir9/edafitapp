import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onRegistrationComplete;
  final VoidCallback? onShowLogin; // ← ДОБАВЛЕНО

  const RegistrationScreen({
    super.key,
    required this.onRegistrationComplete,
    this.onShowLogin, // ← ДОБАВЛЕНО
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final AuthService _authService = AuthService();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _targetWeightController;

  int _currentStep = 1;
  String _selectedGoal = "Похудение";
  String _selectedGender = "Мужской";
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _ageController = TextEditingController();
    _targetWeightController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    if (_currentStep == 1) {
      if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Заполните все поля")));
        return;
      }
      if (!_emailController.text.contains("@")) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Неверный формат email")));
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Заполните все поля")));
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Пароли не совпадают")));
        return;
      }
      if (_passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Пароль должен быть не менее 6 символов"),
          ),
        );
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      if (_weightController.text.isEmpty ||
          _heightController.text.isEmpty ||
          _targetWeightController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Заполните все параметры")),
        );
        return;
      }

      try {
        print('Attempting to register user: ${_emailController.text}');
        double weight = double.tryParse(_weightController.text) ?? 0.0;
        double height = double.tryParse(_heightController.text) ?? 0.0;
        int? age = _ageController.text.isNotEmpty
            ? int.tryParse(_ageController.text)
            : null;
        double targetWeight =
            double.tryParse(_targetWeightController.text) ?? 0.0;

        final userCredential = await _authService.signUp(
          _emailController.text,
          _passwordController.text,
          displayName: _nameController.text,
          weight: weight,
          height: height,
          age: age,
          targetWeight: targetWeight,
          goal: _selectedGoal,
          gender: _selectedGender,
        );

        final userModel = await _authService.getUserData(
          userCredential.user!.uid,
        );

        if (userModel == null) {
          throw Exception('Не удалось получить данные пользователя после регистрации');
        }

        final userData = {
          'name': userModel.displayName ?? _nameController.text,
          'email': userModel.email,
          'weight': userModel.weight ?? weight,
          'height': userModel.height ?? height,
          'age': userModel.age ?? age,
          'targetWeight': userModel.targetWeight ?? targetWeight,
          'goal': userModel.goal ?? _selectedGoal,
          'gender': userModel.gender ?? _selectedGender,
          'products': userModel.products ?? [],
          'customRecipes': userModel.customRecipes ?? [],
          'workouts': userModel.workouts ?? [],
          'favorites': userModel.favorites ?? [],
          'dailyDiary': userModel.dailyDiary ?? {},
        };

        widget.onRegistrationComplete(userData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Регистрация успешна! Добро пожаловать!"),
          ),
        );
      } catch (e) {
        print('Registration error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка регистрации: $e")));
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
  child: Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Image.asset(
      'edafit.png',
      height: 80,
      fit: BoxFit.contain,
    ),
  ),
),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Создать аккаунт",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "Начните отслеживать питание",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
              const SizedBox(height: 28),

              // Шаг 1
              if (_currentStep == 1) ...[
                _buildTextField(
                  controller: _nameController,
                  label: "Имя",
                  icon: Icons.person,
                  hint: "Ваше имя",
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _emailController,
                  label: "Email",
                  icon: Icons.email,
                  hint: "example@email.com",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildGenderSelection(),
                const SizedBox(height: 12),
                _buildRegistrationType(),
              ],

              // Шаг 2
              if (_currentStep == 2) ...[
                const Text(
                  "Пароль",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "*******",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Подтверждение пароля",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "*******",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmPasswordVisible =
                            !_isConfirmPasswordVisible,
                      ),
                    ),
                  ),
                ),
              ],

              // Шаг 3
              if (_currentStep == 3) ...[
                _buildTextField(
                  controller: _weightController,
                  label: "Вес (кг)",
                  icon: Icons.monitor_weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _heightController,
                  label: "Рост (см)",
                  icon: Icons.height,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _ageController,
                  label: "Возраст (опционально)",
                  icon: Icons.cake,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Цель",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _targetWeightController,
                  label: "Целевой вес (кг)",
                  icon: Icons.flag,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGoalDropdown(),
              ],

              const SizedBox(height: 32),

              // Кнопки навигации
              Row(
                children: [
                  if (_currentStep > 1)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        onPressed: _previousStep,
                        child: const Text("Назад"),
                      ),
                    ),
                  if (_currentStep > 1) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentStep == 3 ? "Зарегистрироваться" : "Далее",
                      ),
                    ),
                  ),
                ],
              ),

              // ← ДОБАВЛЕНО: ссылка "Уже есть аккаунт?"
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Уже есть аккаунт? ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: widget.onShowLogin,
                    child: const Text(
                      'Войти',
                      style: TextStyle(
                        color: Color(0xFF2A4973),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String hint = "",
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint.isNotEmpty ? hint : null,
            prefixIcon: Icon(icon, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGoal,
      items: const [
        DropdownMenuItem(value: "Похудение", child: Text("Похудение")),
        DropdownMenuItem(value: "Поддержание", child: Text("Поддержание")),
        DropdownMenuItem(value: "Набор мышц", child: Text("Набор мышц")),
      ],
      onChanged: (v) => setState(() => _selectedGoal = v ?? _selectedGoal),
      decoration: const InputDecoration(),
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Пол", style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                value: "Мужской",
                groupValue: _selectedGender,
                title: const Text("Мужской"),
                onChanged: (value) =>
                    setState(() => _selectedGender = value ?? _selectedGender),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RadioListTile<String>(
                value: "Женский",
                groupValue: _selectedGender,
                title: const Text("Женский"),
                onChanged: (value) =>
                    setState(() => _selectedGender = value ?? _selectedGender),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegistrationType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Я хочу зарегистрироваться как:",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3D8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA5C75D)),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.person_outline,
                color: Color(0xFFA5C75D),
                size: 30,
              ),
              SizedBox(height: 6),
              Text(
                "Клиент",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFA5C75D),
                ),
              ),
              Text(
                "Отслеживать питание",
                style: TextStyle(fontSize: 11, color: Color(0xFF5B7D36)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
