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
  String? _userName;

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // ✅ أضف هذا السطر
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

  // جلب الأرقام الموجودة بالفعل على الجهاز
  Future<Set<String>> getExistingPhoneNumbersOnDevice() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint(
      '📱 [getExistingPhoneNumbersOnDevice] بدء قراءة جهات الاتصال على الجهاز',
    );

    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        debugPrint(
          '❌ [getExistingPhoneNumbersOnDevice] مفيش إذن لقراءة الجهات',
        );
        return {};
      }

      List<Contact> deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      debugPrint(
        '📱 [getExistingPhoneNumbersOnDevice] تم قراءة ${deviceContacts.length} جهة اتصال من الجهاز',
      );

      Set<String> existingNumbers = {};
      for (var contact in deviceContacts) {
        for (var phone in contact.phones) {
          String number = PhoneNormalizer.normalize(phone.number);
          existingNumbers.add(number);
        }
      }

      debugPrint(
        '📱 [getExistingPhoneNumbersOnDevice] أرقام فريدة على الجهاز: ${existingNumbers.length}',
      );
      if (existingNumbers.isNotEmpty) {
        debugPrint(
          '📱 [getExistingPhoneNumbersOnDevice] مثال لأول 5 أرقام: ${existingNumbers.take(5).toList()}',
        );
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return existingNumbers;
    } catch (e) {
      debugPrint('❌ [getExistingPhoneNumbersOnDevice] خطأ: $e');
      return {};
    }
  }

  // حفظ الأرقام الجديدة في جهات اتصال الجهاز
  // lib/screens/security_screen.dart
