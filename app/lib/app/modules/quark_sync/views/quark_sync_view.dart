import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_auto_save_task_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../controllers/quark_sync_controller.dart';

class QuarkSyncView extends GetView<QuarkSyncController> {
  const QuarkSyncView({super.key});

  static const Map<int, String> _weekLabels = <int, String>{
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步任务')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: FloatingActionButton(
        onPressed: controller.openCreatePage,
        backgroundColor: AppThemeColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildSearchCard(),
          ),
          Expanded(child: _buildTaskList()),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '筛选条件',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: controller.taskNameController,
            onSubmitted: (_) => controller.search(),
            decoration: InputDecoration(
              hintText: '按任务名称搜索',
              hintStyle: TextStyle(fontSize: 13.sp, color: Colors.white38),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20.w,
                color: Colors.white38,
              ),
              filled: true,
              fillColor: const Color(0xFF101010),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: AppThemeColors.primary),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.resetFilters,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(44.h),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: const Text('重置'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: FilledButton(
                  onPressed: controller.search,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(44.h),
                    backgroundColor: AppThemeColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: const Text('搜索'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return Obx(() {
      final tasks = controller.tasks;
      final loading = controller.loading.value;
      final hasMore = controller.hasMore.value;
      final loadingMore = controller.loadingMore.value;

      if (loading && tasks.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: () => controller.loadTasks(refresh: true),
        child: tasks.isEmpty
            ? ListView(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.w, 64.h, 20.w, 120.h),
                children: [
                  Icon(
                    Icons.sync_problem_outlined,
                    size: 60.w,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 14.h),
                  Center(
                    child: Text(
                      '暂无同步任务',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: controller.scrollController,
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
                itemCount: tasks.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  if (index >= tasks.length) {
                    return loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }

                  final task = tasks[index];
                  return _TaskCard(
                    task: task,
                    busy: controller.isTaskBusy(task.id),
                    ruleText: _formatRule(task),
                    onEdit: () => controller.openEditPage(task),
                    onRunOnce: () => controller.runTaskOnce(task),
                    onDelete: () => controller.confirmDelete(task),
                  );
                },
              ),
      );
    });
  }

  static String _formatRule(QuarkAutoSaveTaskModel task) {
    final runTime = task.runTime;
    if (runTime.isEmpty) return '未设置执行时间';

    if (task.scheduleType == 'weekly') {
      final days = task.runWeekDays
          .map((item) => _weekLabels[item] ?? '周$item')
          .join('、');
      return days.isEmpty ? '每周 $runTime' : '每周（$days）$runTime';
    }

    return '每天 $runTime';
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.busy,
    required this.ruleText,
    required this.onEdit,
    required this.onRunOnce,
    required this.onDelete,
  });

  final QuarkAutoSaveTaskModel task;
  final bool busy;
  final String ruleText;
  final VoidCallback onEdit;
  final VoidCallback onRunOnce;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.taskName.isEmpty ? '未命名任务' : task.taskName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      task.enabled ? '启用中' : '已停用',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: task.enabled
                            ? const Color(0xFF81C784)
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color:
                      (task.enabled ? const Color(0xFF81C784) : Colors.white30)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  task.enabled ? '启用' : '停用',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: task.enabled
                        ? const Color(0xFF81C784)
                        : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _buildInfoRow(
            Icons.folder_open_outlined,
            task.savePath.isEmpty ? '未设置保存路径' : task.savePath,
          ),
          SizedBox(height: 8.h),
          _buildInfoRow(Icons.schedule_outlined, ruleText),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.link_rounded,
            task.shareUrl.isEmpty ? '未设置分享链接' : task.shareUrl,
            maxLines: 2,
          ),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.update_outlined,
            task.lastRunAt == null
                ? '最近执行：暂无记录'
                : '最近执行：${_formatDate(task.lastRunAt!)}',
          ),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.edit_calendar_outlined,
            task.updatedAt == null
                ? '更新时间未知'
                : '更新于 ${_formatDate(task.updatedAt!)}',
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _ActionChip(
                label: '编辑',
                color: AppThemeColors.primary,
                icon: Icons.edit_outlined,
                onTap: busy ? null : onEdit,
              ),
              _ActionChip(
                label: busy ? '执行中' : '执行一次',
                color: const Color(0xFF81C784),
                icon: busy
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
                onTap: busy ? null : onRunOnce,
              ),
              _ActionChip(
                label: '删除',
                color: const Color(0xFFE57373),
                icon: Icons.delete_outline_rounded,
                onTap: busy ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: maxLines > 1 ? 2.h : 0),
          child: Icon(icon, size: 16.w, color: Colors.white38),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              height: maxLines > 1 ? 1.5 : null,
              color: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16.w, color: color),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
