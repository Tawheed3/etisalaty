// lib/screens/employee_screen.dart
import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/contacts_service.dart';
import '../service/local_storage.dart';
import 'clean_duplicates_screen.dart';
import '../main.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  bool _isUploading = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    String? name = await LocalStorage.getUserName();
    setState(() => _userName = name);
  }

  Future<void> _uploadContacts() async {
    setState(() => _isUploading = true);

    try {
      // 1. جلب كل جهات الاتصال من الجهاز
      List<Map<String, String>> allContacts =
          await ContactsManager.getAllContacts();

      if (allContacts.isEmpty) {
        _showMessage('مفيش جهات اتصال على الجهاز', Colors.orange);
        return;
      }

      debugPrint('📱 [_uploadContacts] تم جلب ${allContacts.length} جهة اتصال');

      // 2. جلب التوكن
      String? token = await LocalStorage.getToken();
      if (token == null) {
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        return;
      }

      // 3. رفع كل الأرقام للسيرفر (السيرفر هو اللي يفلتر)
      debugPrint(
        '📡 [_uploadContacts] إرسال ${allContacts.length} رقم إلى السيرفر...',
      );
      final result = await ApiService.uploadContacts(token, allContacts);

      if (result['status'] == 'success') {
        int newCount = result['data']['new_contacts_added'] ?? 0;
        int alreadyExists = result['data']['already_exists'] ?? 0;
        int duplicatesByEmployee =
            result['data']['duplicates_by_employee'] ?? 0;

        debugPrint('✅ [_uploadContacts] نتيجة الرفع:');
        debugPrint('   - جديد في النظام: $newCount');
        debugPrint('   - موجود مسبقاً: $alreadyExists');
        debugPrint('   - مكرر من الموظف: $duplicatesByEmployee');

        _showMessage(
          '✅ تم رفع ${allContacts.length} رقم\n'
          '🆕 جديد في النظام: $newCount\n'
          '⚠️ موجود مسبقاً: $alreadyExists\n'
          '👤 مكرر منك: $duplicatesByEmployee',
          Colors.green,
        );
      } else {
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ [_uploadContacts] خطأ: ${e.toString()}');
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل خروج'),
        content: Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      await MyApp.logoutAndNavigate(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً $_userName', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'تسجيل خروج',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadContacts,
                icon: _isUploading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.cloud_upload, size: 28),
                label: Text(
                  _isUploading ? 'جاري الرفع...' : 'رفع الأرقام',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CleanDuplicatesScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.cleaning_services, size: 28),
                label: Text(
                  'تنظيف الأرقام المكررة',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
