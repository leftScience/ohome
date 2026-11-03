import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_auto_save_task_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../../../widgets/main_tab_content_insets.dart';
import '../controllers/quark_sync_controller.dart';

class QuarkSyncView extends GetView<QuarkSyncController> {
  const QuarkSyncView({super.key, this.embedded = false});

  /// 作为底部 tab 内嵌时隐藏 AppBar，并由外层任务中心提供顶部新建入口。
  final bool embedded;

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
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, embedded ? 2.h : 14.h, 16.w, 10.h),
          child: embedded ? _buildCompactSearchBar() : _buildSearchCard(),
        ),
        Expanded(child: _buildTaskList(context)),
      ],
    );

    if (embedded) {
      return SafeArea(bottom: false, child: body);
    }

    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('同步任务')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: _buildCreateButton(),
      body: body,
    );
  }

  Widget _buildCreateButton() {
    return FloatingActionButton(
      heroTag: 'quark-sync-create-fab',
      onPressed: controller.openCreatePage,
      backgroundColor: AppThemeColors.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    );
  }

  Widget _buildCompactSearchBar() {
    final radius = BorderRadius.circular(15.r);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: TextField(
        controller: controller.taskNameController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => controller.search(),
        style: TextStyle(
          fontSize: 13.5.sp,
          fontWeight: FontWeight.w500,
          color: AppThemeColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '搜索同步任务名称...',
          hintStyle: TextStyle(
            fontSize: 12.5.sp,
            color: AppThemeColors.textDisabled,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(7.w),
            child: Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: AppThemeColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 18.w,
                color: AppThemeColors.primary,
              ),
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 46.w,
            minHeight: 46.w,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.taskNameController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: '清空搜索',
                onPressed: controller.resetFilters,
                icon: Icon(
                  Icons.cancel_rounded,
                  size: 18.w,
                  color: AppThemeColors.textDisabled,
                ),
              );
            },
          ),
          filled: true,
          fillColor: AppThemeColors.surface,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 12.h,
          ),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppThemeColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppThemeColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(
              color: AppThemeColors.primary,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppThemeColors.border),
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '筛选条件',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppThemeColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: controller.taskNameController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => controller.search(),
            decoration: InputDecoration(
              hintText: '按任务名称搜索',
              hintStyle: TextStyle(
                fontSize: 13.sp,
                color: AppThemeColors.textDisabled,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20.w,
                color: AppThemeColors.textDisabled,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller.taskNameController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    onPressed: controller.resetFilters,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.w,
                      color: AppThemeColors.textDisabled,
                    ),
                  );
                },
              ),
              filled: true,
              fillColor: AppThemeColors.surfaceMuted,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: AppThemeColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: AppThemeColors.border),
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
                    side: const BorderSide(color: AppThemeColors.borderStrong),
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

  Widget _buildTaskList(BuildContext context) {
    final bottomPadding = embedded
        ? MainTabContentInsets.bottom(context) + 72.h
        : 100.h;

    return Obx(() {
      final tasks = controller.tasks;
      final loading = controller.loading.value;
      final hasMore = controller.hasMore.value;
      final loadingMore = controller.loadingMore.value;
      final hasKeyword = controller.taskNameController.text.trim().isNotEmpty;

      if (loading && tasks.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: () => controller.loadTasks(refresh: true),
        child: tasks.isEmpty
            ? ListView(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.w, 36.h, 20.w, bottomPadding),
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 36.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppThemeColors.border),
                      boxShadow: AppThemeColors.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            color: AppThemeColors.primary.withValues(
                              alpha: 0.08,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasKeyword
                                ? Icons.search_off_rounded
                                : Icons.event_repeat_rounded,
                            size: 28.w,
                            color: AppThemeColors.primary,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Text(
                          hasKeyword ? '没有找到匹配的同步任务' : '暂无同步任务',
                          style: TextStyle(
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppThemeColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          hasKeyword
                              ? '尝试更换搜索关键词或重置筛选条件'
                              : '配置定时同步规则，自动追更分享链接中的新剧集与文件',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppThemeColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        FilledButton.tonalIcon(
                          onPressed: hasKeyword
                              ? controller.resetFilters
                              : controller.openCreatePage,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppThemeColors.primary.withValues(
                              alpha: 0.10,
                            ),
                            foregroundColor: AppThemeColors.primary,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          icon: Icon(
                            hasKeyword
                                ? Icons.refresh_rounded
                                : Icons.add_rounded,
                            size: 18.w,
                          ),
                          label: Text(
                            hasKeyword ? '清除搜索条件' : '新建同步任务',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: controller.scrollController,
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomPadding),
                itemCount: tasks.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, _) => SizedBox(height: 10.h),
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
                    key: ValueKey('sync-task-${task.id ?? index}'),
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
    super.key,
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
    final enabledColor = task.enabled
        ? AppThemeColors.success
        : AppThemeColors.textMuted;
    final lastRunText = task.lastRunAt == null
        ? '最近执行：暂无记录'
        : '最近执行：${_formatDate(task.lastRunAt!)}';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppThemeColors.border),
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: task.enabled
                      ? AppThemeColors.primary.withValues(alpha: 0.10)
                      : AppThemeColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.event_repeat_rounded,
                  size: 20.w,
                  color: task.enabled
                      ? AppThemeColors.primary
                      : AppThemeColors.textMuted,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.taskName.isEmpty ? '未命名任务' : task.taskName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppThemeColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12.5.w,
                          color: AppThemeColors.textMuted,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            ruleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: AppThemeColors.textMuted,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: enabledColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: enabledColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      task.enabled ? '启用中' : '已停用',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: enabledColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: AppThemeColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppThemeColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.folder_outlined,
                  '保存路径',
                  task.savePath.isEmpty ? '未设置保存路径' : task.savePath,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Divider(
                    height: 1,
                    thickness: 0.7,
                    color: AppThemeColors.divider,
                  ),
                ),
                _buildInfoRow(
                  Icons.link_rounded,
                  '分享链接',
                  task.shareUrl.isEmpty ? '未设置分享链接' : task.shareUrl,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  lastRunText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppThemeColors.textMuted,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _ActionChip(
                label: busy ? '执行中' : '执行一次',
                color: AppThemeColors.success,
                icon: busy
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
                onTap: busy ? null : onRunOnce,
              ),
              SizedBox(width: 6.w),
              _ActionChip(
                label: '编辑',
                color: AppThemeColors.primary,
                icon: Icons.edit_outlined,
                onTap: busy ? null : onEdit,
              ),
              SizedBox(width: 6.w),
              _ActionChip(
                label: '删除',
                color: AppThemeColors.danger,
                icon: Icons.delete_outline_rounded,
                onTap: busy ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String text, {
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15.w, color: AppThemeColors.textMuted),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w500,
            color: AppThemeColors.textMuted,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              height: maxLines > 1 ? 1.4 : null,
              color: AppThemeColors.textPrimary,
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14.5.w, color: color),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
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
