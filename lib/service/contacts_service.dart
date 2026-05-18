// lib/service/contacts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../constants/phone_normalizer.dart';

class ContactsManager {
  static Future<List<Map<String, String>>> getAllContacts() async {
    debugPrint('📱 [ContactsManager.getAllContacts] بدء جلب الجهات');

    if (!await FlutterContacts.requestPermission(readonly: true)) {
      debugPrint('❌ [ContactsManager.getAllContacts] مفيش إذن');
      throw Exception('مفيش إذن للوصول لجهات الاتصال');
    }

    List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    debugPrint(
      '📱 [ContactsManager.getAllContacts] تم جلب ${contacts.length} جهة اتصال',
    );

    List<Map<String, String>> formattedContacts = [];
    Set<String> uniqueNumbers = {};

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String number = PhoneNormalizer.normalize(phone.number);

        if (number.length >= 9 && !uniqueNumbers.contains(number)) {
          uniqueNumbers.add(number);

          String contactName = _displayNameFor(contact);

          formattedContacts.add({
            'phone_number': number,
            'contact_name': contactName,
          });
        }
      }
    }

    debugPrint(
      '📱 [ContactsManager.getAllContacts] تم تنسيق ${formattedContacts.length} رقم فريد',
    );
    return formattedContacts;
  }

  static Future<Map<String, List<Contact>>> findDuplicateContacts() async {
    debugPrint(
      '🔍 [ContactsManager.findDuplicateContacts] بدء البحث عن المكررات',
    );

    if (!await FlutterContacts.requestPermission(readonly: true)) {
      debugPrint('❌ [ContactsManager.findDuplicateContacts] مفيش إذن');
      throw Exception('مفيش إذن للوصول لجهات الاتصال');
    }

    List<Contact> allContacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    debugPrint(
      '🔍 [ContactsManager.findDuplicateContacts] تم جلب ${allContacts.length} جهة اتصال',
    );

    Map<String, List<Contact>> phoneToContacts = {};

    for (var contact in allContacts) {
      for (var phone in contact.phones) {
        String cleanNumber = PhoneNormalizer.normalize(phone.number);

        phoneToContacts.putIfAbsent(cleanNumber, () => []);

        bool alreadyExists = phoneToContacts[cleanNumber]!.any(
          (c) => c.id == contact.id,
        );
        if (!alreadyExists) {
          phoneToContacts[cleanNumber]!.add(contact);
        }
      }
    }

    Map<String, List<Contact>> duplicates = {};
    phoneToContacts.forEach((phone, contacts) {
      if (contacts.length > 1) {
        duplicates[phone] = contacts;
      }
    });

    debugPrint(
      '🔍 [ContactsManager.findDuplicateContacts] تم العثور على ${duplicates.length} رقم مكرر',
    );
    return duplicates;
  }

  static Future<void> mergeDuplicates({
    required String phoneNumber,
    required Contact keepThisContact,
    List<Contact>? deleteTheseContacts,
    String? newName,
  }) async {
    debugPrint(
      '🔧 [ContactsManager.mergeDuplicates] بدء دمج الرقم $phoneNumber',
    );
    debugPrint('   - الاحتفاظ بـ: ${keepThisContact.displayName}');
    debugPrint('   - عدد المحذوفات: ${deleteTheseContacts?.length ?? 0}');

    if (!await FlutterContacts.requestPermission()) {
      debugPrint('❌ [ContactsManager.mergeDuplicates] مفيش إذن للتعديل');
      throw Exception('مفيش إذن لتعديل جهات الاتصال');
    }

    if (newName != null && newName.isNotEmpty) {
      debugPrint('   - تغيير الاسم إلى: $newName');
      keepThisContact.displayName = newName;
      keepThisContact.name.first = newName;
      keepThisContact.name.middle = '';
      keepThisContact.name.last = '';
      await keepThisContact.update();
    }

    List<Contact> toDelete = deleteTheseContacts ?? [];
    for (var contact in toDelete) {
      if (contact.id != keepThisContact.id) {
        debugPrint('   - حذف: ${contact.displayName}');
        await contact.delete();
      }
    }

    debugPrint(
      '✅ [ContactsManager.mergeDuplicates] تم دمج الرقم $phoneNumber بنجاح',
    );
  }

  static String _displayNameFor(Contact contact) {
    final displayName = contact.displayName.trim();
    if (displayName.isNotEmpty) return displayName;

    final structuredName = [
      contact.name.first,
      contact.name.middle,
      contact.name.last,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();

    if (structuredName.isNotEmpty) return structuredName;

    final nickname = contact.name.nickname.trim();
    if (nickname.isNotEmpty) return nickname;

    return 'بدون اسم';
  }
}
