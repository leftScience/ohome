import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/main_tab_content_insets.dart';
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                child: Text(
                  '任务中心',
                  style: TextStyle(
                    fontSize: 22.sp,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppThemeColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
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
          Positioned(
            right: 20.w,
            bottom: MainTabContentInsets.bottom(context) + 8.h,
            child: _buildCreateButton(context, isTransferTab),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, bool isTransferTab) {
    return FloatingActionButton(
      heroTag: 'quark-tasks-create-fab',
      tooltip: isTransferTab ? '新建转存' : '新建同步',
      onPressed: () => _handleCreateTap(context),
      backgroundColor: AppThemeColors.primary,
      foregroundColor: Colors.white,
      child: Icon(Icons.add_rounded, size: 26.w),
    );
  }
}
