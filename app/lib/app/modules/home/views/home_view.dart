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

  /// 根据当前时段返回问候语
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了 🌙';
    if (hour < 12) return '早上好 ☀️';
    if (hour < 14) return '中午好 🌤️';
    if (hour < 18) return '下午好 ⛅';
    return '晚上好 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return _HomeBody(greeting: _greeting, controller: controller);
  }
}

/// 首页采用「头部信息 + 搜索 + 快捷入口 + 推荐面板」结构，
/// 推荐列表向上滚动时自动收起顶部区域，为内容让出空间。
class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.greeting, required this.controller});

  final String greeting;
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
    final bottomInset = MainTabContentInsets.bottom(context);
    final t = Curves.easeOutCubic.transform(_progress);
    final topPad = lerpDouble(16.h, 4.h, t)!;
    final headerGap = lerpDouble(14.h, 0, t)!;
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
                            SizedBox(height: headerGap <= 0 ? 0 : headerGap),
                            _buildSearchBar(),
                            SizedBox(height: headerGap <= 0 ? 0 : headerGap),
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
              padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, bottomInset),
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
    final titleSize = lerpDouble(23.sp, 18.sp, t)!;
    final greetingFactor = (1 - t * 1.35).clamp(0.0, 1.0);

    return Obx(() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: greetingFactor,
                    child: Opacity(
                      opacity: greetingFactor,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 3.h),
                        child: Text(
                          widget.greeting,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppThemeColors.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  widget.controller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    height: 1.25,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary,
                    letterSpacing: 0.5,
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
      final size = lerpDouble(46.w, 38.w, t)!;
      final iconSize = lerpDouble(23.w, 20.w, t)!;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Material(
              color: AppThemeColors.surface,
              borderRadius: BorderRadius.circular(18.r),
              child: InkWell(
                onTap: widget.controller.openMessages,
                borderRadius: BorderRadius.circular(18.r),
                child: Ink(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: AppThemeColors.border),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: AppThemeColors.textSecondary,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2.w,
              top: -2.h,
              child: Container(
                constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.h),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                  ),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(color: AppThemeColors.surface, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 0.5.h),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildSearchBar() {
    final radius = BorderRadius.circular(18.r);
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
                height: 56.h,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: AppThemeColors.border, width: 1.1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: AppThemeColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppThemeColors.primary,
                        size: 19.w,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '搜索资源',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppThemeColors.textPrimary,
                              fontSize: 14.sp,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            '影视 · 短剧 · 播客 · 阅读',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppThemeColors.textMuted,
                              fontSize: 10.5.sp,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: const BoxDecoration(
                        color: AppThemeColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 13.w,
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
        icon: Icons.movie_rounded,
        label: '影视',
        iconBackground: const Color(0xFFF8D2B5),
        iconColor: const Color(0xFFC75C32),
        onTap: () => Get.toNamed(Routes.TV),
      ),
      _ResourceEntry(
        icon: Icons.live_tv_rounded,
        label: '短剧',
        iconBackground: const Color(0xFFF4DDA3),
        iconColor: const Color(0xFFB97918),
        onTap: () => Get.toNamed(Routes.PLAYLET),
      ),
      _ResourceEntry(
        icon: Icons.podcasts_rounded,
        label: '播客',
        iconBackground: const Color(0xFFF2C6BE),
        iconColor: const Color(0xFFB84E3B),
        onTap: () => Get.toNamed(Routes.MUSIC),
      ),
      _ResourceEntry(
        icon: Icons.menu_book_rounded,
        label: '阅读',
        iconBackground: const Color(0xFFDDE0B5),
        iconColor: const Color(0xFF737A36),
        onTap: () => Get.toNamed(Routes.READ),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppThemeColors.border, width: 1.1),
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
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: entry.iconBackground,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
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
                    height: 1.1,
                    fontWeight: FontWeight.w700,
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
    required this.iconBackground,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback? onTap;
}
