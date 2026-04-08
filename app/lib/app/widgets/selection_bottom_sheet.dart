import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

String quarkApplicationLabel(String application) {
  switch (application.trim().toLowerCase()) {
    case 'playlet':
      return '短剧';
    case 'music':
      return '播客';
    case 'read':
      return '阅读';
    case 'tv':
      return '影视';
    default:
      return application.trim();
  }
}

IconData quarkApplicationIcon(String application) {
  switch (application.trim().toLowerCase()) {
    case 'playlet':
      return Icons.movie_filter_rounded;
    case 'music':
      return Icons.podcasts_rounded;
    case 'read':
      return Icons.menu_book_rounded;
    case 'tv':
    default:
      return Icons.live_tv_rounded;
  }
}

Color quarkApplicationAccent(String application) {
  switch (application.trim().toLowerCase()) {
    case 'playlet':
      return const Color(0xFFFB7185);
    case 'music':
      return const Color(0xFF22C55E);
    case 'read':
      return const Color(0xFF14B8A6);
    case 'tv':
    default:
      return const Color(0xFF8B5CF6);
  }
}

class SelectionBottomSheetMeta {
  const SelectionBottomSheetMeta({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;
}

class SelectionBottomSheetOption<T> {
  const SelectionBottomSheetOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.statusText,
    this.enabled = true,
  });

  final T value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String statusText;
  final bool enabled;
}

Future<T?> showSelectionBottomSheet<T>({
  required BuildContext context,
  required List<SelectionBottomSheetOption<T>> options,
  required SelectionBottomSheetMeta meta,
  required String helperText,
  required String emptyTitle,
  required String emptyDescription,
  IconData emptyIcon = Icons.folder_off_rounded,
  Color emptyAccent = const Color(0xFFF59E0B),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) {
      return Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SelectionBottomSheet<T>(
            options: options,
            meta: meta,
            helperText: helperText,
            emptyTitle: emptyTitle,
            emptyDescription: emptyDescription,
            emptyIcon: emptyIcon,
            emptyAccent: emptyAccent,
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: curve,
          child: child,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 36.h * (1 - curve.value)),
              child: child,
            );
          },
        ),
      );
    },
  );
}

class SelectionBottomSheet<T> extends StatelessWidget {
  const SelectionBottomSheet({
    super.key,
    required this.options,
    required this.meta,
    required this.helperText,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
    required this.emptyAccent,
  });

  final List<SelectionBottomSheetOption<T>> options;
  final SelectionBottomSheetMeta meta;
  final String helperText;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;
  final Color emptyAccent;

  @override
  Widget build(BuildContext context) {
    final availableCount = options.where((option) => option.enabled).length;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = math.min(screenHeight * 0.78, 620.h);

    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  _buildMetaChip(
                    icon: meta.icon,
                    label: meta.label,
                    accent: meta.accent,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      helperText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Expanded(
                child: availableCount == 0
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < options.length;
                            index++
                          ) ...[
                            if (index > 0) SizedBox(height: 10.h),
                            _buildOptionTile(context, options[index]),
                          ],
                          const Spacer(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14.w),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: emptyAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Icon(emptyIcon, color: emptyAccent, size: 26.w),
            ),
            SizedBox(height: 14.h),
            Text(
              emptyTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              emptyDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    SelectionBottomSheetOption<T> option,
  ) {
    final onPointerDown = option.enabled
        ? (PointerDownEvent _) => Navigator.of(context).pop(option.value)
        : null;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: option.enabled
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: option.enabled
                  ? option.accent.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: onPointerDown,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: option.enabled
                          ? option.accent.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      option.icon,
                      color: option.enabled ? option.accent : Colors.white38,
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.title,
                                style: TextStyle(
                                  color: option.enabled
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 5.h,
                              ),
                              decoration: BoxDecoration(
                                color: option.enabled
                                    ? option.accent.withValues(alpha: 0.14)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Text(
                                option.statusText,
                                style: TextStyle(
                                  color: option.enabled
                                      ? option.accent
                                      : Colors.white38,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 9.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                option.enabled
                                    ? Icons.drive_folder_upload_rounded
                                    : Icons.block_rounded,
                                color: option.enabled
                                    ? Colors.white70
                                    : Colors.white30,
                                size: 16.w,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  option.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: option.enabled
                                        ? Colors.white70
                                        : Colors.white30,
                                    fontSize: 11.sp,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Icon(
                    option.enabled
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.remove_rounded,
                    color: option.enabled ? Colors.white38 : Colors.white24,
                    size: option.enabled ? 16.w : 20.w,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
