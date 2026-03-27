import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../data/api/config.dart';
import '../../../data/api/quark.dart';
import '../../../data/models/quark_file_entry.dart';
import '../../../services/playback_entry_service.dart';
import '../../../services/video_cast_service.dart';
import '../../../utils/app_env.dart';
import '../../../utils/media_path.dart';
import '../../../data/storage/playback_progress_storage.dart';
import '../../../data/storage/skip_settings_storage.dart';
import '../../video_cast/views/video_cast_view.dart';
import '../../music_player/controllers/music_player_controller.dart';

enum _InitialEpisodeSource { none, preferred, explicitResume, storedResume }

enum FullscreenFitMode { contain, cover }

class PlayerController extends GetxController {
  PlayerController({
    ConfigApi? configApi,
    PlaybackProgressStorage? progressStorage,
    SkipSettingsStorage? skipSettingsStorage,
    String applicationType = 'tv',
  }) : _configApi = configApi ?? Get.find<ConfigApi>(),
       _providedProgressStorage = progressStorage,
       _defaultApplicationType = applicationType,
       _applicationType = applicationType,
       _skipStorage =
           skipSettingsStorage ??
           SkipSettingsStorage(keyPrefix: 'video_skip_settings_');

  final player = Player();
  late final VideoController videoController = VideoController(player);

  final currentIndex = 0.obs;
  final episodesAscending = true.obs;

  final resourceTitle = '影视'.obs;
  final resourceIntro = ''.obs;

  final episodes = <Episode>[].obs;
  int _initialIndex = 0;

  final PlaybackProgressStorage? _providedProgressStorage;
  late PlaybackProgressStorage _progressStorage;
  final String _defaultApplicationType;
  final ConfigApi _configApi;
  final SkipSettingsStorage _skipStorage;
  final WebdavApi _webdavApi = Get.find<WebdavApi>();
  final VideoCastService _castService = Get.find<VideoCastService>();
  final RxDouble videoAspectRatio = (16 / 9).obs;
  final RxBool isPortraitVideo = false.obs;
  final Rxn<Duration> scrubPreview = Rxn<Duration>();
  final RxBool isScrubbing = false.obs;
  final RxDouble playbackRate = 1.0.obs;
  final RxBool isFullscreen = false.obs;
  final RxBool isSpeedBoosting = false.obs;
  final RxDouble speedBoostRate = 3.0.obs;
  final RxBool isControlsLocked = false.obs;
  final Rx<Duration> skipIntro = Duration.zero.obs;
  final Rx<Duration> skipOutro = Duration.zero.obs;
  final Rx<FullscreenFitMode> fullscreenFitMode = FullscreenFitMode.contain.obs;
  final RxBool isLoadingPlaylist = false.obs;
  final RxString globalPlaybackProxyMode = _defaultPlaybackProxyMode.obs;
  final RxnString currentPlaybackProxyModeOverride = RxnString();

  bool _autoNextRunning = false;
  Duration? _pendingSeek;
  Duration? _lastPersistedPosition;
  String? _currentEpisodePath;
  String? _currentEpisodeUrl;
  String? _openingEpisodePath;
  String? _openingEpisodeUrl;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<int?>? _widthSubscription;
  StreamSubscription<int?>? _heightSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  String? _folderPath;
  String? _resumeEpisodePath;
  Duration? _resumePosition;
  Timer? _scrubTimer;
  double _scrubViewWidth = 0;
  double _scrubDeltaDx = 0;
  Duration _scrubStartPos = Duration.zero;
  Duration _scrubDuration = Duration.zero;
  bool _ready = false;
  String? _lastArgsKey;
  String _applicationType;
  bool _playerConfigured = false;
  double? _rateBeforeBoost;
  bool _skipSettingsLoaded = false;
  String? _skipFolderKey;
  bool _outroSkipTriggered = false;
  int _routeArgsVersion = 0;
  bool _blockPlaybackOnOpen = false;
  Timer? _castProgressTimer;
  Duration? _lastCastPersistedPosition;

  bool get isPlayletMode => _applicationType.trim().toLowerCase() == 'playlet';
  bool get isCasting => _castService.isCasting.value;
  String get castingDeviceName => _castService.currentDeviceName.value.trim();
  String get effectivePlaybackProxyMode =>
      currentPlaybackProxyModeOverride.value ?? globalPlaybackProxyMode.value;
  String get effectivePlaybackProxyModeLabel {
    switch (effectivePlaybackProxyMode) {
      case '302_redirect':
        return '302';
      default:
        return '本地代理';
    }
  }

  bool get canSwitchCurrentPlaybackProxyMode {
    final current = _currentEpisode;
    return current != null && _supportsPlaybackProxyMode(current);
  }

  bool get canCastCurrentEpisode => currentCastUrl != null;

