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
          // 顶部渐变装饰背景
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A237E).withValues(alpha: 0.6),
                    const Color(0xFF4A148C).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 装饰性光点
          Positioned(
            top: 30.h,
            right: 40.w,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 100.h,
            left: -20.w,
            child: Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF448AFF).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 主内容
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 180.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                _buildHeader(),
                SizedBox(height: 20.h),
                _buildSearchBar(),
                SizedBox(height: 24.h),
                _buildResourceGrid(),
                SizedBox(height: 24.h),
                const HomeTodoPanel(),
                SizedBox(height: 24.h),
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
      return Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: controller.openMessages,
          borderRadius: BorderRadius.circular(16.r),
          child: Ink(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white70,
                    size: 22.w,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4.w,
                    top: -4.h,
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: 18.w,
                        minHeight: 18.h,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: const Color(0xFF121212),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.SEARCH),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 14.w),
            Icon(Icons.search_rounded, color: Colors.white38, size: 20.w),
            SizedBox(width: 10.w),
            Text(
              '搜索影视、音乐、有声书...',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14.sp,
                height: 1.2,
              ),
            ),
          ],
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
        gradient: const [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        iconColor: const Color(0xFFCE93D8),
        onTap: () => Get.toNamed(Routes.TV),
      ),
      _ResourceEntry(
        icon: Icons.live_tv_rounded,
        label: '短剧',
        subtitle: '精彩短剧',
        gradient: const [Color(0xFF00695C), Color(0xFF004D40)],
        iconColor: const Color(0xFF80CBC4),
        onTap: () => Get.toNamed(Routes.PLAYLET),
      ),
      _ResourceEntry(
        icon: Icons.music_note_rounded,
        label: '音乐',
        subtitle: '畅听无限',
        gradient: const [Color(0xFF1565C0), Color(0xFF0D47A1)],
        iconColor: const Color(0xFF90CAF9),
        onTap: () => Get.toNamed(Routes.MUSIC),
      ),
      _ResourceEntry(
        icon: Icons.headphones_rounded,
        label: '有声书',
        subtitle: '沉浸听书',
        gradient: const [Color(0xFFE65100), Color(0xFFBF360C)],
        iconColor: const Color(0xFFFFCC80),
        onTap: () => Get.toNamed(Routes.AUDIOBOOK),
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
          borderRadius: BorderRadius.circular(18.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: entry.gradient,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: entry.gradient[0].withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -18.w,
              bottom: -22.h,
              child: Container(
                width: 92.w,
                height: 92.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // 右上角装饰光晕
            Positioned(
              top: -8.h,
              right: -8.w,
              child: Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      entry.iconColor.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.34],
                  ),
                ),
              ),
            ),
            // 内容
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                        size: 15.w,
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
                            color: entry.iconColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            entry.icon,
                            color: Colors.white.withValues(alpha: 0.95),
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
                                    fontSize: 15.sp,
                                    height: 1.0,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  entry.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    height: 1.1,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.72),
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
