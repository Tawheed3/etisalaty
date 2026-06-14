import 'package:etisalaty/utils/saudi_phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaudiPhoneNumber.canonicalize', () {
    const canonical = '+966512345678';

    for (final input in const [
      '+966512345678',
      '00966512345678',
      '966512345678',
      '0512345678',
      '512345678',
      '+966 51 234 5678',
      '00966-51-234-5678',
      '(+966) 51 234 5678',
      '٠٠٩٦٦٥١٢٣٤٥٦٧٨',
      '+۹۶۶۵۱۲۳۴۵۶۷۸',
    ]) {
      test('normalizes $input', () {
        expect(SaudiPhoneNumber.canonicalize(input), canonical);
      });
    }

    for (final input in const [
      '',
      '+201012345678',
      '01012345678',
      '+966112345678',
      '+96651234567',
      '+9665123456789',
      '12345',
    ]) {
      test('rejects $input', () {
        expect(SaudiPhoneNumber.canonicalize(input), isNull);
      });
    }
  });

  group('SaudiPhoneNumber.isSystemContactName', () {
    test('accepts current and historical system suffixes', () {
      expect(
        SaudiPhoneNumber.isSystemContactName('Customer (Z - system)'),
        isTrue,
      );
      expect(
        SaudiPhoneNumber.isSystemContactName('Customer - SYSTEM'),
        isTrue,
      );
    });

    test('does not match system in the middle of a normal name', () {
      expect(
        SaudiPhoneNumber.isSystemContactName('System Support Customer'),
        isFalse,
      );
    });
  });

  group('SaudiPhoneNumber.removeOwnershipSystemSuffix', () {
    for (final marker in const ['Z', 'M', 'K', 'ZM', 'ZK', 'MK', 'ZMK']) {
      test('removes $marker ownership suffix', () {
        expect(
          SaudiPhoneNumber.removeOwnershipSystemSuffix(
            'Ahmed ( $marker - system )',
          ),
          'Ahmed',
        );
      });
    }

    test('is case-insensitive', () {
      expect(
        SaudiPhoneNumber.removeOwnershipSystemSuffix('Ahmed (zm - SYSTEM)'),
        'Ahmed',
      );
    });

    test('removes repeated ownership suffixes', () {
      expect(
        SaudiPhoneNumber.removeOwnershipSystemSuffix(
          'Ahmed (ZM - system) (M - system)',
        ),
        'Ahmed',
      );
    });

    test('does not change unrelated names', () {
      expect(
        SaudiPhoneNumber.removeOwnershipSystemSuffix('System Support'),
        isNull,
      );
      expect(
        SaudiPhoneNumber.removeOwnershipSystemSuffix(
          'Ahmed (UNKNOWN - system)',
        ),
        isNull,
      );
      expect(
        SaudiPhoneNumber.removeOwnershipSystemSuffix('Ahmed - system'),
        isNull,
      );
    });
  });
}
