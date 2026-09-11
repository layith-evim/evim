import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';

enum AuthMode { signIn, signUp }

/// Main authentication screen supporting Sign In and Sign Up with dual-mode toggle
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shared Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Registration Profile Controllers
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();

  // Registration State Values
  String? _selectedCity = 'إسطنبول';
  String? _selectedNationality = 'سوري';
  String _selectedGender = 'ذكر';

  AuthMode _authMode = AuthMode.signIn;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const List<String> _turkishCities = [
    'إسطنبول',
    'أنقرة',
    'إزمير',
    'بورصة',
    'أنطاليا',
    'غازي عنتاب',
    'قونيا',
    'مرسين',
    'أخرى',
  ];

  static const List<String> _nationalities = [
    'سوري',
    'عراقي',
    'يمني',
    'مصري',
    'فلسطيني',
    'أردني',
    'مغربي',
    'لبناني',
    'سوداني',
    'تركي',
    'أخرى',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final controller = ref.read(authControllerProvider.notifier);

    if (_authMode == AuthMode.signIn) {
      await controller.signIn(email: email, password: password);
    } else {
      final rawPhone = _phoneController.text.trim();
      final formattedPhone = rawPhone.isNotEmpty
          ? (rawPhone.startsWith('+90')
              ? rawPhone
              : '+90 ${rawPhone.replaceAll(RegExp(r'^[+0\s]+'), '')}')
          : null;

      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'full_name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'phone': formattedPhone,
        'city': _selectedCity,
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'nationality': _selectedNationality,
        'gender': _selectedGender,
      };

      final success = await controller.signUp(
        email: email,
        password: password,
        data: data,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.oliveGreen,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'تم إنشاء الحساب بنجاح! إذا تطلب تأكيد البريد يرجى مراجعة صندوق الوارد.',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Roboto', fontSize: 14),
            ),
          ),
        );
      }
    }
  }

  void _switchAuthMode(AuthMode mode) {
    if (_authMode != mode) {
      setState(() {
        _authMode = mode;
      });
      _formKey.currentState?.reset();
    }
  }

  Widget _buildFieldLabel(String label, {bool isRequired = true}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Listen for errors to display localized Arabic error notifications
    ref.listen<AsyncValue<void>>(authControllerProvider, (_, next) {
      if (next.hasError) {
        final appException = AppException.fromGeneric(next.error);
        final errorMessage = appException.localizedMessage('ar');
        final isInvalidCreds = appException.code == 'AUTH_INVALID_CREDENTIALS' ||
            errorMessage.contains('غير مسجل') ||
            errorMessage.contains('تم حذفه');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.terracotta,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: (_authMode == AuthMode.signIn && isInvalidCreds)
                ? SnackBarAction(
                    label: 'إنشاء حساب جديد',
                    textColor: Colors.white,
                    onPressed: () => _switchAuthMode(AuthMode.signUp),
                  )
                : null,
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon and Header
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            size: 38,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'مرحباً بك في إيفيم — Evim',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'منصة إدارة شؤون الأسرة والمقيمين في تركيا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Segmented Mode Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModeTab(
                                title: 'تسجيل الدخول',
                                isSelected: _authMode == AuthMode.signIn,
                                onTap: () => _switchAuthMode(AuthMode.signIn),
                              ),
                            ),
                            Expanded(
                              child: _ModeTab(
                                title: 'حساب جديد',
                                isSelected: _authMode == AuthMode.signUp,
                                onTap: () => _switchAuthMode(AuthMode.signUp),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SIGN UP SPECIFIC PROFILE FIELDS ---
                      if (_authMode == AuthMode.signUp) ...[
                        // 1. First Name & Last Name (Row / 2 columns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('الاسم الأول'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _firstNameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'مثال: محمد',
                                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                    ),
                                    validator: (val) => Validators.validateRequired(val, 'الاسم الأول', locale: 'ar'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('الكنية / العائلة'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _lastNameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'مثال: الحلبي',
                                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                    ),
                                    validator: (val) => Validators.validateRequired(val, 'الكنية', locale: 'ar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field (Both Modes)
                      _buildFieldLabel('البريد الإلكتروني'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          hintTextDirection: TextDirection.ltr,
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (value) => Validators.validateEmail(value, locale: 'ar'),
                      ),
                      const SizedBox(height: 16),

                      // --- SIGN UP SPECIFIC: Phone, City, Age, Nationality, Gender ---
                      if (_authMode == AuthMode.signUp) ...[
                        // 3. Phone Number
                        _buildFieldLabel('رقم الهاتف'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: '5XX XXX XX XX',
                            hintTextDirection: TextDirection.ltr,
                            prefixText: '+90 ',
                            prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'رقم الهاتف مطلوب.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 4. City & Age (Row / 2 columns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('المدينة في تركيا'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCity,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                                    ),
                                    items: _turkishCities
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c, style: const TextStyle(fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedCity = val),
                                    validator: (v) => v == null ? 'يرجى اختيار المدينة' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('العمر'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'مثال: 26',
                                      prefixIcon: Icon(Icons.cake_outlined, size: 20),
                                    ),
                                    validator: (value) => Validators.validateAge(value, locale: 'ar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. Nationality & Gender (Row / 2 columns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('الجنسية'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedNationality,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.public_rounded, size: 20),
                                    ),
                                    items: _nationalities
                                        .map((n) => DropdownMenuItem(
                                              value: n,
                                              child: Text(n, style: const TextStyle(fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedNationality = val),
                                    validator: (v) => v == null ? 'يرجى اختيار الجنسية' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('الجنس'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedGender,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.wc_rounded, size: 20),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'ذكر', child: Text('ذكر', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'أنثى', child: Text('أنثى', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (val) => setState(() => _selectedGender = val ?? 'ذكر'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Password Field (Both Modes)
                      _buildFieldLabel('كلمة المرور'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        textInputAction: _authMode == AuthMode.signUp ? TextInputAction.next : TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintTextDirection: TextDirection.ltr,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) => Validators.validatePassword(value, locale: 'ar'),
                      ),

                      // Confirm Password (Sign Up Mode Only)
                      if (_authMode == AuthMode.signUp) ...[
                        const SizedBox(height: 16),
                        _buildFieldLabel('تأكيد كلمة المرور'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintTextDirection: TextDirection.ltr,
                            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) => Validators.validateConfirmPassword(
                            value,
                            _passwordController.text,
                            locale: 'ar',
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _authMode == AuthMode.signIn ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      // Inline Error Banner when Sign In fails
                      if (_authMode == AuthMode.signIn && authState.hasError) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppException.fromGeneric(authState.error).localizedMessage('ar'),
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _switchAuthMode(AuthMode.signUp),
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                label: const Text(
                                  'إنشاء حساب جديد',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Hint footer
                      Text(
                        _authMode == AuthMode.signIn
                            ? 'إيفيم يساعدك على ربط مشترياتك وفواتيرك ومواعيدك القانونية مع عائلتك'
                            : 'بإنشاء حساب، ستتمكن من إنشاء منزلك ومشاركة الرمز مع أفراد أسرتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
