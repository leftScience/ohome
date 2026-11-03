import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/media_history_entry.dart';
import '../../../data/storage/app_env_storage.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../../../services/history_playback_service.dart';
import '../../../services/media_history_service.dart';
import '../../../services/playback_entry_service.dart';
import '../../../utils/app_env.dart';
import '../../../utils/quark_error_helper.dart';
import '../../messages/controllers/messages_controller.dart';
import '../../music_player/controllers/music_player_controller.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController({
    AuthService? authService,
    MediaHistoryService? mediaHistoryService,
    HistoryPlaybackService? historyPlaybackService,
    PlaybackEntryService? entryService,
    MessagesController? messagesController,
    AppEnvStorage? appEnvStorage,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _mediaHistoryService =
           mediaHistoryService ?? Get.find<MediaHistoryService>(),
       _historyPlaybackService =
           historyPlaybackService ?? Get.find<HistoryPlaybackService>(),
       _entryService = entryService ?? Get.find<PlaybackEntryService>(),
       _messagesController =
           messagesController ?? Get.find<MessagesController>(),
       _appEnvStorage = appEnvStorage ?? AppEnvStorage();

  final AuthService _authService;
  final MediaHistoryService _mediaHistoryService;
  final HistoryPlaybackService _historyPlaybackService;
  final PlaybackEntryService _entryService;
  final MessagesController _messagesController;
  final AppEnvStorage _appEnvStorage;

  final recentHistory = Rxn<MediaHistoryEntry>();
  final recentHistoryLoading = false.obs;
  final recentHistoryOpening = false.obs;
  final initializingAudioPlayback = false.obs;

  bool _appWentBackground = false;
  bool _shouldReloadHistoryOnNextPlayerOpen = false;

  String get name => _authService.user.value?.name ?? '';
  bool get isLoggedIn =>
      _authService.isLoggedIn && _authService.user.value != null;
  int get unreadMessageCount => _messagesController.unreadCount.value;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    refreshRecentHistory();
    unawaited(
      _messagesController.loadMessages(refresh: true, showErrorToast: false),
    );
    unawaited(_maybeShowDefaultBackendNotice());
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

  /// 播放音频（播客）但不跳转页面
  /// 用于首页播放条的播放按钮点击
  Future<bool> playAudioWithoutNavigation(MediaHistoryEntry entry) async {
    final applicationType = entry.applicationType.trim().toLowerCase();
    if (applicationType != 'music') {
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
      Get.snackbar('提示', '播放失败：${QuarkErrorHelper.toFriendlyMessage(e)}');
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

  Future<void> _maybeShowDefaultBackendNotice() async {
    if (!_authService.consumeDefaultBackendNoticeFlag()) {
      return;
    }
    final currentUser = _authService.user.value;
    if (currentUser == null || currentUser.isSuperAdmin) {
      return;
    }
    if (!AppEnv.instance.isUsingDefaultApiBaseUrl) {
      return;
    }
    if (await _appEnvStorage.readDefaultBackendNoticeDismissed()) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (isClosed) return;

    final action = await Get.dialog<_DefaultBackendNoticeAction>(
      AlertDialog(
        title: const Text('提示'),
        content: const Text(
          '你目前使用的是开发者提供的免费后端接口。如需稳定的后端，以及数据的绝对安全，请自部署后端服务器并进行连接。部署方式请参考关于oHome-github的文档',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(result: _DefaultBackendNoticeAction.close);
            },
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Get.back(result: _DefaultBackendNoticeAction.dismissForever);
            },
            child: const Text('永久关闭'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (action == _DefaultBackendNoticeAction.dismissForever) {
      await _appEnvStorage.writeDefaultBackendNoticeDismissed(true);
    }
  }
}

enum _DefaultBackendNoticeAction { close, dismissForever }
