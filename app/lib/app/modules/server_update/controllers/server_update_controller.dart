import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/server_update.dart';
import '../../../data/models/app_update_info.dart';
import '../../../data/models/server_update_models.dart';
import '../../../services/app_update_service.dart';
import '../../../services/auth_service.dart';

class ServerUpdateController extends GetxController {
  ServerUpdateController({
    ServerUpdateApi? serverUpdateApi,
    AppUpdateService? appUpdateService,
    AuthService? authService,
  }) : _serverUpdateApi = serverUpdateApi ?? Get.find<ServerUpdateApi>(),
       _appUpdateService = appUpdateService ?? Get.find<AppUpdateService>(),
       _authService = authService ?? Get.find<AuthService>();

  final ServerUpdateApi _serverUpdateApi;
  final AppUpdateService _appUpdateService;
  final AuthService _authService;

  final loading = false.obs;
  final checking = false.obs;
  final applying = false.obs;
  final reconnecting = false.obs;

  final appUpdateChecking = false.obs;

  final info = Rxn<ServerUpdateInfo>();
  final checkResult = Rxn<ServerUpdateCheckResult>();
  final currentTask = Rxn<ServerUpdateTask>();
  final appUpdateResult = Rxn<AppUpdateCheckResult>();
  final appCurrentVersionText = '--'.obs;

  Timer? _pollTimer;
  String? _activeTaskId;

  bool get isSuperAdmin => _authService.user.value?.isSuperAdmin ?? false;
  bool get isAppUpdating => _appUpdateService.isUpdating.value;

  bool get hasActiveTask =>
      currentTask.value != null && !(currentTask.value?.isTerminal ?? true);

  String get serverTaskStatusLabel {
    final task = currentTask.value;
    if (task == null) return '空闲';
    switch (task.status) {
      case 'queued':
        return '已排队';
      case 'checking':
        return '检查中';
      case 'downloading':
        return '下载中';
      case 'installing':
        return '安装中';
      case 'health_check':
        return '健康检查';
      case 'success':
        return '更新成功';
      case 'failed':
        return '更新失败';
      case 'rolled_back':
        return '已自动回退';
      default:
        return task.status.isNotEmpty ? task.status : '处理中';
    }
  }

  String get serverTaskMessage {
    final task = currentTask.value;
    if (task == null) return '';
    if (task.message.isNotEmpty) return task.message;
    if (task.step.isNotEmpty) return task.step;
    return '';
  }

  String get appCurrentVersion =>
      appUpdateResult.value?.currentVersion.trim().isNotEmpty == true
      ? appUpdateResult.value!.currentVersion
      : appCurrentVersionText.value;

  String get appLatestVersion {
    final result = appUpdateResult.value;
    if (result == null) return '--';
    switch (result.status) {
      case AppUpdateCheckStatus.available:
        return result.info?.displayVersion ?? '--';
      case AppUpdateCheckStatus.upToDate:
        return result.currentVersion;
      case AppUpdateCheckStatus.notConfigured:
      case AppUpdateCheckStatus.unsupported:
      case AppUpdateCheckStatus.disabledInDev:
        return '--';
    }
  }

  String get appUpdateStatusLabel {
    final result = appUpdateResult.value;
    if (result == null) return '未检查';
    switch (result.status) {
      case AppUpdateCheckStatus.available:
        return '发现新版本';
      case AppUpdateCheckStatus.upToDate:
        return '已是最新';
      case AppUpdateCheckStatus.notConfigured:
        return '未配置';
      case AppUpdateCheckStatus.unsupported:
        return '当前平台不支持';
      case AppUpdateCheckStatus.disabledInDev:
        return '开发环境已禁用';
    }
  }

