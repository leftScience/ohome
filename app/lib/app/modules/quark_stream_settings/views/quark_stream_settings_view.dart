import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../controllers/quark_stream_settings_controller.dart';

class QuarkStreamSettingsView extends GetView<QuarkStreamSettingsController> {
  const QuarkStreamSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('夸克播放')),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
          children: [
            SizedBox(height: 16.h),
            _buildModeCard(),
          ],
        );
      }),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: Obx(() {
          return FilledButton.icon(
            onPressed: controller.saving.value ? null : controller.save,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 50.h),
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            icon: controller.saving.value
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(controller.saving.value ? '保存中' : '保存配置'),
          );
        }),
      ),
    );
  }

  Widget _buildModeCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppThemeColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: AppThemeColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '代理模式（全局）',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatUpdatedAt(
                        controller.updatedAtFor(
                          QuarkStreamSettingsController.webProxyModeKey,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Obx(() {
            return Column(
              children: [
                _buildModeOption(
                  value: 'native_proxy',
                  title: '本地代理（推荐）',
                  selected: controller.selectedMode.value == 'native_proxy',
                ),
                SizedBox(height: 10.h),
                _buildModeOption(
                  value: '302_redirect',
                  title: '302 转码',
                  selected: controller.selectedMode.value == '302_redirect',
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String value,
    required String title,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.selectedMode.value = value,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: selected
                ? AppThemeColors.primary.withValues(alpha: 0.12)
                : AppThemeColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected
                  ? AppThemeColors.primary.withValues(alpha: 0.5)
                  : AppThemeColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppThemeColors.primary
                        : AppThemeColors.borderStrong,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 10.w : 0,
                    height: selected ? 10.w : 0,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppThemeColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return '尚未保存';
    return '最近保存：${_formatDate(updatedAt)}';
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
