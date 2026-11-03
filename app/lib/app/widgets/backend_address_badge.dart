import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

class BackendAddressBadge extends StatelessWidget {
  const BackendAddressBadge({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 220.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppThemeColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns_rounded,
              size: 16.sp,
              color: AppThemeColors.textSecondary,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppThemeColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
