import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_share_preview_file.dart';
import '../../../theme/app_theme.dart';
import '../controllers/share_preview_controller.dart';

class SharePreviewView extends GetView<SharePreviewController> {
  const SharePreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        controller.handleBack();
      },
      child: Scaffold(
        backgroundColor: AppThemeColors.pageBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: controller.handleBack,
          ),
          title: Obx(() {
            return Text(
              controller.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          }),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: controller.refreshCurrent,
            ),
          ],
        ),
      body: Obx(() {
        if (controller.loading.value && controller.files.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = controller.errorMessage.value;
        if (error.isNotEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40.w,
                    color: AppThemeColors.textDisabled,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppThemeColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  OutlinedButton(
                    onPressed: controller.refreshCurrent,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }
        final files = controller.files;
        if (files.isEmpty) {
          return Center(
            child: Text(
              '该目录暂无内容',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppThemeColors.textMuted,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refreshCurrent,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
            itemCount: files.length,
            separatorBuilder: (_, _) => SizedBox(height: 8.h),
            itemBuilder: (context, index) => _SharePreviewTile(
              item: files[index],
              onTap: () => controller.enterDir(files[index]),
            ),
          ),
        );
      }),
      ),
    );
  }
}

class _SharePreviewTile extends StatelessWidget {
  const _SharePreviewTile({required this.item, required this.onTap});

  final QuarkSharePreviewFile item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();
    return Material(
      color: AppThemeColors.surface,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: item.isDir ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              Icon(
                item.isDir
                    ? Icons.folder_rounded
                    : Icons.insert_drive_file_rounded,
                size: 22.w,
                color: item.isDir
                    ? AppThemeColors.warning
                    : AppThemeColors.primary,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName.isEmpty ? '未命名' : item.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppThemeColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppThemeColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.isDir)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.w,
                  color: AppThemeColors.textDisabled,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (!item.isDir) {
      final size = _formatBytes(item.size);
      if (size.isNotEmpty) parts.add(size);
    }
    final updated = _formatUpdatedAt(item.updatedAt);
    if (updated.isNotEmpty) parts.add(updated);
    return parts.join('  ');
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final fixed = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
    return '${size.toStringAsFixed(fixed)}${units[unit]}';
  }

  static String _formatUpdatedAt(int seconds) {
    if (seconds <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }
}