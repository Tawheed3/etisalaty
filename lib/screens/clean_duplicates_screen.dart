// lib/screens/clean_duplicates_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../service/contacts_service.dart';

class CleanDuplicatesScreen extends StatefulWidget {
  @override
  _CleanDuplicatesScreenState createState() => _CleanDuplicatesScreenState();
}

class _CleanDuplicatesScreenState extends State<CleanDuplicatesScreen> {
  Map<String, List<Contact>>? duplicates;
  bool isLoading = true;

  Map<String, Contact?> selectedContacts = {};
  Map<String, TextEditingController> newNameControllers = {};
  Map<String, bool> useNewName = {};

  @override
  void initState() {
    super.initState();
    print('🧹 [CleanDuplicatesScreen] تهيئة الشاشة');
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    print('🧹 [_loadDuplicates] بدء البحث عن الأرقام المكررة');
    setState(() => isLoading = true);
    try {
      duplicates = await ContactsManager.findDuplicateContacts();

      if (duplicates == null || duplicates!.isEmpty) {
        print('🧹 [_loadDuplicates] مفيش أرقام مكررة على الجهاز');
      } else {
        print('🧹 [_loadDuplicates] تم العثور على ${duplicates!.length} رقم مكرر');

        for (var entry in duplicates!.entries) {
          print('   - الرقم: ${entry.key} مكرر ${entry.value.length} مرات');
          selectedContacts[entry.key] = entry.value.first;
          newNameControllers[entry.key] = TextEditingController();
          useNewName[entry.key] = false;
        }
      }
    } catch (e) {
      print('❌ [_loadDuplicates] خطأ: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في قراءة الجهات: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => isLoading = false);
    print('🧹 [_loadDuplicates] انتهى البحث');
  }

  Future<void> _applyClean() async {
    print('🧹 [_applyClean] بدء عملية دمج التكرارات');

    if (duplicates == null || duplicates!.isEmpty) {
      print('🧹 [_applyClean] مفيش مكررات للدمج');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      int mergedCount = 0;
      for (var entry in duplicates!.entries) {
        String phone = entry.key;
        List<Contact> contacts = entry.value;
        Contact? selected = selectedContacts[phone];

        if (selected != null) {
          List<Contact> toDelete = contacts
              .where((c) => c.id != selected.id)
              .toList();

          String? newName;
          if (useNewName[phone] == true && newNameControllers[phone]!.text.isNotEmpty) {
            newName = newNameControllers[phone]!.text;
            print('🧹 [_applyClean] الرقم $phone: استخدام اسم جديد "$newName"');
          } else {
            print('🧹 [_applyClean] الرقم $phone: الاحتفاظ بـ "${selected.displayName}"');
          }

          print('🧹 [_applyClean] دمج ${contacts.length} جهة اتصال للرقم $phone');
          await ContactsManager.mergeDuplicates(
            phoneNumber: phone,
            keepThisContact: selected,
            deleteTheseContacts: toDelete,
            newName: newName,
          );
          mergedCount++;
        }
      }

      Navigator.pop(context);

      print('🧹 [_applyClean] ✅ تم دمج $mergedCount رقم مكرر بنجاح');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تنظيف $mergedCount رقم مكرر بنجاح'), backgroundColor: Colors.green),
      );

      await _loadDuplicates();

    } catch (e) {
      print('❌ [_applyClean] خطأ: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    print('🧹 [CleanDuplicatesScreen] تنظيف الموارد');
    for (var controller in newNameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🧹 [CleanDuplicatesScreen] بناء واجهة المستخدم');
    return Scaffold(
      appBar: AppBar(
        title: Text('تنظيف جهات الاتصال'),
        backgroundColor: Colors.orange,
        actions: [
          if (duplicates != null && duplicates!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.check, color: Colors.white),
              onPressed: _applyClean,
              tooltip: 'تطبيق التغييرات',
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : duplicates == null || duplicates!.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text('🎉 مفيش أرقام مكررة!', style: TextStyle(fontSize: 24)),
            Text('جهات الاتصال نظيفة', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        itemCount: duplicates!.length,
        itemBuilder: (context, index) {
          String phone = duplicates!.keys.elementAt(index);
          List<Contact> contacts = duplicates![phone]!;

          print('🧹 بناء عنصر للرقم $phone (${contacts.length} مرات)');

          return Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phone,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${contacts.length} مرات',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  Card(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: useNewName[phone],
                                onChanged: (val) {
                                  setState(() {
                                    useNewName[phone] = val ?? false;
                                    if (!useNewName[phone]!) {
                                      newNameControllers[phone]!.clear();
                                    }
                                  });
                                },
                              ),
                              Text('استخدام اسم جديد لكل الأرقام'),
                            ],
                          ),
                          if (useNewName[phone] == true) ...[
                            SizedBox(height: 8),
                            TextField(
                              controller: newNameControllers[phone],
                              decoration: InputDecoration(
                                hintText: 'اكتب الاسم الجديد...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  Text('اختر الاسم اللي تحتفظ به:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),

                  ...contacts.map((contact) {
                    bool isSelected = selectedContacts[phone]?.id == contact.id;
                    String phoneNumber = contact.phones.isNotEmpty ? contact.phones.first.number : '';

                    return RadioListTile<Contact>(
                      title: Text(
                        contact.displayName.isNotEmpty ? contact.displayName : 'بدون اسم',
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(phoneNumber),
                      value: contact,
                      groupValue: selectedContacts[phone],
                      onChanged: useNewName[phone] == true
                          ? null
                          : (val) {
                        setState(() {
                          selectedContacts[phone] = val;
                        });
                      },
                      activeColor: Colors.green,
                      selected: isSelected,
                      tileColor: isSelected ? Colors.green.shade50 : null,
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}