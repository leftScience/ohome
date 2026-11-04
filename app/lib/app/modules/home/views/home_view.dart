import 'dart:math' as math;
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

/// 首页采用「头部 + 搜索 + 快捷入口 + 推荐面板」结构，
/// 推荐列表向上滚动时平滑收起顶部区域，为内容让出空间。
class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.controller});

  final HomeController controller;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody>
    with SingleTickerProviderStateMixin {
  static const double _collapseRange = 96;

  /// 0 = 展开，1 = 收起顶部区域。
  double _progress = 0;

  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

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
    final sectionGap = lerpDouble(12.h, 0, t)!;
    final chromeOpacity = (1 - t * 1.15).clamp(0.0, 1.0);
    final chromeFactor = (1 - t).clamp(0.0, 1.0);
    final chromeScale = lerpDouble(1.0, 0.96, t)!;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: _buildHeader(),
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
                      child: Transform.scale(
                        scale: chromeScale,
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: sectionGap <= 0 ? 0 : sectionGap,
                              ),
                              _buildSearchBar(),
                              SizedBox(
                                height: sectionGap <= 0 ? 0 : sectionGap,
                              ),
                              _buildResourceMenu(
                                disableAnimations: disableAnimations,
                              ),
                            ],
                          ),
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

  Widget _buildHeader() {
    return Obx(() {
      final displayName = widget.controller.name.trim().isEmpty
          ? '欢迎回来'
          : widget.controller.name.trim();

      return SizedBox(
        height: 42.w,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22.sp,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppThemeColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            _buildMessageButton(),
          ],
        ),
      );
    });
  }

  Widget _buildMessageButton() {
    return Obx(() {
      final unreadCount = widget.controller.unreadMessageCount;
      final size = 42.w;
      final iconSize = 21.w;
      final radius = BorderRadius.circular(14.r);

      return Semantics(
        button: true,
        label: unreadCount > 0 ? '通知消息，$unreadCount条未读' : '通知消息',
        child: _PressableScale(
          onTap: widget.controller.openMessages,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppThemeColors.surface.withValues(alpha: 0.92),
                  borderRadius: radius,
                  border: Border.all(
                    color: unreadCount > 0
                        ? AppThemeColors.primary.withValues(alpha: 0.28)
                        : AppThemeColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (unreadCount > 0
                                  ? AppThemeColors.primary
                                  : AppThemeColors.shadowSoft)
                              .withValues(alpha: unreadCount > 0 ? 0.14 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    unreadCount > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: unreadCount > 0
                        ? AppThemeColors.primary
                        : AppThemeColors.textPrimary,
                    size: iconSize,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -3.w,
                  top: -3.h,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: 17.w,
                      minHeight: 17.h,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 1.h,
                    ),
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
                          color: const Color(
                            0xFFFF5252,
                          ).withValues(alpha: 0.38),
                          blurRadius: 6,
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
        ),
      );
    });
  }

  Widget _buildSearchBar() {
    final radius = BorderRadius.circular(18.r);

    return Semantics(
      button: true,
      label: '搜索影视、短剧、播客和阅读资源',
      child: _PressableScale(
        onTap: () => Get.toNamed(Routes.SEARCH),
        child: Container(
          height: 50.h,
          padding: EdgeInsets.all(1.2.w),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeColors.primary.withValues(alpha: 0.28),
                AppThemeColors.accent.withValues(alpha: 0.20),
                AppThemeColors.border,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: AppThemeColors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16.8.r),
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppThemeColors.primary.withValues(alpha: 0.14),
                        AppThemeColors.accent.withValues(alpha: 0.09),
                      ],
                    ),
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
    );
  }

  // ─── 一行四个 3D Bento 质感快捷入口 ───

  Widget _buildResourceMenu({required bool disableAnimations}) {
    final entries = [
      _ResourceEntry(
        icon: Icons.movie_filter_rounded,
        label: '影视',
        gradientColors: const [Color(0xFFEFF5FF), Color(0xFFDBEAFE)],
        iconGradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        accentColor: const Color(0xFF186EEF),
        onTap: () => Get.toNamed(Routes.TV),
      ),
      _ResourceEntry(
        icon: Icons.bolt_rounded,
        label: '短剧',
        gradientColors: const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
        iconGradient: const [Color(0xFFF97316), Color(0xFFEA580C)],
        accentColor: const Color(0xFFE66A00),
        onTap: () => Get.toNamed(Routes.PLAYLET),
      ),
      _ResourceEntry(
        icon: Icons.podcasts_rounded,
        label: '播客',
        gradientColors: const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
        iconGradient: const [Color(0xFFF43F5E), Color(0xFFE11D48)],
        accentColor: const Color(0xFFE11D48),
        onTap: () => Get.toNamed(Routes.MUSIC),
      ),
      _ResourceEntry(
        icon: Icons.auto_stories_rounded,
        label: '阅读',
        gradientColors: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
        iconGradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
        accentColor: const Color(0xFF0D9488),
        onTap: () => Get.toNamed(Routes.READ),
      ),
    ];

    return Row(
      children: List.generate(entries.length, (i) {
        final entry = entries[i];
        final card = _buildBentoResourceCard(entry);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4.5.w,
              right: i == entries.length - 1 ? 0 : 4.5.w,
            ),
            child: disableAnimations
                ? card
                : AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      final start = (i * 0.12).clamp(0.0, 0.6);
                      final end = (start + 0.52).clamp(0.0, 1.0);
                      final curved = CurvedAnimation(
                        parent: _entranceController,
                        curve: Interval(start, end, curve: Curves.easeOutBack),
                      ).value;
                      final opacity = CurvedAnimation(
                        parent: _entranceController,
                        curve: Interval(start, end, curve: Curves.easeOut),
                      ).value;
                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, (1 - curved) * 16),
                          child: Transform.scale(
                            scale: 0.92 + 0.08 * curved,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: card,
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildBentoResourceCard(_ResourceEntry entry) {
    final radius = BorderRadius.circular(18.r);
    return Semantics(
      button: true,
      label: '进入${entry.label}',
      child: _PressableScale(
        onTap: entry.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeColors.surface,
                entry.gradientColors.first.withValues(alpha: 0.85),
                entry.gradientColors.last.withValues(alpha: 0.65),
              ],
            ),
            border: Border.all(
              color: entry.accentColor.withValues(alpha: 0.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: entry.accentColor.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 右下角微光装饰水印图标
              Positioned(
                right: -10.w,
                bottom: -10.h,
                child: Transform.rotate(
                  angle: -math.pi / 12,
                  child: Icon(
                    entry.icon,
                    size: 44.w,
                    color: entry.accentColor.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 11.h,
                  ),
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
                            colors: entry.iconGradient,
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: entry.accentColor.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            entry.icon,
                            color: Colors.white,
                            size: 22.w,
                          ),
                        ),
                      ),
                      SizedBox(height: 7.h),
                      Text(
                        entry.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: AppThemeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    required this.iconGradient,
    required this.accentColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final List<Color> iconGradient;
  final Color accentColor;
  final VoidCallback? onTap;
}

/// 轻量按压回弹反馈组件，提供顺滑的缩放阻尼手感。
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (_pressed && !disableAnimations) ? 0.95 : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
