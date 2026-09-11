import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/gov_guide/data/gov_guide_repository.dart';
import 'package:evim/features/gov_guide/domain/models/gov_guide_model.dart';
import 'package:evim/features/gov_guide/domain/models/gov_task_model.dart';
import 'package:evim/features/gov_guide/presentation/screens/gov_guide_detail_screen.dart';

class GovGuidesScreen extends ConsumerStatefulWidget {
  const GovGuidesScreen({super.key});

  @override
  ConsumerState<GovGuidesScreen> createState() => _GovGuidesScreenState();
}

class _GovGuidesScreenState extends ConsumerState<GovGuidesScreen> {
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;

  final List<({String key, String label, IconData icon})> _categories = const [
    (key: 'all', label: 'الكل', icon: Icons.apps_rounded),
    (key: 'residency', label: 'الإقامة والنفوس', icon: Icons.home_work_rounded),
    (key: 'utilities', label: 'الخدمات والعدادات', icon: Icons.bolt_rounded),
    (key: 'tax', label: 'الضرائب والمالية', icon: Icons.account_balance_wallet_rounded),
    (key: 'legal', label: 'القانون والسيارات', icon: Icons.directions_car_rounded),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesCategory(String? guideCategory, String filterKey) {
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

  bool _matchesSearch(GovGuideModel guide, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    return guide.title.toLowerCase().contains(q) ||
        guide.description.toLowerCase().contains(q) ||
        guide.category.toLowerCase().contains(q);
  }

  IconData _getIconForGuide(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.location_city_rounded;
      case 'electric_bolt':
        return Icons.bolt_rounded;
      case 'badge':
        return Icons.badge_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Color _getColorForCategory(String category) {
    final cat = category.toLowerCase().trim();
    if (cat == 'residency' || cat == 'nufus' || cat == 'ikamet') {
      return AppColors.primaryLight;
    } else if (cat == 'utilities') {
      return AppColors.turquoise;
    } else if (cat == 'tax') {
      return AppColors.warmAmber;
    } else if (cat == 'legal' || cat == 'tuvturk') {
      return AppColors.terracotta;
    }
    return AppColors.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    final guidesAsync = ref.watch(govGuidesListProvider);
    final household = ref.watch(currentHouseholdProvider).value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.account_balance_rounded, color: AppColors.primaryDark),
              SizedBox(width: 8),
              Text(
                'دليل المعاملات الحكومية',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: AppColors.primaryDark,
              ),
              tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكي',
              onPressed: () {
                setState(() => _isGridView = !_isGridView);
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث الدليل',
              onPressed: () {
                ref.invalidate(govGuidesListProvider);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Smart Search Field
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث عن معاملة، وثيقة، أو جهة حكومية...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                  ),
                ),
              ),
            ),

            // Category Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat.key;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.label,
                              style: TextStyle(
                                color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.primary,
                        checkmarkColor: AppColors.onPrimary,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryDark : AppColors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat.key;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Guides List / Grid Content
            Expanded(
              child: guidesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'تعذر تحميل المعاملات: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(govGuidesListProvider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (guides) {
                  final filteredGuides = guides
                      .where((g) => _matchesCategory(g.category, _selectedCategory))
                      .where((g) => _matchesSearch(g, _searchQuery))
                      .toList();

                  if (filteredGuides.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 54,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty
                                   ? 'لم يتم العثور على نتائج تطابق: "$_searchQuery"'
                                  : 'لا توجد أدلة في هذا التصنيف حالياً',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedCategory = 'all';
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة ضبط البحث'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: filteredGuides.length,
                      itemBuilder: (context, index) {
                        final guide = filteredGuides[index];
                        final categoryColor = _getColorForCategory(guide.category);
                        final iconData = _getIconForGuide(guide.icon);

                        return _GovGuideGridCard(
                          guide: guide,
                          color: categoryColor,
                          icon: iconData,
                          householdId: household?.id ?? '',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => GovGuideDetailScreen(guide: guide),
                              ),
                            );
                            ref.invalidate(guideTasksProvider(guide.id));
                          },
                        );
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredGuides.length,
                    itemBuilder: (context, index) {
                      final guide = filteredGuides[index];
                      final categoryColor = _getColorForCategory(guide.category);
                      final iconData = _getIconForGuide(guide.icon);

                      return _GovGuideCard(
                        guide: guide,
                        color: categoryColor,
                        icon: iconData,
                        householdId: household?.id ?? '',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GovGuideDetailScreen(guide: guide),
                            ),
                          );
                          // Refresh tasks progress after returning
                          ref.invalidate(guideTasksProvider(guide.id));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GovGuideGridCard extends ConsumerWidget {
  final GovGuideModel guide;
  final Color color;
  final IconData icon;
  final String householdId;
  final VoidCallback onTap;

  const _GovGuideGridCard({
    required this.guide,
    required this.color,
    required this.icon,
    required this.householdId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(guideTasksProvider(guide.id));

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Icon & Duration Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (guide.estimatedDays != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            guide.estimatedDays!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                guide.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const Spacer(),

              // Mini Progress Bar
              tasksAsync.when<Widget>(
                loading: () => const LinearProgressIndicator(minHeight: 3),
                error: (_, __) => const SizedBox.shrink(),
                data: (List<GovTaskModel> tasks) {
                  if (tasks.isEmpty) return const SizedBox.shrink();
                  final completedCount = tasks.where((t) => t.isCompleted).length;
                  final totalCount = tasks.length;
                  final double percent = totalCount > 0 ? (completedCount / totalCount) : 0.0;
                  final isAllDone = completedCount == totalCount && totalCount > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedCount/$totalCount منجز',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? AppColors.accent : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(percent * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? AppColors.accent : color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 4,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAllDone ? AppColors.accent : color,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GovGuideCard extends ConsumerWidget {
  final GovGuideModel guide;
  final Color color;
  final IconData icon;
  final String householdId;
  final VoidCallback onTap;

  const _GovGuideCard({
    required this.guide,
    required this.color,
    required this.icon,
    required this.householdId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(guideTasksProvider(guide.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (guide.estimatedDays != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                guide.estimatedDays!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                guide.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Progress Indicator
              tasksAsync.when<Widget>(
                loading: () => const LinearProgressIndicator(minHeight: 4),
                error: (_, __) => const SizedBox.shrink(),
                data: (List<GovTaskModel> tasks) {
                  if (tasks.isEmpty) return const SizedBox.shrink();
                  final completedCount = tasks.where((t) => t.isCompleted).length;
                  final totalCount = tasks.length;
                  final double percent = totalCount > 0 ? (completedCount / totalCount) : 0.0;
                  final isAllDone = completedCount == totalCount && totalCount > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAllDone
                                ? '🎉 تم إنجاز جميع الخطوات'
                                : '$completedCount من $totalCount خطوات منجزة',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? AppColors.accent : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(percent * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? AppColors.accent : color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAllDone ? AppColors.accent : color,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
