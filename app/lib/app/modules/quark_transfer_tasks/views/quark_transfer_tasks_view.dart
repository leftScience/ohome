import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_transfer_task_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../../../widgets/main_tab_content_insets.dart';
import '../controllers/quark_transfer_tasks_controller.dart';
import 'manual_transfer_task_sheet.dart';

class QuarkTransferTasksView extends GetView<QuarkTransferTasksController> {
  const QuarkTransferTasksView({super.key, this.embedded = false});

  /// 作为底部 tab 内嵌时隐藏 AppBar，并由外层任务中心提供顶部新建入口。
  final bool embedded;

  static const List<_StatusFilterOption> _filters = <_StatusFilterOption>[
    _StatusFilterOption(label: '全部', value: ''),
    _StatusFilterOption(
      label: '排队中',
      value: 'queued',
      dotColor: Color(0xFF1E88E5),
    ),
    _StatusFilterOption(
      label: '转存中',
      value: 'processing',
      dotColor: Color(0xFFF57C00),
    ),
    _StatusFilterOption(
      label: '转存成功',
      value: 'success',
      dotColor: Color(0xFF12B76A),
    ),
    _StatusFilterOption(
      label: '转存失败',
      value: 'failed',
      dotColor: Color(0xFFF04438),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, embedded ? 2.h : 14.h, 16.w, 0),
          child: _buildSearchBar(),
        ),
        Padding(
          padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
          child: _buildFilters(),
        ),
        Expanded(child: _buildTaskList(context)),
      ],
    );

    if (embedded) {
      return SafeArea(bottom: false, child: body);
    }

    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('转存任务')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: _buildCreateButton(context),
      body: body,
    );
  }

  Widget _buildSearchBar() {
    final radius = BorderRadius.circular(15.r);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: TextField(
        controller: controller.keywordController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => controller.search(),
        style: TextStyle(
          fontSize: 13.5.sp,
          fontWeight: FontWeight.w500,
          color: AppThemeColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '搜索任务',
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
            valueListenable: controller.keywordController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: '清空搜索',
                onPressed: controller.resetKeyword,
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

  Widget _buildCreateButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'quark-transfer-create-fab',
      onPressed: () => _openCreateSheet(context),
      backgroundColor: AppThemeColors.primary,
      foregroundColor: Colors.white,
      child: Icon(Icons.add_rounded, size: 26.w),
    );
  }

  Future<void> _openCreateSheet(BuildContext context) {
    return showManualTransferTaskSheet(
      context: context,
      loadSavePathOptions: controller.fetchSavePathOptions,
      onSubmit:
          ({
            required String title,
            required String shareUrl,
            required String savePath,
            required String passcode,
          }) {
            return controller.submitManualTransfer(
              title: title,
              shareUrl: shareUrl,
              savePath: savePath,
              passcode: passcode,
            );
          },
    );
  }

  Widget _buildFilters() {
    return Obx(() {
      final current = controller.statusFilter.value;
      return SizedBox(
        height: 34.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: _filters.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final selected = current == filter.value;
            return _FilterPill(
              label: filter.label,
              dotColor: filter.dotColor,
              selected: selected,
              onTap: () => controller.changeStatusFilter(filter.value),
            );
          },
        ),
      );
    });
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
      final hasFilter =
          controller.keyword.value.trim().isNotEmpty ||
          controller.statusFilter.value.isNotEmpty;

      if (loading && tasks.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: controller.refreshList,
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
                            hasFilter
                                ? Icons.filter_alt_off_rounded
                                : Icons.cloud_download_outlined,
                            size: 28.w,
                            color: AppThemeColors.primary,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Text(
                          hasFilter ? '没有匹配的转存任务' : '暂无转存任务',
                          style: TextStyle(
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppThemeColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            if (hasFilter) {
                              controller.changeStatusFilter('');
                              controller.resetKeyword();
                            } else {
                              _openCreateSheet(context);
                            }
                          },
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
                            hasFilter
                                ? Icons.refresh_rounded
                                : Icons.add_rounded,
                            size: 18.w,
                          ),
                          label: Text(
                            hasFilter ? '清除筛选条件' : '新建转存任务',
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
                    key: ValueKey('transfer-task-${task.id ?? index}'),
                    task: task,
                    deleting: controller.isDeleting(task.id),
                    onDelete: () => controller.confirmDelete(task),
                    onGoSync: task.canGoSync
                        ? () => controller.openSyncForm(task)
                        : null,
                  );
                },
              ),
      );
    });
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.deleting,
    required this.onDelete,
    required this.onGoSync,
  });

  final QuarkTransferTaskModel task;
  final bool deleting;
  final VoidCallback onDelete;
  final VoidCallback? onGoSync;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(task.status);
    final statusIcon = _statusIcon(task.status);
    final createdTimeText = task.createdAt == null
        ? '创建时间未知'
        : _formatDate(task.createdAt!);

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
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(statusIcon, size: 20.w, color: statusColor),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayName,
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
                    Text(
                      '${task.sourceTypeLabel} · $createdTimeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppThemeColors.textMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      task.statusLabel,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
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
                  task.displaySavePath.isEmpty ? '—' : task.displaySavePath,
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
                  task.shareUrl.isEmpty ? '—' : task.shareUrl,
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
                child: Row(
                  children: [
                    Icon(
                      task.isFailed
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 14.w,
                      color: task.isFailed
                          ? AppThemeColors.danger
                          : AppThemeColors.textMuted,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        _buildResultText(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          height: 1.3,
                          color: task.isFailed
                              ? AppThemeColors.danger
                              : AppThemeColors.textMuted,
                          fontWeight: task.isFailed
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (task.canGoSync) ...[
                _ActionChip(
                  label: '去同步',
                  color: AppThemeColors.primary,
                  icon: Icons.sync_alt_rounded,
                  onTap: deleting ? null : onGoSync,
                ),
                SizedBox(width: 6.w),
              ],
              _ActionChip(
                label: deleting ? '删除中' : '删除',
                color: AppThemeColors.danger,
                icon: deleting
                    ? Icons.hourglass_top_rounded
                    : Icons.delete_outline_rounded,
                onTap: deleting ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildResultText() {
    if (task.isQueued) {
      return '排队中';
    }
    if (task.isProcessing) {
      return '转存中...';
    }
    if (task.isFailed) {
      final message = task.resultMessage.trim();
      return message.isEmpty ? '转存失败' : message;
    }
    final finished = task.finishedAt == null
        ? '转存完成'
        : '完成于 ${_formatDate(task.finishedAt!)}';
    final message = task.resultMessage.trim();
    if (message.isEmpty) {
      return finished;
    }
    return '$finished · $message';
  }

  Widget _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15.w, color: AppThemeColors.textMuted),
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'queued':
        return const Color(0xFF1E88E5);
      case 'processing':
        return const Color(0xFFF57C00);
      case 'success':
        return AppThemeColors.success;
      case 'failed':
        return AppThemeColors.danger;
      default:
        return AppThemeColors.textMuted;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'queued':
        return Icons.hourglass_empty_rounded;
      case 'processing':
        return Icons.sync_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
      default:
        return Icons.folder_copy_outlined;
    }
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      AppThemeColors.primary,
                      AppThemeColors.primaryDeep,
                    ],
                  )
                : null,
            color: selected ? null : AppThemeColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: AppThemeColors.border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppThemeColors.primary.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5.w),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppThemeColors.textOnAccent
                      : AppThemeColors.textSecondary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption({
    required this.label,
    required this.value,
    this.dotColor,
  });

  final String label;
  final String value;
  final Color? dotColor;
}
