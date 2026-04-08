import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

import '../../../data/api/quark.dart';
import '../../../data/models/quark_file_entry.dart';
import '../../../data/storage/playback_progress_storage.dart';
import '../../../data/storage/skip_settings_storage.dart';
import '../../../data/storage/volume_settings_storage.dart';
import '../../../services/auth_service.dart';
import '../../../services/music_audio_handler.dart';
import '../../../services/playback_audio_session.dart';
import '../../../services/playback_entry_service.dart';
import '../../../utils/app_env.dart';
import '../../../utils/media_path.dart';

enum _InitialTrackSource { none, preferred, explicitResume, storedResume }

class MusicPlayerController extends GetxController with WidgetsBindingObserver {
  MusicPlayerController({
    PlaybackProgressStorage? progressStorage,
    SkipSettingsStorage? skipSettingsStorage,
    String defaultApplicationType = 'music',
  }) : _providedProgressStorage = progressStorage,
       _defaultApplicationType = defaultApplicationType,
       _skipStorage = skipSettingsStorage ?? SkipSettingsStorage();

  final Player _player = Player();
  final PlaybackProgressStorage? _providedProgressStorage;
  late PlaybackProgressStorage _progressStorage;
  final SkipSettingsStorage _skipStorage;
  final VolumeSettingsStorage _volumeStorage = VolumeSettingsStorage();
  final Random _random = Random();
  final WebdavApi _webdavApi = Get.find<WebdavApi>();
  final AuthService _authService = Get.find<AuthService>();
  late final PlaybackAudioSession _audioSession = PlaybackAudioSession(
    onPauseRequested: pause,
    isPlaying: () => _player.state.playing,
  );
  MusicAudioHandler? _audioHandler;
  bool _audioHandlerInitializing = false;

  final playlistTitle = 'Music'.obs;
  final folderPath = ''.obs;
  final tracks = <MusicTrack>[].obs;
  final currentIndex = 0.obs;
  final isPlaying = false.obs;
  final isBuffering = false.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final sleepRemaining = Rxn<Duration>();
  final skipIntro = Duration.zero.obs;
  final skipOutro = Duration.zero.obs;
  final playMode = PlayMode.sequential.obs;
  final actionsReady = false.obs;
  final volume = 1.0.obs;
  final isLoadingPlaylist = false.obs;

  int _initialIndex = 0;
  Duration? _pendingSeek;
  Duration? _lastPersistedPosition;
  String? _currentTrackPath;
  String? _resumeTrackPath;
  Duration? _resumePosition;
  String? _folderKey;
  bool _skipSettingsLoaded = false;
  late String _applicationType = _defaultApplicationType;
  final String _defaultApplicationType;
  bool _ready = false;
  String? _lastArgsKey;
  bool _playlistLoaded = false;
  bool _outroTriggered = false;
  bool _autoCompleting = false;
  bool _appWasBackgrounded = false;
  int _routeArgsVersion = 0;
  List<String> _supportedExtensions = const <String>[];
  final Map<String, double> _playlistSheetOffsets = <String, double>{};
  bool _blockPlaybackOnOpen = false;

  Timer? _sleepTimer;
  DateTime? _sleepDeadline;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Playlist>? _playlistSub;
  StreamSubscription<bool>? _completedSub;

  MusicTrack? get currentTrack {
    final list = tracks;
    if (list.isEmpty) return null;
    final index = currentIndex.value;
    if (index < 0 || index >= list.length) return null;
    return list[index];
  }

  String get applicationType => _applicationType;

  bool get isSleepTimerActive => _sleepDeadline != null;

