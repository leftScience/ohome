import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../services/app_update_service.dart';
import '../controllers/server_update_controller.dart';

class ServerUpdateView extends GetView<ServerUpdateController> {
  const ServerUpdateView({super.key});

  static const _githubUrl = 'https://github.com/leftScience/ohome';
  static const _qqNumber = '1184222624';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111218),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('关于oHome'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Obx(() {
        final isSuperAdmin = controller.isSuperAdmin;
        final info = controller.info.value;
        final check = controller.checkResult.value;
        final task = controller.currentTask.value;

        return Stack(
          children: [
            Positioned(
              top: -60.h,
              right: -40.w,
              child: Container(
                width: 320.w,
                height: 320.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 200.h,
              left: -80.w,
              child: Container(
                width: 280.w,
                height: 280.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF448AFF).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: controller.refreshPage,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 28.h),
                  children: [
                    _AboutHeroCard(
                      githubUrl: _githubUrl,
                      qqNumber: _qqNumber,
                      onCopyGithub: () =>
                          _copyText(label: 'GitHub 地址', value: _githubUrl),
                      onCopyQq: () => _copyText(label: 'QQ', value: _qqNumber),
                    ),
                    SizedBox(height: 10.h),
                    _SectionCard(
                      title: '应用更新',
                      trailing: FilledButton.icon(
                        onPressed:
                            controller.appUpdateChecking.value ||
                                controller.isAppUpdating
                            ? null
                            : () => controller.checkAppUpdate(
                                promptWhenAvailable: true,
                              ),
                        icon: controller.appUpdateChecking.value
                            ? SizedBox(
                                width: 14.w,
                                height: 14.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          controller.appUpdateChecking.value ? '检查中' : '检查更新',
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            label: '当前版本',
                            value: controller.appCurrentVersion,
                          ),
                          _InfoRow(
                            label: '最新版本',
                            value: controller.appLatestVersion,
                          ),
                          _InfoRow(
                            label: '更新状态',
                            value: controller.appUpdateStatusLabel,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            controller.appUpdateMessage,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          if (controller.isAppUpdating) ...[
                            SizedBox(height: 12.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999.r),
                              child: Obx(() {
                                final progress =
                                    Get.find<AppUpdateService>().progress.value;
                                return LinearProgressIndicator(
                                  value: progress == null
                                      ? null
                                      : progress / 100,
                                  minHeight: 8.h,
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSuperAdmin) ...[
                      SizedBox(height: 10.h),
                      _SectionCard(
                        title: '服务端更新',
                        trailing: FilledButton.icon(
                          onPressed: controller.checking.value
                              ? null
                              : controller.checkUpdate,
                          icon: controller.checking.value
                              ? SizedBox(
                                  width: 14.w,
                                  height: 14.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            controller.checking.value ? '检查中' : '检查更新',
                          ),
                        ),
                        child: controller.loading.value && info == null
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    label: '部署模式',
                                    value: info?.deployMode.isNotEmpty == true
                                        ? info!.deployMode
                                        : (check?.deployMode.isNotEmpty == true
                                              ? check!.deployMode
                                              : '--'),
                                  ),
                                  _InfoRow(
                                    label: '当前版本',
                                    value:
                                        info?.currentVersion.isNotEmpty == true
                                        ? info!.currentVersion
                                        : (check?.currentVersion.isNotEmpty ==
                                                  true
                                              ? check!.currentVersion
                                              : '--'),
                                  ),
                                  _InfoRow(
                                    label: 'Updater',
                                    value: info == null
                                        ? '--'
                                        : (info.updaterReachable ? '在线' : '离线'),
                                  ),
                                  _InfoRow(
                                    label: '最新版本',
                                    value:
                                        check?.latestVersion.isNotEmpty == true
                                        ? check!.latestVersion
                                        : '--',
                                  ),
                                  _InfoRow(
                                    label: '是否可更新',
                                    value: check == null
                                        ? '--'
                                        : (check.available ? '是' : '否'),
                                  ),
                                  if (controller.reconnecting.value) ...[
                                    SizedBox(height: 8.h),
                                    Text(
                                      '服务重启中，正在重连…',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                  ],
                                  if ((check?.releaseNotes ?? '')
                                      .isNotEmpty) ...[
                                    SizedBox(height: 6.h),
                                    Text(
                                      check!.releaseNotes,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 10.h),
                                  Text(
                                    '点击“检查更新”后，会先检查版本，再由你确认是否开始升级。',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.white60,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (controller.hasActiveTask &&
                                      task != null) ...[
                                    SizedBox(height: 16.h),
                                    Text(
                                      controller.serverTaskStatusLabel,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (controller
                                        .serverTaskMessage
                                        .isNotEmpty) ...[
                                      SizedBox(height: 6.h),
                                      Text(
                                        controller.serverTaskMessage,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.white70,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: 10.h),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        999.r,
                                      ),
                                      child: LinearProgressIndicator(
                                        value:
                                            (task.progress <= 0 ||
                                                    task.progress >= 100) &&
                                                !task.isTerminal
                                            ? null
                                            : task.progress / 100,
                                        minHeight: 8.h,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      '${task.progress}%',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _copyText({required String label, required String value}) async {
    await Clipboard.setData(ClipboardData(text: value));
    Get.snackbar('已复制', '$label 已复制到剪贴板');
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard({
    required this.githubUrl,
    required this.qqNumber,
    required this.onCopyGithub,
    required this.onCopyQq,
  });

  final String githubUrl;
  final String qqNumber;
  final VoidCallback onCopyGithub;
  final VoidCallback onCopyQq;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      Icons.home_work_rounded,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'oHome',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '家庭场景下的个人 / 家庭资源管理项目',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: _CompactContactTile(
                      icon: Icons.code_rounded,
                      iconColor: const Color(0xFF81C784),
                      title: '复制 GitHub',
                      onTap: onCopyGithub,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _CompactContactTile(
                      icon: Icons.forum_rounded,
                      iconColor: const Color(0xFF64B5F6),
                      title: '复制 QQ',
                      onTap: onCopyQq,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactContactTile extends StatelessWidget {
  const _CompactContactTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 16.w),
            SizedBox(width: 6.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64B5F6),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[SizedBox(width: 12.w), trailing!],
                ],
              ),
              SizedBox(height: 12.h),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
