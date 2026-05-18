// lib/utils/constants.dart
class AppConstants {
  static const String baseUrl = 'https://admin.rehltna.com/api/v1/etisalaty';

  // API Key Constants
  static const String apiKey = 'P4OIp8prRKBeO0kogfGViTNzmAT8UnzL';
  static const String tenantId = '1';

  // Endpoints
  static const String loginEndpoint = '/login';
  static const String uploadContactsEndpoint = '/upload-contacts';
  static const String downloadContactsEndpoint = '/download-all-contacts';

  // SharedPreferences Keys
  static const String tokenKey = 'user_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String uploadedNumbersKey = 'uploaded_numbers';

  // Supported Countries
  static const List<String> supportedCountries = ['EG', 'SA'];
  static const Map<String, String> countryCodes = {'EG': '+20', 'SA': '+966'};
}
