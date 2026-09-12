import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  print('Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const appBackground = Color(0xFFF7F5E6);
    const cardBackground = Color(0xFFF6F6F8);
    const primaryGreen = Color(0xFFA5C75D);
    const textDark = Color(0xFF242A35);

    return MaterialApp(
      title: 'EdaFit',
      theme: ThemeData(
        scaffoldBackgroundColor: appBackground,
        colorScheme: const ColorScheme.light(
          primary: primaryGreen,
          secondary: Color(0xFFF4DAD9),
          surface: cardBackground,
          onPrimary: Colors.white,
          onSurface: textDark,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: textDark,
          displayColor: textDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: appBackground,
          elevation: 0,
          centerTitle: true,
          foregroundColor: textDark,
        ),
        cardTheme: CardThemeData(
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F2F2),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: primaryGreen, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textDark,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFF6F6F6),
          selectedItemColor: primaryGreen,
          unselectedItemColor: Color(0xFF757575),
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthService _authService = AuthService();
  bool _isUserAuthenticated = false;
  bool _showLogin = false; // ← ИСПРАВЛЕНИЕ 1: добавлено поле
  Map<String, dynamic> _userData = {};
  int _selectedIndex = 0;
  bool _showOnboarding = true;

  List<Widget> get _screens {
    return [
      HomeScreen(userData: _userData),
      StatisticsScreen(
        userData: _userData,
        onUserDataUpdated: (data) {
          setState(() {
            _userData.addAll(data);
          });
        },
      ),
      RecipesScreen(userData: _userData),
      ProfileScreen(
        userData: _userData,
        onUserDataUpdated: (data) {
          setState(() {
            _userData.addAll(data);
          });
        },
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showTutorial() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const OnboardingScreen()));
    setState(() {
      _showOnboarding = false;
    });
  }

  void _handleRegistration(Map<String, dynamic> userData) {
    setState(() {
      _isUserAuthenticated = true;
      _userData = userData;
      _showLogin = false;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showTutorial();
    });
  }

  void _handleLogin(Map<String, dynamic> userData) {
    setState(() {
      _isUserAuthenticated = true;
      _userData = userData;
      _showLogin = false;
    });
  }

  void _showLoginScreen() {
    setState(() {
      _showLogin = true;
    });
  }

  void _showRegistrationScreen() {
    setState(() {
      _showLogin = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _userData = {};
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        print('User is signed in: ${user.uid}');
        final userModel = await _authService.getUserData(user.uid);
        if (userModel != null) {
          setState(() {
            _isUserAuthenticated = true;
            _userData = {
              'name': userModel.displayName ?? '',
              'email': userModel.email,
              'weight': userModel.weight,
              'height': userModel.height,
              'age': userModel.age,
              'targetWeight': userModel.targetWeight,
              'goal': userModel.goal,
              'gender': userModel.gender,
              'products': userModel.products ?? [],
              'customRecipes': userModel.customRecipes ?? [],
              'workouts': userModel.workouts ?? [],
              'favorites': userModel.favorites ?? [],
              'dailyDiary': userModel.dailyDiary ?? {},
              'healthIntegration': userModel.healthIntegration ?? {},
            };
          });
        }
      } else {
        setState(() {
          _isUserAuthenticated = false;
          _userData = {};
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUserAuthenticated) {
      if (_showLogin) {
        return LoginScreen(
          onLoginComplete: _handleLogin,
          onShowRegistration: _showRegistrationScreen,
        );
      }
      return RegistrationScreen(
        onRegistrationComplete: _handleRegistration,
        onShowLogin: _showLoginScreen,
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Дневник',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'Рецепты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
      floatingActionButton: !_showOnboarding
          ? FloatingActionButton(
              onPressed: _showTutorial,
              tooltip: 'Показать туториал',
              child: const Icon(Icons.help_outline),
            )
          : null,
    );
  }
}
