import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../routes/app_pages.dart';
import '../controllers/home_controller.dart';
import '../widgets/home_todo_panel.dart';

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
    return SafeArea(
      child: Stack(
        children: [
          // 顶部深色磨砂光晕背景
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF131521),
                    const Color(0xFF1B1E34).withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 右上方紫色光晕
          Positioned(
            top: -40.h,
            right: -20.w,
            child: Container(
              width: 260.w,
              height: 260.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: 0.22),
                    const Color(0xFF7C4DFF).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // 左侧蓝色光晕
          Positioned(
            top: 100.h,
            left: -60.w,
            child: Container(
              width: 220.w,
              height: 220.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF448AFF).withValues(alpha: 0.16),
                    const Color(0xFF448AFF).withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 主内容
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 160.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 24.h),
                _buildSearchBar(),
                SizedBox(height: 28.h),
                _buildResourceGrid(),
                SizedBox(height: 28.h),
                const HomeTodoPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white60,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  controller.name,
                  style: TextStyle(
                    fontSize: 24.sp,
                    height: 1.3,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          _buildMessageButton(),
        ],
      );
    });
  }

  Widget _buildMessageButton() {
    return Obx(() {
      final unreadCount = controller.unreadMessageCount;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20.r),
                child: InkWell(
                  onTap: controller.openMessages,
                  borderRadius: BorderRadius.circular(20.r),
                  child: Ink(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 24.w,
                      ),
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
                  border: Border.all(
                    color: const Color(0xFF121212),
                    width: 1.5,
                  ),
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
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.SEARCH),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 52.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 16.w),
                Icon(Icons.search_rounded, color: Colors.white54, size: 22.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    '搜索影视、短剧、播客、阅读...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14.5.sp,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(right: 6.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Text(
                    '搜索',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
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

  // ─── 2×2 资源快捷入口 ───

  Widget _buildResourceGrid() {
    final entries = [
      _ResourceEntry(
        icon: Icons.movie_rounded,
        label: '影视',
        subtitle: '海量资源',
        gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // 优雅深紫
        iconColor: const Color(0xFFD8B5FF),
        onTap: () => Get.toNamed(Routes.TV),
      ),
      _ResourceEntry(
        icon: Icons.live_tv_rounded,
        label: '短剧',
        subtitle: '精彩短剧',
        gradient: const [Color(0xFF00B4DB), Color(0xFF0083B0)], // 清新海蓝
        iconColor: const Color(0xFFB3E5FC),
        onTap: () => Get.toNamed(Routes.PLAYLET),
      ),
      _ResourceEntry(
        icon: Icons.podcasts_rounded,
        label: '播客',
        subtitle: '随时播放',
        gradient: const [Color(0xFF1CB5E0), Color(0xFF000851)], // 深邃幽蓝
        iconColor: const Color(0xFF89F7FE),
        onTap: () => Get.toNamed(Routes.MUSIC),
      ),
      _ResourceEntry(
        icon: Icons.menu_book_rounded,
        label: '阅读',
        subtitle: '打开文本',
        gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        iconColor: const Color(0xFFD1FAE5),
        onTap: () => Get.toNamed(Routes.READ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 1.95,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildGridCard(entries[index]),
    );
  }

  Widget _buildGridCard(_ResourceEntry entry) {
    return GestureDetector(
      onTap: entry.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: entry.gradient,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: entry.gradient[1].withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 左下角大光晕
            Positioned(
              left: -20.w,
              bottom: -24.h,
              child: Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 右上角特定颜色光晕
            Positioned(
              top: -12.h,
              right: -12.w,
              child: Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      entry.iconColor.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ),
            // 内容
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 26.w,
                      height: 26.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 13.w,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: entry.iconColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            entry.icon,
                            color: Colors.white,
                            size: 22.w,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 20.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  entry.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    height: 1.1,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceEntry {
  const _ResourceEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final Color iconColor;
  final VoidCallback? onTap;
}
