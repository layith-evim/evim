import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evim/core/constants/app_constants.dart';
import 'package:evim/core/error/app_exception.dart';
import 'package:evim/core/services/supabase_service.dart';
import 'package:evim/features/gov_guide/domain/models/gov_guide_model.dart';
import 'package:evim/features/gov_guide/domain/models/gov_task_model.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';

abstract class GovGuideRepository {
  Future<List<GovGuideModel>> getGuides();
  Future<List<GovTaskModel>> getTasksForGuide({
    required String guideId,
    required String householdId,
    String? category,
    String? title,
  });
  Future<void> toggleTaskProgress({
    required String householdId,
    required String taskId,
    required bool isCompleted,
  });
  Future<void> convertTaskToDeadline({
    required String householdId,
    required String title,
    required DateTime dueDate,
    String? notes,
  });
}

class SupabaseGovGuideRepository implements GovGuideRepository {
  final SupabaseClient _client;

  SupabaseGovGuideRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  // Fallback procedural guides for instant offline / pre-seeded operation
  static const List<GovGuideModel> _defaultGuides = [
    GovGuideModel(
      id: 'guide-adres',
      title: 'تثبيت النفوس وتسجيل العنوان (Adres Kaydı)',
      category: 'residency',
      description:
          'إجراءات تثبيت السكن في دائرة النفوس التركية واستخراج وثيقة الإقامة الرسمية (Yerleşim Yeri).',
      estimatedDays: '1 - 3 أيام',
      icon: 'home',
    ),
    GovGuideModel(
      id: 'guide-utilities',
      title: 'فتح عدادات الكهرباء والماء والغاز',
      category: 'utilities',
      description:
          'خطوات نقل واشتراك عدادات الخدمات الأساسية (BEDAŞ, İSKİ, İGDAŞ) باسم المستأجر الجديد.',
      estimatedDays: '2 - 4 أيام',
      icon: 'electric_bolt',
    ),
    GovGuideModel(
      id: 'guide-tax',
      title: 'استخراج الرقم الضريبي (Vergi Numarası)',
      category: 'tax',
      description:
          'استخراج الرقم الضريبي المالي لفتح الحسابات البنكية وتوثيق العقود والمعاملات الرسمية.',
      estimatedDays: 'فوري (أونلاين)',
      icon: 'badge',
    ),
    GovGuideModel(
      id: 'guide-tuvturk',
      title: 'فحص المركبات الدوري (TÜVTÜRK)',
      category: 'legal',
      description:
          'دليل حجز وتجهيز فحص السيارة الإلزامي الدوري لتجنب الغرامات وسحب الترخيص.',
      estimatedDays: 'يوم واحد',
      icon: 'directions_car',
    ),
  ];

