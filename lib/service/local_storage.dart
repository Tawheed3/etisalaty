// lib/services/local_storage.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';
import '../constants/phone_normalizer.dart';

class LocalStorage {
  static Future<void> saveUserData({
    required String token,
    required String role,
    required int userId,
    required String name,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userRoleKey, role);
    await prefs.setInt(AppConstants.userIdKey, userId);
    await prefs.setString(AppConstants.userNameKey, name);

    debugPrint('💾 Saved user data: $name ($role)');
  }

  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<String?> getUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userRoleKey);
  }

  static Future<String?> getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userNameKey);
  }

  static Future<void> saveUploadedNumbers(List<String> numbers) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> existing =
        prefs.getStringList(AppConstants.uploadedNumbersKey) ?? [];

    // توحيد كل الأرقام قبل الحفظ
    Set<String> allNumbers = {};
    for (var n in existing) {
      allNumbers.add(PhoneNormalizer.normalize(n));
    }
    for (var n in numbers) {
      allNumbers.add(PhoneNormalizer.normalize(n));
    }

    await prefs.setStringList(
      AppConstants.uploadedNumbersKey,
      allNumbers.toList(),
    );

    debugPrint('💾 Saved ${numbers.length} uploaded numbers (normalized)');
  }

  static Future<List<String>> getUploadedNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? numbers = prefs.getStringList(
      AppConstants.uploadedNumbersKey,
    );
    return numbers?.map((n) => PhoneNormalizer.normalize(n)).toList() ?? [];
  }

  static Future<void> clearUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userNameKey);
    await prefs.remove(AppConstants.uploadedNumbersKey);

    debugPrint('🗑️ User data cleared');
  }

  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }
}
