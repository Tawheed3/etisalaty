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
  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _isUploading = false;
  bool _isDownloading = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    String? name = await LocalStorage.getUserName();
    setState(() => _userName = name);
    print('👤 Loaded user name: $name');
  }

  // جلب الأرقام الموجودة بالفعل على الجهاز (موحدة الصيغة)
  Future<Set<String>> getExistingPhoneNumbersOnDevice() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 [getExistingPhoneNumbersOnDevice] بدء قراءة جهات الاتصال على الجهاز');

    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        print('❌ [getExistingPhoneNumbersOnDevice] مفيش إذن لقراءة الجهات');
        return {};
      }

      List<Contact> deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      print('📱 [getExistingPhoneNumbersOnDevice] تم قراءة ${deviceContacts.length} جهة اتصال من الجهاز');

      Set<String> existingNumbers = {};
      for (var contact in deviceContacts) {
        for (var phone in contact.phones) {
          String number = PhoneNormalizer.normalize(phone.number);
          existingNumbers.add(number);
        }
      }

      print('📱 [getExistingPhoneNumbersOnDevice] أرقام فريدة على الجهاز: ${existingNumbers.length}');
      if (existingNumbers.isNotEmpty) {
        print('📱 [getExistingPhoneNumbersOnDevice] مثال لأول 5 أرقام: ${existingNumbers.take(5).toList()}');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return existingNumbers;
    } catch (e) {
      print('❌ [getExistingPhoneNumbersOnDevice] خطأ: $e');
      return {};
    }
  }

  // حفظ الأرقام الجديدة في جهات اتصال الجهاز (بالصيغة الموحدة)
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
      String phoneNumber = contact['phone_number'] ?? '';
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
      String phoneNumber = contactData['phone_number'] ?? '';
      String contactName = contactData['contact_name'] ?? 'بدون اسم';

      String cleanNumber = PhoneNormalizer.normalize(phoneNumber);

      String countryCode = PhoneNormalizer.getCountryCode(cleanNumber);
      String displayCountry = countryCode == '+20' ? 'مصر' : (countryCode == '+966' ? 'السعودية' : 'غير معروف');

      try {
        final Contact newContact = Contact()
          ..displayName = contactName
          ..phones = [Phone(cleanNumber, label: PhoneLabel.mobile)];

        await newContact.insert();
        savedCount++;

        if (i % 10 == 0) {
          print('💾 [_saveContactsToDevice] تقدم: $savedCount/$total تم حفظهم');
          if (mounted) {
            setState(() {});
          }
          await Future.delayed(Duration(milliseconds: 100));
        }

        print('✅ [_saveContactsToDevice] تم حفظ ($savedCount/$total): $contactName - $cleanNumber [$displayCountry]');
      } catch (e) {
        print('❌ [_saveContactsToDevice] خطأ في حفظ $contactName: $e');
      }
    }

    print('🎉 [_saveContactsToDevice] تم حفظ $savedCount جهة اتصال جديدة من أصل $total');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (mounted && savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حفظ $savedCount رقم جديد'), backgroundColor: Colors.green),
      );
    }
  }

  // زر الرفع (يرفع كل الأرقام، السيرفر هو اللي يفلتر)
  Future<void> _uploadContacts() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📤 [_uploadContacts] بدء عملية رفع الأرقام');
    setState(() => _isUploading = true);

    try {
      List<Map<String, String>> allContacts = await ContactsManager.getAllContacts();

      if (allContacts.isEmpty) {
        print('⚠️ [_uploadContacts] مفيش جهات اتصال على الجهاز');
        _showMessage('مفيش جهات اتصال على الجهاز', Colors.orange);
        return;
      }

      print('📱 [_uploadContacts] تم جلب ${allContacts.length} جهة اتصال من الجهاز');

      String? token = await LocalStorage.getToken();
      if (token == null) {
        print('❌ [_uploadContacts] مفيش توكن');
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        return;
      }

      print('📡 [_uploadContacts] إرسال ${allContacts.length} رقم إلى السيرفر...');
      final result = await ApiService.uploadContacts(token, allContacts);

      if (result['status'] == 'success') {
        int newCount = result['data']['new_contacts_added'] ?? 0;
        int alreadyExists = result['data']['already_exists'] ?? 0;
        int duplicatesByEmployee = result['data']['duplicates_by_employee'] ?? 0;

        print('✅ [_uploadContacts] نتيجة الرفع:');
        print('   - جديد في النظام: $newCount');
        print('   - موجود مسبقاً: $alreadyExists');
        print('   - مكرر من الموظف: $duplicatesByEmployee');

        _showMessage(
            '✅ تم رفع ${allContacts.length} رقم\n'
                '🆕 جديد في النظام: $newCount\n'
                '⚠️ موجود مسبقاً: $alreadyExists\n'
                '👤 مكرر منك: $duplicatesByEmployee',
            Colors.green
        );
      } else {
        print('❌ [_uploadContacts] فشل الرفع: ${result['message']}');
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }

    } catch (e) {
      print('❌ [_uploadContacts] خطأ: ${e.toString()}');
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isUploading = false);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // زر السحب (مسؤول الأمن فقط)
  Future<void> _downloadContacts() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📥 [_downloadContacts] بدء عملية سحب الأرقام');
    setState(() => _isDownloading = true);

    try {
      String? token = await LocalStorage.getToken();
      if (token == null) {
        print('❌ [_downloadContacts] مفيش توكن');
        _showMessage('من فضلك سجل الدخول مرة أخرى', Colors.red);
        setState(() => _isDownloading = false);
        return;
      }

      print('📡 [_downloadContacts] إرسال طلب إلى السيرفر...');
      final result = await ApiService.downloadContacts(token);

      if (result['status'] == 'success') {
        List allContacts = result['data']['contacts'] ?? [];
        int totalFromServer = allContacts.length;
        print('📊 [_downloadContacts] إجمالي الأرقام من السيرفر: $totalFromServer');

        print('🔍 [_downloadContacts] جلب الأرقام الموجودة على الجهاز...');
        Set<String> existingOnDevice = await getExistingPhoneNumbersOnDevice();
        print('📱 [_downloadContacts] الأرقام الموجودة على الجهاز قبل الفلترة: ${existingOnDevice.length}');

        List newContacts = [];
        int skippedCount = 0;
        Map<String, int> countryStats = {'+20': 0, '+966': 0};

        for (var contact in allContacts) {
          String phoneNumber = contact['phone_number'] ?? '';
          String cleanNumber = PhoneNormalizer.normalize(phoneNumber);

          String countryCode = PhoneNormalizer.getCountryCode(cleanNumber);
          if (countryStats.containsKey(countryCode)) {
            countryStats[countryCode] = countryStats[countryCode]! + 1;
          }

          bool exists = existingOnDevice.contains(cleanNumber);

          if (exists) {
            skippedCount++;
            if (skippedCount <= 10) {
              print('⚠️ [_downloadContacts] رقم موجود مسبقاً، تم تخطيه: $cleanNumber');
            }
          } else {
            newContacts.add(contact);
          }
        }

        int newContactsCount = newContacts.length;

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📊 [_downloadContacts] نتائج الفلترة:');
        print('   - إجمالي من السيرفر: $totalFromServer');
        print('   - أرقام جديدة: $newContactsCount');
        print('   - أرقام موجودة مسبقاً وتم تخطيها: $skippedCount');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📊 إحصاء الأرقام حسب كود البلد:');
        print('   - مصر (+20): ${countryStats['+20']} رقم');
        print('   - السعودية (+966): ${countryStats['+966']} رقم');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (newContactsCount == 0) {
          print('⚠️ [_downloadContacts] كل الأرقام موجودة بالفعل على جهازك');
          _showMessage('📱 كل الأرقام موجودة بالفعل على جهازك ($skippedCount رقم متكرر)', Colors.orange);
        } else {
          print('💾 [_downloadContacts] بدء حفظ $newContactsCount رقم جديد...');
          await _saveContactsToDevice(newContacts);
          _showMessage(
              '✅ تم تحميل $newContactsCount رقم جديد\n⚠️ تم تخطي $skippedCount رقم موجود مسبقاً',
              Colors.green
          );
        }

        _showDownloadSummary(newContactsCount, skippedCount, totalFromServer, countryStats);
      } else {
        print('❌ [_downloadContacts] فشل السحب: ${result['message']}');
        _showMessage(result['message'] ?? 'حدث خطأ', Colors.red);
      }

    } catch (e) {
      print('❌ [_downloadContacts] خطأ: ${e.toString()}');
      _showMessage('خطأ: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isDownloading = false);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  void _showDownloadSummary(int newCount, int skippedCount, int total, Map<String, int> countryStats) {
    print('📊 [_showDownloadSummary] عرض ملخص التحميل للمستخدم');
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
            Text('✅ أرقام جديدة تم تحميلها: $newCount', style: TextStyle(color: Colors.green)),
            Text('   🇪🇬 مصر: ${countryStats['+20'] ?? 0} رقم', style: TextStyle(fontSize: 12)),
            Text('   🇸🇦 السعودية: ${countryStats['+966'] ?? 0} رقم', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('⚠️ أرقام موجودة مسبقاً وتم تخطيها: $skippedCount', style: TextStyle(color: Colors.orange)),
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
    print('📢 [_showMessage] $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _logout() async {
    print('🚪 [_logout] بدء عملية تسجيل الخروج');
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

    if (confirm == true) {
      print('🚪 [_logout] تأكيد تسجيل الخروج');
      await MyApp.logoutAndNavigate(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🖥️ [SecurityScreen] بناء واجهة المستخدم');
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً $_userName (مسؤول أمن)', style: TextStyle(fontSize: 16)),
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
            // زر رفع الأرقام
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

            // زر سحب الأرقام (للمسؤول فقط)
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

            // زر تنظيف المكررات
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  print('🧹 [SecurityScreen] فتح شاشة تنظيف المكررات');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CleanDuplicatesScreen()),
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