  static const Map<String, List<GovTaskModel>> _defaultTasksByGuide = {
    'guide-adres': [
      GovTaskModel(
        id: 'task-adres-1',
        guideId: 'guide-adres',
        stepNumber: 1,
        title: 'استخراج وثيقة Numarataj وتصديق عقد الإيجار',
        instructions:
            'توجه إلى بلدية منطقتك (Belediye) للحصول على وثيقة الترقيم العقاري (Numarataj)، ثم قم بتصديق عقد الإيجار لدى كاتب العدل (Noter).',
        requiredDocs: [
          'عقد الإيجار الأصلي',
          'وثيقة Numarataj من البلدية',
          'جواز السفر / بطاقة الإقامة',
        ],
        eDevletLink: null,
      ),
      GovTaskModel(
        id: 'task-adres-2',
        guideId: 'guide-adres',
        stepNumber: 2,
        title: 'حجز موعد في دائرة النفوس (Nüfus Müdürlüğü)',
        instructions:
            'احجز موعداً في مديرية النفوس التابعة لمنطقة سكنك عبر البوابة الإلكترونية أو عبر الاتصال بالرقم 199.',
        requiredDocs: [
          'رسالة تأكيد الموعد على الهاتف',
          'الهوية الشخصية / الإقامة',
        ],
        eDevletLink: 'https://randevu.nvi.gov.tr/',
      ),
      GovTaskModel(
        id: 'task-adres-3',
        guideId: 'guide-adres',
        stepNumber: 3,
        title: 'حضور الموعد واستخراج قيد السكن (Yerleşim Yeri)',
        instructions:
            'احضر بالموعد المحدد مع جميع أفراد العائلة البالغين. بعد التثبيت يمكنك تنزيل قيد السكن فوراً عبر E-Devlet بصيغة PDF.',
        requiredDocs: [
          'عقد الإيجار المصدق',
          'فاتورة مسجلة باسمك (كهرباء أو ماء إن وجدت)',
          'جوازات السفر والإقامات لجميع أفراد الأسرة',
        ],
        eDevletLink: 'https://www.turkiye.gov.tr/nvi-yerlesim-yeri-ve-diger-adres-belgesi-sorgulama',
      ),
    ],
    'guide-utilities': [
      GovTaskModel(
        id: 'task-util-1',
        guideId: 'guide-utilities',
        stepNumber: 1,
        title: 'الحصول على بوليصة تأمين الزلازل (DASK)',
        instructions:
            'اطلب من مالك العقار صورة عن وثيقة تأمين الزلازل السارية (DASK) والرقم التسلسلي للعدادات.',
        requiredDocs: [
          'بوليصة DASK سارية المفعول',
          'أرقام العدادات القديمة (Sayaç / Tesisat No)',
        ],
        eDevletLink: null,
      ),
      GovTaskModel(
        id: 'task-util-2',
        guideId: 'guide-utilities',
        stepNumber: 2,
        title: 'فتح اشتراك الكهرباء (BEDAŞ / Enerjisa)',
        instructions:
            'قدم طلب الاشتراك عبر E-Devlet أو بزيارة مركز خدمة المشتركين ودفع رسوم التأمين المستردة (Güvence Bedeli).',
        requiredDocs: [
          'عقد الإيجار',
          'وثيقة DASK',
          'الهوية الشخصية / الإقامة',
          'رقم المنشأة (Tesisat No)',
        ],
        eDevletLink: 'https://www.turkiye.gov.tr/enerjisa-elektrik-abonelik-basvurusu',
      ),
      GovTaskModel(
        id: 'task-util-3',
        guideId: 'guide-utilities',
        stepNumber: 3,
        title: 'فتح اشتراك المياه (İSKİ / ASAT)',
        instructions:
            'تقديم طلب فتح عداد المياه عبر تطبيق أو موقع İSKİ وسداد رسوم التأمين.',
        requiredDocs: [
          'عقد الإيجار',
          'وثيقة DASK',
          'رقم عداد المياه (Sayaç No)',
        ],
        eDevletLink: 'https://www.turkiye.gov.tr/iski-abonelik-basvurusu',
      ),
      GovTaskModel(
        id: 'task-util-4',
        guideId: 'guide-utilities',
        stepNumber: 4,
        title: 'فتح اشتراك الغاز الطبيعي (İGDAŞ) وحجز موعد الفحص',
        instructions:
            'توقيع عقد الغاز وحجز موعد للفني لفتح العداد وفحص سلامة التمديدات المنزلية.',
        requiredDocs: [
          'عقد الإيجار',
          'وثيقة DASK',
          'رقم العداد (Tesisat No)',
        ],
        eDevletLink: 'https://www.turkiye.gov.tr/igdas-abonelik-basvurusu',
      ),
    ],
    'guide-tax': [
      GovTaskModel(
        id: 'task-tax-1',
        guideId: 'guide-tax',
        stepNumber: 1,
        title: 'الدخول إلى بوابة مصلحة الضرائب الرقمية (İnteraktif Vergi Dairesi)',
        instructions:
            'افتح موقع الضرائب التركي واضغط على خيار (Yabancılar İçin Potansiyel Vergi Kimlik Numarası).',
        requiredDocs: [
          'بيانات جواز السفر بدقة',
          'العنوان داخل تركيا',
          'رقم هاتف تركي فعال',
        ],
        eDevletLink: 'https://dijital.gib.gov.tr/foreigners/potansiyelVergiKimlikNo',
      ),
      GovTaskModel(
        id: 'task-tax-2',
        guideId: 'guide-tax',
        stepNumber: 2,
        title: 'تعبئة البيانات ورفع صورة جواز السفر',
        instructions:
            'أدخل الاسم واللقب واسم الأب والأم كما في الجواز بالأحرف اللاتينية، وأرفق صورة واضحة لصفحة بيانات الجواز.',
        requiredDocs: [
          'صورة واضحة ملونة لصفحة الجواز',
        ],
        eDevletLink: null,
      ),
      GovTaskModel(
        id: 'task-tax-3',
        guideId: 'guide-tax',
        stepNumber: 3,
        title: 'تحميل وثيقة الرقم الضريبي الرسمية (PDF)',
        instructions:
            'فور إرسال الطلب سيظهر لك الرقم الضريبي (10 أرقام). قم بتنزيل ملف PDF واحتفظ به لاستخدامه في البنك والمعاملات.',
        requiredDocs: [
          'ملف PDF للرقم الضريبي',
        ],
        eDevletLink: null,
      ),
    ],
    'guide-tuvturk': [
      GovTaskModel(
        id: 'task-tuv-1',
        guideId: 'guide-tuvturk',
        stepNumber: 1,
        title: 'التأكد من خلو المركبة من المخالفات والتأمين الساري',
        instructions:
            'تحقق عبر E-Devlet من سداد ضريبة المركبات (MTV) وجميع المخالفات المرورية وسريان تأمين المرور الإلزامي.',
        requiredDocs: [
          'رخصة السيارة (Ruhsat)',
          'بوليصة تأمين المرور (Trafik Sigortası)',
        ],
        eDevletLink: 'https://www.turkiye.gov.tr/arac-plaka-sorgulama',
      ),
      GovTaskModel(
        id: 'task-tuv-2',
        guideId: 'guide-tuvturk',
        stepNumber: 2,
        title: 'حجز موعد فحص محطة TÜVTÜRK الرسمي',
        instructions:
            'احجز موعداً في أقرب محطة فحص فني عبر موقع TÜVTÜRK الرسمي مجاناً وتحديد نوع الفحص.',
        requiredDocs: [
          'رقم اللوحة ورقم الرخصة',
        ],
        eDevletLink: 'https://www.tuvturk.com.tr/randevu-kayit.aspx',
      ),
      GovTaskModel(
        id: 'task-tuv-3',
        guideId: 'guide-tuvturk',
        stepNumber: 3,
        title: 'تجهيز حقيبة السلامة والذهاب لمحطة الفحص',
        instructions:
            'تأكد من وجود طفاية حريق صالحة، ومثلثين عاكسين، وحقيبة إسعافات أولية قبل التوجه للمحطة.',
        requiredDocs: [
          'بطاقة الهوية / الإقامة',
          'رخصة المركبة',
          'رسوم الفحص',
        ],
        eDevletLink: null,
      ),
    ],
  };