// دالة _saveContactsToDevice كاملة مع طباعة مفصلة

  Future<void> _saveContactsToDevice(List contacts) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('💾 [_saveContactsToDevice] بدء حفظ ${contacts.length} جهة اتصال');

    if (!await FlutterContacts.requestPermission()) {
      print('❌ [_saveContactsToDevice] مفيش إذن لحفظ جهات الاتصال');
      throw Exception('مفيش إذن لحفظ جهات الاتصال');
    }

    print('🔍 [_saveContactsToDevice] جلب الأرقام الموجودة حالياً على الجهاز للتأكد من عدم التكرار...');
    Set<String> currentDeviceNumbers = await getExistingPhoneNumbersOnDevice();
    print('📱 [_saveContactsToDevice] الأرقام الموجودة حالياً: ${currentDeviceNumbers.length}');

    List finalContacts = contacts.where((contact) {
      String phoneNumber = _readContactField(contact, const [
        'phone_number',
        'phoneNumber',
        'phone',
        'number',
        'mobile',
      ]);
      String cleanNumber = PhoneNormalizer.normalize(phoneNumber);
      bool exists = currentDeviceNumbers.contains(cleanNumber);
      if (exists) {
        print('⚠️ [_saveContactsToDevice] رقم موجود بالفعل، تم تخطيه: $cleanNumber');
      }
      return !exists;
    }).toList();

    int filteredCount = contacts.length - finalContacts.length;
    print('🔍 [_saveContactsToDevice] بعد الفلترة: ${finalContacts.length} جديد، $filteredCount تم تخطيهم');

    int savedCount = 0;
    int total = finalContacts.length;

    for (int i = 0; i < total; i++) {
      var contactData = finalContacts[i];

      String phoneNumber = _readContactField(contactData, const [
        'phone_number',
        'phoneNumber',
        'phone',
        'number',
        'mobile',
      ]);
      String contactName = _readContactField(contactData, const [
        'contact_name',
        'contactName',
        'name',
        'display_name',
        'displayName',
        'full_name',
        'fullName',
      ]);
      String cleanNumber = PhoneNormalizer.normalize(phoneNumber);
      String displayName = _cleanContactName(contactName, cleanNumber);

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💾 حفظ رقم #${i+1}/$total');
      print('   📞 الرقم الأصلي من السيرفر: "$phoneNumber"');
      print('   📞 الرقم بعد التوحيد: "$cleanNumber"');
      print('   📝 الاسم الأصلي من السيرفر: "$contactName"');
      print('   📝 الاسم بعد التنظيف: "$displayName"');

      _traceContact(
        'SAVE_PREP index=$i rawKeys=${_contactKeys(contactData)} '
            'rawName="$contactName" rawPhone="$phoneNumber" '
            'displayName="$displayName" normalizedPhone="$cleanNumber"',
      );

      String countryCode = PhoneNormalizer.getCountryCode(cleanNumber);
      String displayCountry = countryCode == '+20'
          ? 'مصر'
          : (countryCode == '+966' ? 'السعودية' : 'غير معروف');

      print('   🌍 البلد: $displayCountry ($countryCode)');

      try {
        final Contact newContact = Contact()
          ..displayName = displayName
          ..name.first = displayName
          ..phones = [Phone(cleanNumber, label: PhoneLabel.mobile)];

        _traceContact(
          'INSERT_CONTACT index=$i '
              'contact.displayName="${newContact.displayName}" '
              'contact.name.first="${newContact.name.first}" '
              'phone="${newContact.phones.first.number}"',
        );

        await newContact.insert();
        savedCount++;

        if (i % 10 == 0) {
          print('💾 [_saveContactsToDevice] تقدم: $savedCount/$total تم حفظهم');
          if (mounted) {
            setState(() {});
          }
          await Future.delayed(Duration(milliseconds: 100));
        }

        print('✅ [_saveContactsToDevice] تم حفظ ($savedCount/$total): "$displayName" - $cleanNumber [$displayCountry]');
      } catch (e) {
        print('❌ [_saveContactsToDevice] خطأ في حفظ "$displayName": $e');
      }
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎉 [_saveContactsToDevice] تم حفظ $savedCount جهة اتصال جديدة من أصل $total');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (mounted && savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم حفظ $savedCount رقم جديد'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

  String _cleanContactName(String name, String phoneNumber) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned == phoneNumber) {
      return 'بدون اسم';
    }

    return cleaned;
  }

  void _traceServerContacts(List contacts) {
    if (!_traceContacts) return;

    _traceContact('SERVER_RESPONSE count=${contacts.length}');
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final rawName = _readContactField(contact, const [
        'contact_name',
        'contactName',
        'name',
        'display_name',
        'displayName',
        'full_name',
        'fullName',
      ]);
      final rawPhone = _readContactField(contact, const [
        'phone_number',
        'phoneNumber',
        'phone',
        'number',
        'mobile',
      ]);

      _traceContact(
        'SERVER_CONTACT index=$i keys=${_contactKeys(contact)} '
        'rawName="$rawName" rawPhone="$rawPhone" '
        'raw=$contact',
      );
    }
  }

  String _contactKeys(dynamic contactData) {
    if (contactData is Map) {
      return contactData.keys.map((key) => key.toString()).join(',');
    }
    return contactData.runtimeType.toString();
  }

  void _traceContact(String message) {
    if (_traceContacts) {
      debugPrint('ETISALATY_CONTACT_TRACE $message', wrapWidth: 1024);
    }
  }

  // زر الرفع
  Future<void> _uploadContacts() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📤 [_uploadContacts] بدء عملية رفع الأرقام');
    setState(() => _isUploading = true);

    try {
      List<Map<String, String>> allContacts =
          await ContactsManager.getAllContacts();

      if (allContacts.isEmpty) {
        debugPrint('⚠️ [_uploadContacts] مفيش جهات اتصال على الجهاز');
        _showMessage('مفيش جهات اتصال على الجهاز', Colors.orange);
        return;
      }

      debugPrint(
        '📱 [_uploadContacts] تم جلب ${allContacts.length} جهة اتصال من الجهاز',
      );

      String? token = await LocalStorage.getToken();
      if (token == null) {
        debugPrint('❌ [_uploadContacts] مفيش توكن');
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        return;
      }

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
        debugPrint('❌ [_uploadContacts] فشل الرفع: ${result['message']}');
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ [_uploadContacts] خطأ: ${e.toString()}');
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isUploading = false);
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // زر السحب
  Future<void> _downloadContacts() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📥 [_downloadContacts] بدء عملية سحب الأرقام');
    setState(() => _isDownloading = true);

    try {
      String? token = await LocalStorage.getToken();
      if (token == null) {
        debugPrint('❌ [_downloadContacts] مفيش توكن');
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        setState(() => _isDownloading = false);
        return;
      }

      debugPrint('📡 [_downloadContacts] إرسال طلب إلى السيرفر...');
      final result = await ApiService.downloadContacts(token);

      if (result['status'] == 'success') {
        List allContacts = result['data']['contacts'] ?? [];
        _traceServerContacts(allContacts);

        int totalFromServer = allContacts.length;
        debugPrint(
          '📊 [_downloadContacts] إجمالي الأرقام من السيرفر: $totalFromServer',
        );

        debugPrint('🔍 [_downloadContacts] جلب الأرقام الموجودة على الجهاز...');
        Set<String> existingOnDevice = await getExistingPhoneNumbersOnDevice();
        debugPrint(
          '📱 [_downloadContacts] الأرقام الموجودة على الجهاز قبل الفلترة: ${existingOnDevice.length}',
        );

        List newContacts = [];
        int skippedCount = 0;
        Map<String, int> countryStats = {'+20': 0, '+966': 0};

        for (var contact in allContacts) {
          String phoneNumber = _readContactField(contact, const [
            'phone_number',
            'phoneNumber',
            'phone',
            'number',
            'mobile',
          ]);
          String cleanNumber = PhoneNormalizer.normalize(phoneNumber);

          String countryCode = PhoneNormalizer.getCountryCode(cleanNumber);
          if (countryStats.containsKey(countryCode)) {
            countryStats[countryCode] = countryStats[countryCode]! + 1;
          }

          bool exists = existingOnDevice.contains(cleanNumber);

          if (exists) {
            skippedCount++;
            if (skippedCount <= 10) {
              debugPrint(
                '⚠️ [_downloadContacts] رقم موجود مسبقاً، تم تخطيه: $cleanNumber',
              );
            }
          } else {
            newContacts.add(contact);
          }
        }

        int newContactsCount = newContacts.length;

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 [_downloadContacts] نتائج الفلترة:');
        debugPrint('   - إجمالي من السيرفر: $totalFromServer');
        debugPrint('   - أرقام جديدة: $newContactsCount');
        debugPrint('   - أرقام موجودة مسبقاً وتم تخطيها: $skippedCount');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 إحصاء الأرقام حسب كود البلد:');
        debugPrint('   - مصر (+20): ${countryStats['+20']} رقم');
        debugPrint('   - السعودية (+966): ${countryStats['+966']} رقم');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (newContactsCount == 0) {
          debugPrint(
            '⚠️ [_downloadContacts] كل الأرقام موجودة بالفعل على جهازك',
          );
          _showMessage(
            '📱 كل الأرقام موجودة بالفعل على جهازك ($skippedCount رقم متكرر)',
            Colors.orange,
          );
        } else {
          debugPrint(
            '💾 [_downloadContacts] بدء حفظ $newContactsCount رقم جديد...',
          );
          await _saveContactsToDevice(newContacts);
          _showMessage(
            '✅ تم تحميل $newContactsCount رقم جديد\n⚠️ تم تخطي $skippedCount رقم موجود مسبقاً',
            Colors.green,
          );
        }

        _showDownloadSummary(
          newContactsCount,
          skippedCount,
          totalFromServer,
          countryStats,
        );
      } else {
        debugPrint('❌ [_downloadContacts] فشل السحب: ${result['message']}');
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ [_downloadContacts] خطأ: ${e.toString()}');
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isDownloading = false);
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  void _showDownloadSummary(
    int newCount,
    int skippedCount,
    int total,
    Map<String, int> countryStats,
  ) {
    debugPrint('📊 [_showDownloadSummary] عرض ملخص التحميل للمستخدم');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('نتيجة التحميل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 إجمالي الأرقام من السيرفر: $total'),
            SizedBox(height: 8),
            Text(
              '✅ أرقام جديدة تم تحميلها: $newCount',
              style: TextStyle(color: Colors.green),
            ),
            Text(
              '   🇪🇬 مصر: ${countryStats['+20'] ?? 0} رقم',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '   🇸🇦 السعودية: ${countryStats['+966'] ?? 0} رقم',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              '⚠️ أرقام موجودة مسبقاً وتم تخطيها: $skippedCount',
              style: TextStyle(color: Colors.orange),
            ),
            SizedBox(height: 16),
            Text('💾 تم حفظ الأرقام الجديدة في جهات اتصال هاتفك'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, Color color) {
    debugPrint('📢 [_showMessage] $message');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _logout() async {
    debugPrint('🚪 [_logout] بدء عملية تسجيل الخروج');
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
      debugPrint('🚪 [_logout] تأكيد تسجيل الخروج');
      await MyApp.logoutAndNavigate(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🖥️ [SecurityScreen] بناء واجهة المستخدم');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'مرحباً $_userName (مسؤول أمن)',
          style: TextStyle(fontSize: 16),
        ),
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
                onPressed: _isDownloading ? null : _downloadContacts,
                icon: _isDownloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.cloud_download, size: 28),
                label: Text(
                  _isDownloading ? 'جاري السحب...' : 'سحب الأرقام',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                  debugPrint('🧹 [SecurityScreen] فتح شاشة تنظيف المكررات');
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
