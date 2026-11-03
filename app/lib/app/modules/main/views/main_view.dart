import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../home/controllers/home_controller.dart';
import '../../home/views/home_view.dart';
import '../../home/widgets/home_history_banner.dart';
import '../../me/views/me_view.dart';
import '../../quark_tasks/views/quark_tasks_view.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/home_style_backdrop.dart';
import '../../../widgets/main_tab_content_insets.dart';
import '../controllers/main_controller.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  static const List<Widget> _tabViews = <Widget>[
    HomeView(),
    QuarkTasksView(),
    MeView(),
  ];
  static const double _tabBarHeight = MainTabContentInsets.tabBarHeight;
  static const double _floatingBottomSpacing =
      MainTabContentInsets.floatingBottomSpacing;
  static const double _historyBannerGap = MainTabContentInsets.historyBannerGap;
  static const double _tabBarInnerHorizontalPadding = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          const HomeStyleBackdrop(),
          // 主内容区域
          Obx(
            () => IndexedStack(
              index: controller.index.value,
              children: List<Widget>.generate(_tabViews.length, (tabIndex) {
                if (!controller.loadedIndexes.contains(tabIndex)) {
                  return const SizedBox.shrink();
                }
                return _tabViews[tabIndex];
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, _floatingBottomSpacing),
        child: Obx(() {
          final showHistoryBanner =
              controller.index.value == 0 && Get.isRegistered<HomeController>();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHistoryBanner) ...[
                const HomeHistoryBanner(),
                const SizedBox(height: _historyBannerGap),
              ],
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: _buildFloatingTabBar(),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFloatingTabBar() {
    return Container(
      height: _tabBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: _tabBarInnerHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: AppThemeColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppThemeColors.border, width: 1),
        boxShadow: AppThemeColors.floatingShadow,
      ),
      child: Row(
        children: [
          _buildTabItem(
            index: 0,
            label: '首页',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
          ),
          _buildTabItem(
            index: 1,
            label: '任务',
            icon: Icons.task_alt_rounded,
            activeIcon: Icons.task_alt_rounded,
          ),
          _buildTabItem(
            index: 2,
            label: '设置',
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = controller.index.value == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: GestureDetector(
          onTap: () => controller.setIndex(index),
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16.w : 12.w,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppThemeColors.primary,
                            AppThemeColors.primaryDeep,
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppThemeColors.primary.withValues(
                              alpha: 0.28,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected
                          ? AppThemeColors.textOnAccent
                          : AppThemeColors.textMuted,
                      size: 22,
                    ),
                    if (isSelected) ...[
                      SizedBox(width: 6.w),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppThemeColors.textOnAccent,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