  static List<GovTaskModel> _findFallbackTasks(
    String guideId, {
    String? category,
    String? title,
  }) {
    if (_defaultTasksByGuide.containsKey(guideId)) {
      return _defaultTasksByGuide[guideId]!;
    }

    final search = '${guideId.toLowerCase()} ${category?.toLowerCase() ?? ''} ${title?.toLowerCase() ?? ''}';
    if (search.contains('adres') ||
        search.contains('nufus') ||
        search.contains('ikamet') ||
        search.contains('residency') ||
        search.contains('نفوس') ||
        search.contains('عنوان') ||
        search.contains('سكن') ||
        search.contains('إقامة')) {
      return _defaultTasksByGuide['guide-adres']!;
    }
    if (search.contains('util') ||
        search.contains('electric') ||
        search.contains('water') ||
        search.contains('gas') ||
        search.contains('كهرباء') ||
        search.contains('ماء') ||
        search.contains('غاز') ||
        search.contains('عداد')) {
      return _defaultTasksByGuide['guide-utilities']!;
    }
    if (search.contains('tax') ||
        search.contains('vergi') ||
        search.contains('ضريب') ||
        search.contains('مالي')) {
      return _defaultTasksByGuide['guide-tax']!;
    }
    if (search.contains('tuv') ||
        search.contains('car') ||
        search.contains('legal') ||
        search.contains('فحص') ||
        search.contains('سيار') ||
        search.contains('مركب')) {
      return _defaultTasksByGuide['guide-tuvturk']!;
    }

    return _defaultTasksByGuide['guide-adres']!;
  }

