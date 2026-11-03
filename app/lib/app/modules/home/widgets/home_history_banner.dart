import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/media_history_entry.dart';
import '../../../theme/app_theme.dart';
import '../../../routes/app_pages.dart';
import '../../../widgets/main_tab_content_insets.dart';
import '../../music_player/controllers/music_player_controller.dart';
import '../controllers/home_controller.dart';

class HomeHistoryBanner extends GetView<HomeController> {
  const HomeHistoryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final musicController = _activeMusicController();
      final entry = controller.recentHistory.value;
      final hasActiveAudio = _shouldShowActiveAudio(
        controller: musicController,
        recentHistory: entry,
      );
      final loading = controller.recentHistoryLoading.value;
      final bufferingPlayback = musicController?.isBuffering.value ?? false;
      final visiblyPlaying =
          (musicController?.isPlaying.value ?? false) && !bufferingPlayback;
      final initializingPlayback =
          controller.initializingAudioPlayback.value ||
          (musicController?.isLoadingPlaylist.value ?? false) ||
          (hasActiveAudio && bufferingPlayback);

      final title = hasActiveAudio
          ? _playingTitle(
              musicController!.playlistTitle.value,
              musicController.folderPath.value,
            )
          : entry == null
          ? '历史记录'
          : _folderTitle(entry.folderTitle, entry.folderPath);

      final summary = hasActiveAudio
          ? '${_itemTitle(_pickActiveTrackTitle(musicController!))} · 点击进入播放页'
          : loading && entry == null
          ? '正在加载最近播放...'
          : entry != null
          ? '${_typeLabel(entry.applicationType)} · ${_itemTitle(entry.itemTitle)} · ${_formatDate(entry.lastPlayedAt)}'
          : '暂无历史记录';

      void onContinue() {
        if (hasActiveAudio) {
          controller.openActiveAudioPlayer();
          return;
        }
        if (entry != null) {
          controller.openRecentHistory();
        }
      }

      void onList() {
        Get.toNamed(Routes.HISTORY);
      }

      final VoidCallback? onBannerTap = !hasActiveAudio
          ? null
          : () {
              controller.openActiveAudioPlayer();
            };

      Future<void> onPlayButtonTap() async {
        if (hasActiveAudio) {
          musicController!.togglePlayback();
          return;
        }
        if (entry != null && _isAudioType(entry.applicationType)) {
          // 播客直接播放，不跳转页面
          await controller.playAudioWithoutNavigation(entry);
          return;
        }
        onContinue();
      }

      final playing = hasActiveAudio && visiblyPlaying;
      final bannerRadius = BorderRadius.circular(18.r);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBannerTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: bannerRadius,
            boxShadow: AppThemeColors.floatingShadow,
          ),
          child: ClipRRect(
            borderRadius: bannerRadius,
            child: Container(
              width: double.infinity,
              height: MainTabContentInsets.historyBannerHeight.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                borderRadius: bannerRadius,
                border: Border.all(color: AppThemeColors.borderStrong),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: hasActiveAudio || entry != null
                          ? onContinue
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppThemeColors.textPrimary,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              if (hasActiveAudio) ...[
                                const SizedBox(width: 6),
                                _PlaybackStatusBadge(playing: visiblyPlaying),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            initializingPlayback ? '正在加载播放列表...' : summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppThemeColors.textSecondary,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  _BannerIconButton(
                    tooltip: playing ? '暂停' : '播放',
                    onPressed:
                        (hasActiveAudio || entry != null) &&
                            !initializingPlayback
                        ? onPlayButtonTap
                        : null,
                    icon: initializingPlayback
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 28,
                          ),
                  ),
                  SizedBox(width: 2.w),
                  _BannerIconButton(
                    tooltip: '历史记录',
                    onPressed: onList,
                    icon: const Icon(Icons.queue_music_rounded, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  static MusicPlayerController? _activeMusicController() {
    if (!Get.isRegistered<MusicPlayerController>()) {
      return null;
    }
    return Get.find<MusicPlayerController>();
  }

  static bool _shouldShowActiveAudio({
    required MusicPlayerController? controller,
    required MediaHistoryEntry? recentHistory,
  }) {
    if (!_hasAudioSession(controller)) return false;
    if (controller!.isPlaying.value) return true;
    if (recentHistory == null) return true;
    return _matchesRecentAudioSession(controller, recentHistory);
  }

  static bool _hasAudioSession(MusicPlayerController? controller) {
    if (controller == null) return false;
    return controller.tracks.isNotEmpty;
  }

  static bool _matchesRecentAudioSession(
    MusicPlayerController controller,
    MediaHistoryEntry recentHistory,
  ) {
    final historyType = recentHistory.applicationType.trim().toLowerCase();
    if (historyType == 'tv' || historyType == 'playlet') {
      return false;
    }
    final activeType = controller.applicationType.trim().toLowerCase();
    if (activeType != historyType) {
      return false;
    }
    return _normalizeFolderPath(controller.folderPath.value) ==
        _normalizeFolderPath(recentHistory.folderPath);
  }

  static String _normalizeFolderPath(String value) {
    return value.replaceAll('\\', '/').trim();
  }

  static String _playingTitle(String playlistTitle, String folderPath) {
    final title = playlistTitle.trim();
    if (title.isNotEmpty) return title;
    return _folderTitle('', folderPath);
  }

  static String _pickActiveTrackTitle(MusicPlayerController controller) {
    final index = controller.currentIndex.value;
    final list = controller.tracks;
    if (index >= 0 && index < list.length) {
      final title = list[index].title.trim();
      if (title.isNotEmpty) return title;
    }

    final fallback = controller.currentTrack?.title.trim() ?? '';
    if (fallback.isNotEmpty) return fallback;
    return '-';
  }

  static String _folderTitle(String folderTitle, String folderPath) {
    final title = folderTitle.trim();
    if (title.isNotEmpty) return title;

    final normalized = folderPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return '历史记录';
    final parts = normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return normalized;
    return parts.last;
  }

  static String _itemTitle(String itemTitle) {
    final title = itemTitle.trim();
    return title.isEmpty ? '-' : title;
  }

  static bool _isAudioType(String applicationType) {
    final normalized = applicationType.trim().toLowerCase();
    return normalized == 'music';
  }

  static String _typeLabel(String applicationType) {
    switch (applicationType.trim().toLowerCase()) {
      case 'tv':
        return '影视';
      case 'music':
        return '播客';
      case 'read':
        return '阅读';
      case 'playlet':
        return '短剧';
      default:
        return applicationType;
    }
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '未知时间';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _PlaybackStatusBadge extends StatelessWidget {
  const _PlaybackStatusBadge({required this.playing});

  final bool playing;

  static const double _chipWidth = 48;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _chipWidth.w,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: playing
              ? const LinearGradient(
                  colors: [AppThemeColors.primary, AppThemeColors.secondary],
                )
              : null,
          color: playing ? null : AppThemeColors.surfaceMuted,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          playing ? '正在播放' : '已暂停',
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.sp,
            color: playing ? Colors.white : AppThemeColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _BannerIconButton extends StatelessWidget {
  const _BannerIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final buttonSize = 34.r;

    return SizedBox(
      width: 38.w,
      child: Center(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: buttonSize,
            height: buttonSize,
          ),
          style: IconButton.styleFrom(
            foregroundColor: AppThemeColors.primary,
            disabledForegroundColor: AppThemeColors.textDisabled,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: icon,
        ),
      ),
    );
  }
}
