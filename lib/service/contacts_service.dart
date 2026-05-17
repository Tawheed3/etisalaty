// lib/services/contacts_service.dart
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/phone_normalizer.dart';

class ContactsManager {
  
  static Future<List<Map<String, String>>> getAllContacts() async {
    print('📱 [ContactsManager.getAllContacts] بدء جلب الجهات');
    
    PermissionStatus status = await Permission.contacts.request();
    if (status != PermissionStatus.granted) {
      print('❌ [ContactsManager.getAllContacts] مفيش إذن');
      throw Exception('مفيش إذن للوصول لجهات الاتصال');
    }
    
    Iterable<Contact> contacts = await ContactsService.getContacts();
    
    print('📱 [ContactsManager.getAllContacts] تم جلب ${contacts.length} جهة اتصال');
    
    List<Map<String, String>> formattedContacts = [];
    Set<String> uniqueNumbers = {};
    
    for (var contact in contacts) {
      for (var phone in contact.phones ?? []) {
        if (phone.value != null && phone.value!.isNotEmpty) {
          String number = PhoneNormalizer.normalize(phone.value!);
          
          if (number.length >= 9 && !uniqueNumbers.contains(number)) {
            uniqueNumbers.add(number);
            
            String contactName = contact.displayName ?? 'بدون اسم';
            if (contactName.trim().isEmpty) {
              contactName = 'بدون اسم';
            }
            
            formattedContacts.add({
              'phone_number': number,
              'contact_name': contactName,
            });
          }
        }
      }
    }
    
    print('📱 [ContactsManager.getAllContacts] تم تنسيق ${formattedContacts.length} رقم فريد');
    return formattedContacts;
  }
  
  static Future<Map<String, List<Contact>>> findDuplicateContacts() async {
    print('🔍 [ContactsManager.findDuplicateContacts] بدء البحث عن المكررات');
    
    PermissionStatus status = await Permission.contacts.request();
    if (status != PermissionStatus.granted) {
      print('❌ [ContactsManager.findDuplicateContacts] مفيش إذن');
      throw Exception('مفيش إذن للوصول لجهات الاتصال');
    }
    
    Iterable<Contact> allContacts = await ContactsService.getContacts();
    
    print('🔍 [ContactsManager.findDuplicateContacts] تم جلب ${allContacts.length} جهة اتصال');
    
    Map<String, List<Contact>> phoneToContacts = {};
    
    for (var contact in allContacts) {
      for (var phone in contact.phones ?? []) {
        if (phone.value != null && phone.value!.isNotEmpty) {
          String cleanNumber = PhoneNormalizer.normalize(phone.value!);
          
          phoneToContacts.putIfAbsent(cleanNumber, () => []);
          
          bool alreadyExists = phoneToContacts[cleanNumber]!.any((c) => c.identifier == contact.identifier);
          if (!alreadyExists) {
            phoneToContacts[cleanNumber]!.add(contact);
          }
        }
      }
    }
    
    Map<String, List<Contact>> duplicates = {};
    phoneToContacts.forEach((phone, contacts) {
      if (contacts.length > 1) {
        duplicates[phone] = contacts;
      }
    });
    
    print('🔍 [ContactsManager.findDuplicateContacts] تم العثور على ${duplicates.length} رقم مكرر');
    return duplicates;
  }
  
  static Future<void> mergeDuplicates({
    required String phoneNumber,
    required Contact keepThisContact,
    List<Contact>? deleteTheseContacts,
    String? newName,
  }) async {
    print('🔧 [ContactsManager.mergeDuplicates] بدء دمج الرقم $phoneNumber');
    print('   - الاحتفاظ بـ: ${keepThisContact.displayName}');
    print('   - عدد المحذوفات: ${deleteTheseContacts?.length ?? 0}');
    
    PermissionStatus status = await Permission.contacts.request();
    if (status != PermissionStatus.granted) {
      print('❌ [ContactsManager.mergeDuplicates] مفيش إذن للتعديل');
      throw Exception('مفيش إذن لتعديل جهات الاتصال');
    }
    
    if (newName != null && newName.isNotEmpty) {
      print('   - تغيير الاسم إلى: $newName');
      keepThisContact.displayName = newName;
      await ContactsService.updateContact(keepThisContact);
    }
    
    List<Contact> toDelete = deleteTheseContacts ?? [];
    for (var contact in toDelete) {
      if (contact.identifier != keepThisContact.identifier) {
        print('   - حذف: ${contact.displayName}');
        await ContactsService.deleteContact(contact);
      }
    }
    
    print('✅ [ContactsManager.mergeDuplicates] تم دمج الرقم $phoneNumber بنجاح');
  }
}