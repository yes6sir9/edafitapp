import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final DateTime? createdAt;
  final double? weight;
  final double? height;
  final int? age;
  final double? targetWeight;
  final String? goal;
  final String? gender;
  final List<Map<String, dynamic>>? products;
  final List<Map<String, dynamic>>? customRecipes;
  final List<Map<String, dynamic>>? workouts;
  final List<int>? favorites;
  final Map<String, dynamic>? dailyDiary;
  final Map<String, dynamic>? healthIntegration;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.createdAt,
    this.weight,
    this.height,
    this.age,
    this.targetWeight,
    this.goal,
    this.gender,
    this.products,
    this.customRecipes,
    this.workouts,
    this.favorites,
    this.dailyDiary,
    this.healthIntegration,
  });

  // Factory constructor to create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      weight: data['weight']?.toDouble(),
      height: data['height']?.toDouble(),
      age: data['age']?.toInt(),
      targetWeight: data['targetWeight']?.toDouble(),
      goal: data['goal'],
      gender: data['gender'],
      products: (data['products'] as List<dynamic>?)
          ?.map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList(),
      customRecipes: (data['customRecipes'] as List<dynamic>?)
          ?.map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList(),
      workouts: (data['workouts'] as List<dynamic>?)
          ?.map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList(),
      favorites: (data['favorites'] as List<dynamic>?)
          ?.map((item) => int.tryParse(item.toString()) ?? 0)
          .where((value) => value > 0)
          .toList(),
      dailyDiary: data['dailyDiary'] is Map
          ? Map<String, dynamic>.from(data['dailyDiary'] as Map)
          : {},
      healthIntegration: data['healthIntegration'] is Map
          ? Map<String, dynamic>.from(data['healthIntegration'] as Map)
          : {},
    );
  }

  // Method to convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : Timestamp.now(),
      'weight': weight,
      'height': height,
      'age': age,
      'targetWeight': targetWeight,
      'goal': goal,
      'gender': gender,
      'products': products,
      'customRecipes': customRecipes,
      'workouts': workouts,
      'favorites': favorites,
      'dailyDiary': dailyDiary,
      'healthIntegration': healthIntegration,
    };
  }
}