  String? get currentCastUrl {
    final current = _currentEpisode;
    if (current == null) return null;
    final direct = current.url?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final path = current.path?.trim();
    if (path == null || path.isEmpty) return null;
    final streamUrl = _buildStreamUrl(path);
    if (streamUrl == null || streamUrl.isEmpty) return null;
    final uri = Uri.parse(streamUrl);
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'cast': 'true',
          },
        )
        .toString();
  }

  String get currentCastSourcePath => _currentEpisode?.path?.trim() ?? '';

  String get currentCastTitle {
    final current = _currentEpisode;
    final title = current?.title.trim() ?? '';
    if (title.isNotEmpty) return title;
    final subTitle = current?.subTitle.trim() ?? '';
    if (subTitle.isNotEmpty) return subTitle;
    final resource = resourceTitle.value.trim();
    if (resource.isNotEmpty) return resource;
    return '当前视频';
  }

  Episode? get _currentEpisode {
    final index = currentIndex.value;
    if (index < 0 || index >= episodes.length) return null;
    return episodes[index];
  }

  @override
  void onInit() {
    super.onInit();
    _progressStorage =
        _providedProgressStorage ??
        PlaybackProgressStorage(applicationType: _applicationType);
    unawaited(_loadGlobalPlaybackProxyMode());
    handleRouteArguments(Get.arguments);
  }

  @override
  void onReady() {
    super.onReady();
    _playingSubscription = player.stream.playing.listen(_handlePlayingChanged);
    _completedSubscription = player.stream.completed.listen(
      _handleCompletedChanged,
    );
    _rateSubscription = player.stream.rate.listen((rate) {
      playbackRate.value = rate;
    });
    _positionSubscription = player.stream.position.listen(
      _handlePositionUpdate,
    );
    _durationSubscription = player.stream.duration.listen((_) {
      _tryApplyPendingSeek();
    });
    _widthSubscription = player.stream.width.listen((_) {
      _updateAspectRatio();
    });
    _heightSubscription = player.stream.height.listen((_) {
      _updateAspectRatio();
    });
    _videoParamsSubscription = player.stream.videoParams.listen((_) {
      _updateAspectRatio();
    });
    _ready = true;
    if (episodes.isNotEmpty) {
      unawaited(_startInitialPlayback());
    }
  }

  Future<void> _startInitialPlayback() async {
    await _configurePlayerIfNeeded();
    if (isCasting) {
      await stopPlayback();
      return;
    }
    if (episodes.isNotEmpty && !_blockPlaybackOnOpen) {
      await playAt(_initialIndex);
    }
  }

  Future<void> _configurePlayerIfNeeded() async {
    if (_playerConfigured) return;
    _playerConfigured = true;
  }

  void handleRouteArguments(dynamic args) {
    unawaited(_handleRouteArgumentsInternal(args));
  }

  Future<void> _handleRouteArgumentsInternal(dynamic args) async {
    if (args is! Map) return;

    final key = _argsKey(args);
    if (_lastArgsKey == key) return;
    _lastArgsKey = key;
    final version = ++_routeArgsVersion;

    _applicationType = _defaultApplicationType;
    _applyArgs(args);
    _progressStorage =
        _providedProgressStorage ??
        PlaybackProgressStorage(applicationType: _applicationType);
    if (_shouldLoadCollectionOnEnter(args)) {
      await _loadEpisodesOnEnter(args, version);
    } else if (_hasExplicitInitialTarget(args)) {
      await _resolveExplicitPlaybackTarget(args, version);
    } else if (!_hasExplicitResumeTarget()) {
      await _restorePlaybackTargetFromStorage(version);
    }
    if (_routeArgsVersion != version) return;
    if (_ready && episodes.isNotEmpty && !_blockPlaybackOnOpen) {
      await _startInitialPlayback();
    }
  }

  String _argsKey(Map args) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final app = (args['applicationType'] as String?)?.trim() ?? '';
    final folder = (args['folderPath'] as String?)?.trim() ?? '';
    final title = (args['title'] as String?)?.trim() ?? '';
    final rawEpisodes = args['episodes'];
    final count = rawEpisodes is List ? rawEpisodes.length : 0;
    final initialIndex = parseInt(args['initialIndex']);
    final preferredPath =
        (args[PlaybackEntryConfig.preferredItemPathKey] as String?)?.trim() ??
        '';
    final resume = (args['resumeEpisodePath'] as String?)?.trim() ?? '';
    final resumePositionMs = parseInt(args['resumePositionMs']);
    final loadOnEnter =
        args[PlaybackEntryConfig.loadCollectionOnEnterKey] == true ? '1' : '0';
    return '$app|$folder|$title|$count|$initialIndex|$preferredPath|$resume|$resumePositionMs|$loadOnEnter';
  }

  void _handlePlayingChanged(bool playing) {
    _updateAspectRatio();
    _syncWakelock(playing);
  }

  void _handleCompletedChanged(bool completed) {
    if (!completed) return;
    unawaited(onVideoEnd());
  }

  void _syncWakelock(bool playing) {
    final shouldEnable = playing;
    unawaited(shouldEnable ? WakelockPlus.enable() : WakelockPlus.disable());
  }

  Future<void> stopPlayback() async {
    await _persistPlaybackSnapshot();
    try {
      await player.stop();
    } catch (_) {}
    unawaited(WakelockPlus.disable());
  }

  Future<void> _persistPlaybackSnapshot() async {
    final folder = _folderPath;
    final episodePath = _currentEpisodePath;
    if (folder == null || folder.isEmpty) return;
    if (episodePath == null || episodePath.isEmpty) return;

    final current = _currentEpisode;
    final rawTitle = (current?.title ?? '').trim();
    final title = rawTitle.isNotEmpty ? rawTitle : _titleFromPath(episodePath);

    await _progressStorage.saveProgress(
      folderPath: folder,
      itemTitle: title,
      itemPath: episodePath,
      position: player.state.position,
    );
  }

  void _updateAspectRatio() {
    final rawWidth = player.state.width;
    final rawHeight = player.state.height;
    if (rawWidth == null || rawHeight == null) return;
    var width = rawWidth.toDouble();
    var height = rawHeight.toDouble();
    if (width <= 0 || height <= 0) return;
    final rotate = (player.state.videoParams.rotate ?? 0) % 360;
    if (rotate == 90 || rotate == 270) {
      final temp = width;
      width = height;
      height = temp;
    }
    final ratio = (width / height).clamp(0.4, 3.0);
    if ((videoAspectRatio.value - ratio).abs() > 0.01) {
      videoAspectRatio.value = ratio;
    }
    final portrait = ratio < 0.85;
    if (isPortraitVideo.value != portrait) {
      isPortraitVideo.value = portrait;
    }
  }

  void toggleEpisodeOrder() {
    episodesAscending.value = !episodesAscending.value;
  }

  List<int> get visibleEpisodeIndices {
    final count = episodes.length;
    if (episodesAscending.value) {
      return List<int>.generate(count, (i) => i, growable: false);
    }
    return List<int>.generate(count, (i) => count - 1 - i, growable: false);
  }

  void onManualNext() {
    final next = currentIndex.value + 1;
    if (next >= episodes.length) return;
    currentIndex.value = next;
  }

  Future<void> playNextEpisode() => playAt(currentIndex.value + 1);

  Future<void> playPreviousEpisode() => playAt(currentIndex.value - 1);

  Future<void> castCurrentEpisode() async {
    final url = currentCastUrl;
    if (url == null || url.isEmpty) {
      Get.snackbar('提示', '当前视频没有可投屏地址');
      return;
    }
    final result = await Get.bottomSheet<bool>(
      VideoCastView(
        url: url,
        title: currentCastTitle,
        sourcePath: currentCastSourcePath,
        asBottomSheet: true,
        onCastStarted: _enterCastingLocalStandby,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
    );
    if (result == true) return;
  }

  Future<void> stopCasting() async {
    await _persistCastProgressSnapshot();
    final wasCasting = isCasting;
    await _castService.stopCasting();
    _stopCastProgressPolling();
    if (!wasCasting) return;
    await _restoreLocalPlaybackAfterCasting();
  }

  Future<void> _enterCastingLocalStandby() async {
    await stopSpeedBoost();
    _lastCastPersistedPosition = null;
    _startCastProgressPolling();
    try {
      await player.pause();
    } catch (_) {}
    await stopPlayback();
  }

  Future<void> _restoreLocalPlaybackAfterCasting() async {
    final episode = _currentEpisode;
    if (episode == null) return;
    await _ensureSkipSettingsLoaded();

    final url = _episodeUrl(episode);
    if (url == null || url.isEmpty) return;

    final episodePath = episode.path?.trim();
    final intro = skipIntro.value;

    try {
      _openingEpisodePath = episodePath;
      _openingEpisodeUrl = url;
      await player.stop();
      _currentEpisodePath = episodePath;
      _currentEpisodeUrl = url;
      _lastPersistedPosition = null;
      _outroSkipTriggered = false;
      _pendingSeek = intro > Duration.zero ? intro : null;
      await player.open(Media(url), play: false);
    } catch (_) {
      Get.snackbar('播放失败', '当前视频恢复失败，请重试');
    } finally {
      _openingEpisodePath = null;
      _openingEpisodeUrl = null;
    }
  }

  Future<void> setPlaybackRate(double rate) async {
    if (rate <= 0) return;
    try {
      await player.setRate(rate);
    } catch (_) {}
  }

  Future<void> setCurrentPlaybackProxyMode(String mode) async {
    if (!canSwitchCurrentPlaybackProxyMode) return;
    if (isCasting) {
      Get.snackbar('提示', '投屏时暂不支持切换当前播放模式');
      return;
    }

    final normalized = _normalizePlaybackProxyMode(mode);
    final nextOverride = normalized == globalPlaybackProxyMode.value
        ? null
        : normalized;
    final currentOverride = currentPlaybackProxyModeOverride.value;
    if (effectivePlaybackProxyMode == normalized &&
        currentOverride == nextOverride) {
      return;
    }

    currentPlaybackProxyModeOverride.value = nextOverride;
    await _restartCurrentEpisode();
  }

  Future<void> startSpeedBoost([double rate = 3.0]) async {
    if (isSpeedBoosting.value) return;
    if (rate <= 0) return;
    isSpeedBoosting.value = true;
    speedBoostRate.value = rate;
    _rateBeforeBoost = player.state.rate;
    await setPlaybackRate(rate);
  }

  Future<void> stopSpeedBoost() async {
    if (!isSpeedBoosting.value) return;
    isSpeedBoosting.value = false;
    final restore = _rateBeforeBoost;
    _rateBeforeBoost = null;
    if (restore != null && restore > 0) {
      await setPlaybackRate(restore);
      return;
    }
    await setPlaybackRate(1.0);
  }

  Future<void> setControlsLocked(bool locked) async {
    if (isControlsLocked.value == locked) return;
    isControlsLocked.value = locked;
    if (locked) {
      await stopSpeedBoost();
    }
  }

  bool get isFullscreenCover =>
      fullscreenFitMode.value == FullscreenFitMode.cover;

  void setFullscreenFitMode(FullscreenFitMode mode) {
    if (fullscreenFitMode.value == mode) return;
    fullscreenFitMode.value = mode;
  }

  void toggleFullscreenFitMode() {
    setFullscreenFitMode(
      isFullscreenCover ? FullscreenFitMode.contain : FullscreenFitMode.cover,
    );
  }

  Future<void> setSkipIntro(Duration intro) async {
    final folder = _skipFolderKey;
    if (folder == null || folder.trim().isEmpty) return;
    final seconds = intro.inSeconds.clamp(0, 300);
    skipIntro.value = Duration(seconds: seconds);
    _skipSettingsLoaded = true;
    _persistSkipSettings(folder);
  }

  Future<void> setSkipOutro(Duration outro) async {
    final folder = _skipFolderKey;
    if (folder == null || folder.trim().isEmpty) return;
    final seconds = outro.inSeconds.clamp(0, 300);
    skipOutro.value = Duration(seconds: seconds);
    _skipSettingsLoaded = true;
    _persistSkipSettings(folder);
  }

  Future<void> clearSkipSettings() async {
    final folder = _skipFolderKey;
    if (folder == null || folder.trim().isEmpty) return;
    skipIntro.value = Duration.zero;
    skipOutro.value = Duration.zero;
    _skipSettingsLoaded = true;
    try {
      await _skipStorage.clear(folder);
    } catch (_) {}
  }

  void _persistSkipSettings(String folderPath) {
    final settings = SkipSettings(
      intro: skipIntro.value,
      outro: skipOutro.value,
    );
    unawaited(_skipStorage.save(folderPath, settings));
  }

  Future<void> _ensureSkipSettingsLoaded() async {
    final folder = _skipFolderKey;
    if (folder == null || folder.trim().isEmpty) return;
    if (_skipSettingsLoaded) return;
    try {
      final settings = await _skipStorage.read(folder);
      if (settings != null) {
        skipIntro.value = settings.intro;
        skipOutro.value = settings.outro;
      }
    } catch (_) {}
    _skipSettingsLoaded = true;
  }

  void beginScrub({required double viewWidth}) {
    if (viewWidth <= 0) return;
    if (player.state.duration <= Duration.zero) return;
    _scrubViewWidth = viewWidth;
    _scrubDeltaDx = 0;
    _scrubStartPos = player.state.position;
    _scrubDuration = player.state.duration;
    isScrubbing.value = true;
    scrubPreview.value = _scrubStartPos;
  }

  void updateScrub(double deltaDx) {
    if (!isScrubbing.value) return;
    if (_scrubViewWidth <= 0) return;
    final durationMs = _scrubDuration.inMilliseconds;
    if (durationMs <= 0) return;

    _scrubDeltaDx += deltaDx;
    final offsetMs = (_scrubDeltaDx / _scrubViewWidth) * durationMs;
    final targetMs = (_scrubStartPos.inMilliseconds + offsetMs.round()).clamp(
      0,
      durationMs,
    );
    final target = Duration(milliseconds: targetMs);
    scrubPreview.value = target;

    _scrubTimer?.cancel();
    _scrubTimer = Timer(const Duration(milliseconds: 90), () {
      unawaited(player.seek(Duration(milliseconds: targetMs)));
    });
  }

  void endScrub() {
    if (!isScrubbing.value) return;
    _scrubTimer?.cancel();
    _scrubTimer = null;
    final preview = scrubPreview.value;
    final durationMs = player.state.duration.inMilliseconds;
    if (preview != null && durationMs > 0) {
      final targetMs = preview.inMilliseconds.clamp(0, durationMs);
      unawaited(player.seek(Duration(milliseconds: targetMs)));
    }
    isScrubbing.value = false;
    scrubPreview.value = null;
  }

  Future<void> onVideoEnd() async {
    if (_autoNextRunning) return;
    _autoNextRunning = true;
    try {
      await playAt(currentIndex.value + 1);
    } finally {
      _autoNextRunning = false;
    }
  }

  Future<void> playAt(
    int index, {
    Duration? startPosition,
    bool clearResume = false,
  }) async {
    if (index < 0 || index >= episodes.length) return;
    await _ensureSkipSettingsLoaded();

    if (Get.isRegistered<MusicPlayerController>()) {
      unawaited(Get.find<MusicPlayerController>().pause());
    }

    final episode = episodes[index];
    final episodePath = episode.path?.trim();
    if (!_isSameEpisodeSelection(index, episodePath)) {
      currentPlaybackProxyModeOverride.value = null;
    }
    final url = _episodeUrl(episode);
    if (url == null) {
      Get.snackbar('提示', '登录已过期，请重新登录');
      return;
    }

    if (isCasting) {
      final castUrl = _castUrlForEpisode(episode);
      if (castUrl == null || castUrl.isEmpty) {
        Get.snackbar('提示', '当前视频没有可投屏地址');
        return;
      }
      final switched = await _castService.castToCurrentDevice(
        url: castUrl,
        title: _castTitleForEpisode(episode),
        sourcePath: episodePath ?? '',
      );
      if (!switched) {
        Get.snackbar('投屏失败', '当前设备没有接受切换请求');
        return;
      }
      _lastCastPersistedPosition = null;
      await stopPlayback();
      _currentEpisodePath = episodePath;
      _currentEpisodeUrl = url;
      currentIndex.value = index;
      return;
    }

    Duration? resume;
    if (!clearResume &&
        _resumeEpisodePath != null &&
        episodePath != null &&
        MediaPath.equals(_resumeEpisodePath, episodePath) &&
        _resumePosition != null &&
        _resumePosition! > Duration.zero) {
      resume = _resumePosition;
      _resumeEpisodePath = null;
      _resumePosition = null;
    }
    if (clearResume) {
      _resumeEpisodePath = null;
      _resumePosition = null;
    }

    var pendingSeek = startPosition ?? resume ?? Duration.zero;
    final intro = skipIntro.value;
    if (intro > Duration.zero && pendingSeek < intro) {
      pendingSeek = intro;
    }

    if (_shouldSkipDuplicateOpen(index, episodePath, url)) {
      currentIndex.value = index;
      if (clearResume) {
        _resumeEpisodePath = null;
        _resumePosition = null;
      }
      return;
    }

    try {
      _openingEpisodePath = episodePath;
      _openingEpisodeUrl = url;
      await player.stop();
      _currentEpisodePath = episodePath;
      _currentEpisodeUrl = url;
      _lastPersistedPosition = null;
      _outroSkipTriggered = false;
      _pendingSeek = pendingSeek > Duration.zero ? pendingSeek : null;
      await player.open(Media(url), play: true);
      currentIndex.value = index;
    } catch (_) {
      Get.snackbar('播放失败', '请稍后重试');
    } finally {
      _openingEpisodePath = null;
      _openingEpisodeUrl = null;
    }
  }

  String? _episodeUrl(Episode episode) {
    final path = episode.path?.trim();
    final url = episode.url?.trim();
    if (url != null && url.isNotEmpty) {
      if (_isLocalProxyStreamUrl(url)) {
        return _applyPlaybackProxyModeToUrl(
          url,
          mode: currentPlaybackProxyModeOverride.value,
        );
      }
      if (path == null || path.isEmpty) {
        return url;
      }
    }
    if (path == null || path.isEmpty) return null;
    return _buildStreamUrl(path, mode: currentPlaybackProxyModeOverride.value);
  }

  String? _castUrlForEpisode(Episode episode) {
    final streamUrl = _episodeUrl(episode);
    if (streamUrl == null || streamUrl.isEmpty) return null;
    final uri = Uri.parse(streamUrl);
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'cast': 'true',
          },
        )
        .toString();
  }

  String _castTitleForEpisode(Episode episode) {
    final title = episode.title.trim();
    if (title.isNotEmpty) return title;
    final subTitle = episode.subTitle.trim();
    if (subTitle.isNotEmpty) return subTitle;
    final resource = resourceTitle.value.trim();
    if (resource.isNotEmpty) return resource;
    return '当前视频';
  }

  void _applyArgs(dynamic args) {
    if (args is! Map) return;
    _initialIndex = 0;
    _resumeEpisodePath = null;
    _resumePosition = null;
    _currentEpisodePath = null;
    _currentEpisodeUrl = null;
    _pendingSeek = null;
    _lastPersistedPosition = null;
    _blockPlaybackOnOpen = false;
    isLoadingPlaylist.value = false;
    currentPlaybackProxyModeOverride.value = null;

    final applicationType = args['applicationType'];
    if (applicationType is String && applicationType.trim().isNotEmpty) {
      _applicationType = applicationType.trim();
    }

    final title = args['title'];
    if (title is String && title.trim().isNotEmpty) {
      resourceTitle.value = title.trim();
    }

    final intro = args['intro'];
    if (intro is String) {
      resourceIntro.value = intro.trim();
    } else {
      resourceIntro.value = '';
    }

    final initialIndex = args['initialIndex'];
    if (initialIndex is int) _initialIndex = initialIndex;
    if (initialIndex is String) {
      _initialIndex = int.tryParse(initialIndex) ?? _initialIndex;
    }

    final rawEpisodes = args['episodes'];
    final parsed = <Episode>[];
    if (rawEpisodes is List) {
      for (final e in rawEpisodes) {
        if (e is! Map) continue;
        final map = e.cast<dynamic, dynamic>();
        final t = map['title'];
        final st = map['subTitle'];
        final url = map['url'];
        final path = map['path'];
        if (t is! String || t.trim().isEmpty) continue;
        parsed.add(
          Episode(
            title: t.trim(),
            subTitle: st is String ? st.trim() : '',
            url: url is String ? url.trim() : null,
            path: path is String ? path.trim() : null,
          ),
        );
      }
    }
    episodes.assignAll(parsed);
    if (_initialIndex < 0) _initialIndex = 0;
    if (_initialIndex >= episodes.length) _initialIndex = 0;

    final folderPath = args['folderPath'];
    if (folderPath is String && folderPath.trim().isNotEmpty) {
      final nextFolder = folderPath.trim();
      _folderPath = nextFolder;
      if (_skipFolderKey != nextFolder) {
        _skipFolderKey = nextFolder;
        _skipSettingsLoaded = false;
        skipIntro.value = Duration.zero;
        skipOutro.value = Duration.zero;
        unawaited(_ensureSkipSettingsLoaded());
      }
    } else {
      _folderPath = null;
      _skipFolderKey = null;
      _skipSettingsLoaded = true;
      skipIntro.value = Duration.zero;
      skipOutro.value = Duration.zero;
    }

    final resumeEpisodePath = args['resumeEpisodePath'];
    if (resumeEpisodePath is String && resumeEpisodePath.trim().isNotEmpty) {
      _resumeEpisodePath = MediaPath.normalize(resumeEpisodePath);
    }

    final resumePositionMs = _toInt(args['resumePositionMs']);
    if (resumePositionMs != null && resumePositionMs > 0) {
      _resumePosition = Duration(milliseconds: resumePositionMs);
    }

    _syncInitialIndexWithResumePath();
  }

  bool _shouldLoadCollectionOnEnter(Map args) {
    return args[PlaybackEntryConfig.loadCollectionOnEnterKey] == true;
  }

  bool _hasExplicitInitialTarget(Map args) {
    final preferredPath = MediaPath.normalize(
      args[PlaybackEntryConfig.preferredItemPathKey] as String?,
    );
    if (preferredPath.isNotEmpty) {
      return true;
    }
    final explicitResumePath = MediaPath.normalize(
      args['resumeEpisodePath'] as String?,
    );
    return explicitResumePath.isNotEmpty;
  }

  Future<void> _loadEpisodesOnEnter(Map args, int version) async {
    final folder = _folderPath;
    if (folder == null || folder.isEmpty) return;

    isLoadingPlaylist.value = true;
    episodes.clear();
    currentIndex.value = 0;
    resourceIntro.value = '';

    try {
      final files = await _webdavApi.fetchFileList(
        applicationType: _applicationType,
        path: folder,
      );
      if (_routeArgsVersion != version) return;

      final nextEpisodes = _buildEpisodesFromEntries(files);
      episodes.assignAll(nextEpisodes);
      if (nextEpisodes.isEmpty) return;

      resourceIntro.value = '共 ${nextEpisodes.length} 集';
      await _resolveInitialPlaybackTarget(args, version);
    } catch (error) {
      if (_routeArgsVersion != version) return;
      Get.snackbar('提示', '获取播放列表失败：$error');
    } finally {
      if (_routeArgsVersion == version) {
        isLoadingPlaylist.value = false;
      }
    }
  }

  Future<void> _resolveExplicitPlaybackTarget(Map args, int version) async {
    if (episodes.isEmpty) return;

    final preferredPath = MediaPath.normalize(
      args[PlaybackEntryConfig.preferredItemPathKey] as String?,
    );
    final explicitResumePath = MediaPath.normalize(
      args['resumeEpisodePath'] as String?,
    );
    final explicitResumePositionMs = _toInt(args['resumePositionMs']);

    var initialPath = '';
    var resumePath = '';
    int? resumePositionMs;
    var source = _InitialEpisodeSource.none;

    if (preferredPath.isNotEmpty) {
      initialPath = preferredPath;
      source = _InitialEpisodeSource.preferred;
      if (explicitResumePath.isNotEmpty &&
          MediaPath.equals(explicitResumePath, preferredPath)) {
        resumePath = explicitResumePath;
        resumePositionMs = explicitResumePositionMs;
      }
    } else if (explicitResumePath.isNotEmpty) {
      initialPath = explicitResumePath;
      resumePath = explicitResumePath;
      resumePositionMs = explicitResumePositionMs;
      source = _InitialEpisodeSource.explicitResume;
    }

    if (initialPath.isEmpty) return;

    final matchedIndex = _episodeIndexByPath(initialPath);
    if (matchedIndex < 0) {
      await _handleMissingInitialEpisode(
        folder: _folderPath ?? '',
        source: source,
        targetPath: initialPath,
      );
      if (_routeArgsVersion != version) return;
      return;
    }

    _initialIndex = matchedIndex;
    currentIndex.value = matchedIndex;
    _resumeEpisodePath = resumePath.isNotEmpty ? resumePath : null;
    _resumePosition = resumePositionMs != null && resumePositionMs > 0
        ? Duration(milliseconds: resumePositionMs)
        : null;
  }

  Future<void> _resolveInitialPlaybackTarget(Map args, int version) async {
    final folder = _folderPath;
    if (folder == null || folder.isEmpty) return;
    if (episodes.isEmpty) return;

    final preferredPath = MediaPath.normalize(
      args[PlaybackEntryConfig.preferredItemPathKey] as String?,
    );
    final explicitResumePath = MediaPath.normalize(
      args['resumeEpisodePath'] as String?,
    );
    final explicitResumePositionMs = _toInt(args['resumePositionMs']);

    PlaybackProgress? progress;
    try {
      progress = await _progressStorage.readProgress(folder);
    } catch (error) {
      Get.log('read playback progress failed: $error');
    }
    if (_routeArgsVersion != version) return;

    final storedResumePath = MediaPath.normalize(
      progress?.buildItemPath(folder),
    );
    final storedResumePositionMs =
        progress != null && progress.position > Duration.zero
        ? progress.position.inMilliseconds
        : null;

    var initialPath = '';
    var resumePath = '';
    int? resumePositionMs;
    var source = _InitialEpisodeSource.none;

    if (preferredPath.isNotEmpty) {
      initialPath = preferredPath;
      source = _InitialEpisodeSource.preferred;
      if (explicitResumePath.isNotEmpty &&
          MediaPath.equals(explicitResumePath, preferredPath)) {
        resumePath = explicitResumePath;
        resumePositionMs = explicitResumePositionMs;
      } else if (storedResumePath.isNotEmpty &&
          MediaPath.equals(storedResumePath, preferredPath)) {
        resumePath = storedResumePath;
        resumePositionMs = storedResumePositionMs;
      }
    } else if (explicitResumePath.isNotEmpty) {
      initialPath = explicitResumePath;
      resumePath = explicitResumePath;
      resumePositionMs = explicitResumePositionMs;
      source = _InitialEpisodeSource.explicitResume;
    } else if (storedResumePath.isNotEmpty) {
      initialPath = storedResumePath;
      resumePath = storedResumePath;
      resumePositionMs = storedResumePositionMs;
      source = _InitialEpisodeSource.storedResume;
    }

    var initialIndex = 0;
    if (initialPath.isNotEmpty) {
      final matchedIndex = _episodeIndexByPath(initialPath);
      if (matchedIndex >= 0) {
        initialIndex = matchedIndex;
      } else {
        final shouldContinue = await _handleMissingInitialEpisode(
          folder: folder,
          source: source,
          targetPath: initialPath,
        );
        if (_routeArgsVersion != version) return;
        if (!shouldContinue) {
          return;
        }
        resumePath = '';
        resumePositionMs = null;
      }
    }

    _initialIndex = initialIndex;
    currentIndex.value = initialIndex;
    _resumeEpisodePath = resumePath.isNotEmpty ? resumePath : null;
    _resumePosition = resumePositionMs != null && resumePositionMs > 0
        ? Duration(milliseconds: resumePositionMs)
        : null;
  }

  Future<void> _restorePlaybackTargetFromStorage(int version) async {
    final folder = _folderPath;
    if (folder == null || folder.isEmpty) return;
    if (episodes.isEmpty) return;

    try {
      final progress = await _progressStorage.readProgress(folder);
      if (_routeArgsVersion != version || progress == null) return;

      final resumePath = MediaPath.normalize(progress.buildItemPath(folder));
      if (resumePath.isEmpty) return;

      final index = _episodeIndexByPath(resumePath);
      if (index < 0) {
        await _progressStorage.clearProgress(folder);
        return;
      }

      _initialIndex = index;
      _resumeEpisodePath = resumePath;
      _resumePosition = progress.position > Duration.zero
          ? progress.position
          : null;
    } catch (error) {
      Get.log('restore playback target failed: $error');
    }
  }

  bool _hasExplicitResumeTarget() {
    final resumePath = MediaPath.normalize(_resumeEpisodePath);
    if (resumePath.isNotEmpty) {
      return true;
    }
    return _resumePosition != null && _resumePosition! > Duration.zero;
  }

  Future<bool> _handleMissingInitialEpisode({
    required String folder,
    required _InitialEpisodeSource source,
    required String targetPath,
  }) async {
    if (source == _InitialEpisodeSource.storedResume) {
      await _progressStorage.clearProgress(folder);
      _resumeEpisodePath = null;
      _resumePosition = null;
      Get.log(
        'stale stored video resume cleared: folder=$folder target=$targetPath',
      );
      return true;
    }

    _blockPlaybackOnOpen = true;
    _resumeEpisodePath = null;
    _resumePosition = null;
    Get.snackbar('提示', '目标视频不存在，请刷新记录后重试');
    return false;
  }

  List<Episode> _buildEpisodesFromEntries(List<WebdavFileEntry> entries) {
    final parsed = <Episode>[];
    for (final entry in entries) {
      if (!_isPlayableVideo(entry)) continue;
      final url = _resolveEntryStreamUrl(entry);
      if (url.isEmpty) continue;
      final index = parsed.length;
      parsed.add(
        Episode(
          title: entry.name,
          subTitle: '第 ${index + 1} 集',
          path: entry.path,
          url: url,
        ),
      );
    }
    return parsed;
  }

  bool _isPlayableVideo(WebdavFileEntry entry) {
    if (entry.isDir) return false;
    final lower = entry.name.trim().toLowerCase();
    return _videoExtensions.any(lower.endsWith);
  }

  String _resolveEntryStreamUrl(WebdavFileEntry entry) {
    return entry.resolveStreamUrl(applicationType: _applicationType);
  }

  void _syncInitialIndexWithResumePath() {
    final resumePath = MediaPath.normalize(_resumeEpisodePath);
    if (resumePath.isEmpty) return;
    final index = _episodeIndexByPath(resumePath);
    if (index >= 0) {
      _initialIndex = index;
    }
  }

  int _episodeIndexByPath(String path) {
    final normalized = MediaPath.normalize(path);
    if (normalized.isEmpty) return -1;
    for (var i = 0; i < episodes.length; i++) {
      if (MediaPath.equals(episodes[i].path, normalized)) {
        return i;
      }
    }
    return -1;
  }

  bool _shouldSkipDuplicateOpen(int index, String? episodePath, String url) {
    final normalizedPath = MediaPath.normalize(episodePath);
    final hasPath = normalizedPath.isNotEmpty;
    final sameCurrentPath =
        hasPath && MediaPath.equals(_currentEpisodePath, normalizedPath);
    final sameOpeningPath =
        hasPath && MediaPath.equals(_openingEpisodePath, normalizedPath);
    final sameCurrentUrl =
        !hasPath && _currentEpisodeUrl == url && currentIndex.value == index;
    final sameOpeningUrl = !hasPath && _openingEpisodeUrl == url;
    return sameCurrentPath ||
        sameOpeningPath ||
        sameCurrentUrl ||
        sameOpeningUrl;
  }

  void _tryApplyPendingSeek() {
    final seek = _pendingSeek;
    if (seek == null) return;
    final duration = player.state.duration;
    if (duration <= Duration.zero) return;
    _pendingSeek = null;
    final target = seek > duration ? duration : seek;
    unawaited(player.seek(target));
  }

  void _handlePositionUpdate(Duration position) {
    final folder = _folderPath;
    final episodePath = _currentEpisodePath;
    if (folder == null || episodePath == null) return;

    final pending = _pendingSeek;
    if (pending != null && position < pending) return;

    if (!_outroSkipTriggered &&
        skipOutro.value > Duration.zero &&
        player.state.playing &&
        !isScrubbing.value) {
      final duration = player.state.duration;
      if (duration > Duration.zero) {
        final remaining = duration - position;
        if (remaining <= skipOutro.value) {
          _outroSkipTriggered = true;
          unawaited(onVideoEnd());
          return;
        }
      }
    }

    final last = _lastPersistedPosition;
    if (last != null && (position - last).abs() < const Duration(seconds: 5)) {
      return;
    }
    _lastPersistedPosition = position;
    final currentEpisode = _currentEpisode;
    final currentTitle = (currentEpisode?.title ?? '').trim();
    final title = currentTitle.isNotEmpty
        ? currentTitle
        : _titleFromPath(episodePath);
    unawaited(
      _progressStorage.saveProgress(
        folderPath: folder,
        itemTitle: title,
        itemPath: episodePath,
        position: position,
      ),
    );
  }

  void _startCastProgressPolling() {
    _castProgressTimer?.cancel();
    _castProgressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_persistCastProgressSnapshot());
    });
  }

  void _stopCastProgressPolling() {
    _castProgressTimer?.cancel();
    _castProgressTimer = null;
  }

  Future<void> _persistCastProgressSnapshot() async {
    if (!isCasting) return;
    final folder = _folderPath;
    final episodePath = _currentEpisodePath;
    if (folder == null || folder.isEmpty) return;
    if (episodePath == null || episodePath.isEmpty) return;

    final position = await _castService.currentPosition();
    if (position == null || position < Duration.zero) return;

    final last = _lastCastPersistedPosition;
    if (last != null && (position - last).abs() < const Duration(seconds: 5)) {
      return;
    }
    _lastCastPersistedPosition = position;

    final currentEpisode = _currentEpisode;
    final currentTitle = (currentEpisode?.title ?? '').trim();
    final title = currentTitle.isNotEmpty
        ? currentTitle
        : _titleFromPath(episodePath);
    await _progressStorage.saveProgress(
      folderPath: folder,
      itemTitle: title,
      itemPath: episodePath,
      position: position,
    );
  }

  Future<void> _loadGlobalPlaybackProxyMode() async {
    try {
      final config = await _configApi.findConfigByKey(_webProxyModeKey);
      globalPlaybackProxyMode.value = _normalizePlaybackProxyMode(
        config?.value ?? _defaultPlaybackProxyMode,
      );
    } catch (_) {
      globalPlaybackProxyMode.value = _defaultPlaybackProxyMode;
    }
  }

  Future<void> _restartCurrentEpisode() async {
    if (episodes.isEmpty) return;
    final index = currentIndex.value;
    if (index < 0 || index >= episodes.length) return;

    final wasPlaying = player.state.playing;
    final position = player.state.position;
    await playAt(index, startPosition: position, clearResume: true);
    if (!wasPlaying) {
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  bool _supportsPlaybackProxyMode(Episode episode) {
    final path = episode.path?.trim();
    if (path != null && path.isNotEmpty) return true;
    final url = episode.url?.trim();
    if (url == null || url.isEmpty) return false;
    return _isLocalProxyStreamUrl(url);
  }

  bool _isSameEpisodeSelection(int index, String? episodePath) {
    final normalizedPath = MediaPath.normalize(episodePath);
    if (normalizedPath.isNotEmpty) {
      return MediaPath.equals(_currentEpisodePath, normalizedPath) ||
          MediaPath.equals(_openingEpisodePath, normalizedPath);
    }
    return currentIndex.value == index;
  }

  String? _buildStreamUrl(
    String path, {
    String? applicationType,
    String? mode,
  }) {
    final base = Uri.parse(AppEnv.instance.apiBaseUrl);
    final streamPath = _joinPath(
      base.path,
      'public/quarkFs/${applicationType ?? _applicationType}/files/stream',
    );
    final normalizedMode = mode == null || mode.trim().isEmpty
        ? null
        : _normalizePlaybackProxyMode(mode);
    return base
        .replace(
          path: streamPath,
          queryParameters: <String, String>{
            'path': path,
            ...?normalizedMode == null
                ? null
                : <String, String>{'mode': normalizedMode},
          },
        )
        .toString();
  }

  String _normalizePlaybackProxyMode(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'redirect':
      case '302':
      case '302_redirect':
      case 'direct':
        return '302_redirect';
      default:
        return _defaultPlaybackProxyMode;
    }
  }

  bool _isLocalProxyStreamUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;
    final normalizedPath = uri.path.replaceAll('\\', '/').trim();
    return normalizedPath.contains('/public/quarkFs/') &&
        normalizedPath.endsWith('/files/stream');
  }

  String _applyPlaybackProxyModeToUrl(String rawUrl, {String? mode}) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !_isLocalProxyStreamUrl(rawUrl)) return rawUrl;

    final nextQuery = <String, String>{...uri.queryParameters};
    final normalizedMode = mode == null || mode.trim().isEmpty
        ? null
        : _normalizePlaybackProxyMode(mode);
    if (normalizedMode == null) {
      nextQuery.remove('mode');
    } else {
      nextQuery['mode'] = normalizedMode;
    }
    return uri.replace(queryParameters: nextQuery).toString();
  }

  static String _joinPath(String basePath, String child) {
    final bp = basePath.trim().isEmpty ? '' : basePath;
    if (bp.isEmpty) return '/$child';
    if (bp.endsWith('/')) return '$bp$child';
    return '$bp/$child';
  }

  static String _titleFromPath(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return '';
    final parts = normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return normalized;
    return parts.last;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static const List<String> _videoExtensions = <String>[
    '.mp4',
    '.mkv',
    '.mov',
    '.m4v',
    '.avi',
    '.wmv',
    '.flv',
    '.webm',
  ];
  static const String _webProxyModeKey = 'quark_fs_web_proxy_mode';
  static const String _defaultPlaybackProxyMode = 'native_proxy';

  @override
  void onClose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _rateSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    _scrubTimer?.cancel();
    _castProgressTimer?.cancel();
    player.dispose();
    unawaited(WakelockPlus.disable());
    super.onClose();
  }
}

class Episode {
  Episode({required this.title, required this.subTitle, this.path, this.url});

  final String title;
  final String subTitle;
  final String? path;
  final String? url;
}
