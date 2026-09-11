import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supported locales for error messaging
enum AppLanguage { ar, tr }

/// Unified domain failure class for the Evim application
class AppException implements Exception {
  final String messageAr;
  final String messageTr;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.messageAr,
    required this.messageTr,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  /// Returns user-facing message based on the specified language code ('ar' or 'tr')
  String localizedMessage([String lang = 'ar']) {
    return lang.toLowerCase() == 'tr' ? messageTr : messageAr;
  }

  @override
  String toString() => 'AppException(code: $code, messageAr: $messageAr, messageTr: $messageTr)';

  /// Factory mapper from Supabase AuthException
  factory AppException.fromAuth(AuthException error, [StackTrace? stackTrace]) {
    final msg = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('invalid_grant') ||
        code.contains('invalid_credentials') ||
        code.contains('invalid_grant') ||
        error.statusCode == '400') {
      return AppException(
        code: 'AUTH_INVALID_CREDENTIALS',
        messageAr: 'هذا الحساب غير مسجل أو تم حذفه مسبقاً. يرجى التأكد من البيانات أو إنشاء حساب جديد.',
        messageTr: 'Bu hesap kayıtlı değil veya silinmiş. Lütfen bilgilerinizi kontrol edin veya yeni bir hesap oluşturun.',
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (msg.contains('user already registered') || msg.contains('user_already_exists')) {
      return AppException(
        code: 'AUTH_USER_EXISTS',
        messageAr: 'هذا البريد الإلكتروني مسجل بالفعل. يرجى تسجيل الدخول أو استعادة كلمة المرور.',
        messageTr: 'Bu e-posta adresi zaten kayıtlı. Lütfen giriş yapın veya şifrenizi sıfırlayın.',
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (msg.contains('email not confirmed')) {
      return AppException(
        code: 'AUTH_EMAIL_UNCONFIRMED',
        messageAr: 'يرجى تأكيد بريدك الإلكتروني أولاً قبل المتابعة.',
        messageTr: 'Lütfen devam etmeden önce e-posta adresinizi onaylayınız.',
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (msg.contains('password') && (msg.contains('weak') || msg.contains('short'))) {
      return AppException(
        code: 'AUTH_WEAK_PASSWORD',
        messageAr: 'كلمة المرور ضعيفة جداً. يجب أن تحتوي على 8 أحرف على الأقل مع حرف كبير ورقم.',
        messageTr: 'Şifre çok zayıf. En az 8 karakter, bir büyük harf ve bir rakam içermelidir.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      code: error.statusCode ?? 'AUTH_GENERIC_ERROR',
      messageAr: 'حدث خطأ أثناء المصادقة. يرجى المحاولة مرة أخرى.',
      messageTr: 'Kimlik doğrulama sırasında bir hata oluştu. Lütfen tekrar deneyin.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Factory mapper from Supabase PostgrestException (RLS, constraints, etc.)
  factory AppException.fromPostgrest(PostgrestException error, [StackTrace? stackTrace]) {
    final code = error.code ?? '';
    final details = error.details?.toString().toLowerCase() ?? '';
    final message = error.message.toLowerCase();

    // RLS or permission denied
    if (code == '42501' || message.contains('row-level security') || message.contains('permission denied')) {
      return AppException(
        code: 'DB_FORBIDDEN',
        messageAr: 'ليس لديك الصلاحية للوصول إلى بيانات هذه العائلة أو تعديلها.',
        messageTr: 'Bu hanenin verilerine erişim veya düzenleme yetkiniz yok.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Unique constraint violation (e.g. duplicate invite code, duplicate member)
    if (code == '23505') {
      if (details.contains('invite_code') || message.contains('invite_code')) {
        return AppException(
          code: 'DB_DUPLICATE_INVITE_CODE',
          messageAr: 'رمز الدعوة موجود بالفعل، جاري إنشاء رمز بديل...',
          messageTr: 'Davet kodu zaten mevcut, yeni bir kod oluşturuluyor...',
          originalError: error,
          stackTrace: stackTrace,
        );
      }
      return AppException(
        code: 'DB_DUPLICATE_RECORD',
        messageAr: 'هذا السجل مسجل بالفعل في النظام.',
        messageTr: 'Bu kayıt sistemde zaten mevcut.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Foreign key violation
    if (code == '23503') {
      return AppException(
        code: 'DB_RELATION_NOT_FOUND',
        messageAr: 'العنصر المطلوب أو العائلة المحددة غير موجودة.',
        messageTr: 'İstenen kayıt veya hane bulunamadı.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Record not found
    if (code == 'PGRST116') {
      return AppException(
        code: 'NOT_FOUND',
        messageAr: 'لم يتم العثور على البيانات المطلوبة.',
        messageTr: 'İstenen bilgi bulunamadı.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      code: code.isNotEmpty ? code : 'DB_GENERIC_ERROR',
      messageAr: 'تعذر إتمام العملية في قاعدة البيانات. يرجى المحاولة لاحقاً.',
      messageTr: 'Veritabanı işlemi gerçekleştirilemedi. Lütfen daha sonra tekrar deneyin.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Factory mapper for network/connection errors
  factory AppException.fromNetwork(dynamic error, [StackTrace? stackTrace]) {
    return AppException(
      code: 'NETWORK_ERROR',
      messageAr: 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',
      messageTr: 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// General catch-all error mapper
  factory AppException.fromGeneric(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;
    if (error is AuthException) return AppException.fromAuth(error, stackTrace);
    if (error is PostgrestException) return AppException.fromPostgrest(error, stackTrace);
    if (error is SocketException) return AppException.fromNetwork(error, stackTrace);

    return AppException(
      code: 'UNKNOWN_ERROR',
      messageAr: 'حدث خطأ غير متوقع. يرجى إعادة المحاولة.',
      messageTr: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Convenience alias for mapping Supabase exceptions
  factory AppException.fromSupabase(dynamic error, [StackTrace? stackTrace]) {
    return AppException.fromGeneric(error, stackTrace);
  }
}
