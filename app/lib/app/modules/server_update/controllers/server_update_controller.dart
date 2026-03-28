import 'dart:async';

import 'package:get/get.dart';

import '../../../data/api/server_update.dart';
import '../../../data/models/server_update_models.dart';

class ServerUpdateController extends GetxController {
  ServerUpdateController({ServerUpdateApi? serverUpdateApi})
    : _serverUpdateApi = serverUpdateApi ?? Get.find<ServerUpdateApi>();

  final ServerUpdateApi _serverUpdateApi;

  final loading = false.obs;
  final checking = false.obs;
  final applying = false.obs;
  final rollingBack = false.obs;
  final reconnecting = false.obs;

  final info = Rxn<ServerUpdateInfo>();
  final checkResult = Rxn<ServerUpdateCheckResult>();
  final currentTask = Rxn<ServerUpdateTask>();

  Timer? _pollTimer;
  String? _activeTaskId;

  bool get hasActiveTask =>
      currentTask.value != null && !(currentTask.value?.isTerminal ?? true);

  @override
  void onInit() {
    super.onInit();
    loadInfo();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> loadInfo({bool silent = false}) async {
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

  Future<void> checkUpdate() async {
    if (checking.value) return;
    checking.value = true;
    try {
      final result = await _serverUpdateApi.check();
      checkResult.value = result;
      if (!result.available) {
        Get.snackbar('提示', '当前后端已是最新版本（${result.currentVersion}）');
      }
    } catch (error) {
      Get.snackbar('提示', '检查服务端更新失败：$error');
    } finally {
      checking.value = false;
    }
  }

  Future<void> applyUpdate() async {
    if (applying.value || hasActiveTask) return;
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

  Future<void> rollback() async {
    if (rollingBack.value || hasActiveTask) return;
    rollingBack.value = true;
    try {
      final result = await _serverUpdateApi.rollback(
        taskId: currentTask.value?.id,
      );
      _activeTaskId = result.taskId;
      await _fetchTask();
      _ensurePolling();
      Get.snackbar('提示', '已发起回滚任务');
    } catch (error) {
      Get.snackbar('提示', '发起回滚失败：$error');
    } finally {
      rollingBack.value = false;
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
}
