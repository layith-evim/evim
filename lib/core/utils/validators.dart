/// Core input validators for Evim adhering to dual-layer validation standards.
class Validators {
  Validators._();

  // RFC 5322 compliant email regex pattern
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  // Invite code: exactly 6 uppercase alphanumeric characters
  static final RegExp _inviteCodeRegex = RegExp(r'^[A-Z0-9]{6}$');

  // Turkish mobile phone regex: supports '+90 5XX XXX XX XX', '+905XXXXXXXXX', '05XXXXXXXXX', or '5XXXXXXXXX'
  static final RegExp _turkishMobileRegex = RegExp(
    r'^(?:\+90\s?|0)?5[0-9]{2}[\s\-]?[0-9]{3}[\s\-]?[0-9]{2}[\s\-]?[0-9]{2}$',
  );

  /// Validates email format according to RFC 5322.
  static String? validateEmail(String? value, {String locale = 'ar'}) {
    if (value == null || value.trim().isEmpty) {
      return locale == 'tr' ? 'E-posta adresi boş bırakılamaz.' : 'البريد الإلكتروني مطلوب.';
    }
    final trimmed = value.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return locale == 'tr'
          ? 'Geçerli bir e-posta adresi giriniz.'
          : 'يرجى إدخال بريد إلكتروني صالح.';
    }
    return null;
  }

  /// Validates password: min 8 characters, at least 1 uppercase letter, 1 numeric digit.
  static String? validatePassword(String? value, {String locale = 'ar'}) {
    if (value == null || value.isEmpty) {
      return locale == 'tr' ? 'Şifre boş bırakılamaz.' : 'كلمة المرور مطلوبة.';
    }
    if (value.length < 8) {
      return locale == 'tr'
          ? 'Şifre en az 8 karakter olmalıdır.'
          : 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return locale == 'tr'
          ? 'Şifre en az bir büyük harf içermelidir.'
          : 'يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return locale == 'tr'
          ? 'Şifre en az bir rakam içermelidir.'
          : 'يجب أن تحتوي كلمة المرور على رقم واحد على الأقل.';
    }
    return null;
  }

  /// Validates 6-character uppercase alphanumeric household invite code.
  static String? validateInviteCode(String? value, {String locale = 'ar'}) {
    if (value == null || value.trim().isEmpty) {
      return locale == 'tr' ? 'Davet kodu gereklidir.' : 'رمز الدعوة مطلوب.';
    }
    final trimmed = value.trim();
    if (!_inviteCodeRegex.hasMatch(trimmed)) {
      return locale == 'tr'
          ? 'Davet kodu tam olarak 6 haneli büyük harf veya rakam olmalıdır.'
          : 'رمز الدعوة يجب أن يتكون من 6 خانات (أحرف إنجليزية كبيرة أو أرقام).';
    }
    return null;
  }

  /// Validates positive monetary amount.
  static String? validatePositiveAmount(String? value, {String locale = 'ar'}) {
    if (value == null || value.trim().isEmpty) {
      return locale == 'tr' ? 'Tutar boş bırakılamaz.' : 'المبلغ مطلوب.';
    }
    final cleaned = value.trim().replaceAll(',', '.');
    final amount = double.tryParse(cleaned);
    if (amount == null || amount <= 0) {
      return locale == 'tr'
          ? 'Geçerli ve pozitif bir tutar giriniz (₺).'
          : 'يرجى إدخال مبلغ صحيح وموجب بالليرة التركية.';
    }
    return null;
  }

  /// Validates Turkish mobile telephone number.
  static String? validateTurkishPhone(String? value, {String locale = 'ar'}) {
    if (value == null || value.trim().isEmpty) {
      return locale == 'tr' ? 'Telefon numarası gereklidir.' : 'رقم الهاتف مطلوب.';
    }
    final cleaned = value.trim();
    if (!_turkishMobileRegex.hasMatch(cleaned)) {
      return locale == 'tr'
          ? 'Geçerli bir Türkiye cep telefonu numarası giriniz (+90 5XX XXX XX XX).'
          : 'يرجى إدخال رقم هاتف تركي صحيح (+90 5XX XXX XX XX).';
    }
    return null;
  }

  /// Normalizes invite code to uppercase trimmed string.
  static String normalizeInviteCode(String code) {
    return code.trim().toUpperCase();
  }

  /// Checks if a string is a valid positive number.
  static bool isValidAmount(String value) {
    final cleaned = value.trim().replaceAll(',', '.');
    final num? parsed = num.tryParse(cleaned);
    return parsed != null && parsed > 0;
  }
}