  String get appUpdateMessage {
    final result = appUpdateResult.value;
    if (result == null) return '可在这里统一检查 App 更新。';
    switch (result.status) {
      case AppUpdateCheckStatus.available:
        final notes = (result.info?.releaseNotes ?? '').trim();
        return notes.isNotEmpty ? notes : '检测到新版本，点击“检查更新”后可直接选择安装。';
      case AppUpdateCheckStatus.upToDate:
        return '当前已是最新版本（${result.currentVersion}）。';
      case AppUpdateCheckStatus.notConfigured:
        return '未配置更新地址，请先设置 appUpdateManifestUrl。';
      case AppUpdateCheckStatus.unsupported:
        return '当前平台暂不支持在线更新。';
      case AppUpdateCheckStatus.disabledInDev:
        return '开发环境已禁用在线更新。';
    }
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadCurrentAppVersion());
    if (isSuperAdmin) {
      unawaited(loadInfo(silent: true));
    }
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshPage({bool silent = false}) async {
    await checkAppUpdate(silent: silent, promptWhenAvailable: false);
    if (isSuperAdmin) {
      await loadInfo(silent: silent);
    }
  }

  Future<void> loadInfo({bool silent = false}) async {
    if (!isSuperAdmin) return;
    if (!silent) loading.value = true;
    try {
      final result = await _serverUpdateApi.getInfo();
      info.value = result;
      currentTask.value = result.currentTask;
      if (result.currentTask != null &&
          !(result.currentTask?.isTerminal ?? true)) {
        _activeTaskId = result.currentTask!.id;
        _ensurePolling();
      }
      reconnecting.value = false;
    } catch (error) {
      if (!silent) {
        Get.snackbar('提示', '加载服务端更新信息失败：$error');
      }
    } finally {
      if (!silent) loading.value = false;
    }
  }

  Future<void> checkAppUpdate({
    bool silent = false,
    bool promptWhenAvailable = true,
  }) async {
    if (appUpdateChecking.value || isAppUpdating) return;

    appUpdateChecking.value = true;
    try {
      final result = await _appUpdateService.checkForUpdate();
      appUpdateResult.value = result;
      switch (result.status) {
        case AppUpdateCheckStatus.disabledInDev:
          if (!silent) {
            Get.snackbar('提示', '开发环境已禁用在线更新');
          }
          return;
        case AppUpdateCheckStatus.unsupported:
          if (!silent) {
            Get.snackbar('提示', '当前平台暂不支持在线更新');
          }
          return;
        case AppUpdateCheckStatus.notConfigured:
          if (!silent) {
            Get.snackbar('提示', '未配置更新地址，请先设置 appUpdateManifestUrl');
          }
          return;
        case AppUpdateCheckStatus.upToDate:
          if (!silent) {
            Get.snackbar('提示', '当前已是最新版本（${result.currentVersion}）');
          }
          return;
        case AppUpdateCheckStatus.available:
          if (!promptWhenAvailable) {
            if (!silent) {
              final latest = result.info?.displayVersion ?? '--';
              Get.snackbar('提示', '发现新版本：$latest');
            }
            return;
          }
          await startAvailableAppUpdate();
          return;
      }
    } catch (error) {
      if (!silent) {
        Get.snackbar('提示', '检查 App 更新失败：$error');
      }
    } finally {
      appUpdateChecking.value = false;
    }
  }

  Future<void> startAvailableAppUpdate() async {
    final info = appUpdateResult.value?.info;
    final currentVersion = appUpdateResult.value?.currentVersion ?? '--';
    if (info == null) {
      Get.snackbar('提示', '更新信息为空，请先重新检查');
      return;
    }
    await _showUpdateDialog(currentVersion: currentVersion, info: info);
  }

  Future<void> checkUpdate() async {
    if (!isSuperAdmin || checking.value) return;
    checking.value = true;
    try {
      final result = await _serverUpdateApi.check();
      checkResult.value = result;
      if (result.available) {
        await _showServerUpdateDialog(result);
      } else {
        Get.snackbar('提示', '当前后端已是最新版本（${result.currentVersion}）');
      }
    } catch (error) {
      Get.snackbar('提示', '检查服务端更新失败：$error');
    } finally {
      checking.value = false;
    }
  }

