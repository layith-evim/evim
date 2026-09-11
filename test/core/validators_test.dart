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

    group('Password Validation (Min 8, 1 uppercase, 1 digit)', () {
      test('valid strong password returns null', () {
        expect(Validators.validatePassword('Evim2026!'), isNull);
        expect(Validators.validatePassword('Password123'), isNull);
      });

      test('password lacking length returns error', () {
        expect(Validators.validatePassword('Pass1'), isNotNull);
      });

      test('password lacking uppercase returns error', () {
        expect(Validators.validatePassword('evimistanbul1'), isNotNull);
      });

      test('password lacking digit returns error', () {
        expect(Validators.validatePassword('EvimIstanbulNoDigit'), isNotNull);
      });
    });

    group('Invite Code Validation (6 uppercase alphanumeric)', () {
      test('valid invite code returns null', () {
        expect(Validators.validateInviteCode('A1B2C3'), isNull);
        expect(Validators.validateInviteCode('EVIM01'), isNull);
      });

      test('invalid invite code returns error', () {
        expect(Validators.validateInviteCode(''), isNotNull);
        expect(Validators.validateInviteCode('12345'), isNotNull); // 5 chars
        expect(Validators.validateInviteCode('1234567'), isNotNull); // 7 chars
        expect(Validators.validateInviteCode('evim01'), isNotNull); // lowercase
        expect(Validators.validateInviteCode('EVIM!1'), isNotNull); // special char
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
        expect(Validators.validateTurkishPhone('02121234567'), isNotNull); // landline
        expect(Validators.validateTurkishPhone('+1 555 123 4567'), isNotNull); // US number
      });
    });
  });
}
