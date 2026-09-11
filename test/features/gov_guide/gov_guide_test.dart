import 'package:flutter_test/flutter_test.dart';
import 'package:evim/features/gov_guide/domain/models/gov_guide_model.dart';
import 'package:evim/features/gov_guide/domain/models/gov_task_model.dart';
import 'package:evim/features/gov_guide/data/gov_guide_repository.dart';

class FakeGovGuideRepository implements GovGuideRepository {
  final List<GovGuideModel> guides = [
    const GovGuideModel(
      id: 'guide-adres',
      title: 'تثبيت النفوس',
      category: 'residency',
      description: 'دليل تثبيت السكن',
      estimatedDays: '2 أيام',
      icon: 'home',
    ),
    const GovGuideModel(
      id: 'guide-tax',
      title: 'الرقم الضريبي',
      category: 'tax',
      description: 'دليل الرقم الضريبي',
      estimatedDays: 'فوري',
      icon: 'badge',
    ),
  ];

  final Map<String, List<GovTaskModel>> tasks = {
    'guide-adres': [
      const GovTaskModel(
        id: 't-1',
        guideId: 'guide-adres',
        stepNumber: 1,
        title: 'استخراج Numarataj',
        instructions: 'الذهاب للبلدية',
        requiredDocs: ['عقد الإيجار', 'جواز السفر'],
      ),
      const GovTaskModel(
        id: 't-2',
        guideId: 'guide-adres',
        stepNumber: 2,
        title: 'حجز موعد النفوس',
        instructions: 'الدخول للبوابة',
        requiredDocs: ['كود الموعد'],
        eDevletLink: 'https://randevu.nvi.gov.tr/',
      ),
    ],
  };

  final Set<String> completedTaskIds = {};
  final List<Map<String, dynamic>> createdDeadlines = [];

  @override
  Future<List<GovGuideModel>> getGuides() async => guides;

  @override
  Future<List<GovTaskModel>> getTasksForGuide({
    required String guideId,
    required String householdId,
    String? category,
    String? title,
  }) async {
    final list = tasks[guideId] ?? [];
    return list.map((t) {
      return t.copyWith(isCompleted: completedTaskIds.contains(t.id));
    }).toList();
  }

  @override
  Future<void> toggleTaskProgress({
    required String householdId,
    required String taskId,
    required bool isCompleted,
  }) async {
    if (isCompleted) {
      completedTaskIds.add(taskId);
    } else {
      completedTaskIds.remove(taskId);
    }
  }

  @override
  Future<void> convertTaskToDeadline({
    required String householdId,
    required String title,
    required DateTime dueDate,
    String? notes,
  }) async {
    createdDeadlines.add({
      'household_id': householdId,
      'title': title,
      'due_date': dueDate,
      'notes': notes,
    });
  }
}

