import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_share_preview_file.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/quark_transfer_helper.dart';
import '../controllers/share_preview_controller.dart';

class SharePreviewView extends GetView<SharePreviewController> {
  const SharePreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canPop = !controller.canGoBack;
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          controller.popDir();
        },
        child: Scaffold(
          backgroundColor: AppThemeColors.pageBackground,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: controller.popDir,
            ),
            title: Text(
              controller.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: controller.refreshCurrent,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildBody()),
              _buildTransferBar(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      final err = controller.error.value;
      if (err != null && err.isNotEmpty && controller.files.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 34.w,
                  color: AppThemeColors.textMuted,
                ),
                SizedBox(height: 10.h),
                Text(
                  err,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppThemeColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton.icon(
                  onPressed: controller.refreshCurrent,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      }

      if (controller.loading.value && controller.files.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final files = controller.files;
      if (files.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 34.w,
                  color: AppThemeColors.textMuted,
                ),
                SizedBox(height: 10.h),
                Text(
                  '该目录暂无内容',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppThemeColors.textMuted,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '可以返回上级目录，或直接转存整个分享',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.refreshCurrent,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          itemCount: files.length,
          separatorBuilder: (_, _) => SizedBox(height: 8.h),
          itemBuilder: (context, index) => _SharePreviewTile(
            file: files[index],
            onTap: files[index].isDir
                ? () => controller.enterDir(files[index])
                : null,
          ),
        ),
      );
    });
  }

  Widget _buildTransferBar() {
    return Obx(() {
      final transferring = controller.transferring.value;
      return SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
          decoration: BoxDecoration(
            color: AppThemeColors.surface,
            border: Border(
              top: BorderSide(color: AppThemeColors.border, width: 1),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48.h,
            child: FilledButton.icon(
              onPressed: transferring ? null : controller.transferCurrent,
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppThemeColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: Icon(
                transferring
                    ? Icons.more_horiz_rounded
                    : Icons.cloud_download_rounded,
                size: 18.w,
              ),
              label: Text(
                transferring ? '提交中...' : '一键转存',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _SharePreviewTile extends StatelessWidget {
  const _SharePreviewTile({required this.file, this.onTap});

  final QuarkSharePreviewFile file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizeText = file.isDir
        ? '文件夹'
        : QuarkTransferHelper.formatFileSize(file.size);
    final subtitle = sizeText.isEmpty ? '文件' : sizeText;

    return Material(
      color: AppThemeColors.surface,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppThemeColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: file.isDir
                      ? const Color(0xFFFFF4E3)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  file.isDir
                      ? Icons.folder_rounded
                      : Icons.insert_drive_file_rounded,
                  color: file.isDir
                      ? const Color(0xFFE48700)
                      : AppThemeColors.textSecondary,
                  size: 22.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName.isEmpty ? '未命名' : file.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (file.isDir)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppThemeColors.textDisabled,
                  size: 22.w,
                ),
            ],
          ),
        ),
      ),
    );
  }
}