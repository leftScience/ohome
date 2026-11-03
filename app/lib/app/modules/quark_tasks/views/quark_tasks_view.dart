import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../quark_sync/controllers/quark_sync_controller.dart';
import '../../quark_sync/views/quark_sync_view.dart';
import '../../quark_transfer_tasks/controllers/quark_transfer_tasks_controller.dart';
import '../../quark_transfer_tasks/views/manual_transfer_task_sheet.dart';
import '../../quark_transfer_tasks/views/quark_transfer_tasks_view.dart';

class QuarkTasksView extends StatefulWidget {
  const QuarkTasksView({super.key});

  @override
  State<QuarkTasksView> createState() => _QuarkTasksViewState();
}

class _QuarkTasksViewState extends State<QuarkTasksView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.index != _currentIndex && mounted) {
      setState(() => _currentIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTap(BuildContext context) async {
    if (_currentIndex == 0) {
      if (!Get.isRegistered<QuarkTransferTasksController>()) return;
      final transferController = Get.find<QuarkTransferTasksController>();
      await showManualTransferTaskSheet(
        context: context,
        loadSavePathOptions: transferController.fetchSavePathOptions,
        onSubmit:
            ({
              required String title,
              required String shareUrl,
              required String savePath,
              required String passcode,
            }) {
              return transferController.submitManualTransfer(
                title: title,
                shareUrl: shareUrl,
                savePath: savePath,
                passcode: passcode,
              );
            },
      );
    } else {
      if (!Get.isRegistered<QuarkSyncController>()) return;
      await Get.find<QuarkSyncController>().openCreatePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransferTab = _currentIndex == 0;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '任务中心',
                        style: TextStyle(
                          fontSize: 22.sp,
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
                _buildCreateActionButton(
                  context: context,
                  label: isTransferTab ? '新建转存' : '新建同步',
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppThemeColors.border),
                boxShadow: AppThemeColors.cardShadow,
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(12.r),
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppThemeColors.primary,
                      AppThemeColors.primaryDeep,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeColors.primary.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                dividerColor: Colors.transparent,
                labelColor: AppThemeColors.textOnAccent,
                unselectedLabelColor: AppThemeColors.textSecondary,
                labelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(
                    height: 36.h,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 17.w),
                        SizedBox(width: 6.w),
                        const Text('转存任务'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 36.h,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.autorenew_rounded, size: 17.w),
                        SizedBox(width: 6.w),
                        const Text('同步任务'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                QuarkTransferTasksView(embedded: true),
                QuarkSyncView(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateActionButton({
    required BuildContext context,
    required String label,
  }) {
    final radius = BorderRadius.circular(14.r);
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppThemeColors.primary, AppThemeColors.primaryDeep],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.primary.withValues(alpha: 0.26),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: () => _handleCreateTap(context),
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 9.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18.w, color: Colors.white),
                  SizedBox(width: 4.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
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
