// lib/service/local_storage.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

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

    print('💾 Saved user data: $name ($role) - ID: $userId');
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

  static Future<int?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.userIdKey);
  }

  static Future<void> saveUploadedNumbers(List<String> numbers) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> existing = prefs.getStringList(AppConstants.uploadedNumbersKey) ?? [];
    Set<String> allNumbers = {...existing, ...numbers};
    await prefs.setStringList(AppConstants.uploadedNumbersKey, allNumbers.toList());

    print('💾 Saved ${numbers.length} uploaded numbers');
  }

  static Future<List<String>> getUploadedNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConstants.uploadedNumbersKey) ?? [];
  }

  static Future<void> clearUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userNameKey);
    await prefs.remove(AppConstants.uploadedNumbersKey);

    print('🗑️ User data cleared');
  }

  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }
}