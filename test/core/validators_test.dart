import 'package:flutter_test/flutter_test.dart';
import 'package:evim/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests', () {
    group('Email Validation (RFC 5322)', () {
      test('valid email returns null', () {
        expect(Validators.validateEmail('user@domain.com'), isNull);
        expect(Validators.validateEmail('family.member+exp@sub.domain.org'), isNull);
      });

      test('invalid email returns error message', () {
        expect(Validators.validateEmail(''), isNotNull);
        expect(Validators.validateEmail('plainaddress'), isNotNull);
        expect(Validators.validateEmail('missing@dot'), isNotNull);
        expect(Validators.validateEmail('@missinguser.com'), isNotNull);
      });
    });

    group('Strict Password Validation (Min 8, 1 uppercase A-Z)', () {
      test('valid strong password returns null', () {
        expect(Validators.validatePassword('Evim2026!'), isNull);
        expect(Validators.validatePassword('Password123'), isNull);
        expect(Validators.validatePassword('LongSecretPassword'), isNull);
      });

      test('password lacking length (< 8) returns error', () {
        expect(Validators.validatePassword('Pass1'), isNotNull);
        expect(
          Validators.validatePassword('Pass1'),
          'يجب أن تتكون كلمة المرور من 8 خانات على الأقل وتحتوي على حرف كبير واحد على الأقل (A-Z).',
        );
      });

      test('password lacking uppercase returns error', () {
        expect(Validators.validatePassword('12345678'), isNotNull);
        expect(Validators.validatePassword('evimistanbul1'), isNotNull);
        expect(
          Validators.validatePassword('12345678'),
          'يجب أن تتكون كلمة المرور من 8 خانات على الأقل وتحتوي على حرف كبير واحد على الأقل (A-Z).',
        );
      });
    });

    group('Password Confirmation Match Validation', () {
      test('matching passwords return null', () {
        expect(
          Validators.validateConfirmPassword('MyPassword123', 'MyPassword123'),
          isNull,
        );
      });

      test('mismatched passwords return error', () {
        expect(
          Validators.validateConfirmPassword('WrongPass', 'MyPassword123'),
          'كلمتا المرور غير متطابقتين.',
        );
      });

      test('empty confirmation returns error', () {
        expect(
          Validators.validateConfirmPassword('', 'MyPassword123'),
          'يرجى تأكيد كلمة المرور.',
        );
      });
    });

    group('Age Validation (12 to 100)', () {
      test('valid age within range returns null', () {
        expect(Validators.validateAge('26'), isNull);
        expect(Validators.validateAge('12'), isNull);
        expect(Validators.validateAge('100'), isNull);
      });

      test('age out of range or invalid returns error', () {
        expect(Validators.validateAge('11'), isNotNull);
        expect(Validators.validateAge('105'), isNotNull);
        expect(Validators.validateAge(''), isNotNull);
        expect(Validators.validateAge('abc'), isNotNull);
      });
    });

    group('Required Field Validation', () {
      test('non-empty value returns null', () {
        expect(Validators.validateRequired('محمد', 'الاسم الأول'), isNull);
      });

      test('empty value returns error with field name', () {
        expect(Validators.validateRequired('', 'الاسم الأول'), 'الاسم الأول مطلوب.');
        expect(Validators.validateRequired('   ', 'الكنية'), 'الكنية مطلوب.');
      });
    });

    group('Invite Code Validation (6 uppercase alphanumeric)', () {
      test('valid invite code returns null', () {
        expect(Validators.validateInviteCode('A1B2C3'), isNull);
        expect(Validators.validateInviteCode('EVIM01'), isNull);
      });

      test('invalid invite code returns error', () {
        expect(Validators.validateInviteCode(''), isNotNull);
        expect(Validators.validateInviteCode('12345'), isNotNull);
        expect(Validators.validateInviteCode('1234567'), isNotNull);
        expect(Validators.validateInviteCode('evim01'), isNotNull);
        expect(Validators.validateInviteCode('EVIM!1'), isNotNull);
      });
    });

    group('Positive Financial Amount Validation', () {
      test('valid positive amount returns null', () {
        expect(Validators.validatePositiveAmount('1500'), isNull);
        expect(Validators.validatePositiveAmount('250.75'), isNull);
        expect(Validators.validatePositiveAmount('350,50'), isNull);
      });

      test('zero, negative or non-numeric returns error', () {
        expect(Validators.validatePositiveAmount('0'), isNotNull);
        expect(Validators.validatePositiveAmount('-150'), isNotNull);
        expect(Validators.validatePositiveAmount('abc'), isNotNull);
        expect(Validators.validatePositiveAmount(''), isNotNull);
      });
    });

    group('Turkish Mobile Phone Validation', () {
      test('valid Turkish mobile numbers return null', () {
        expect(Validators.validateTurkishPhone('+90 532 123 45 67'), isNull);
        expect(Validators.validateTurkishPhone('+905321234567'), isNull);
        expect(Validators.validateTurkishPhone('05321234567'), isNull);
        expect(Validators.validateTurkishPhone('5321234567'), isNull);
      });

      test('invalid phone numbers return error', () {
        expect(Validators.validateTurkishPhone(''), isNotNull);
        expect(Validators.validateTurkishPhone('02121234567'), isNotNull);
        expect(Validators.validateTurkishPhone('+1 555 123 4567'), isNotNull);
      });
    });
  });
}