  @override
  Future<List<GovGuideModel>> getGuides() async {
    try {
      final response = await _client
          .from(AppConstants.tableGovGuides)
          .select()
          .order('title', ascending: true);

      final list = response as List<dynamic>;
      if (list.isEmpty) {
        return _defaultGuides;
      }
      return list
          .map((item) => GovGuideModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback gracefully to default rich guides
      return _defaultGuides;
    }
  }

  @override
  Future<List<GovTaskModel>> getTasksForGuide({
    required String guideId,
    required String householdId,
    String? category,
    String? title,
  }) async {
    List<GovTaskModel> baseTasks = [];

    try {
      final response = await _client
          .from(AppConstants.tableGovTasks)
          .select()
          .eq('guide_id', guideId)
          .order('step_number', ascending: true);

      final list = response as List<dynamic>;
      if (list.isNotEmpty) {
        baseTasks = list
            .map((item) => GovTaskModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // fallback
    }

    if (baseTasks.isEmpty) {
      baseTasks = _findFallbackTasks(guideId, category: category, title: title);
    }

    // Now fetch completed state from household_gov_progress
    final completedTaskIds = <String>{};
    if (householdId.isNotEmpty) {
      try {
        final progressRes = await _client
            .from(AppConstants.tableHouseholdGovProgress)
            .select('task_id, is_completed')
            .eq('household_id', householdId)
            .eq('is_completed', true);

        final pList = progressRes as List<dynamic>;
        for (final item in pList) {
          final tId = item['task_id'] as String?;
          if (tId != null) {
            completedTaskIds.add(tId);
          }
        }
      } catch (_) {
        // ignore progress query errors in offline/dev
      }
    }

    return baseTasks.map((t) {
      final isDone = completedTaskIds.contains(t.id);
      return t.copyWith(isCompleted: isDone);
    }).toList();
  }

  @override
  Future<void> toggleTaskProgress({
    required String householdId,
    required String taskId,
    required bool isCompleted,
  }) async {
    try {
      await _client.from(AppConstants.tableHouseholdGovProgress).upsert(
        {
          'household_id': householdId,
          'task_id': taskId,
          'is_completed': isCompleted,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'household_id,task_id',
      );
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> convertTaskToDeadline({
    required String householdId,
    required String title,
    required DateTime dueDate,
    String? notes,
  }) async {
    try {
      await _client.from(AppConstants.tableCriticalDeadlines).insert({
        'household_id': householdId,
        'title': title.trim(),
        'category': 'residency',
        'due_date': dueDate.toIso8601String().split('T').first,
        'reminder_days_before': 7,
        'notes': notes?.trim() ?? 'تم التحويل من المعاملات الحكومية',
        'is_completed': false,
      });
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

final govGuideRepositoryProvider = Provider<GovGuideRepository>((ref) {
  return SupabaseGovGuideRepository();
});

final govGuidesListProvider = FutureProvider<List<GovGuideModel>>((ref) async {
  final repo = ref.watch(govGuideRepositoryProvider);
  return repo.getGuides();
});

/// Family provider fetching tasks for a specific guide in the active household context
final guideTasksProvider =
    FutureProvider.family<List<GovTaskModel>, String>((ref, guideId) async {
  final repo = ref.watch(govGuideRepositoryProvider);
  final household = ref.watch(currentHouseholdProvider).value;
  final householdId = household?.id ?? '';
  final guidesList = ref.watch(govGuidesListProvider).value;
  final matchedGuide = guidesList?.where((g) => g.id == guideId).firstOrNull;

  return repo.getTasksForGuide(
    guideId: guideId,
    householdId: householdId,
    category: matchedGuide?.category,
    title: matchedGuide?.title,
  );
});