  Future<void> applyUpdate() async {
    if (!isSuperAdmin || applying.value || hasActiveTask) return;
    applying.value = true;
    try {
      final targetVersion = checkResult.value?.latestVersion;
      final result = await _serverUpdateApi.apply(targetVersion: targetVersion);
      _activeTaskId = result.taskId;
      await _fetchTask();
      _ensurePolling();
      Get.snackbar('提示', '已发起服务端更新任务');
    } catch (error) {
      Get.snackbar('提示', '发起服务端更新失败：$error');
    } finally {
      applying.value = false;
    }
  }

  void _ensurePolling() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchTask(),
    );
  }

  Future<void> _fetchTask() async {
    final taskId = _activeTaskId ?? currentTask.value?.id;
    if (taskId == null || taskId.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    try {
      final task = await _serverUpdateApi.getTask(taskId);
      currentTask.value = task;
      reconnecting.value = false;
      if (task.isTerminal) {
        _pollTimer?.cancel();
        _pollTimer = null;
        await loadInfo(silent: true);
      }
    } catch (_) {
      reconnecting.value = true;
      try {
        final latestInfo = await _serverUpdateApi.getInfo();
        info.value = latestInfo;
        if (latestInfo.currentTask != null) {
          currentTask.value = latestInfo.currentTask;
          _activeTaskId = latestInfo.currentTask!.id;
          if (latestInfo.currentTask!.isTerminal) {
            _pollTimer?.cancel();
            _pollTimer = null;
          }
        }
      } catch (_) {
        // keep reconnecting state and continue polling
      }
    }
  }

  Future<void> _showUpdateDialog({
    required String currentVersion,
    required AppUpdateInfo info,
  }) async {
    final notes = (info.releaseNotes ?? '').trim();
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：$currentVersion'),
            const SizedBox(height: 8),
            Text('最新版本：${info.displayVersion}'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新内容：'),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('更新'),
          ),
        ],
      ),
      barrierDismissible: !info.forceUpdate,
    );
    if (confirm != true) return;

    await _startOtaUpdate(info);
  }

  Future<void> _showServerUpdateDialog(ServerUpdateCheckResult result) async {
    final notes = result.releaseNotes.trim();
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('发现服务端新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${result.currentVersion}'),
            const SizedBox(height: 8),
            Text('最新版本：${result.latestVersion}'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新内容：'),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await applyUpdate();
  }

  Future<void> _startOtaUpdate(AppUpdateInfo info) async {
    Get.dialog<void>(
      PopScope(
        canPop: false,
        child: Obx(() {
          final progress = _appUpdateService.progress.value;
          final statusText = _appUpdateService.statusText.value;
          return AlertDialog(
            title: const Text('正在更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusText.isNotEmpty) Text(statusText),
                const SizedBox(height: 12),
                if (progress != null) ...[
                  LinearProgressIndicator(value: progress / 100),
                  const SizedBox(height: 8),
                  Text('${progress.toStringAsFixed(0)}%'),
                ] else
                  const LinearProgressIndicator(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _appUpdateService.cancelUpdate,
                child: const Text('取消'),
              ),
            ],
          );
        }),
      ),
      barrierDismissible: false,
    );

    try {
      await _appUpdateService.startUpdate(info);
      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
      Get.snackbar('提示', '安装包已准备完成，请按系统提示继续安装');
    } catch (error) {
      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
      Get.snackbar('提示', '$error');
    }
  }

  Future<void> _loadCurrentAppVersion() async {
    try {
      appCurrentVersionText.value = await _appUpdateService
          .getCurrentVersionLabel();
    } catch (_) {
      // ignore version read failures and keep placeholder
    }
  }
}
