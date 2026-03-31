import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
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
                    SizedBox(height: 14.h),
                    Obx(() {
                      final overview = _controller.overview.value;
                      return Row(
                        children: [
                          Expanded(
                            child: _ReminderEntryCard(
                              label: '临期',
                              value: overview?.expiringSoonCount ?? 0,
                              color: const Color(0xFFE57373),
                              icon: Icons.inventory_2_outlined,
                              onTap: _controller.openExpiringReminders,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _ReminderEntryCard(
                              label: '临近',
                              value: overview?.monthEventCount ?? 0,
                              color: const Color(0xFF81C784),
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
              SizedBox(height: 6.h),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30.r),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(30.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 0),
                        child: Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101113),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            onTap: (value) {
                              if (value == 1) {
                                _ensureEventsController();
                              }
                            },
                            isScrollable: false,
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2B78FF), Color(0xFF1967EA)],
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppThemeColors.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            overlayColor: WidgetStatePropertyAll(
                              Colors.white.withValues(alpha: 0.03),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white54,
                            labelPadding: EdgeInsets.zero,
                            indicatorPadding: EdgeInsets.zero,
                            labelStyle: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: [
                              Tab(
                                height: 48.h,
                                child: Text('物资', style: TextStyle(height: 1)),
                              ),
                              Tab(
                                height: 48.h,
                                child: Text('日期', style: TextStyle(height: 1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            DropsItemsPanel(
                              controller: _itemsController,
                              filterPadding: EdgeInsets.fromLTRB(
                                14.w,
                                0,
                                14.w,
                                12.h,
                              ),
                              listPadding: EdgeInsets.fromLTRB(
                                14.w,
                                0,
                                14.w,
                                bottomInset,
                              ),
                            ),
                            _buildEventsPanel(bottomInset),
                          ],
                        ),
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
          Positioned(
            right: 20.w,
            bottom: MediaQuery.of(context).padding.bottom + 68.h,
            child: FloatingActionButton(
              heroTag: 'drops-create-fab',
              onPressed: _handleCreate,
              backgroundColor: AppThemeColors.primary,
              foregroundColor: Colors.white,
              elevation: 14,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: const Icon(Icons.add),
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
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.12),
                      color.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: color.withValues(alpha: 0.16)),
                ),
                child: Row(
                  children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 19.w),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12.w,
                  color: Colors.white30,
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
}

class _DropsBackdrop extends StatelessWidget {
  const _DropsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF131521),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60.h,
              right: -40.w,
              child: _BackdropGlow(
                size: 320.w,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              top: 200.h,
              left: -80.w,
              child: _BackdropGlow(
                size: 280.w,
                color: const Color(0xFF448AFF).withValues(alpha: 0.12),
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
