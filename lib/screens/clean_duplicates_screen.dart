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

  // contact IDs selected for DELETION — nothing pre-selected
  Map<String, Set<String>> selectedForDeletion = {};

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    setState(() => isLoading = true);
    try {
      duplicates = await ContactsManager.findDuplicateContacts();
      if (duplicates != null) {
        for (var key in duplicates!.keys) {
          selectedForDeletion[key] = {};
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في قراءة الجهات: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => isLoading = false);
  }

  int get totalSelected =>
      selectedForDeletion.values.fold(0, (sum, set) => sum + set.length);

  Future<void> _applyClean() async {
    if (totalSelected == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار على الأقل جهة واحدة للحذف'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هتحذف $totalSelected جهة اتصال. مش هيتراجع. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      int deletedCount = 0;
      for (var entry in selectedForDeletion.entries) {
        String phone = entry.key;
        Set<String> idsToDelete = entry.value;
        if (idsToDelete.isEmpty) continue;

        List<Contact> allContacts = duplicates![phone]!;
        List<Contact> toDelete = allContacts.where((c) => idsToDelete.contains(c.id)).toList();

        for (var contact in toDelete) {
          await FlutterContacts.deleteContact(contact);
          deletedCount++;
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حذف $deletedCount جهة اتصال بنجاح'), backgroundColor: Colors.green),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظيف جهات الاتصال'),
        backgroundColor: Colors.orange,
        actions: [
          if (totalSelected > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: _applyClean,
                icon: const Icon(Icons.delete, color: Colors.white),
                label: Text(
                  'حذف ($totalSelected)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : duplicates == null || duplicates!.isEmpty
              ? const Center(
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
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Colors.orange.shade50,
                      child: Text(
                        '${duplicates!.length} رقم مكرر — اختار اللي تحذفه',
                        style: const TextStyle(fontSize: 14, color: Colors.orange),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: duplicates!.length,
                        itemBuilder: (context, index) {
                          String phone = duplicates!.keys.elementAt(index);
                          List<Contact> contacts = duplicates![phone]!;
                          Set<String> selectedIds = selectedForDeletion[phone]!;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            phone,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${contacts.length} مرات',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'ضع علامة على اللي تحذفه:',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  ...contacts.map((contact) {
                                    bool isChecked = selectedIds.contains(contact.id);
                                    String displayName = contact.displayName.isNotEmpty
                                        ? contact.displayName
                                        : 'بدون اسم';
                                    String phoneNumber = contact.phones.isNotEmpty
                                        ? contact.phones.first.number
                                        : '';
                                    return CheckboxListTile(
                                      title: Text(displayName),
                                      subtitle: Text(phoneNumber),
                                      value: isChecked,
                                      activeColor: Colors.red,
                                      checkColor: Colors.white,
                                      tileColor: isChecked ? Colors.red.shade50 : null,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            selectedIds.add(contact.id);
                                          } else {
                                            selectedIds.remove(contact.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
