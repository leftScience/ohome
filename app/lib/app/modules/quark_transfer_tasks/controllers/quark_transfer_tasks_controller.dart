import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/quark.dart';
import '../../../data/api/quark_transfer.dart';
import '../../../data/api/quark_transfer_task.dart';
import '../../../data/models/quark_transfer_task_model.dart';
import '../../../utils/http_client.dart';
import '../../quark_sync/models/quark_sync_form_draft.dart';
import '../../quark_sync/views/quark_sync_form_view.dart';

class QuarkTransferTasksController extends GetxController {
  QuarkTransferTasksController({
    QuarkTransferTaskApi? taskApi,
    QuarkTransferRepository? transferRepository,
    WebdavApi? webdavApi,
  }) : _taskApi = taskApi ?? Get.find<QuarkTransferTaskApi>(),
       _transferRepository = transferRepository ?? QuarkTransferRepository(),
       _webdavApi = webdavApi ?? Get.find<WebdavApi>();

  static const int _pageSize = 20;

  final QuarkTransferTaskApi _taskApi;
  final QuarkTransferRepository _transferRepository;
  final WebdavApi _webdavApi;

  final scrollController = ScrollController();
  final tasks = <QuarkTransferTaskModel>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final statusFilter = ''.obs;
  final deletingTaskIds = <int>{}.obs;
  final submittingManualTask = false.obs;

  int _page = 1;
  int _loadToken = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_handleScroll);
    loadTasks(refresh: true);
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadTasks({required bool refresh, bool silent = false}) async {
    late final int token;
    if (refresh) {
      if (loading.value) return;
      token = ++_loadToken;
      _page = 1;
      hasMore.value = true;
      loading.value = true;
      loadingMore.value = false;
    } else {
      if (loading.value || loadingMore.value || !hasMore.value) {
        return;
      }
      token = _loadToken;
      loadingMore.value = true;
    }

    try {
      final result = await _taskApi.getTaskList(
        status: _resolvedStatusFilter,
        page: _page,
        limit: _pageSize,
        showErrorToast: !silent,
      );
      if (token != _loadToken) return;

      if (refresh) {
        tasks.assignAll(result.records);
      } else {
        tasks.addAll(result.records);
      }

      hasMore.value = tasks.length < result.total;
      if (hasMore.value) {
        _page += 1;
      }
    } catch (_) {
      return;
    } finally {
      if (token == _loadToken) {
        if (refresh) {
          loading.value = false;
        } else {
          loadingMore.value = false;
        }
      }
    }
  }

  Future<void> refreshList() => loadTasks(refresh: true);

  void changeStatusFilter(String status) {
    if (statusFilter.value == status) return;
    statusFilter.value = status;
    unawaited(loadTasks(refresh: true));
  }

  Future<List<QuarkConfigOption>> fetchSavePathOptions() async {
    final configs = await _webdavApi.fetchMoveTargets();
    final options = configs
        .where((item) {
          final path = item.rootPath.trim();
          final application = item.application.trim().toLowerCase();
          return path.isNotEmpty && path != '/' && application != 'upload';
        })
        .toList(growable: true);
    options.sort((left, right) {
      final leftLabel = left.remark.isNotEmpty ? left.remark : left.application;
      final rightLabel = right.remark.isNotEmpty
          ? right.remark
          : right.application;
      return leftLabel.toLowerCase().compareTo(rightLabel.toLowerCase());
    });
    return options;
  }

  Future<bool> submitManualTransfer({
    required String title,
    required String shareUrl,
    required String savePath,
  }) async {
    if (submittingManualTask.value) return false;

    final taskTitle = title.trim();
    final link = shareUrl.trim();
    final path = savePath.trim();
    if (taskTitle.isEmpty || link.isEmpty || path.isEmpty) {
      Get.snackbar('提示', '请填写标题、链接和转存路径');
      return false;
    }

    submittingManualTask.value = true;
    try {
      await _transferRepository.transferOnce(
        shareUrl: link,
        savePath: path,
        application: '',
        resourceName: taskTitle,
      );
      Get.snackbar('提示', '已加入转存任务');
      await loadTasks(refresh: true);
      return true;
    } on ApiException catch (e) {
      final message = e.message.trim();
      Get.snackbar('转存失败', message.isEmpty ? '请稍后重试' : message);
      return false;
    } catch (_) {
      Get.snackbar('转存失败', '请稍后重试');
      return false;
    } finally {
      submittingManualTask.value = false;
    }
  }

  Future<void> openSyncForm(QuarkTransferTaskModel task) async {
    if (!task.canGoSync) return;
    await Get.to<bool>(
      () => QuarkSyncFormView(
        initialDraft: QuarkSyncFormDraft(
          taskName: task.displayName,
          shareUrl: task.shareUrl,
          savePath: task.savePath,
          application: task.application.isEmpty ? null : task.application,
        ),
      ),
    );
  }

  bool isDeleting(int? id) => id != null && deletingTaskIds.contains(id);

  Future<void> confirmDelete(QuarkTransferTaskModel task) async {
    final id = task.id;
    if (id == null || isDeleting(id)) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除转存任务'),
        content: Text(
          task.isProcessing
              ? '删除后只会移除任务记录，不会中止后台转存。确定继续吗？'
              : '确定删除 ${task.displayName} 这条转存任务记录吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    deletingTaskIds.add(id);
    try {
      await _taskApi.deleteTask(id);
      Get.snackbar('提示', '转存任务已删除');
      await loadTasks(refresh: true);
    } catch (_) {
      return;
    } finally {
      deletingTaskIds.remove(id);
    }
  }

  String get _resolvedStatusFilter => statusFilter.value.trim();

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 200) {
      loadTasks(refresh: false, silent: true);
    }
  }
}
