import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../controllers/drops_controller.dart';
import '../controllers/drops_events_controller.dart';
import '../controllers/drops_items_controller.dart';
import 'drops_shared_widgets.dart';

class DropsView extends StatefulWidget {
  const DropsView({super.key});

  @override
  State<DropsView> createState() => _DropsViewState();
}

class _DropsViewState extends State<DropsView>
    with SingleTickerProviderStateMixin {
  static const String _itemsTag = 'drops-main-items';
  static const String _eventsTag = 'drops-main-events';

  late final DropsController _controller;
  late final DropsItemsController _itemsController;
  late final TabController _tabController;
  DropsEventsController? _eventsController;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<DropsController>();
    _controller.ensureDictsLoaded();
    _itemsController = Get.isRegistered<DropsItemsController>(tag: _itemsTag)
        ? Get.find<DropsItemsController>(tag: _itemsTag)
        : Get.put(DropsItemsController(), tag: _itemsTag);
    _eventsController = Get.isRegistered<DropsEventsController>(tag: _eventsTag)
        ? Get.find<DropsEventsController>(tag: _eventsTag)
        : null;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleInnerTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleInnerTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleInnerTabChange() {
    if (_tabController.index == 1) {
      _ensureEventsController();
    }
  }

  void _ensureEventsController() {
    if (_eventsController != null) return;

    final controller = Get.isRegistered<DropsEventsController>(tag: _eventsTag)
        ? Get.find<DropsEventsController>(tag: _eventsTag)
        : Get.put(DropsEventsController(), tag: _eventsTag);

    if (!mounted) {
      _eventsController = controller;
      return;
    }
    setState(() {
      _eventsController = controller;
    });
  }

  Widget _buildEventsPanel(double bottomInset) {
    final controller = _eventsController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return DropsEventsPanel(
      controller: controller,
      filterPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
      listPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, bottomInset),
    );
  }

  Future<void> _handleCreate() async {
    final activeTabIndex = _tabController.index;
    var changed = false;
    switch (activeTabIndex) {
      case 0:
        changed = await _controller.openNewItem();
        break;
      case 1:
        changed = await _controller.openNewEvent();
        break;
      default:
        break;
    }
    if (!changed) return;
    if (activeTabIndex == 0) {
      await _itemsController.loadItems(refresh: true);
      return;
    }
    _ensureEventsController();
    await _eventsController?.loadEvents(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 108.h;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          const _DropsBackdrop(),
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '点滴',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Obx(() {
                      final overview = _controller.overview.value;
                      return Row(
                        children: [
                          Expanded(
                            child: _ReminderEntryCard(
                              label: '临期',
                              value: overview?.expiringSoonCount ?? 0,
                              gradient: const [
                                Color(0xFFFF512F),
                                Color(0xFFDD2476),
                              ],
                              iconColor: const Color(0xFFFFDAB9),
                              icon: Icons.inventory_2_outlined,
                              onTap: _controller.openExpiringReminders,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: _ReminderEntryCard(
                              label: '临近',
                              value: overview?.monthEventCount ?? 0,
                              gradient: const [
                                Color(0xFF00B4DB),
                                Color(0xFF0083B0),
                              ],
                              iconColor: const Color(0xFFB3E5FC),
                              icon: Icons.event_available_outlined,
                              onTap: _controller.openUpcomingReminders,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: TabBar(
                        controller: _tabController,
                        onTap: (value) {
                          if (value == 1) {
                            _ensureEventsController();
                          }
                        },
                        splashBorderRadius: BorderRadius.circular(24.r),
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: EdgeInsets.all(4.w),
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2B78FF), Color(0xFF1967EA)],
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemeColors.primary.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(text: '物资'),
                          Tab(text: '日期'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    DropsItemsPanel(
                      controller: _itemsController,
                      filterPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                      listPadding: EdgeInsets.fromLTRB(
                        20.w,
                        0,
                        20.w,
                        bottomInset,
                      ),
                    ),
                    _buildEventsPanel(bottomInset),
                  ],
                ),
              ),
            ],
          ),
          AppFloatingActionButtonAnchor(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'drops-create-fab',
                onPressed: _handleCreate,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2B78FF), Color(0xFF1967EA)],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.add, size: 28)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderEntryCard extends StatelessWidget {
  const _ReminderEntryCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.iconColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final List<Color> gradient;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 84.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: gradient[1].withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradient[0].withValues(alpha: 0.75),
                    gradient[1].withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Stack(
                children: [
                  // Left bottom big glow
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
                  // Right top specific color glow
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
                            iconColor.withValues(alpha: 0.35),
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
                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22.w),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  height: 1.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                '$value',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
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
                      ],
                    ),
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

class _DropsBackdrop extends StatelessWidget {
  const _DropsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF131521)),
        child: Stack(
          children: [
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
                      const Color(0xFF1B1E34).withValues(alpha: 0.5),
                      const Color(0xFF131521).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80.h,
              right: -60.w,
              child: _BackdropGlow(
                size: 400.w,
                color: const Color(0xFFDD2476).withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              top: 250.h,
              left: -100.w,
              child: _BackdropGlow(
                size: 360.w,
                color: const Color(0xFF00B4DB).withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