  double get playlistSheetInitialOffset {
    final key = _playlistSheetOffsetKey;
    if (key.isEmpty) return 0;
    return _playlistSheetOffsets[key] ?? 0;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    actionsReady.value = false;
    _applicationType = _defaultApplicationType;
    unawaited(_audioSession.initialize());
    unawaited(_ensureAudioHandlerInitialized());
    unawaited(_restoreVolume());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _appWasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _appWasBackgrounded) {
      _appWasBackgrounded = false;
      _handleResumeSessionCheck();
    }
  }

  @override
  void onReady() {
    super.onReady();
    _playingSub = _player.stream.playing.listen((playing) {
      isPlaying.value = playing;
      _syncAudioPlaybackState();
    });
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      isBuffering.value = buffering;
      _syncAudioPlaybackState();
    });
    _positionSub = _player.stream.position.listen((value) {
      position.value = value;
      _handlePositionUpdate(value);
      _checkOutroSkip(value);
    });
    _durationSub = _player.stream.duration.listen((value) {
      duration.value = value;
      unawaited(_tryApplyPendingSeek());
      _syncAudioMediaItem();
      _syncAudioPlaybackState();
    });
    _playlistSub = _player.stream.playlist.listen((playlist) {
      final sessionReady = _isIncomingPlaylistReady(playlist);
      if (!sessionReady) {
        _playlistLoaded = false;
        _syncAudioPlaybackState();
        return;
      }
      _playlistLoaded = true;
      final index = playlist.index;
      if (index >= 0 && index < tracks.length) {
        currentIndex.value = index;
        final path = tracks[index].path.trim();
        _currentTrackPath = path.isEmpty ? null : path;
        _syncAudioMediaItem();
      } else {
        _restoreCurrentIndexFromTrackPath();
      }
      _syncAudioPlaybackState();
    });
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) {
        unawaited(_handleCompletedPlayback());
      }
      _syncAudioPlaybackState();
    });

    _ready = true;
    actionsReady.value = true;
    _syncAudioQueue();
    _syncAudioMediaItem();
    _syncAudioPlaybackState();
  }

  void _handleResumeSessionCheck() {
    if (tracks.isEmpty) {
      _playlistLoaded = false;
      return;
    }
    if (_isPlaylistSessionHealthy()) return;
    _playlistLoaded = false;
    _restoreCurrentIndexFromTrackPath();
    unawaited(_primeResumeFromHistoryForCurrentTrack());
    _syncAudioPlaybackState();
  }

  Future<void> _primeResumeFromHistoryForCurrentTrack() async {
    final folder = _folderKey;
    if (folder == null || folder.isEmpty) return;
    if (tracks.isEmpty) return;

    final normalizedCurrentPath = _normalizedCurrentTrackPath();
    final progress = await _progressStorage.readProgress(folder);
    if (progress == null) return;

    final resumePath = MediaPath.normalize(progress.buildItemPath(folder));
    if (resumePath.isEmpty) return;
    if (normalizedCurrentPath.isNotEmpty &&
        resumePath != normalizedCurrentPath) {
      return;
    }

    final resumeIndex = _indexForTrackPath(resumePath);
    if (resumeIndex < 0) {
      await _progressStorage.clearProgress(folder);
      return;
    }

    if (normalizedCurrentPath.isEmpty && resumeIndex != currentIndex.value) {
      currentIndex.value = resumeIndex;
      final restoredPath = tracks[resumeIndex].path.trim();
      _currentTrackPath = restoredPath.isEmpty ? null : restoredPath;
    }

    _resumeTrackPath = resumePath;
    _resumePosition = progress.position > Duration.zero
        ? progress.position
        : null;
  }

  String _normalizedCurrentTrackPath() {
    final currentPath = MediaPath.normalize(_currentTrackPath);
    if (currentPath.isNotEmpty) return currentPath;

    final index = currentIndex.value;
    if (index >= 0 && index < tracks.length) {
      return MediaPath.normalize(tracks[index].path);
    }
    return '';
  }

  void savePlaylistSheetOffset(double offset) {
    final key = _playlistSheetOffsetKey;
    if (key.isEmpty) return;
    if (!offset.isFinite) return;
    _playlistSheetOffsets[key] = offset < 0 ? 0 : offset;
  }

  String get _playlistSheetOffsetKey {
    final folder = _folderKey?.trim() ?? '';
    if (folder.isNotEmpty) {
      return 'folder:${_applicationType.trim()}|$folder';
    }

    final title = playlistTitle.value.trim();
    if (title.isNotEmpty || tracks.isNotEmpty) {
      return 'fallback:${_applicationType.trim()}|$title|${tracks.length}';
    }

    return '';
  }

  bool _isIncomingPlaylistReady(Playlist playlist) {
    if (tracks.isEmpty) return false;
    final count = _playlistMediaCountOf(playlist);
    if (count == null || count <= 0) return false;
    return count == tracks.length;
  }

  bool _isPlaylistSessionHealthy() {
    if (!_playlistLoaded || tracks.isEmpty) return false;
    final count = _playlistMediaCountOf(_player.state.playlist);
    if (count == null || count <= 0) return false;
    if (count != tracks.length) return false;
    final index = _playlistIndexOf(_player.state.playlist);
    if (index == null) return true;
    return index >= -1 && index < tracks.length;
  }

  int? _playlistMediaCountOf(Object? source) {
    if (source == null) return null;
    try {
      final dynamic value = source;
      final dynamic medias = value.medias;
      if (medias is List) return medias.length;
      if (medias is Iterable) return medias.length;
    } catch (_) {}
    return null;
  }

  int? _playlistIndexOf(Object? source) {
    if (source == null) return null;
    try {
      final dynamic value = source;
      final dynamic raw = value.index;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
    } catch (_) {}
    return null;
  }

  void _restoreCurrentIndexFromTrackPath() {
    if (tracks.isEmpty) {
      currentIndex.value = 0;
      _currentTrackPath = null;
      return;
    }

    final restored = _indexForTrackPath(_currentTrackPath);
    if (restored >= 0) {
      currentIndex.value = restored;
      final path = tracks[restored].path.trim();
      _currentTrackPath = path.isEmpty ? null : path;
      return;
    }

    currentIndex.value = 0;
    final fallbackPath = tracks[0].path.trim();
    _currentTrackPath = fallbackPath.isEmpty ? null : fallbackPath;
  }

  int _indexForTrackPath(String? path) {
    final target = MediaPath.normalize(path);
    if (target.isEmpty) return -1;
    for (var i = 0; i < tracks.length; i++) {
      if (MediaPath.equals(tracks[i].path, target)) {
        return i;
      }
    }
    return -1;
  }

  Future<void> handleRouteArguments(
    dynamic arguments, {
    bool forceReload = false,
  }) {
    return _handleRouteArgumentsInternal(arguments, forceReload: forceReload);
  }

  Future<void> _handleRouteArgumentsInternal(
    dynamic arguments, {
    bool forceReload = false,
  }) async {
    if (arguments is! Map) return;

    final key = _argsKey(arguments);
    if (!forceReload && _lastArgsKey == key) return;
    _lastArgsKey = key;
    final version = ++_routeArgsVersion;

    _applicationType = _defaultApplicationType;
    _applyArgs(arguments);
    _progressStorage =
        _providedProgressStorage ??
        PlaybackProgressStorage(applicationType: _applicationType);
    _playlistLoaded = false;
    if (_shouldLoadCollectionOnEnter(arguments)) {
      await _loadTracksOnEnter(arguments, version);
    } else if (_hasExplicitInitialTarget(arguments)) {
      await _resolveExplicitPlaybackTarget(arguments, version);
    } else if (!_hasExplicitResumeTarget()) {
      await _restorePlaybackTargetFromStorage(version);
    }
    if (_routeArgsVersion != version) return;

    if (_ready && tracks.isNotEmpty && !_blockPlaybackOnOpen) {
      await playAt(_initialIndex, forceReopen: forceReload);
    }
  }

  String _argsKey(Map arguments) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final folder = (arguments['folderPath'] as String?)?.trim() ?? '';
    final title = (arguments['title'] as String?)?.trim() ?? '';
    final app = (arguments['applicationType'] as String?)?.trim() ?? '';
    final rawTracks = arguments['tracks'];
    final count = rawTracks is List ? rawTracks.length : 0;
    final initialIndex = parseInt(arguments['initialIndex']);
    final preferredPath =
        (arguments[PlaybackEntryConfig.preferredItemPathKey] as String?)
            ?.trim() ??
        '';
    final resume = (arguments['resumeTrackPath'] as String?)?.trim() ?? '';
    final resumePositionMs = parseInt(arguments['resumePositionMs']);
    final loadOnEnter =
        arguments[PlaybackEntryConfig.loadCollectionOnEnterKey] == true
        ? '1'
        : '0';
    return '$app|$folder|$title|$count|$initialIndex|$preferredPath|$resume|$resumePositionMs|$loadOnEnter';
  }

  void _applyArgs(dynamic arguments) {
    if (arguments is! Map) return;
    _initialIndex = 0;
    _resumeTrackPath = null;
    _resumePosition = null;
    _currentTrackPath = null;
    _pendingSeek = null;
    _lastPersistedPosition = null;
    _blockPlaybackOnOpen = false;
    isLoadingPlaylist.value = false;

    final appType = arguments['applicationType'];
    if (appType is String && appType.trim().isNotEmpty) {
      _applicationType = appType.trim();
    }

    final title = arguments['title'];
    if (title is String && title.trim().isNotEmpty) {
      playlistTitle.value = title.trim();
    }

    final folder = arguments['folderPath'];
    if (folder is String && folder.trim().isNotEmpty) {
      final value = folder.trim();
      folderPath.value = value;
      _folderKey = value;
      _skipSettingsLoaded = false;
      unawaited(_restoreSkipSettings());
    } else {
      folderPath.value = '';
      _folderKey = null;
      _skipSettingsLoaded = true;
      skipIntro.value = Duration.zero;
      skipOutro.value = Duration.zero;
    }

    _supportedExtensions = _parseSupportedExtensions(
      arguments['supportedExtensions'],
      fallbackApplicationType: _applicationType,
    );

    final initial = arguments['initialIndex'];
    if (initial is int) {
      _initialIndex = initial;
    } else if (initial is String) {
      _initialIndex = int.tryParse(initial) ?? 0;
    }

    final rawTracks = arguments['tracks'];
    final parsed = <MusicTrack>[];
    if (rawTracks is List) {
      for (final item in rawTracks) {
        if (item is! Map) continue;
        final map = item.cast<dynamic, dynamic>();
        final itemTitle = (map['title'] as String?)?.trim() ?? '';
        final itemUrl = (map['url'] as String?)?.trim() ?? '';
        final itemPath = (map['path'] as String?)?.trim() ?? '';
        if (itemTitle.isEmpty || itemUrl.isEmpty) continue;
        parsed.add(MusicTrack(title: itemTitle, url: itemUrl, path: itemPath));
      }
    }
    tracks.assignAll(parsed);
    if (_initialIndex < 0 || _initialIndex >= tracks.length) _initialIndex = 0;
    currentIndex.value = _initialIndex;
    _syncAudioQueue();
    _syncAudioMediaItem();
    _syncAudioPlaybackState();

    final resumeTrack = arguments['resumeTrackPath'];
    if (resumeTrack is String && resumeTrack.trim().isNotEmpty) {
      _resumeTrackPath = resumeTrack.trim();
    } else {
      _resumeTrackPath = null;
    }

    final resumePositionMs = arguments['resumePositionMs'];
    final parsedResumePositionMs = _toInt(resumePositionMs);
    if (parsedResumePositionMs != null && parsedResumePositionMs > 0) {
      _resumePosition = Duration(milliseconds: parsedResumePositionMs);
    } else {
      _resumePosition = null;
    }
  }

  bool _shouldLoadCollectionOnEnter(Map arguments) {
    return arguments[PlaybackEntryConfig.loadCollectionOnEnterKey] == true;
  }

  bool _hasExplicitInitialTarget(Map arguments) {
    final preferredPath = MediaPath.normalize(
      arguments[PlaybackEntryConfig.preferredItemPathKey] as String?,
    );
    if (preferredPath.isNotEmpty) {
      return true;
    }
    final explicitResumePath = MediaPath.normalize(
      arguments['resumeTrackPath'] as String?,
    );
    return explicitResumePath.isNotEmpty;
  }

  Future<void> _loadTracksOnEnter(Map arguments, int version) async {
    final folder = _folderKey;
    if (folder == null || folder.isEmpty) return;

    isLoadingPlaylist.value = true;
    tracks.clear();
    currentIndex.value = 0;
    _syncAudioQueue();
    _syncAudioMediaItem();
    _syncAudioPlaybackState();

    try {
      final files = await _webdavApi.fetchFileList(
        applicationType: _applicationType,
        path: folder,
      );
      if (_routeArgsVersion != version) return;

      final nextTracks = _buildTracksFromEntries(files);
      tracks.assignAll(nextTracks);
      if (nextTracks.isEmpty) return;

      _syncAudioQueue();
      _syncAudioMediaItem();
      _syncAudioPlaybackState();
      await _resolveInitialPlaybackTarget(arguments, version);
    } catch (error) {
      if (_routeArgsVersion != version) return;
      Get.snackbar('提示', '获取播放列表失败：$error');
    } finally {
      if (_routeArgsVersion == version) {
        isLoadingPlaylist.value = false;
      }
    }
  }

  Future<void> _resolveExplicitPlaybackTarget(
    Map arguments,
    int version,
  ) async {
    if (tracks.isEmpty) return;

    final preferredPath = MediaPath.normalize(
      arguments[PlaybackEntryConfig.preferredItemPathKey] as String?,
    );
    final explicitResumePath = MediaPath.normalize(
      arguments['resumeTrackPath'] as String?,
    );
    final explicitResumePositionMs = _toInt(arguments['resumePositionMs']);

    var initialPath = '';
    var resumePath = '';
    int? resumePositionMs;
    var source = _InitialTrackSource.none;

    if (preferredPath.isNotEmpty) {
      initialPath = preferredPath;
      source = _InitialTrackSource.preferred;
      if (explicitResumePath.isNotEmpty &&
          MediaPath.equals(explicitResumePath, preferredPath)) {
        resumePath = explicitResumePath;
        resumePositionMs = explicitResumePositionMs;
      }
    } else if (explicitResumePath.isNotEmpty) {
      initialPath = explicitResumePath;
      resumePath = explicitResumePath;
      resumePositionMs = explicitResumePositionMs;
      source = _InitialTrackSource.explicitResume;
    }

    if (initialPath.isEmpty) return;

    final matchedIndex = _indexForTrackPath(initialPath);
    if (matchedIndex < 0) {
      await _handleMissingInitialTrack(
        folder: _folderKey ?? '',
        source: source,
        targetPath: initialPath,
      );
      if (_routeArgsVersion != version) return;
      return;
    }

    _initialIndex = matchedIndex;
    currentIndex.value = matchedIndex;
    final selectedPath = tracks[matchedIndex].path.trim();
    _currentTrackPath = selectedPath.isEmpty ? null : selectedPath;
    _resumeTrackPath = resumePath.isNotEmpty ? resumePath : null;
    _resumePosition = resumePositionMs != null && resumePositionMs > 0
        ? Duration(milliseconds: resumePositionMs)
        : null;
    _syncAudioMediaItem();
    _syncAudioPlaybackState();
  }

  Future<void> _resolveInitialPlaybackTarget(Map arguments, int version) async {
    final folder = _folderKey;
    if (folder == null || folder.isEmpty) return;
    if (tracks.isEmpty) return;

    final preferredPath = MediaPath.normalize(
      arguments[PlaybackEntryConfig.preferredItemPathKey] as String?,
    );
    final explicitResumePath = MediaPath.normalize(
      arguments['resumeTrackPath'] as String?,
    );
    final explicitResumePositionMs = _toInt(arguments['resumePositionMs']);

    PlaybackProgress? progress;
    try {
      progress = await _progressStorage.readProgress(folder);
    } catch (_) {}
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
    var source = _InitialTrackSource.none;

    if (preferredPath.isNotEmpty) {
      initialPath = preferredPath;
      source = _InitialTrackSource.preferred;
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
      source = _InitialTrackSource.explicitResume;
    } else if (storedResumePath.isNotEmpty) {
      initialPath = storedResumePath;
      resumePath = storedResumePath;
      resumePositionMs = storedResumePositionMs;
      source = _InitialTrackSource.storedResume;
    }

    var initialIndex = 0;
    if (initialPath.isNotEmpty) {
      final matchedIndex = _indexForTrackPath(initialPath);
      if (matchedIndex >= 0) {
        initialIndex = matchedIndex;
      } else {
        final shouldContinue = await _handleMissingInitialTrack(
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
    final selectedPath = tracks[initialIndex].path.trim();
    _currentTrackPath = selectedPath.isEmpty ? null : selectedPath;
    _resumeTrackPath = resumePath.isNotEmpty ? resumePath : null;
    _resumePosition = resumePositionMs != null && resumePositionMs > 0
        ? Duration(milliseconds: resumePositionMs)
        : null;
    _syncAudioMediaItem();
    _syncAudioPlaybackState();
  }

  Future<void> _restorePlaybackTargetFromStorage(int version) async {
    final folder = _folderKey;
    if (folder == null || folder.isEmpty) return;
    if (tracks.isEmpty) return;

    try {
      final progress = await _progressStorage.readProgress(folder);
      if (_routeArgsVersion != version || progress == null) return;

      final resumePath = MediaPath.normalize(progress.buildItemPath(folder));
      if (resumePath.isEmpty) return;

      final index = _indexForTrackPath(resumePath);
      if (index < 0) {
        await _progressStorage.clearProgress(folder);
        return;
      }

      _initialIndex = index;
      currentIndex.value = index;
      _resumeTrackPath = resumePath;
      _resumePosition = progress.position > Duration.zero
          ? progress.position
          : null;
    } catch (_) {}
  }

  bool _hasExplicitResumeTarget() {
    final resumePath = MediaPath.normalize(_resumeTrackPath);
    if (resumePath.isNotEmpty) {
      return true;
    }
    return _resumePosition != null && _resumePosition! > Duration.zero;
  }

  Future<bool> _handleMissingInitialTrack({
    required String folder,
    required _InitialTrackSource source,
    required String targetPath,
  }) async {
    if (source == _InitialTrackSource.storedResume) {
      await _progressStorage.clearProgress(folder);
      _resumeTrackPath = null;
      _resumePosition = null;
      return true;
    }

    _blockPlaybackOnOpen = true;
    _resumeTrackPath = null;
    _resumePosition = null;
    Get.snackbar('提示', '目标音频不存在，请刷新记录后重试');
    return false;
  }

  List<MusicTrack> _buildTracksFromEntries(List<WebdavFileEntry> entries) {
    final parsed = <MusicTrack>[];
    for (final entry in entries) {
      if (!_isPlayableEntry(entry)) continue;
      final streamUrl = _resolveStreamUrl(entry);
      if (streamUrl.isEmpty) continue;
      parsed.add(
        MusicTrack(title: entry.name, url: streamUrl, path: entry.path),
      );
    }
    return parsed;
  }

  bool _isPlayableEntry(WebdavFileEntry entry) {
    if (entry.isDir) return false;
    final lower = entry.name.trim().toLowerCase();
    return _supportedExtensions.any(lower.endsWith);
  }

  String _resolveStreamUrl(WebdavFileEntry entry) {
    return _applyAccessTokenToStreamUrl(
      entry.resolveStreamUrl(applicationType: _applicationType),
    );
  }

  String _resolveTrackUrlForPlayback(MusicTrack track) {
    final path = track.path.trim();
    if (path.isNotEmpty) {
      return _buildStreamUrl(path);
    }
    return _applyAccessTokenToStreamUrl(track.url);
  }

  String _buildStreamUrl(String path) {
    final base = Uri.parse(AppEnv.instance.apiBaseUrl);
    final streamPath = _joinPath(
      base.path,
      'public/quarkFs/$_applicationType/files/stream',
    );
    final accessToken = _currentAccessToken();
    return base
        .replace(
          path: streamPath,
          queryParameters: <String, String>{
            'path': path,
            ...?accessToken == null
                ? null
                : <String, String>{'access_token': accessToken},
          },
        )
        .toString();
  }

  String _applyAccessTokenToStreamUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !_isLocalProxyStreamUrl(rawUrl)) return rawUrl;

    final nextQuery = <String, String>{...uri.queryParameters};
    final accessToken = _currentAccessToken();
    if (accessToken == null) {
      nextQuery.remove('access_token');
    } else {
      nextQuery['access_token'] = accessToken;
    }
    return uri.replace(queryParameters: nextQuery).toString();
  }

  bool _isLocalProxyStreamUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;
    final normalizedPath = uri.path.replaceAll('\\', '/').trim();
    return (normalizedPath.contains('/public/quarkFs/') ||
            normalizedPath.contains('/quarkFs/')) &&
        normalizedPath.endsWith('/files/stream');
  }

  String? _currentAccessToken() {
    final token = _authService.accessToken.value?.trim() ?? '';
    if (token.isEmpty) return null;
    return token;
  }

  static String _joinPath(String basePath, String child) {
    final bp = basePath.trim().isEmpty ? '' : basePath;
    if (bp.isEmpty) return '/$child';
    if (bp.endsWith('/')) return '$bp$child';
    return '$bp/$child';
  }

  List<String> _parseSupportedExtensions(
    dynamic value, {
    required String fallbackApplicationType,
  }) {
    if (value is List) {
      final parsed = value
          .whereType<String>()
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return _defaultSupportedExtensionsFor(fallbackApplicationType);
  }

  List<String> _defaultSupportedExtensionsFor(String applicationType) {
    return const <String>[
      '.mp3',
      '.aac',
      '.m4a',
      '.flac',
      '.wav',
      '.ogg',
      '.opus',
      '.wma',
      '.m4b',
      '.mpga',
    ];
  }

  Future<bool> _ensurePlaylistLoaded({int? initialIndex}) async {
    if (_playlistLoaded) return false;
    if (tracks.isEmpty) return false;

    final safeIndex = (initialIndex ?? currentIndex.value).clamp(
      0,
      tracks.length - 1,
    );
    final medias = tracks
        .map((track) => Media(_resolveTrackUrlForPlayback(track)))
        .toList(growable: false);
    await _player.open(Playlist(medias, index: safeIndex), play: false);
    await _player.setVolume(volume.value * 100);
    _playlistLoaded = true;
    return true;
  }

  Future<void> playAt(
    int index, {
    bool forceReopen = false,
    Duration? startPosition,
    bool clearResume = false,
  }) async {
    if (index < 0 || index >= tracks.length) return;
    try {
      final focusAcquired = await _audioSession.activate(_audioProfile);
      if (!focusAcquired) return;
      if (forceReopen) {
        _playlistLoaded = false;
      }
      final openedPlaylist = await _ensurePlaylistLoaded(initialIndex: index);
      await _syncPlayMode();

      final track = tracks[index];
      final trackPath = track.path.trim();
      _currentTrackPath = trackPath.isEmpty ? null : trackPath;
      _outroTriggered = false;
      _lastPersistedPosition = null;

      final intro = skipIntro.value;
      if (clearResume) {
        _resumeTrackPath = null;
        _resumePosition = null;
      }
      final resume = clearResume
          ? null
          : _takeResumeForTrack(_currentTrackPath);
      final startOffset = startPosition != null
          ? _maxDuration(intro, startPosition)
          : _maxDuration(intro, resume);
      _pendingSeek = startOffset > Duration.zero ? startOffset : null;

      if (!openedPlaylist) {
        await _player.jump(index);
      }
      if (startOffset <= Duration.zero && !openedPlaylist) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
      unawaited(_tryApplyPendingSeek());
      currentIndex.value = index;
      _syncAudioMediaItem();
      _syncAudioPlaybackState();
    } catch (e) {
      await _audioSession.deactivate();
      Get.snackbar('播放失败', e.toString());
    }
  }

  PlaybackAudioProfile get _audioProfile {
    return PlaybackAudioProfile.media;
  }

  Future<void> _syncPlayMode() async {
    switch (playMode.value) {
      case PlayMode.sequential:
        await _player.setShuffle(false);
        await _player.setPlaylistMode(PlaylistMode.none);
        break;
      case PlayMode.single:
        await _player.setShuffle(false);
        await _player.setPlaylistMode(PlaylistMode.single);
        break;
      case PlayMode.shuffle:
        await _player.setShuffle(false);
        await _player.setPlaylistMode(PlaylistMode.none);
        break;
    }
  }

  Duration _maxDuration(Duration a, Duration? b) {
    if (b == null) return a;
    return a >= b ? a : b;
  }

  Duration? _takeResumeForTrack(String? trackPath) {
    final resumePath = _resumeTrackPath;
    final resumePosition = _resumePosition;
    if (resumePath == null || resumePath.isEmpty) return null;
    if (trackPath == null || trackPath.isEmpty) return null;
    final normalizedResume = MediaPath.normalize(resumePath);
    final normalizedTrack = MediaPath.normalize(trackPath);
    if (normalizedResume.isEmpty || normalizedTrack.isEmpty) return null;
    if (normalizedResume != normalizedTrack) return null;
    _resumeTrackPath = null;
    _resumePosition = null;
    return resumePosition;
  }

  Future<void> _tryApplyPendingSeek() async {
    final pending = _pendingSeek;
    if (pending == null || pending <= Duration.zero) return;

    final total = duration.value;
    if (total <= Duration.zero) return;

    final target = pending > total ? total : pending;
    if (target <= Duration.zero) {
      _pendingSeek = null;
      return;
    }

    // Keep pending value aligned with clamped target to avoid waiting forever.
    _pendingSeek = target;
    try {
      await _player.seek(target);
    } catch (_) {}
  }

  Future<void> play() async {
    if (tracks.isEmpty) return;
    if (!_isPlaylistSessionHealthy()) {
      _playlistLoaded = false;
      _restoreCurrentIndexFromTrackPath();
      await _primeResumeFromHistoryForCurrentTrack();
      await playAt(currentIndex.value, forceReopen: true);
      return;
    }
    final focusAcquired = await _audioSession.activate(_audioProfile);
    if (!focusAcquired) return;
    await _player.play();
    _syncAudioPlaybackState();
  }

  Future<void> pause() async {
    try {
      if (tracks.isNotEmpty) {
        await _player.pause();
        _syncAudioPlaybackState();
      }
    } finally {
      await _audioSession.deactivate();
    }
  }

  Future<void> togglePlayback() async {
    if (tracks.isEmpty) return;
    if (_player.state.playing) {
      await pause();
      return;
    }
    await play();
  }

  Future<void> playNext({bool fromAutoComplete = false}) async {
    if (tracks.isEmpty) return;
    final total = tracks.length;
    if (playMode.value == PlayMode.single && fromAutoComplete) {
      await playAt(currentIndex.value);
      return;
    }

    if (total == 1) {
      await playAt(0);
      return;
    }

    if (playMode.value == PlayMode.shuffle) {
      await playAt(_randomIndex(exclude: currentIndex.value));
      return;
    }

    if (playMode.value == PlayMode.sequential &&
        fromAutoComplete &&
        currentIndex.value == total - 1) {
      await playAt(0, forceReopen: true);
      return;
    }

    final nextIndex = (currentIndex.value + 1) % total;
    final wrappedToStart = currentIndex.value == total - 1 && nextIndex == 0;
    await playAt(nextIndex, forceReopen: wrappedToStart);
  }

  Future<void> playPrevious() async {
    if (tracks.isEmpty) return;
    final total = tracks.length;
    if (playMode.value == PlayMode.shuffle && total > 1) {
      await playAt(_randomIndex(exclude: currentIndex.value));
      return;
    }
    if (total == 1) {
      await playAt(0);
      return;
    }
    final prevIndex = currentIndex.value - 1 < 0
        ? total - 1
        : currentIndex.value - 1;
    await playAt(prevIndex);
  }

  Future<void> _handleCompletedPlayback() async {
    if (_autoCompleting) return;
    _autoCompleting = true;
    try {
      await playNext(fromAutoComplete: true);
    } finally {
      _autoCompleting = false;
    }
  }

  Future<void> seekTo(Duration value) async {
    try {
      await _player.seek(value);
      _syncAudioPlaybackState();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      isPlaying.value = false;
      _syncAudioPlaybackState(forceStopped: true);
    } finally {
      await _audioSession.deactivate();
    }
  }

  Future<void> clearPlaybackSession() async {
    cancelSleepTimer();
    try {
      await _player.stop();
    } catch (_) {}

    _pendingSeek = null;
    _lastPersistedPosition = null;
    _currentTrackPath = null;
    _resumeTrackPath = null;
    _resumePosition = null;
    _folderKey = null;
    _applicationType = _defaultApplicationType;
    _lastArgsKey = null;
    _playlistLoaded = false;
    _outroTriggered = false;
    _routeArgsVersion++;
    _blockPlaybackOnOpen = false;
    _supportedExtensions = const <String>[];
    _skipSettingsLoaded = false;
    _playlistSheetOffsets.clear();

    playlistTitle.value = 'Music';
    folderPath.value = '';
    tracks.clear();
    currentIndex.value = 0;
    isPlaying.value = false;
    isBuffering.value = false;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    skipIntro.value = Duration.zero;
    skipOutro.value = Duration.zero;
    playMode.value = PlayMode.sequential;
    isLoadingPlaylist.value = false;

    _syncAudioQueue();
    _syncAudioMediaItem();
    _syncAudioPlaybackState(forceStopped: true);
    await _audioSession.deactivate();
  }

  Future<void> setVolume(double value, {bool persist = true}) async {
    final safe = value.clamp(0.0, 1.0);
    volume.value = safe;
    await _player.setVolume(safe * 100);
    if (persist) {
      unawaited(_volumeStorage.save(safe));
    }
  }

  Future<void> _restoreVolume() async {
    final stored = await _volumeStorage.read();
    if (stored == null) {
      await setVolume(volume.value, persist: false);
      return;
    }
    await setVolume(stored, persist: false);
  }

  void setSkipIntro(Duration value) {
    final safe = value < Duration.zero ? Duration.zero : value;
    skipIntro.value = safe;
    _persistSkipSettings();
    if (isPlaying.value && safe > Duration.zero && position.value < safe) {
      unawaited(_player.seek(safe));
    }
  }

  void setSkipOutro(Duration value) {
    final safe = value < Duration.zero ? Duration.zero : value;
    skipOutro.value = safe;
    _outroTriggered = false;
    _persistSkipSettings();
  }

  void cyclePlayMode() {
    final next = (playMode.value.index + 1) % PlayMode.values.length;
    playMode.value = PlayMode.values[next];
    unawaited(_syncPlayMode());
  }

  void startSleepTimer(Duration value) {
    if (value <= Duration.zero) {
      cancelSleepTimer();
      return;
    }
    _sleepDeadline = DateTime.now().add(value);
    sleepRemaining.value = value;
    _sleepTimer?.cancel();
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickSleepTimer();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    sleepRemaining.value = null;
  }

  void _tickSleepTimer() {
    final deadline = _sleepDeadline;
    if (deadline == null) {
      cancelSleepTimer();
      return;
    }
    final remain = deadline.difference(DateTime.now());
    if (remain <= Duration.zero) {
      _handleSleepTimeout();
    } else {
      sleepRemaining.value = remain;
    }
  }

  void _handleSleepTimeout() {
    cancelSleepTimer();
    Get.snackbar('提示', '已到达定时关闭时间，播放已停止');
    unawaited(stop());
  }

  void _handlePositionUpdate(Duration currentPosition) {
    final folder = _folderKey;
    final path = _currentTrackPath;
    if (folder == null || folder.isEmpty) return;
    if (path == null || path.isEmpty) return;

    final pending = _pendingSeek;
    if (pending != null) {
      if (currentPosition < pending) return;
      _pendingSeek = null;
    }

    if (!isPlaying.value && currentPosition <= Duration.zero) {
      return;
    }

    final last = _lastPersistedPosition;
    if (last != null &&
        (currentPosition - last).abs() < const Duration(seconds: 5)) {
      return;
    }
    _lastPersistedPosition = currentPosition;
    final track = currentTrack;
    final trackTitle = (track?.title ?? '').trim();
    final title = trackTitle.isNotEmpty ? trackTitle : _titleFromPath(path);
    unawaited(
      _progressStorage.saveProgress(
        folderPath: folder,
        itemTitle: title,
        itemPath: path,
        position: currentPosition,
        duration: duration.value,
      ),
    );
  }

  void _checkOutroSkip(Duration currentPosition) {
    final outro = skipOutro.value;
    final total = duration.value;
    if (outro <= Duration.zero ||
        total <= Duration.zero ||
        _outroTriggered ||
        tracks.isEmpty) {
      if (outro <= Duration.zero) _outroTriggered = false;
      return;
    }
    final threshold = total - outro;
    if (threshold <= Duration.zero) return;
    if (currentPosition >= threshold) {
      _outroTriggered = true;
      if (tracks.length <= 1) {
        if (playMode.value == PlayMode.single) {
          unawaited(playAt(currentIndex.value));
        } else {
          unawaited(stop());
        }
      } else {
        unawaited(playNext(fromAutoComplete: true));
      }
    }
  }

  void _persistSkipSettings() {
    final folder = _folderKey;
    if (folder == null || folder.isEmpty) return;
    final settings = SkipSettings(
      intro: skipIntro.value,
      outro: skipOutro.value,
    );
    unawaited(_skipStorage.save(folder, settings));
  }

  Future<void> _restoreSkipSettings() async {
    final folder = _folderKey;
    if (folder == null || folder.isEmpty) return;
    if (_skipSettingsLoaded) return;
    final settings = await _skipStorage.read(folder);
    if (settings != null) {
      skipIntro.value = settings.intro;
      skipOutro.value = settings.outro;
    }
    _skipSettingsLoaded = true;
  }

  int _randomIndex({int? exclude}) {
    if (tracks.isEmpty) return 0;
    if (tracks.length == 1) return 0;
    var index = _random.nextInt(tracks.length);
    if (exclude != null) {
      while (index == exclude) {
        index = _random.nextInt(tracks.length);
      }
    }
    return index;
  }

  String formatDuration(Duration value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(value.inMinutes.remainder(60));
    final seconds = two(value.inSeconds.remainder(60));
    final hours = value.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<void> _ensureAudioHandlerInitialized() async {
    if (_audioHandler != null || _audioHandlerInitializing) return;
    _audioHandlerInitializing = true;
    try {
      final handler = await AudioService.init(
        builder: () => MusicAudioHandler(
          onPlay: play,
          onPause: pause,
          onStop: stop,
          onSkipToNext: playNext,
          onSkipToPrevious: playPrevious,
          onSeek: seekTo,
          onSkipToQueueItem: playAt,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'xyz.iosjk.app.music.playback',
          androidNotificationChannelName: 'Smart Zone Audio Playback',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidStopForegroundOnPause: false,
        ),
      );
      _audioHandler = handler;
      _syncAudioQueue();
      _syncAudioMediaItem();
      _syncAudioPlaybackState();
    } catch (_) {
      _audioHandler = null;
    } finally {
      _audioHandlerInitializing = false;
    }
  }

  List<MediaItem> _buildQueueItems() {
    final albumTitle = playlistTitle.value.trim();
    return List<MediaItem>.generate(tracks.length, (index) {
      final track = tracks[index];
      final title = track.title.trim().isEmpty
          ? 'Track ${index + 1}'
          : track.title.trim();
      return MediaItem(
        id: _mediaItemIdForTrack(track, index),
        title: title,
        album: albumTitle.isEmpty ? null : albumTitle,
        extras: {'path': track.path, 'url': track.url, 'index': index},
      );
    }, growable: false);
  }

  String _mediaItemIdForTrack(MusicTrack track, int index) {
    final path = track.path.trim();
    if (path.isNotEmpty) return 'path:$path';
    final url = track.url.trim();
    if (url.isNotEmpty) return 'url:$url';
    return 'index:$index';
  }

  void _syncAudioQueue() {
    final handler = _audioHandler;
    if (handler == null) return;
    if (tracks.isEmpty) {
      handler.setQueueItems(const <MediaItem>[]);
      handler.clearMediaItem();
      return;
    }
    handler.setQueueItems(_buildQueueItems());
  }

  MediaItem? _buildCurrentMediaItem() {
    final list = tracks;
    if (list.isEmpty) return null;
    final index = currentIndex.value;
    if (index < 0 || index >= list.length) return null;
    final track = list[index];
    final albumTitle = playlistTitle.value.trim();
    final value = duration.value;
    return MediaItem(
      id: _mediaItemIdForTrack(track, index),
      title: track.title.trim().isEmpty ? 'Track ${index + 1}' : track.title,
      album: albumTitle.isEmpty ? null : albumTitle,
      duration: value > Duration.zero ? value : null,
      extras: {'path': track.path, 'url': track.url, 'index': index},
    );
  }

  void _syncAudioMediaItem() {
    final handler = _audioHandler;
    if (handler == null) return;
    final item = _buildCurrentMediaItem();
    if (item == null) {
      handler.clearMediaItem();
      return;
    }
    handler.setMediaItemData(item);
  }

  AudioProcessingState _resolveAudioProcessingState({
    bool forceStopped = false,
  }) {
    if (forceStopped || tracks.isEmpty) return AudioProcessingState.idle;
    if (isBuffering.value) return AudioProcessingState.buffering;
    final total = duration.value;
    if (total > Duration.zero &&
        position.value >= total &&
        !isPlaying.value &&
        !_outroTriggered) {
      return AudioProcessingState.completed;
    }
    return AudioProcessingState.ready;
  }

  void _syncAudioPlaybackState({bool forceStopped = false}) {
    final handler = _audioHandler;
    if (handler == null) return;

    final total = duration.value;
    final current = position.value;
    final currentPosition = total > Duration.zero && current > total
        ? total
        : current;
    final queueIdx = tracks.isEmpty
        ? null
        : currentIndex.value.clamp(0, tracks.length - 1);

    handler.setPlaybackStateData(
      playing: !forceStopped && isPlaying.value,
      processingState: _resolveAudioProcessingState(forceStopped: forceStopped),
      position: currentPosition,
      bufferedPosition: total > Duration.zero ? total : currentPosition,
      speed: _player.state.rate,
      queueIndex: queueIdx,
    );
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

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    actionsReady.value = false;
    _syncAudioPlaybackState(forceStopped: true);
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playlistSub?.cancel();
    _completedSub?.cancel();
    _sleepTimer?.cancel();
    unawaited(_audioSession.dispose());
    _player.dispose();
    super.onClose();
  }
}

class MusicTrack {
  MusicTrack({required this.title, required this.url, required this.path});

  final String title;
  final String url;
  final String path;
}

enum PlayMode { sequential, single, shuffle }