void main() {
  group('GovGuideModel Tests', () {
    test('fromJson & toMap serialization', () {
      final json = {
        'id': 'guide-test',
        'title': 'دليل اختبار',
        'category': 'residency',
        'description': 'وصف للاختبار',
        'estimated_days': '3 أيام',
        'icon': 'home',
      };

      final guide = GovGuideModel.fromJson(json);
      expect(guide.id, 'guide-test');
      expect(guide.title, 'دليل اختبار');
      expect(guide.category, 'residency');
      expect(guide.estimatedDays, '3 أيام');
      expect(guide.icon, 'home');

      final map = guide.toMap();
      expect(map['id'], 'guide-test');
      expect(map['title'], 'دليل اختبار');
      expect(map['estimated_days'], '3 أيام');
    });

    test('copyWith updates fields cleanly', () {
      const guide = GovGuideModel(
        id: 'g-1',
        title: 'قديم',
        category: 'tax',
        description: 'وصف',
        icon: 'badge',
      );

      final updated = guide.copyWith(title: 'جديد', estimatedDays: '5 أيام');
      expect(updated.title, 'جديد');
      expect(updated.id, 'g-1');
      expect(updated.estimatedDays, '5 أيام');
    });
  });

  group('GovTaskModel Tests', () {
    test('fromJson parses List and String required docs correctly', () {
      final jsonWithList = {
        'id': 't-1',
        'guide_id': 'g-1',
        'step_number': 1,
        'title': 'خطوة 1',
        'instructions': 'تعليمات',
        'required_docs': ['عقد إيجار', 'هوية'],
        'e_devlet_link': 'https://turkiye.gov.tr',
      };

      final task1 = GovTaskModel.fromJson(jsonWithList, isCompleted: true);
      expect(task1.stepNumber, 1);
      expect(task1.requiredDocs.length, 2);
      expect(task1.eDevletLink, 'https://turkiye.gov.tr');
      expect(task1.isCompleted, isTrue);

      final jsonWithStringDocs = {
        'id': 't-2',
        'guide_id': 'g-1',
        'step_number': 2,
        'title': 'خطوة 2',
        'instructions': 'تعليمات',
        'required_docs': 'جواز سفر, تأمين DASK',
      };

      final task2 = GovTaskModel.fromJson(jsonWithStringDocs);
      expect(task2.requiredDocs, ['جواز سفر', 'تأمين DASK']);
      expect(task2.isCompleted, isFalse);
    });

    test('Progress calculation logic for guide tasks', () {
      final tasks = [
        const GovTaskModel(
          id: '1',
          guideId: 'g',
          stepNumber: 1,
          title: 'A',
          instructions: '',
          requiredDocs: [],
          isCompleted: true,
        ),
        const GovTaskModel(
          id: '2',
          guideId: 'g',
          stepNumber: 2,
          title: 'B',
          instructions: '',
          requiredDocs: [],
          isCompleted: false,
        ),
      ];

      final completed = tasks.where((t) => t.isCompleted).length;
      final total = tasks.length;
      final percent = completed / total;

      expect(completed, 1);
      expect(total, 2);
      expect(percent, 0.5);
    });
  });

  group('GovGuideRepository Fake Flow Tests', () {
    test('Fetching tasks and toggling progress in household context', () async {
      final repo = FakeGovGuideRepository();

      final guides = await repo.getGuides();
      expect(guides.length, 2);

      final initialTasks = await repo.getTasksForGuide(
        guideId: 'guide-adres',
        householdId: 'house-123',
      );
      expect(initialTasks.length, 2);
      expect(initialTasks[0].isCompleted, isFalse);
      expect(initialTasks[1].isCompleted, isFalse);

      // Toggle first task to completed
      await repo.toggleTaskProgress(
        householdId: 'house-123',
        taskId: 't-1',
        isCompleted: true,
      );

      final updatedTasks = await repo.getTasksForGuide(
        guideId: 'guide-adres',
        householdId: 'house-123',
      );
      expect(updatedTasks[0].isCompleted, isTrue);
      expect(updatedTasks[1].isCompleted, isFalse);
    });

    test('Converting task to critical deadline', () async {
      final repo = FakeGovGuideRepository();
      final targetDate = DateTime(2026, 10, 15);

      await repo.convertTaskToDeadline(
        householdId: 'house-123',
        title: 'موعد تثبيت النفوس',
        dueDate: targetDate,
        notes: 'حضور مبكر',
      );

      expect(repo.createdDeadlines.length, 1);
      expect(repo.createdDeadlines.first['title'], 'موعد تثبيت النفوس');
      expect(repo.createdDeadlines.first['due_date'], targetDate);
    });
  });

  group('Category Filter Mapping Tests', () {
    bool matchesCategory(String? guideCategory, String filterKey) {
      if (filterKey == 'all') return true;
      if (guideCategory == null || guideCategory.isEmpty) return false;
      final cat = guideCategory.toLowerCase().trim();
      switch (filterKey) {
        case 'residency':
          return cat == 'nufus' || cat == 'ikamet' || cat == 'residency';
        case 'utilities':
          return cat == 'utilities';
        case 'tax':
          return cat == 'tax';
        case 'legal':
          return cat == 'legal' || cat == 'tuvturk';
        default:
          return cat == filterKey;
      }
    }

    test('All filter matches every category', () {
      expect(matchesCategory('nufus', 'all'), isTrue);
      expect(matchesCategory('utilities', 'all'), isTrue);
      expect(matchesCategory('tax', 'all'), isTrue);
      expect(matchesCategory('tuvturk', 'all'), isTrue);
    });

    test('Residency matches nufus, ikamet, and residency', () {
      expect(matchesCategory('nufus', 'residency'), isTrue);
      expect(matchesCategory('ikamet', 'residency'), isTrue);
      expect(matchesCategory('residency', 'residency'), isTrue);
      expect(matchesCategory('utilities', 'residency'), isFalse);
    });

    test('Utilities matches utilities', () {
      expect(matchesCategory('utilities', 'utilities'), isTrue);
      expect(matchesCategory('tax', 'utilities'), isFalse);
    });

    test('Tax matches tax', () {
      expect(matchesCategory('tax', 'tax'), isTrue);
      expect(matchesCategory('legal', 'tax'), isFalse);
    });

    test('Legal matches legal and tuvturk', () {
      expect(matchesCategory('legal', 'legal'), isTrue);
      expect(matchesCategory('tuvturk', 'legal'), isTrue);
      expect(matchesCategory('tax', 'legal'), isFalse);
    });
  });

  group('Smart Search Matching Tests', () {
    bool matchesSearch(GovGuideModel guide, String query) {
      if (query.isEmpty) return true;
      final q = query.toLowerCase().trim();
      return guide.title.toLowerCase().contains(q) ||
          guide.description.toLowerCase().contains(q) ||
          guide.category.toLowerCase().contains(q);
    }

    const testGuide = GovGuideModel(
      id: 'guide-adres',
      title: 'تثبيت النفوس وتسجيل العنوان (Adres Kaydı)',
      category: 'residency',
      description:
          'إجراءات تثبيت السكن في دائرة النفوس التركية واستخراج وثيقة الإقامة الرسمية (Yerleşim Yeri).',
      icon: 'home',
    );

    test('Matches Arabic keywords in title and description', () {
      expect(matchesSearch(testGuide, 'نفوس'), isTrue);
      expect(matchesSearch(testGuide, 'عنوان'), isTrue);
      expect(matchesSearch(testGuide, 'إقامة'), isTrue);
      expect(matchesSearch(testGuide, 'سكن'), isTrue);
    });

    test('Matches Latin / Turkish terms case-insensitively', () {
      expect(matchesSearch(testGuide, 'Adres'), isTrue);
      expect(matchesSearch(testGuide, 'adres'), isTrue);
      expect(matchesSearch(testGuide, 'kaydı'), isTrue);
      expect(matchesSearch(testGuide, 'yerleşim'), isTrue);
    });

    test('Returns false for non-matching queries', () {
      expect(matchesSearch(testGuide, 'كهرباء'), isFalse);
      expect(matchesSearch(testGuide, 'tuvturk'), isFalse);
    });
  });
}
