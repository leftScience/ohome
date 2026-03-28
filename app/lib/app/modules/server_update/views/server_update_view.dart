import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../services/app_update_service.dart';
import '../controllers/server_update_controller.dart';

class ServerUpdateView extends GetView<ServerUpdateController> {
  const ServerUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新管理')),
      body: Obx(() {
        final isSuperAdmin = controller.isSuperAdmin;
        final info = controller.info.value;
        final check = controller.checkResult.value;
        final task = controller.currentTask.value;

        return RefreshIndicator(
          onRefresh: controller.refreshPage,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
            children: [
              _SectionCard(
                title: 'App 更新',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: '当前版本',
                      value: controller.appCurrentVersion,
                    ),
                    _InfoRow(label: '最新版本', value: controller.appLatestVersion),
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
                    SizedBox(height: 14.h),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: [
                        FilledButton.icon(
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
                        FilledButton.icon(
                          onPressed: controller.canStartAppUpdate
                              ? controller.startAvailableAppUpdate
                              : null,
                          icon: controller.isAppUpdating
                              ? SizedBox(
                                  width: 14.w,
                                  height: 14.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.system_update_alt_rounded),
                          label: const Text('立即更新'),
                        ),
                      ],
                    ),
                    if (controller.isAppUpdating) ...[
                      SizedBox(height: 12.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999.r),
                        child: Obx(() {
                          final progress =
                              Get.find<AppUpdateService>().progress.value;
                          return LinearProgressIndicator(
                            value: progress == null ? null : progress / 100,
                            minHeight: 8.h,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSuperAdmin) ...[
                SizedBox(height: 12.h),
                _SectionCard(
                  title: '服务端更新',
                  child: controller.loading.value && info == null
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(
                              label: '部署模式',
                              value: info?.deployMode.isNotEmpty == true
                                  ? info!.deployMode
                                  : '--',
                            ),
                            _InfoRow(
                              label: '当前版本',
                              value: info?.currentVersion.isNotEmpty == true
                                  ? info!.currentVersion
                                  : '--',
                            ),
                            _InfoRow(
                              label: 'Updater',
                              value: info?.updaterReachable == true
                                  ? '在线'
                                  : '离线',
                            ),
                            _InfoRow(
                              label: '最新版本',
                              value: check?.latestVersion.isNotEmpty == true
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
                            if ((check?.releaseNotes ?? '').isNotEmpty) ...[
                              SizedBox(height: 8.h),
                              Text(
                                check!.releaseNotes,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            SizedBox(height: 14.h),
                            Wrap(
                              spacing: 10.w,
                              runSpacing: 10.h,
                              children: [
                                FilledButton.icon(
                                  onPressed: controller.checking.value
                                      ? null
                                      : controller.checkUpdate,
                                  icon: controller.checking.value
                                      ? SizedBox(
                                          width: 14.w,
                                          height: 14.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: const Text('检查更新'),
                                ),
                                FilledButton.icon(
                                  onPressed:
                                      (check?.available == true &&
                                          !controller.applying.value &&
                                          !controller.hasActiveTask)
                                      ? controller.applyUpdate
                                      : null,
                                  icon: controller.applying.value
                                      ? SizedBox(
                                          width: 14.w,
                                          height: 14.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        )
                                      : const Icon(Icons.cloud_sync_outlined),
                                  label: const Text('立即更新'),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      (task?.canRollback == true &&
                                          !controller.rollingBack.value &&
                                          !controller.hasActiveTask)
                                      ? controller.rollback
                                      : null,
                                  icon: controller.rollingBack.value
                                      ? SizedBox(
                                          width: 14.w,
                                          height: 14.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        )
                                      : const Icon(Icons.undo_rounded),
                                  label: const Text('回滚'),
                                ),
                              ],
                            ),
                            if (task != null) ...[
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '任务进度',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    _InfoRow(label: '任务ID', value: task.id),
                                    _InfoRow(label: '状态', value: task.status),
                                    _InfoRow(
                                      label: '步骤',
                                      value: task.step.isNotEmpty
                                          ? task.step
                                          : '--',
                                    ),
                                    _InfoRow(
                                      label: '目标版本',
                                      value: task.targetVersion.isNotEmpty
                                          ? task.targetVersion
                                          : '--',
                                    ),
                                    if (task.message.isNotEmpty) ...[
                                      SizedBox(height: 4.h),
                                      Text(
                                        task.message,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: 12.h),
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
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
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
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
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
