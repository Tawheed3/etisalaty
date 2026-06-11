// lib/screens/security_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../service/api_service.dart';
import '../service/contacts_service.dart';
import '../service/local_storage.dart';
import 'clean_duplicates_screen.dart';
import '../main.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const bool _traceContacts = bool.fromEnvironment(
    'ETISALATY_TRACE_CONTACTS',
  );

  bool _isUploading = false;
  bool _isDownloading = false;
  bool _isDownloadingAssigned = false;
  bool _isDeleting = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadUserName();
  }

  Future<void> _requestPermissions() async {
    await FlutterContacts.requestPermission();
  }

  Future<void> _loadUserName() async {
    String? name = await LocalStorage.getUserName();
    setState(() => _userName = name);
    debugPrint('👤 Loaded user name: $name');
  }

  // تنسيق الاسم مع marker: الاسم (الرمز - system)
  String _formatNameWithMarker(String originalName, String? marker) {
    String name = originalName.trim();
    if (name.isEmpty) name = 'بدون اسم';

    if (marker != null && marker.isNotEmpty) {
      return '$name ($marker - system)';
    }
    return name;
  }

  String _readContactField(dynamic contactData, List<String> keys) {
    if (contactData is! Map) return '';
    for (final key in keys) {
      final value = contactData[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  void _traceContact(String message) {
    if (_traceContacts) {
      debugPrint('ETISALATY_CONTACT_TRACE $message', wrapWidth: 1024);
    }
  }

  String _contactKeys(dynamic contactData) {
    if (contactData is Map) {
      return contactData.keys.map((key) => key.toString()).join(',');
    }
    return contactData.runtimeType.toString();
  }

  void _traceServerContacts(List contacts) {
    if (!_traceContacts) return;
    _traceContact('SERVER_RESPONSE count=${contacts.length}');
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final rawName = _readContactField(contact, const [
        'contact_name', 'contactName', 'name', 'display_name', 'displayName'
      ]);
      final rawPhone = _readContactField(contact, const [
        'phone_number', 'phoneNumber', 'phone', 'number', 'mobile'
      ]);
      final marker = contact is Map ? (contact['ownership_marker'] ?? '') : '';
      _traceContact(
        'SERVER_CONTACT index=$i keys=${_contactKeys(contact)} '
            'rawName="$rawName" rawPhone="$rawPhone" marker="$marker"',
      );
    }
  }

  Future<Set<String>> getExistingPhoneNumbersOnDevice() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📱 بدء قراءة جهات الاتصال');

    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        debugPrint('❌ مفيش إذن لقراءة الجهات');
        return {};
      }

      List<Contact> deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      debugPrint('📱 تم قراءة ${deviceContacts.length} جهة اتصال');

      Set<String> existingNumbers = {};
      for (var contact in deviceContacts) {
        for (var phone in contact.phones) {
          existingNumbers.add(phone.number.trim());
        }
      }

      debugPrint('📱 أرقام فريدة: ${existingNumbers.length}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return existingNumbers;
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      return {};
    }
  }

  // ==================== دوال مساعدة للحفظ ====================

  Future<void> _createNewContact(String displayName, String phoneNumber) async {
    final Contact newContact = Contact()
      ..displayName = displayName
      ..name.first = displayName
      ..phones = [Phone(phoneNumber, label: PhoneLabel.mobile)];
    await newContact.insert();
    debugPrint('   📱 تم إنشاء جهة اتصال جديدة: "$displayName" - $phoneNumber');
  }

  // ==================== حفظ الأرقام (بدون فلترة) ====================

  Future<void> _saveAllContactsToDevice(List contacts) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('💾 بدء حفظ ${contacts.length} جهة اتصال (بدون فلترة)');

    if (!await FlutterContacts.requestPermission()) {
      debugPrint('❌ مفيش إذن لحفظ جهات الاتصال');
      throw Exception('مفيش إذن لحفظ جهات الاتصال');
    }

    int savedCount = 0;
    int duplicateCount = 0;

    for (int i = 0; i < contacts.length; i++) {
      var contactData = contacts[i];
      String phoneNumber = _readContactField(contactData, const ['phone_number', 'phoneNumber', 'phone', 'number', 'mobile']);
      String contactName = _readContactField(contactData, const ['contact_name', 'contactName', 'name', 'display_name', 'displayName']);
      String ownershipMarker = contactData is Map ? (contactData['ownership_marker'] ?? '') : '';
      String cleanNumber = phoneNumber.trim();

      String displayName = _formatNameWithMarker(contactName, ownershipMarker.isNotEmpty ? ownershipMarker : null);

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('💾 حفظ #${i+1}/${contacts.length}');
      debugPrint('   📞 الرقم: $cleanNumber');
      debugPrint('   📝 الاسم: "$displayName"');

      try {
        final Contact newContact = Contact()
          ..displayName = displayName
          ..name.first = displayName
          ..phones = [Phone(cleanNumber, label: PhoneLabel.mobile)];
        await newContact.insert();
        savedCount++;
        debugPrint('   ✅ تم حفظ بنجاح');
      } catch (e) {
        debugPrint('   ❌ خطأ في حفظ: $e');
        duplicateCount++;
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎉 تم حفظ $savedCount جهة اتصال من أصل ${contacts.length}');
    if (duplicateCount > 0) {
      debugPrint('⚠️ $duplicateCount جهة اتصال مكررة (تم تخطيها أو خطأ)');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ==================== حذف الأرقام التي تحتوي على - system (الزر القديم) ====================

  Future<void> _deleteAllSystemContacts() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🗑️ بدء حذف الأرقام التي تحتوي على "- system"');

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الأرقام'),
        content: const Text('هل أنت متأكد من حذف جميع الأرقام التي تحتوي على "- system"؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      if (!await FlutterContacts.requestPermission()) {
        _showMessage('مفيش إذن لحذف جهات الاتصال', Colors.red);
        setState(() => _isDeleting = false);
        return;
      }

      List<Contact> allContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: true,
      );

      List<Contact> contactsToDelete = allContacts.where((contact) {
        String displayName = contact.displayName ?? '';
        return displayName.contains('- system');
      }).toList();

      int totalToDelete = contactsToDelete.length;
      int deletedCount = 0;
      List<String> deletedNames = [];

      for (int i = 0; i < contactsToDelete.length; i++) {
        var contact = contactsToDelete[i];
        String displayName = contact.displayName ?? '';

        await contact.delete();
        deletedCount++;
        deletedNames.add(displayName);
        debugPrint('   🗑️ تم حذف ($deletedCount/$totalToDelete): "$displayName"');

        if (i % 5 == 0 && mounted) {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ تم حذف $deletedCount جهة اتصال');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _showMessage('✅ تم حذف $deletedCount جهة اتصال تحتوي على "- system"', Colors.green);

      if (deletedCount > 0) {
        _showDeletedSummary(deletedCount, deletedNames);
      }
    } catch (e) {
      debugPrint('❌ خطأ أثناء الحذف: $e');
      _showMessage('خطأ أثناء الحذف: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  // ==================== حذف الأرقام التي لا تحتوي على - system ولها نظير به - system (الزر الجديد) ====================

  Future<void> _deleteNonSystemContactsWithSystemDuplicate() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🗑️ بدء حذف الأرقام التي لا تحتوي على "- system" ولها نظير به "- system"');

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الأرقام المكررة'),
        content: const Text(
            'هل أنت متأكد من حذف جميع الأرقام التي لا تحتوي على "- system" '
                'ولها نفس الرقم موجود بالفعل به "- system"؟\nلا يمكن التراجع عن هذا الإجراء.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      if (!await FlutterContacts.requestPermission()) {
        _showMessage('مفيش إذن لحذف جهات الاتصال', Colors.red);
        setState(() => _isDeleting = false);
        return;
      }

      List<Contact> allContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: true,
      );

      // تجميع الأرقام حسب الرقم
      Map<String, List<Contact>> numberToContacts = {};
      for (var contact in allContacts) {
        for (var phone in contact.phones) {
          String number = phone.number.trim();
          numberToContacts.putIfAbsent(number, () => []);
          numberToContacts[number]!.add(contact);
        }
      }

      // تحديد جهات الاتصال التي سيتم حذفها
      List<Contact> contactsToDelete = [];

      for (var entry in numberToContacts.entries) {
        List<Contact> contacts = entry.value;

        // هل فيه جهة اتصال بهذا الرقم تحتوي على "- system"؟
        bool hasSystemContact = contacts.any((contact) {
          String name = contact.displayName ?? '';
          return name.contains('- system');
        });

        if (hasSystemContact) {
          // أضف كل جهات الاتصال التي لا تحتوي على "- system" للحذف
          for (var contact in contacts) {
            String name = contact.displayName ?? '';
            if (!name.contains('- system')) {
              contactsToDelete.add(contact);
            }
          }
        }
      }

      int totalToDelete = contactsToDelete.length;
      int deletedCount = 0;
      List<String> deletedNames = [];

      for (int i = 0; i < contactsToDelete.length; i++) {
        var contact = contactsToDelete[i];
        String displayName = contact.displayName ?? '';

        await contact.delete();
        deletedCount++;
        deletedNames.add(displayName);
        debugPrint('   🗑️ تم حذف ($deletedCount/$totalToDelete): "$displayName"');

        if (i % 5 == 0 && mounted) {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ تم حذف $deletedCount جهة اتصال');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _showMessage('✅ تم حذف $deletedCount جهة اتصال مكررة (بدون - system)', Colors.green);

      if (deletedCount > 0) {
        _showNonSystemDeletedSummary(deletedCount, deletedNames);
      }
    } catch (e) {
      debugPrint('❌ خطأ أثناء الحذف: $e');
      _showMessage('خطأ أثناء الحذف: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  void _showDeletedSummary(int count, List<String> names) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🗑️ تم حذف $count جهة اتصال'),
            const SizedBox(height: 8),
            const Text('الأجهزة المحذوفة:'),
            ...names.take(10).map((name) => Text('• $name', style: const TextStyle(fontSize: 12))),
            if (names.length > 10) Text('... و ${names.length - 10} أخرى'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showNonSystemDeletedSummary(int count, List<String> names) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة حذف الأرقام المكررة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🗑️ تم حذف $count جهة اتصال (بدون - system)'),
            const SizedBox(height: 8),
            const Text('الأجهزة المحذوفة:'),
            ...names.take(10).map((name) => Text('• $name', style: const TextStyle(fontSize: 12))),
            if (names.length > 10) Text('... و ${names.length - 10} أخرى'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  // ==================== رفع الأرقام ====================

  Future<void> _uploadContacts() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📤 بدء عملية رفع الأرقام');
    setState(() => _isUploading = true);

    try {
      List<Map<String, String>> allContacts = await ContactsManager.getAllContacts();

      if (allContacts.isEmpty) {
        _showMessage('مفيش جهات اتصال على الجهاز', Colors.orange);
        return;
      }

      debugPrint('📱 تم جلب ${allContacts.length} جهة اتصال');

      String? token = await LocalStorage.getToken();
      if (token == null) {
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        return;
      }

      final result = await ApiService.uploadContacts(token, allContacts);

      if (result['status'] == 'success') {
        int newCount = result['data']['new_contacts_added'] ?? 0;
        int alreadyExists = result['data']['already_exists'] ?? 0;
        int duplicatesByEmployee = result['data']['duplicates_by_employee'] ?? 0;

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
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isUploading = false);
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // ==================== سحب الأرقام الموزعة ====================

  Future<void> _downloadAssignedContacts() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📥 بدء عملية سحب الأرقام الموزعة');
    setState(() => _isDownloadingAssigned = true);

    try {
      String? token = await LocalStorage.getToken();
      int? employeeId = await LocalStorage.getUserId();

      if (token == null || employeeId == null) {
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        setState(() => _isDownloadingAssigned = false);
        return;
      }

      debugPrint('👤 Employee ID (from login): $employeeId');

      final result = await ApiService.downloadAssignedContacts(token, employeeId);

      if (result['status'] == 'success') {
        List contacts = result['data']['contacts'] ?? [];
        int total = contacts.length;
        String employeeName = result['data']['employee']['name'] ?? '';

        debugPrint('📊 إجمالي الأرقام الموزعة للموظف $employeeName: $total');

        await _saveAllContactsToDevice(contacts);

        _showMessage(
          '✅ تم تحميل $total رقم بنجاح',
          Colors.green,
        );

        _showAssignedSummary(total, employeeName);
      } else {
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }
    } catch (e) {
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isDownloadingAssigned = false);
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // ==================== دوال عرض النتائج ====================

  void _showAssignedSummary(int total, String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة تحميل الأرقام الموزعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👤 الموظف: $employeeName'),
            Text('📊 إجمالي الأرقام الموزعة: $total'),
            const SizedBox(height: 16),
            const Text('✅ تم تحميل جميع الأرقام بنجاح'),
            const Text('💾 تم حفظ الأرقام في جهات اتصال هاتفك'),
            const Text('🏷️ الأرقام تحمل علامة (الرمز - system)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showMessage(String message, Color color) {
    debugPrint('📢 $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _logout() async {
    debugPrint('🚪 بدء عملية تسجيل الخروج');
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل خروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MyApp.logoutAndNavigate(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً $_userName (مسؤول أمن)', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'تسجيل خروج'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // زر رفع الأرقام
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadContacts,
                icon: _isUploading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload, size: 28),
                label: Text(_isUploading ? 'جاري الرفع...' : 'رفع الأرقام', style: const TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // زر سحب الأرقام الموزعة
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isDownloadingAssigned ? null : _downloadAssignedContacts,
                icon: _isDownloadingAssigned
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.assignment_turned_in, size: 28),
                label: Text(
                  _isDownloadingAssigned ? 'جاري التحميل...' : 'سحب الأرقام الموزعة',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // زر تنظيف المكررات
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CleanDuplicatesScreen()));
                },
                icon: const Icon(Icons.cleaning_services, size: 28),
                label: const Text('تنظيف الأرقام المكررة', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // زر حذف الأرقام التي تحتوي على - system (القديم)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _deleteAllSystemContacts,
                icon: _isDeleting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_sweep, size: 28),
                label: Text(
                  _isDeleting ? 'جاري الحذف...' : 'حذف الأرقام (system)',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // زر حذف الأرقام المكررة (الجديد) - اللي بدون - system ولها نظير به - system
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _deleteNonSystemContactsWithSystemDuplicate,
                icon: _isDeleting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.clean_hands, size: 28),
                label: Text(
                  _isDeleting ? 'جاري الحذف...' : 'حذف المكررات (بدون system)',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}