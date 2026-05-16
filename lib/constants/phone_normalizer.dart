// lib/utils/phone_normalizer.dart
class PhoneNormalizer {

  // تحديد بلد الرقم بناءً على مقدمته
  static String detectCountry(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+20')) return 'EG';
    if (cleaned.startsWith('+966')) return 'SA';
    if (cleaned.startsWith('20') && !cleaned.startsWith('+')) return 'EG';
    if (cleaned.startsWith('966') && !cleaned.startsWith('+')) return 'SA';
    if (cleaned.startsWith('0')) {
      // 012... افتراضياً مصر، 05... السعودية
      if (cleaned.startsWith('05')) return 'SA';
      return 'EG';
    }
    if (cleaned.startsWith('5')) return 'SA';

    return 'EG'; // default
  }

  // توحيد رقم الهاتف بالصيغة الدولية
  static String normalize(String phone, {String? countryCode}) {
    if (phone.isEmpty) return '';

    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    String country = countryCode ?? detectCountry(cleaned);

    // لو الرقم بالفعل يبدأ بـ +، نتحقق إنه صيغته صحيحة
    if (cleaned.startsWith('+')) {
      // تأكد إنه يبدأ بكود دولة صحيح
      if (cleaned.startsWith('+20') || cleaned.startsWith('+966')) {
        return cleaned;
      }
      // لو + بس بدون كود دولة، نحذف ال+ ونعالجه
      cleaned = cleaned.substring(1);
    }

    // معالجة الأرقام حسب البلد
    if (country == 'EG') {
      // مصر: كود الدولة 20
      if (cleaned.startsWith('20')) {
        return '+$cleaned';
      }
      if (cleaned.startsWith('0')) {
        return '+20${cleaned.substring(1)}';
      }
      if (cleaned.length == 10 && RegExp(r'^1[0-9]{9}$').hasMatch(cleaned)) {
        return '+20$cleaned';
      }
      return '+20$cleaned';
    }

    if (country == 'SA') {
      // السعودية: كود الدولة 966
      if (cleaned.startsWith('966')) {
        return '+$cleaned';
      }
      if (cleaned.startsWith('0')) {
        return '+966${cleaned.substring(1)}';
      }
      if (cleaned.startsWith('5')) {
        return '+966$cleaned';
      }
      return '+966$cleaned';
    }

    // لو مش معروف، نفس الرقم
    return cleaned;
  }

  // مقارنة رقمين بعد التوحيد
  static bool areSame(String phone1, String phone2) {
    if (phone1.isEmpty || phone2.isEmpty) return false;
    return normalize(phone1) == normalize(phone2);
  }

  // جلب كود الدولة من الرقم
  static String getCountryCode(String phone) {
    String normalized = normalize(phone);
    if (normalized.startsWith('+20')) return '+20';
    if (normalized.startsWith('+966')) return '+966';
    return '';
  }
}