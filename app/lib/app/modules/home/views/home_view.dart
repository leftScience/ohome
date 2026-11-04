import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/main_tab_content_insets.dart';
import '../controllers/home_controller.dart';
import '../widgets/home_recommend_section.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return _HomeBody(controller: controller);
  }
}

/// 首页采用「头部信息 + 搜索 + 快捷入口 + 推荐面板」结构，
/// 推荐列表向上滚动时自动收起顶部区域，为内容让出空间。
class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.controller});

  final HomeController controller;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  static const double _collapseRange = 96;

  /// 0 = 展开，1 = 收起顶部区域。
  double _progress = 0;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <= 0 && _progress > 0) {
      setState(() => _progress = 0);
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    final delta = notification.scrollDelta;
    if (delta == null || delta == 0) return false;

    final next = (_progress + delta / _collapseRange).clamp(0.0, 1.0);
    if ((next - _progress).abs() < 0.002) return false;
    setState(() => _progress = next);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MainTabContentInsets.bottom(
      context,
      withHistoryBanner: true,
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final t = disableAnimations
        ? (_progress >= 0.5 ? 1.0 : 0.0)
        : Curves.easeOutCubic.transform(_progress);
    final topPad = lerpDouble(12.h, 4.h, t)!;
    final sectionGap = lerpDouble(12.h, 0, t)!;
    final chromeOpacity = (1 - t * 1.15).clamp(0.0, 1.0);
    final chromeFactor = (1 - t).clamp(0.0, 1.0);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: _buildHeader(t: t),
                ),
                ClipRect(
                  clipBehavior: chromeFactor >= 0.999
                      ? Clip.none
                      : Clip.hardEdge,
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: chromeFactor,
                    child: Opacity(
                      opacity: chromeOpacity,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: sectionGap <= 0 ? 0 : sectionGap),
                            _buildSearchBar(),
                            SizedBox(height: sectionGap <= 0 ? 0 : sectionGap),
                            _buildResourceMenu(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomInset),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: const HomeRecommendSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required double t}) {
    final titleSize = lerpDouble(22.sp, 17.5.sp, t)!;

    return Obx(() {
      final displayName = widget.controller.name.trim().isEmpty
          ? '欢迎回来'
          : widget.controller.name.trim();

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppThemeColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          _buildMessageButton(t: t),
        ],
      );
    });
  }

  Widget _buildMessageButton({required double t}) {
    return Obx(() {
      final unreadCount = widget.controller.unreadMessageCount;
      final size = lerpDouble(42.w, 36.w, t)!;
      final iconSize = lerpDouble(21.w, 19.w, t)!;
      final radius = BorderRadius.circular(14.r);

      return Semantics(
        button: true,
        label: unreadCount > 0 ? '通知消息，$unreadCount条未读' : '通知消息',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: AppThemeColors.shadowSoft.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Material(
                  color: AppThemeColors.surface,
                  borderRadius: radius,
                  child: InkWell(
                    onTap: widget.controller.openMessages,
                    borderRadius: radius,
                    child: Ink(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: AppThemeColors.border),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: AppThemeColors.textPrimary,
                          size: iconSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -3.w,
                top: -3.h,
                child: Container(
                  constraints: BoxConstraints(minWidth: 17.w, minHeight: 17.h),
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                    ),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: AppThemeColors.surface,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildSearchBar() {
    final radius = BorderRadius.circular(16.r);
    return Semantics(
      button: true,
      label: '搜索影视、短剧、播客和阅读资源',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppThemeColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: AppThemeColors.surface,
            child: InkWell(
              onTap: () => Get.toNamed(Routes.SEARCH),
              borderRadius: radius,
              child: Ink(
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: AppThemeColors.border, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: AppThemeColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(11.r),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppThemeColors.primary,
                        size: 19.w,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        '搜索资源',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppThemeColors.textMuted,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 一行四个快捷入口 ───

  Widget _buildResourceMenu() {
    final entries = [
      _ResourceEntry(
        icon: Icons.movie_filter_rounded,
        label: '影视',
        gradientColors: const [Color(0xFFEAF2FF), Color(0xFFD8E7FF)],
        iconColor: const Color(0xFF186EEF),
        onTap: () => Get.toNamed(Routes.TV),
      ),
      _ResourceEntry(
        icon: Icons.live_tv_rounded,
        label: '短剧',
        gradientColors: const [Color(0xFFFFF4E5), Color(0xFFFFE6C2)],
        iconColor: const Color(0xFFE66A00),
        onTap: () => Get.toNamed(Routes.PLAYLET),
      ),
      _ResourceEntry(
        icon: Icons.podcasts_rounded,
        label: '播客',
        gradientColors: const [Color(0xFFFFEDF1), Color(0xFFFFDAE3)],
        iconColor: const Color(0xFFE11D48),
        onTap: () => Get.toNamed(Routes.MUSIC),
      ),
      _ResourceEntry(
        icon: Icons.menu_book_rounded,
        label: '阅读',
        gradientColors: const [Color(0xFFE7F8F2), Color(0xFFD0F0E4)],
        iconColor: const Color(0xFF0D9488),
        onTap: () => Get.toNamed(Routes.READ),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppThemeColors.border, width: 1),
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries
            .map((entry) => Expanded(child: _buildResourceItem(entry)))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildResourceItem(_ResourceEntry entry) {
    return Semantics(
      button: true,
      label: '进入${entry.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: entry.onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: entry.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: entry.iconColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(entry.icon, color: entry.iconColor, size: 22.w),
                ),
                SizedBox(height: 6.h),
                Text(
                  entry.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourceEntry {
  const _ResourceEntry({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color iconColor;
  final VoidCallback? onTap;
}
