import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUp(String email, String password, {
    String? displayName,
    double? weight,
    double? height,
    int? age,
    double? targetWeight,
    String? goal,
    String? gender,
  }) async {
    try {
      print('Starting user registration for $email');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User created in Firebase Auth: ${userCredential.user?.uid}');

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
        print('Display name updated to $displayName');
      }

      // Create user document in Firestore
      UserModel userModel = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
        weight: weight,
        height: height,
        age: age,
        targetWeight: targetWeight,
        goal: goal,
        gender: gender,
        products: [],
        customRecipes: [],
        workouts: [],
        favorites: [],
        dailyDiary: {},
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userModel.toFirestore());
      print('User data saved to Firestore');
      print('Current user after signUp: ${_auth.currentUser?.uid}');

      return userCredential;
    } catch (e) {
      print('Error during registration: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> saveUserProducts(List<Map<String, dynamic>> products) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await updateUserData(user.uid, {'products': products});
  }

  Future<void> saveUserCustomRecipes(
    List<Map<String, dynamic>> customRecipes,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await updateUserData(user.uid, {'customRecipes': customRecipes});
  }

  Future<void> saveUserFavorites(List<int> favorites) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await updateUserData(user.uid, {'favorites': favorites});
  }

  Future<void> saveUserDailyDiary(Map<String, dynamic> dailyDiary) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await updateUserData(user.uid, {'dailyDiary': dailyDiary});
  }

  Future<void> saveUserWorkouts(List<Map<String, dynamic>> workouts) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await updateUserData(user.uid, {'workouts': workouts});
  }

  Future<void> saveHealthIntegration(Map<String, dynamic> healthIntegration) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await updateUserData(user.uid, {'healthIntegration': healthIntegration});
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      print('Fetching user data from Firestore for UID: $uid');
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        print('User data found in Firestore');
        return UserModel.fromFirestore(doc.data() as Map<String, dynamic>, uid);
      } else {
        print('User data not found in Firestore');
        return null;
      }
    } catch (e) {
      print('Error fetching user data: $e');
      rethrow;
    }
  }
}