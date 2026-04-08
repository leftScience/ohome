import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/api/todo.dart';
import '../../../data/models/media_history_entry.dart';
import '../../../data/models/todo_item_model.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../../../services/history_playback_service.dart';
import '../../../services/media_history_service.dart';
import '../../../services/playback_entry_service.dart';
import '../../messages/controllers/messages_controller.dart';
import '../../music_player/controllers/music_player_controller.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController({
    AuthService? authService,
    MediaHistoryService? mediaHistoryService,
    HistoryPlaybackService? historyPlaybackService,
    PlaybackEntryService? entryService,
    TodoApi? todoApi,
    MessagesController? messagesController,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _mediaHistoryService =
           mediaHistoryService ?? Get.find<MediaHistoryService>(),
       _historyPlaybackService =
           historyPlaybackService ?? Get.find<HistoryPlaybackService>(),
       _entryService = entryService ?? Get.find<PlaybackEntryService>(),
       _todoApi = todoApi ?? Get.find<TodoApi>(),
       _messagesController =
           messagesController ?? Get.find<MessagesController>();

  final AuthService _authService;
  final MediaHistoryService _mediaHistoryService;
  final HistoryPlaybackService _historyPlaybackService;
  final PlaybackEntryService _entryService;
  final TodoApi _todoApi;
  final MessagesController _messagesController;

  final recentHistory = Rxn<MediaHistoryEntry>();
  final recentHistoryLoading = false.obs;
  final recentHistoryOpening = false.obs;
  final initializingAudioPlayback = false.obs;
  final todoItems = <TodoItemModel>[].obs;
  final todoLoading = false.obs;
  final todoSubmitting = false.obs;
  final todoReordering = false.obs;
  final processingTodoIds = <int>{}.obs;
  final completedExpanded = false.obs;

  bool _appWentBackground = false;
  bool _shouldReloadHistoryOnNextPlayerOpen = false;
  int _todoLoadToken = 0;

  String get name => _authService.user.value?.name ?? '';
  bool get isLoggedIn =>
      _authService.isLoggedIn && _authService.user.value != null;
  int get unreadMessageCount => _messagesController.unreadCount.value;
  int get pendingTodoCount => todoItems.where((item) => !item.completed).length;
  bool get canReorderPendingTodos =>
      !todoLoading.value && !todoSubmitting.value && !todoReordering.value;
  List<TodoItemModel> get pendingTodoItems =>
      todoItems.where((item) => !item.completed).toList(growable: false);
  List<TodoItemModel> get completedTodoItems =>
      todoItems.where((item) => item.completed).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    refreshRecentHistory();
    unawaited(loadTodos(showErrorToast: false));
    unawaited(
      _messagesController.loadMessages(refresh: true, showErrorToast: false),
    );
  }



  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _appWentBackground = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _appWentBackground) {
      _appWentBackground = false;
      _shouldReloadHistoryOnNextPlayerOpen = true;
    }
  }



  Future<void> refreshRecentHistory() async {
    if (!_authService.isLoggedIn || _authService.user.value == null) {
      recentHistory.value = null;
      recentHistoryLoading.value = false;
      return;
    }

    recentHistoryLoading.value = true;
    try {
      final result = await _mediaHistoryService.fetchMostRecent();
      recentHistory.value = result;
    } catch (_) {
      recentHistory.value = null;
    } finally {
      recentHistoryLoading.value = false;
    }
  }

  Future<void> loadTodos({bool showErrorToast = true}) async {
    if (!isLoggedIn) {
      todoItems.clear();
      todoLoading.value = false;
      return;
    }

    final token = ++_todoLoadToken;
    todoLoading.value = true;
    try {
      final result = await _todoApi.getTodoList(
        page: 1,
        limit: 200,
        showErrorToast: showErrorToast,
      );
      if (token != _todoLoadToken) return;
      todoItems.assignAll(_sortTodoItems(result.records));
    } catch (_) {
      return;
    } finally {
      if (token == _todoLoadToken) {
        todoLoading.value = false;
      }
    }
  }

  Future<bool> addTodoItem(String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      Get.snackbar('提示', '待办标题不能为空');
      return false;
    }
    if (todoSubmitting.value) return false;

    todoSubmitting.value = true;
    try {
      final item = await _todoApi.addTodoItem(title: normalized);
      _upsertTodoItem(item);
      return true;
    } catch (_) {
      return false;
    } finally {
      todoSubmitting.value = false;
    }
  }

  Future<bool> updateTodoTitle({
    required TodoItemModel item,
    required String title,
  }) async {
    final id = item.id;
    if (id == null || isProcessingTodo(id)) return false;

    final normalized = title.trim();
    if (normalized.isEmpty) {
      Get.snackbar('提示', '待办标题不能为空');
      return false;
    }

    processingTodoIds.add(id);
    try {
      final updated = await _todoApi.updateTodoItem(id: id, title: normalized);
      _upsertTodoItem(updated);
      return true;
    } catch (_) {
      return false;
    } finally {
      processingTodoIds.remove(id);
    }
  }

  Future<bool> toggleTodoCompleted(TodoItemModel item) async {
    final id = item.id;
    if (id == null || isProcessingTodo(id)) return false;

    processingTodoIds.add(id);
    try {
      final updated = await _todoApi.updateTodoStatus(
        id: id,
        completed: !item.completed,
      );
      _upsertTodoItem(updated);
      return true;
    } catch (_) {
      return false;
    } finally {
      processingTodoIds.remove(id);
    }
  }

  Future<bool> deleteTodoItem(TodoItemModel item) async {
    final id = item.id;
    if (id == null || isProcessingTodo(id)) return false;

    processingTodoIds.add(id);
    try {
      await _todoApi.deleteTodoItem(id);
      todoItems.removeWhere((element) => element.id == id);
      return true;
    } catch (_) {
      return false;
    } finally {
      processingTodoIds.remove(id);
    }
  }

  Future<bool> reorderPendingTodos({
    required int oldIndex,
    required int newIndex,
  }) async {
    if (!canReorderPendingTodos) return false;

    final pending = pendingTodoItems.toList(growable: true);
    if (pending.length <= 1) return false;
    if (oldIndex < 0 || oldIndex >= pending.length) return false;

    var targetIndex = newIndex;
    if (targetIndex > pending.length) targetIndex = pending.length;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= pending.length) return false;
    if (oldIndex == targetIndex) return false;

    final moved = pending.removeAt(oldIndex);
    pending.insert(targetIndex, moved);

    final previous = todoItems.toList(growable: false);
    final reorderedPending = _assignPendingSortOrders(pending);
    todoItems.assignAll(<TodoItemModel>[
      ...reorderedPending,
      ...completedTodoItems,
    ]);

    todoReordering.value = true;
    try {
      final ids = reorderedPending
          .map((item) => item.id)
          .whereType<int>()
          .toList(growable: false);
      await _todoApi.reorderTodoItems(ids: ids);
      return true;
    } catch (_) {
      todoItems.assignAll(previous);
      return false;
    } finally {
      todoReordering.value = false;
    }
  }

  bool isProcessingTodo(int? id) =>
      id != null && processingTodoIds.contains(id);

  void toggleCompletedExpanded() {
    completedExpanded.value = !completedExpanded.value;
  }

  Future<void> openRecentHistory() async {
    if (recentHistoryOpening.value) return;
    final entry = recentHistory.value;
    if (entry == null) return;

    recentHistoryOpening.value = true;
    try {
      final opened = await _historyPlaybackService.navigateToEntry(entry);
      if (opened) {
        await refreshRecentHistory();
      }
    } finally {
      recentHistoryOpening.value = false;
    }
  }

  Future<void> openActiveAudioPlayer() async {
    if (recentHistoryOpening.value) return;
    final player = Get.isRegistered<MusicPlayerController>()
        ? Get.find<MusicPlayerController>()
        : null;
    final hasActiveAudio = player != null && player.tracks.isNotEmpty;
    if (hasActiveAudio) {
      _shouldReloadHistoryOnNextPlayerOpen = false;
      if (Get.currentRoute == Routes.MUSIC_PLAYER) return;
      await Get.toNamed(Routes.MUSIC_PLAYER);
      return;
    }

    if (_shouldReloadHistoryOnNextPlayerOpen) {
      await _openFromLatestHistoryAfterResume();
      return;
    }

    if (player == null || player.tracks.isEmpty) return;
    if (Get.currentRoute == Routes.MUSIC_PLAYER) return;

    await Get.toNamed(Routes.MUSIC_PLAYER);
  }

  Future<void> openMessages() async {
    await Get.toNamed(Routes.MESSAGES);
    await _messagesController.loadMessages(
      refresh: true,
      showErrorToast: false,
    );
  }

  /// 播放音频（音乐/有声书）但不跳转页面
  /// 用于首页播放条的播放按钮点击
  Future<bool> playAudioWithoutNavigation(MediaHistoryEntry entry) async {
    final applicationType = entry.applicationType.trim().toLowerCase();
    // 只支持音乐和有声音频
    if (applicationType != 'music' && applicationType != 'xiaoshuo') {
      return false;
    }

    // 检查是否已有相同类型的活跃音频会话
    final player = Get.isRegistered<MusicPlayerController>()
        ? Get.find<MusicPlayerController>()
        : null;

    if (player != null &&
        player.tracks.isNotEmpty &&
        player.applicationType.trim().toLowerCase() == applicationType &&
        player.folderPath.value == entry.folderPath) {
      // 如果已经是相同的播放列表，只切换播放状态
      await player.togglePlayback();
      return true;
    }

    // 需要加载新的播放列表并播放
    initializingAudioPlayback.value = true;
    try {
      recentHistoryOpening.value = true;

      // 注册或重新初始化播放器控制器
      if (player == null) {
        Get.put(MusicPlayerController());
      }

      final musicController = Get.find<MusicPlayerController>();

      // 清空当前播放会话
      await musicController.clearPlaybackSession();

      // 构建路由参数并加载播放列表
      final launch = await _entryService.buildFromHistoryEntry(entry);
      if (launch == null) {
        Get.snackbar('提示', '无法加载播放内容');
        return false;
      }

      // 处理路由参数并等待播放器完成初始化
      await musicController.handleRouteArguments(launch.arguments);

      // 刷新历史记录以更新UI
      await refreshRecentHistory();

      return true;
    } catch (e) {
      Get.snackbar('提示', '播放失败：$e');
      return false;
    } finally {
      recentHistoryOpening.value = false;
      initializingAudioPlayback.value = false;
    }
  }

  Future<void> _openFromLatestHistoryAfterResume() async {
    recentHistoryOpening.value = true;
    try {
      final latest = await _mediaHistoryService.fetchMostRecent();
      if (latest == null) {
        _shouldReloadHistoryOnNextPlayerOpen = false;
        return;
      }

      final opened = await _historyPlaybackService.navigateToEntry(latest);
      if (!opened) return;

      _shouldReloadHistoryOnNextPlayerOpen = false;
      await refreshRecentHistory();
    } catch (_) {
      Get.snackbar('提示', '加载最近播放记录失败，请稍后重试');
    } finally {
      recentHistoryOpening.value = false;
    }
  }



  void _upsertTodoItem(TodoItemModel item) {
    final next = todoItems.toList(growable: true);
    final index = next.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    todoItems.assignAll(_sortTodoItems(next));
  }

  List<TodoItemModel> _sortTodoItems(List<TodoItemModel> items) {
    final next = List<TodoItemModel>.from(items);
    next.sort(_compareTodoItem);
    return next;
  }

  int _compareTodoItem(TodoItemModel a, TodoItemModel b) {
    if (a.completed != b.completed) {
      return a.completed ? 1 : -1;
    }

    if (!a.completed) {
      if (a.sortOrder != 0 && b.sortOrder != 0) {
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        if (bySort != 0) return bySort;
      } else if (a.sortOrder != 0) {
        return -1;
      } else if (b.sortOrder != 0) {
        return 1;
      }
    }

    final aTime = a.completed
        ? (a.completedAt ?? a.updatedAt ?? a.createdAt)
        : (a.updatedAt ?? a.createdAt);
    final bTime = b.completed
        ? (b.completedAt ?? b.updatedAt ?? b.createdAt)
        : (b.updatedAt ?? b.createdAt);

    if (aTime != null && bTime != null) {
      final byTime = bTime.compareTo(aTime);
      if (byTime != 0) return byTime;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }

    final aId = a.id ?? 0;
    final bId = b.id ?? 0;
    return bId.compareTo(aId);
  }

  List<TodoItemModel> _assignPendingSortOrders(List<TodoItemModel> items) {
    return items
        .asMap()
        .entries
        .map(
          (entry) => entry.value.copyWithRaw(<String, dynamic>{
            'sortOrder': (entry.key + 1) * 1024,
          }),
        )
        .toList(growable: false);
  }


}
