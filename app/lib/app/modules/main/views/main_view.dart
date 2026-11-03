import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../home/controllers/home_controller.dart';
import '../../home/views/home_view.dart';
import '../../home/widgets/home_history_banner.dart';
import '../../me/views/me_view.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/home_style_backdrop.dart';
import '../controllers/main_controller.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  static const List<Widget> _tabViews = <Widget>[HomeView(), MeView()];
  static const double _tabBarHeight = 64;
  static const double _floatingHorizontalPadding = 24;
  static const double _floatingBottomSpacing = 16;
  static const double _historyBannerGap = 10;
  static const double _tabBarInnerHorizontalPadding = 14;
  static const double _tabItemWidth = 72;

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
        minimum: const EdgeInsets.fromLTRB(
          _floatingHorizontalPadding,
          0,
          _floatingHorizontalPadding,
          _floatingBottomSpacing,
        ),
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
              _buildFloatingTabBar(),
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
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppThemeColors.border, width: 1.2),
        boxShadow: AppThemeColors.floatingShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTabItem(
            index: 0,
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
          ),
          _buildTabItem(
            index: 1,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = controller.index.value == index;

    return SizedBox(
      width: _tabItemWidth,
      child: GestureDetector(
        onTap: () => controller.setIndex(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppThemeColors.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? AppThemeColors.textOnAccent
                        : AppThemeColors.textMuted,
                    size: 26,
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
