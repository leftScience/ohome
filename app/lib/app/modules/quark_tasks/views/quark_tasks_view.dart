import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_theme.dart';
import '../../quark_sync/views/quark_sync_view.dart';
import '../../quark_transfer_tasks/views/quark_transfer_tasks_view.dart';

class QuarkTasksView extends StatefulWidget {
  const QuarkTasksView({super.key});

  @override
  State<QuarkTasksView> createState() => _QuarkTasksViewState();
}

class _QuarkTasksViewState extends State<QuarkTasksView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 14.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '任务',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: AppThemeColors.textPrimary,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppThemeColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppThemeColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppThemeColors.primary,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                dividerColor: Colors.transparent,
                labelColor: AppThemeColors.textOnAccent,
                unselectedLabelColor: AppThemeColors.textSecondary,
                labelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(height: 38, text: '转存任务'),
                  Tab(height: 38, text: '同步任务'),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
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
}
