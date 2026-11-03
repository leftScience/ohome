import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../controllers/quark_login_controller.dart';

class QuarkLoginView extends GetView<QuarkLoginController> {
  const QuarkLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('夸克登录')),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
          children: [
            _buildLoginCard(
              icon: Icons.cookie_outlined,
              iconColor: const Color(0xFF00897B),
              title: '夸克 Cookie',
              updatedAt: controller.cookieUpdatedAt,
              status: controller.cookieConfigured ? '已保存' : '未保存',
              actionLabel: controller.cookieSaving.value
                  ? '保存中'
                  : controller.cookieConfigured
                  ? '重新登录'
                  : '网页登录',
              onPressed: controller.cookieSaving.value
                  ? null
                  : controller.openWebLogin,
              trailing: controller.cookieSaving.value
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.public_rounded),
            ),
            SizedBox(height: 16.h),
            _buildLoginCard(
              icon: Icons.tv_rounded,
              iconColor: const Color(0xFFF57C00),
              title: '夸克 TV',
              updatedAt: controller.tvUpdatedAt,
              status: controller.tvPending
                  ? '扫码中'
                  : controller.tvConfigured
                  ? '已登录'
                  : '未登录',
              actionLabel: controller.tvLoading.value
                  ? '处理中'
                  : controller.tvConfigured
                  ? '重新登录'
                  : controller.tvPending
                  ? '刷新二维码'
                  : 'TV扫码登录',
              onPressed: controller.tvLoading.value
                  ? null
                  : controller.openTvLogin,
              trailing: controller.tvLoading.value
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_2_rounded),
              subtitle: '302 直连播放会优先使用夸克 TV 转码接口',
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLoginCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String status,
    required String actionLabel,
    required VoidCallback? onPressed,
    required Widget trailing,
    DateTime? updatedAt,
    String? subtitle,
  }) {
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
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: iconColor),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatUpdatedAt(updatedAt),
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
          SizedBox(height: 12.h),
          Text(
            status,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppThemeColors.textSecondary,
            ),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              subtitle.trim(),
              style: TextStyle(
                fontSize: 12.sp,
                color: AppThemeColors.textDisabled,
              ),
            ),
          ],
          SizedBox(height: 16.h),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 48.h),
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            icon: trailing,
            label: Text(actionLabel),
          ),
        ],
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
