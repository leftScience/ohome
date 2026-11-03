import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

class UnderDevelopmentPage extends StatelessWidget {
  const UnderDevelopmentPage({
    super.key,
    required this.title,
    this.icon = Icons.construction_rounded,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标容器，带渐变发光
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    const Color(0xFF448AFF).withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 44.w,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppThemeColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
