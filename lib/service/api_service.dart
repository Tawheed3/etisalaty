// lib/service/api_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/constants.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 30);

  static Map<String, String> _getBaseHeaders({String? token}) {
    final headers = <String, String>{
      'X-API-KEY': AppConstants.apiKey,
      'X-Tenant-ID': AppConstants.tenantId,
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static void _debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return {
      'code': response.statusCode,
      'message': 'استجابة غير صالحة من السيرفر',
    };
  }

  static String _message(Map<String, dynamic> responseData, String fallback) {
    final message = responseData['message'];
    return message is String && message.isNotEmpty ? message : fallback;
  }

  // ==================== LOGIN ====================
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.loginEndpoint}';
      _debug('LOGIN request: $url');

      final response = await http
          .post(
        Uri.parse(url),
        headers: _getBaseHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(_timeout);

      final responseData = _decodeBody(response);
      _debug('LOGIN response status: ${response.statusCode}');

      if (response.statusCode == 200 && responseData['code'] == 200) {
        final data = responseData['data'];
        if (data is! Map<String, dynamic>) {
          return {
            'status': 'error',
            'message': 'بيانات تسجيل الدخول غير مكتملة',
            'statusCode': response.statusCode,
          };
        }

        return {
          'status': 'success',
          'data': {
            'user_id': data['id'],
            'name': data['name'],
            'email': data['email'],
            'role': data['role'],
            'token': data['access_token'],
          },
        };
      }

      return {
        'status': 'error',
        'message': _message(responseData, 'فشل تسجيل الدخول'),
        'code': responseData['code'],
        'statusCode': response.statusCode,
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'انتهت مهلة الاتصال بالسيرفر، حاول مرة أخرى',
      };
    } catch (e) {
      _debug('LOGIN exception: $e');
      return {'status': 'error', 'message': 'خطأ في الاتصال بالسيرفر'};
    }
  }

  // ==================== UPLOAD CONTACTS ====================
  static Future<Map<String, dynamic>> uploadContacts(String token, List<Map<String, String>> contacts) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.uploadContactsEndpoint}';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 UPLOAD REQUEST');
      print('📍 URL: $url');
      print('📦 عدد الأرقام المرسلة: ${contacts.length}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      print('📊 تفاصيل الأرقام المرسلة للسيرفر:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      for (int i = 0; i < (contacts.length > 20 ? 20 : contacts.length); i++) {
        var contact = contacts[i];
        String phone = contact['phone_number'] ?? 'لا يوجد';
        String name = contact['contact_name'] ?? 'بدون اسم';
        print('   ${i + 1}. الرقم: $phone | الاسم: "$name"');
      }

      if (contacts.length > 20) {
        print('   ... و ${contacts.length - 20} أرقام أخرى');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      List sampleContacts = contacts.take(3).toList();
      print('📦 عينة من البيانات المرسلة (أول 3 عناصر):');
      print(jsonEncode({'contacts': sampleContacts}));
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .post(
        Uri.parse(url),
        headers: _getBaseHeaders(token: token),
        body: jsonEncode({'contacts': contacts}),
      )
          .timeout(_timeout);

      final responseData = _decodeBody(response);

      print('📥 UPLOAD RESPONSE Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (response.statusCode == 200 && responseData['code'] == 200) {
        final data = responseData['data'];
        if (data is! Map<String, dynamic>) {
          return {
            'status': 'error',
            'message': 'بيانات الرفع غير مكتملة',
            'statusCode': response.statusCode,
          };
        }

        print('✅ UPLOAD Successful!');
        print('📊 جديد في النظام: ${data['new_contacts_added']}');
        print('📊 موجود مسبقاً: ${data['already_exists']}');
        print('📊 مكرر من الموظف: ${data['duplicates_by_employee']}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return {
          'status': 'success',
          'data': {
            'total_received': data['total_received'],
            'new_contacts_added': data['new_contacts_added'],
            'already_exists': data['already_exists'],
            'duplicates_by_employee': data['duplicates_by_employee'],
          },
        };
      }

      if (response.statusCode == 401) {
        return {
          'status': 'error',
          'message': _message(
            responseData,
            'انتهت صلاحية الجلسة، من فضلك سجل دخول مرة أخرى',
          ),
        };
      }

      return {
        'status': 'error',
        'message': _message(responseData, 'فشل رفع الأرقام'),
        'statusCode': response.statusCode,
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'انتهت مهلة رفع الأرقام، حاول مرة أخرى',
      };
    } catch (e) {
      print('❌ UPLOAD exception: $e');
      return {'status': 'error', 'message': 'خطأ في الاتصال بالسيرفر'};
    }
  }

  // ==================== DOWNLOAD ALL CONTACTS ====================
  static Future<Map<String, dynamic>> downloadContacts(String token) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.downloadContactsEndpoint}';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 DOWNLOAD ALL CONTACTS REQUEST');
      print('📍 URL: $url');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.get(
        Uri.parse(url),
        headers: _getBaseHeaders(token: token),
      );

      print('📥 DOWNLOAD RESPONSE Status: ${response.statusCode}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📄 Full Response Body:');
      print('${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['code'] == 200) {
        List contacts = responseData['data']['contacts'] ?? [];

        print('📊 تفاصيل الأرقام من السيرفر:');
        print('   إجمالي الأرقام: ${contacts.length}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        for (int i = 0; i < (contacts.length > 20 ? 20 : contacts.length); i++) {
          var contact = contacts[i];
          String phone = contact['phone_number'] ?? 'لا يوجد';
          String name = contact['contact_name'] ?? 'بدون اسم';
          print('   ${i + 1}. الرقم: $phone | الاسم: "$name"');
        }

        if (contacts.length > 20) {
          print('   ... و ${contacts.length - 20} أرقام أخرى');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
        print('❌ Access Denied: ${responseData['message']}');
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'غير مصرح لك - هذا الحساب ليس مسؤول أمن'
        };
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized: ${responseData['message']}');
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'انتهت صلاحية الجلسة، من فضلك سجل دخول مرة أخرى'
        };
      } else {
        print('❌ Download Failed: ${responseData['message']}');
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

  // ==================== DOWNLOAD ASSIGNED CONTACTS ====================
  static Future<Map<String, dynamic>> downloadAssignedContacts(String token, int employeeId) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.downloadAssignedContactsEndpoint}/$employeeId';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 DOWNLOAD ASSIGNED CONTACTS REQUEST');
      print('📍 URL: $url');
      print('👤 Employee ID: $employeeId');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.get(
        Uri.parse(url),
        headers: _getBaseHeaders(token: token),
      );

      print('📥 DOWNLOAD ASSIGNED RESPONSE Status: ${response.statusCode}');
      print('📄 Full Response Body:');
      print('${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['code'] == 200) {
        final data = responseData['data'];
        List contacts = data['contacts'] ?? [];
        final employee = data['employee'] ?? {};

        print('📊 الأرقام الموزعة على الموظف: ${employee['name']} (ID: ${employee['id']})');
        print('   إجمالي الأرقام: ${contacts.length}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        for (int i = 0; i < (contacts.length > 20 ? 20 : contacts.length); i++) {
          var contact = contacts[i];
          String phone = contact['phone_number'] ?? '';
          String name = contact['contact_name'] ?? 'بدون اسم';
          String marker = contact['ownership_marker'] ?? '';
          print('   ${i+1}. الرقم: $phone | الاسم: "$name" | الملكية: "$marker"');
        }

        if (contacts.length > 20) {
          print('   ... و ${contacts.length - 20} أرقام أخرى');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        print('✅ Download Assigned Contacts Successful!');
        return {
          'status': 'success',
          'data': {
            'employee': employee,
            'total_contacts': data['total_contacts'] ?? contacts.length,
            'contacts': contacts,
          }
        };
      } else if (response.statusCode == 403) {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'غير مصرح لك - ليس لديك أرقام موزعة'
        };
      } else if (response.statusCode == 401) {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'انتهت صلاحية الجلسة'
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'فشل سحب الأرقام الموزعة'
        };
      }
    } catch (e) {
      print('❌ Download Assigned Exception: $e');
      return {
        'status': 'error',
        'message': 'خطأ في الاتصال بالسيرفر: $e'
      };
    }
  }
}