import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../drops/views/drops_view.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/views/home_view.dart';
import '../../home/widgets/home_history_banner.dart';
import '../../plugin/views/plugin_view.dart';
import '../controllers/main_controller.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  static const List<Widget> _tabViews = <Widget>[
    HomeView(),
    DropsView(),
    PluginView(),
  ];
  static const double _tabBarHeight = 54;
  static const double _floatingHorizontalPadding = 24;
  static const double _floatingBottomSpacing = 16;
  static const double _historyBannerGap = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
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
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabItem(
            index: 0,
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
          ),
          _buildTabItem(
            index: 1,
            icon: Icons.water_drop_outlined,
            activeIcon: Icons.water_drop,
          ),
          _buildTabItem(
            index: 2,
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

    return Expanded(
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
                color: isSelected ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey[400],
                    size: 20,
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
