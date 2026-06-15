class SaudiPhoneNumber {
  // matches any (ANYTHING - system) suffix — covers ZM, ZMK, UNOWNED, etc.
  static final RegExp _ownershipSystemSuffix = RegExp(
    r'\s*\([^)]*-\s*system\s*\)\s*$',
    caseSensitive: false,
  );

  static final RegExp _historicalSystemSuffix = RegExp(
    r'\s*-\s*system\s*$',
    caseSensitive: false,
  );

  // handles: Ahmed(system) / Ahmed (system) / Ahmed ( system )
  static final RegExp _simpleSystemSuffix = RegExp(
    r'\s*\(\s*system\s*\)\s*$',
    caseSensitive: false,
  );

  static const Map<String, String> _localizedDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  /// Returns a Saudi mobile number as +9665XXXXXXXX, or null when invalid.
  static String? canonicalize(String input) {
    var ascii = input;
    _localizedDigits.forEach((digit, replacement) {
      ascii = ascii.replaceAll(digit, replacement);
    });

    var digits = ascii.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00966')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('966')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (!RegExp(r'^5\d{8}$').hasMatch(digits)) {
      return null;
    }

    return '+966$digits';
  }

  static bool isSystemContactName(String name) {
    final trimmed = name.trim();
    return _ownershipSystemSuffix.hasMatch(trimmed) ||
        _historicalSystemSuffix.hasMatch(trimmed) ||
        _simpleSystemSuffix.hasMatch(trimmed);
  }

  /// Removes any recognized system suffix: (ZM - system), - system, (system).
  static String? removeOwnershipSystemSuffix(String name) {
    var renamed = name.trim();
    var removed = false;

    while (_ownershipSystemSuffix.hasMatch(renamed)) {
      renamed = renamed.replaceFirst(_ownershipSystemSuffix, '').trim();
      removed = true;
    }

    while (_simpleSystemSuffix.hasMatch(renamed)) {
      renamed = renamed.replaceFirst(_simpleSystemSuffix, '').trim();
      removed = true;
    }

    while (_historicalSystemSuffix.hasMatch(renamed)) {
      renamed = renamed.replaceFirst(_historicalSystemSuffix, '').trim();
      removed = true;
    }

    if (!removed || renamed.isEmpty) {
      return null;
    }

    return renamed;
  }
}
