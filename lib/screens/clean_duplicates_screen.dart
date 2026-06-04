// lib/screens/clean_duplicates_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../service/contacts_service.dart';

class CleanDuplicatesScreen extends StatefulWidget {
  const CleanDuplicatesScreen({super.key});

  @override
  State<CleanDuplicatesScreen> createState() => _CleanDuplicatesScreenState();
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
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    setState(() => isLoading = true);
    try {
      duplicates = await ContactsManager.findDuplicateContacts();
      if (duplicates != null && duplicates!.isNotEmpty) {
        for (var entry in duplicates!.entries) {
          selectedContacts[entry.key] = entry.value.first;
          newNameControllers[entry.key] = TextEditingController();
          useNewName[entry.key] = false;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في قراءة الجهات: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> _applyClean() async {
    if (duplicates == null || duplicates!.isEmpty) return;

    showDialog(context: context, barrierDismissible: false, builder: (context) => Center(child: CircularProgressIndicator()));

    try {
      int mergedCount = 0;
      for (var entry in duplicates!.entries) {
        String phone = entry.key;
        List<Contact> contacts = entry.value;
        Contact? selected = selectedContacts[phone];
        if (selected != null) {
          List<Contact> toDelete = contacts.where((c) => c.id != selected.id).toList();
          String? newName = (useNewName[phone] == true && newNameControllers[phone]!.text.isNotEmpty)
              ? newNameControllers[phone]!.text
              : null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تنظيف $mergedCount رقم مكرر بنجاح'), backgroundColor: Colors.green),
      );
      await _loadDuplicates();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in newNameControllers.values) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تنظيف جهات الاتصال'),
        backgroundColor: Colors.orange,
        actions: [
          if (duplicates != null && duplicates!.isNotEmpty)
            IconButton(icon: Icon(Icons.check, color: Colors.white), onPressed: _applyClean, tooltip: 'تطبيق التغييرات'),
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
          return Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(child: Text(phone, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                          child: Text('${contacts.length} مرات', style: TextStyle(color: Colors.white)),
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
                                    if (!useNewName[phone]!) newNameControllers[phone]!.clear();
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
                    String displayName = contact.displayName.isNotEmpty ? contact.displayName : 'بدون اسم';
                    return RadioListTile<Contact>(
                      title: Text(displayName, style: TextStyle(fontSize: 16)),
                      subtitle: Text(phoneNumber),
                      value: contact,
                      groupValue: selectedContacts[phone],
                      onChanged: useNewName[phone] == true ? null : (val) => setState(() => selectedContacts[phone] = val),
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