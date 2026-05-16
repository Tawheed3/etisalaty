// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';

class ApiService {

  static Map<String, String> _getBaseHeaders({String? token}) {
    Map<String, String> headers = {
      'X-API-KEY': AppConstants.apiKey,
      'X-Tenant-ID': AppConstants.tenantId,
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    print('🔐 Headers: $headers');
    return headers;
  }

  // تسجيل الدخول
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final body = jsonEncode({
        'email': email,
        'password': password,
      });

      final url = '${AppConstants.baseUrl}${AppConstants.loginEndpoint}';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 LOGIN REQUEST');
      print('📍 URL: $url');
      print('📦 Body: $body');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.post(
        Uri.parse(url),
        headers: _getBaseHeaders(),
        body: body,
      );

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📥 LOGIN RESPONSE');
      print('📊 Status Code: ${response.statusCode}');
      print('📄 Body: ${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['code'] == 200) {
        print('✅ Login Successful!');
        print('👤 User: ${responseData['data']['name']}');
        print('💼 Role: ${responseData['data']['role']}');
        return {
          'status': 'success',
          'data': {
            'user_id': responseData['data']['id'],
            'name': responseData['data']['name'],
            'email': responseData['data']['email'],
            'role': responseData['data']['role'],
            'token': responseData['data']['access_token'],
          }
        };
      } else {
        print('❌ Login Failed!');
        print('📝 Message: ${responseData['message']}');
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'فشل تسجيل الدخول',
          'code': responseData['code'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Login Exception: $e');
      return {
        'status': 'error',
        'message': 'خطأ في الاتصال بالسيرفر: $e'
      };
    }
  }

  // رفع الأرقام
  static Future<Map<String, dynamic>> uploadContacts(String token, List<Map<String, String>> contacts) async {
    try {
      final body = jsonEncode({'contacts': contacts});
      final url = '${AppConstants.baseUrl}${AppConstants.uploadContactsEndpoint}';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 UPLOAD REQUEST');
      print('📍 URL: $url');
      print('📦 Contacts Count: ${contacts.length}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.post(
        Uri.parse(url),
        headers: _getBaseHeaders(token: token),
        body: body,
      );

      print('📥 UPLOAD RESPONSE Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['code'] == 200) {
        print('✅ Upload Successful!');
        print('📊 New: ${responseData['data']['new_contacts_added']}');
        return {
          'status': 'success',
          'data': {
            'total_received': responseData['data']['total_received'],
            'new_contacts_added': responseData['data']['new_contacts_added'],
            'already_exists': responseData['data']['already_exists'],
            'duplicates_by_employee': responseData['data']['duplicates_by_employee'],
          }
        };
      } else if (response.statusCode == 401) {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'انتهت صلاحية الجلسة، من فضلك سجل دخول مرة أخرى'
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'فشل رفع الأرقام'
        };
      }
    } catch (e) {
      print('❌ Upload Exception: $e');
      return {
        'status': 'error',
        'message': 'خطأ في الاتصال بالسيرفر: $e'
      };
    }
  }

  // سحب الأرقام (للمسؤول فقط)
  static Future<Map<String, dynamic>> downloadContacts(String token) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.downloadContactsEndpoint}';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 DOWNLOAD REQUEST');
      print('📍 URL: $url');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.get(
        Uri.parse(url),
        headers: _getBaseHeaders(token: token),
      );

      print('📥 DOWNLOAD RESPONSE Status: ${response.statusCode}');
      print('📄 Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['code'] == 200) {
        print('✅ Download Successful!');
        print('📊 Total Contacts: ${responseData['data']['total_contacts']}');
        return {
          'status': 'success',
          'data': {
            'total_contacts': responseData['data']['total_contacts'],
            'contacts': responseData['data']['contacts'],
          }
        };
      } else if (response.statusCode == 403) {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'غير مصرح لك - هذا الحساب ليس مسؤول أمن'
        };
      } else if (response.statusCode == 401) {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'انتهت صلاحية الجلسة، من فضلك سجل دخول مرة أخرى'
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'فشل سحب الأرقام'
        };
      }
    } catch (e) {
      print('❌ Download Exception: $e');
      return {
        'status': 'error',
        'message': 'خطأ في الاتصال بالسيرفر: $e'
      };
    }
  }
}