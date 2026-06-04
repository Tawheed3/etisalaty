// lib/screens/security_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../constants/phone_normalizer.dart';
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
          existingNumbers.add(PhoneNormalizer.normalize(phone.number));
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

  // ==================== دوال مساعدة للحفظ والتحديث ====================

  Future<void> _createNewContact(String displayName, String phoneNumber) async {
    final Contact newContact = Contact()
      ..displayName = displayName
      ..name.first = displayName
      ..phones = [Phone(phoneNumber, label: PhoneLabel.mobile)];
    await newContact.insert();
    debugPrint('   📱 تم إنشاء جهة اتصال جديدة: "$displayName" - $phoneNumber');
  }

  Future<void> _updateContactName(Contact contact, String newName) async {
    contact.displayName = newName;
    contact.name.first = newName;
    await contact.update();
    debugPrint('   ✏️ تم تحديث الاسم إلى: "$newName"');
  }

  // ==================== حفظ الأرقام في الجهاز ====================

  Future<void> _saveContactsToDevice(List contacts) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('💾 بدء حفظ ${contacts.length} جهة اتصال');

    if (!await FlutterContacts.requestPermission()) {
      debugPrint('❌ مفيش إذن لحفظ جهات الاتصال');
      throw Exception('مفيش إذن لحفظ جهات الاتصال');
    }

    // ✅ جلب جميع جهات الاتصال مع withAccounts: true عشان التحديث يشتغل على Android
    List<Contact> allDeviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: true,
    );

    // إنشاء Map للبحث السريع: الرقم -> الـ Contact
    Map<String, Contact> phoneToContact = {};
    for (var contact in allDeviceContacts) {
      for (var phone in contact.phones) {
        String cleanNumber = PhoneNormalizer.normalize(phone.number);
        phoneToContact[cleanNumber] = contact;
      }
    }

    int savedCount = 0;
    int updatedCount = 0;

    for (int i = 0; i < contacts.length; i++) {
      var contactData = contacts[i];
      String phoneNumber = _readContactField(contactData, const ['phone_number', 'phoneNumber', 'phone', 'number', 'mobile']);
      String contactName = _readContactField(contactData, const ['contact_name', 'contactName', 'name', 'display_name', 'displayName']);
      String ownershipMarker = contactData is Map ? (contactData['ownership_marker'] ?? '') : '';
      String cleanNumber = PhoneNormalizer.normalize(phoneNumber);

      // الاسم الجديد المطلوب حفظه
      String newDisplayName = _formatNameWithMarker(contactName, ownershipMarker.isNotEmpty ? ownershipMarker : null);

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📞 معالجة الرقم: $cleanNumber');
      debugPrint('   الاسم الأصلي من السيرفر: "$contactName"');
      debugPrint('   الاسم الجديد المقترح: "$newDisplayName"');
      debugPrint('   الملكية: "$ownershipMarker"');

      // البحث عن الرقم في جهات الاتصال الموجودة
      Contact? existingContact = phoneToContact[cleanNumber];

      if (existingContact == null) {
        // الحالة 1: الرقم غير موجود → حفظ جديد
        debugPrint('   ✅ حالة 1: رقم جديد، سيتم حفظه');
        await _createNewContact(newDisplayName, cleanNumber);
        savedCount++;
      } else {
        // الرقم موجود، نتحقق من الاسم الحالي
        String currentName = existingContact.displayName ?? '';
        debugPrint('   📝 الاسم الحالي على الجهاز: "$currentName"');

        // التحقق إذا كان الاسم الحالي يحتوي على "- system)"
        bool hasSystemMarker = currentName.contains('- system)');

        if (!hasSystemMarker) {
          // الحالة 2: الرقم موجود بدون علامة system → حفظ جديد (مكرر)
          debugPrint('   ✅ حالة 2: رقم موجود بدون علامة system، سيتم حفظه كجهة اتصال جديدة (مكررة)');
          await _createNewContact(newDisplayName, cleanNumber);
          savedCount++;
        } else {
          // الحالة 3: الرقم موجود وبه علامة system → تحديث الاسم والرمز بالكامل
          if (currentName != newDisplayName) {
            debugPrint('   ✅ حالة 3: رقم موجود به علامة system، سيتم تحديث الاسم إلى "$newDisplayName"');
            await _updateContactName(existingContact, newDisplayName);
            updatedCount++;
          } else {
            debugPrint('   ⏭️ الاسم نفسه، لا حاجة للتحديث');
          }
        }
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎉 النتيجة النهائية:');
    debugPrint('   ✅ تم حفظ $savedCount جهة اتصال جديدة');
    debugPrint('   🔄 تم تحديث $updatedCount جهة اتصال موجودة');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (mounted && (savedCount > 0 || updatedCount > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم حفظ $savedCount رقم جديد، تحديث $updatedCount رقم'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

  // ==================== سحب جميع الأرقام ====================

  Future<void> _downloadContacts() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📥 بدء عملية سحب جميع الأرقام');
    setState(() => _isDownloading = true);

    try {
      String? token = await LocalStorage.getToken();
      if (token == null) {
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        setState(() => _isDownloading = false);
        return;
      }

      final result = await ApiService.downloadContacts(token);

      if (result['status'] == 'success') {
        List allContacts = result['data']['contacts'] ?? [];
        _traceServerContacts(allContacts);

        int totalFromServer = allContacts.length;
        debugPrint('📊 إجمالي الأرقام من السيرفر: $totalFromServer');

        Set<String> existingOnDevice = await getExistingPhoneNumbersOnDevice();
        debugPrint('📱 الأرقام الموجودة على الجهاز: ${existingOnDevice.length}');

        List newContacts = [];
        int skippedCount = 0;
        Map<String, int> countryStats = {'+20': 0, '+966': 0};

        for (var contact in allContacts) {
          String phoneNumber = _readContactField(contact, const ['phone_number', 'phoneNumber', 'phone', 'number', 'mobile']);
          String cleanNumber = PhoneNormalizer.normalize(phoneNumber);

          String countryCode = PhoneNormalizer.getCountryCode(cleanNumber);
          if (countryStats.containsKey(countryCode)) {
            countryStats[countryCode] = countryStats[countryCode]! + 1;
          }

          if (existingOnDevice.contains(cleanNumber)) {
            skippedCount++;
          } else {
            newContacts.add(contact);
          }
        }

        int newContactsCount = newContacts.length;

        if (newContactsCount == 0) {
          _showMessage('📱 كل الأرقام موجودة بالفعل على جهازك', Colors.orange);
        } else {
          await _saveContactsToDevice(newContacts);
          _showMessage(
            '✅ تم تحميل $newContactsCount رقم جديد\n⚠️ تم تخطي $skippedCount رقم موجود مسبقاً',
            Colors.green,
          );
        }

        _showDownloadSummary(newContactsCount, skippedCount, totalFromServer, countryStats);
      } else {
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }
    } catch (e) {
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isDownloading = false);
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

        Set<String> existingNumbers = await getExistingPhoneNumbersOnDevice();

        List newContacts = [];
        List existingContacts = [];

        for (var contact in contacts) {
          String phone = contact['phone_number'] ?? '';
          String cleanNumber = PhoneNormalizer.normalize(phone);
          if (existingNumbers.contains(cleanNumber)) {
            existingContacts.add(contact);
          } else {
            newContacts.add(contact);
          }
        }

        if (newContacts.isNotEmpty) {
          await _saveContactsToDevice(newContacts);
        }

        int updatedCount = 0;
        int duplicatedCount = 0;

        for (var contact in existingContacts) {
          String phoneNumber = contact['phone_number'] ?? '';
          String contactName = contact['contact_name'] ?? 'بدون اسم';
          String ownershipMarker = contact is Map ? (contact['ownership_marker'] ?? '') : '';
          String cleanNumber = PhoneNormalizer.normalize(phoneNumber);
          String newDisplayName = _formatNameWithMarker(contactName, ownershipMarker.isNotEmpty ? ownershipMarker : null);

          // ✅ جلب جهات الاتصال مع withProperties, withPhoto, withAccounts
          List<Contact> deviceContacts = await FlutterContacts.getContacts(
            withProperties: true,
            withPhoto: true,
            withAccounts: true,
          );
          Contact? existingContact;
          for (var deviceContact in deviceContacts) {
            for (var phone in deviceContact.phones) {
              if (PhoneNormalizer.normalize(phone.number) == cleanNumber) {
                existingContact = deviceContact;
                break;
              }
            }
            if (existingContact != null) break;
          }

          if (existingContact != null) {
            String currentName = existingContact.displayName ?? '';
            bool hasSystemMarker = currentName.contains('- system)');

            if (!hasSystemMarker) {
              debugPrint('   ✅ حالة 2: رقم موجود بدون علامة system، سيتم حفظه كجهة اتصال جديدة (مكررة)');
              await _createNewContact(newDisplayName, cleanNumber);
              duplicatedCount++;
            } else if (currentName != newDisplayName) {
              debugPrint('   ✅ حالة 3: تحديث الاسم إلى "$newDisplayName"');
              await _updateContactName(existingContact, newDisplayName);
              updatedCount++;
            }
          } else {
            await _createNewContact(newDisplayName, cleanNumber);
            duplicatedCount++;
          }
        }

        int newCount = newContacts.length;

        _showMessage(
          '✅ تم تحميل $newCount رقم جديد\n'
              '🔄 تم تحديث $updatedCount رقم\n'
              '📱 تم إضافة $duplicatedCount رقم كنسخة مكررة (للدمج لاحقاً)',
          Colors.green,
        );

        _showAssignedSummary(newCount, updatedCount, duplicatedCount, total, employeeName);
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

  void _showDownloadSummary(int newCount, int skippedCount, int total, Map<String, int> countryStats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة التحميل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 إجمالي الأرقام من السيرفر: $total'),
            const SizedBox(height: 8),
            Text('✅ أرقام جديدة تم تحميلها: $newCount', style: TextStyle(color: Colors.green)),
            Text('   🇪🇬 مصر: ${countryStats['+20'] ?? 0} رقم', style: TextStyle(fontSize: 12)),
            Text('   🇸🇦 السعودية: ${countryStats['+966'] ?? 0} رقم', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('⚠️ أرقام موجودة مسبقاً وتم تخطيها: $skippedCount', style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 16),
            const Text('💾 تم حفظ الأرقام الجديدة في جهات اتصال هاتفك'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showAssignedSummary(int newCount, int updatedCount, int duplicatedCount, int total, String employeeName) {
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
            const SizedBox(height: 8),
            Text('✅ أرقام جديدة تم تحميلها: $newCount', style: TextStyle(color: Colors.green)),
            Text('🔄 أرقام تم تحديثها: $updatedCount', style: TextStyle(color: Colors.blue)),
            Text('📱 أرقام مكررة تمت إضافتها (للدمج لاحقاً): $duplicatedCount', style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 16),
            const Text('💾 تم حفظ وتحديث الأرقام في جهات اتصال هاتفك'),
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

            // زر سحب جميع الأرقام
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _downloadContacts,
                icon: _isDownloading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download, size: 28),
                label: Text(_isDownloading ? 'جاري السحب...' : 'سحب جميع الأرقام', style: const TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
          ],
        ),
      ),
    );
  }
}