import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Compact Badge Widget displaying 'PRO' or 'Evim Pro' for premium households
class ProBadge extends StatelessWidget {
  final bool isLarge;
  const ProBadge({super.key, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 10 : 7,
        vertical: isLarge ? 4 : 2,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.warmAmber,
            Color(0xFFF1C40F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmAmber.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: isLarge ? 14 : 11,
            color: const Color(0xFF451A03),
          ),
          const SizedBox(width: 3),
          Text(
            isLarge ? 'Evim Pro' : 'PRO',
            style: TextStyle(
              fontSize: isLarge ? 11 : 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: const Color(0xFF451A03),
            ),
          ),
        ],
      ),
    );
  }
}
