import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_transfer_task_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../controllers/quark_transfer_tasks_controller.dart';
import 'manual_transfer_task_sheet.dart';

class QuarkTransferTasksView extends GetView<QuarkTransferTasksController> {
  const QuarkTransferTasksView({super.key});

  static const List<_StatusFilterOption> _filters = <_StatusFilterOption>[
    _StatusFilterOption(label: '全部', value: ''),
    _StatusFilterOption(label: '排队中', value: 'queued'),
    _StatusFilterOption(label: '转存中', value: 'processing'),
    _StatusFilterOption(label: '转存成功', value: 'success'),
    _StatusFilterOption(label: '转存失败', value: 'failed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('转存任务')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateSheet(context),
        backgroundColor: AppThemeColors.primary,
        foregroundColor: Colors.white,
        child: Icon(Icons.add_rounded, size: 26.w),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildFilters(),
          ),
          Expanded(child: _buildTaskList()),
        ],
      ),
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
          }) {
            return controller.submitManualTransfer(
              title: title,
              shareUrl: shareUrl,
              savePath: savePath,
            );
          },
    );
  }

  Widget _buildFilters() {
    return Obx(() {
      final current = controller.statusFilter.value;
      return Row(
        children: _filters
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final filter = entry.value;
              final selected = current == filter.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _filters.length - 1 ? 0 : 8.w,
                  ),
                  child: _FilterButton(
                    label: filter.label,
                    selected: selected,
                    onTap: () => controller.changeStatusFilter(filter.value),
                  ),
                ),
              );
            })
            .toList(growable: false),
      );
    });
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
        onRefresh: controller.refreshList,
        child: tasks.isEmpty
            ? ListView(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 120.h),
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 60.w,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 14.h),
                  Center(
                    child: Text(
                      '暂无转存任务',
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
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h),
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
                child: Text(
                  task.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  task.statusLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInfoRow(Icons.category_outlined, task.sourceTypeLabel),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.folder_open_outlined,
            task.displaySavePath.isEmpty ? '未记录保存路径' : task.displaySavePath,
          ),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.link_rounded,
            task.shareUrl.isEmpty ? '未记录分享链接' : task.shareUrl,
            maxLines: 2,
          ),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.schedule_outlined,
            task.createdAt == null
                ? '创建时间未知'
                : '创建时间：${_formatDate(task.createdAt!)}',
          ),
          SizedBox(height: 8.h),
          _buildInfoRow(
            task.isFailed
                ? Icons.error_outline_rounded
                : Icons.task_alt_outlined,
            _buildResultText(),
            maxLines: task.isFailed ? 3 : 2,
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              if (task.canGoSync)
                _ActionChip(
                  label: '去同步',
                  color: AppThemeColors.primary,
                  icon: Icons.sync_alt_rounded,
                  onTap: deleting ? null : onGoSync,
                ),
              _ActionChip(
                label: deleting ? '删除中' : '删除',
                color: const Color(0xFFE57373),
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
      return '任务排队中，等待空闲 worker';
    }
    if (task.isProcessing) {
      return '任务进行中';
    }
    if (task.isFailed) {
      final message = task.resultMessage;
      return message.isEmpty ? '失败原因未知' : message;
    }
    final finished = task.finishedAt == null
        ? '完成时间未知'
        : '完成时间：${_formatDate(task.finishedAt!)}';
    final message = task.resultMessage.trim();
    if (message.isEmpty) {
      return finished;
    }
    return '$finished\n$message';
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'queued':
        return const Color(0xFF64B5F6);
      case 'processing':
        return const Color(0xFFFFB74D);
      case 'success':
        return const Color(0xFF81C784);
      case 'failed':
        return const Color(0xFFE57373);
      default:
        return Colors.white54;
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppThemeColors.primary.withValues(alpha: 0.18)
          : const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          height: 42.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? AppThemeColors.primary.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption({required this.label, required this.value});

  final String label;
  final String value;
}
