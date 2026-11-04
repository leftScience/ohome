import 'dart:math' as math;
import 'dart:ui';

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
          ? _itemTitle(_pickActiveTrackTitle(musicController!))
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
      final canPlay =
          (hasActiveAudio || entry != null) && !initializingPlayback;
      final bannerRadius = BorderRadius.circular(18.r);
      final leadingIcon = _resolveLeadingIcon(
        hasActiveAudio: hasActiveAudio,
        applicationType: entry?.applicationType,
      );

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBannerTap ?? (entry != null ? onContinue : onList),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: bannerRadius,
            boxShadow: [
              ...AppThemeColors.cardShadow,
              if (playing)
                BoxShadow(
                  color: AppThemeColors.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: bannerRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: double.infinity,
                height: MainTabContentInsets.historyBannerHeight.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppThemeColors.surface.withValues(alpha: 0.92),
                  borderRadius: bannerRadius,
                  border: Border.all(
                    color: playing
                        ? AppThemeColors.primary.withValues(alpha: 0.30)
                        : AppThemeColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        gradient: hasActiveAudio
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppThemeColors.primary,
                                  AppThemeColors.accent,
                                ],
                              )
                            : null,
                        color: hasActiveAudio
                            ? null
                            : entry != null
                            ? AppThemeColors.primary.withValues(alpha: 0.10)
                            : AppThemeColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: hasActiveAudio
                            ? [
                                BoxShadow(
                                  color: AppThemeColors.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: playing
                            ? const _AnimatedAudioWave()
                            : Icon(
                                leadingIcon,
                                size: 20.w,
                                color: hasActiveAudio
                                    ? Colors.white
                                    : entry != null
                                    ? AppThemeColors.primary
                                    : AppThemeColors.textMuted,
                              ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: hasActiveAudio || entry != null
                            ? onContinue
                            : onList,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppThemeColors.textPrimary,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                if (hasActiveAudio) ...[
                                  SizedBox(width: 6.w),
                                  _PlaybackStatusBadge(playing: visiblyPlaying),
                                ],
                              ],
                            ),
                            SizedBox(height: 2.5.h),
                            Text(
                              initializingPlayback ? '正在加载播放列表...' : summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppThemeColors.textMuted,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _BannerIconButton(
                      tooltip: playing ? '暂停' : '播放',
                      isPrimary: canPlay,
                      onPressed: canPlay ? onPlayButtonTap : null,
                      icon: initializingPlayback
                          ? SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20.w,
                            ),
                    ),
                    SizedBox(width: 6.w),
                    _BannerIconButton(
                      tooltip: '历史记录',
                      isPrimary: false,
                      onPressed: onList,
                      icon: Icon(Icons.queue_music_rounded, size: 19.w),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  static IconData _resolveLeadingIcon({
    required bool hasActiveAudio,
    required String? applicationType,
  }) {
    if (hasActiveAudio) {
      return Icons.graphic_eq_rounded;
    }
    switch ((applicationType ?? '').trim().toLowerCase()) {
      case 'tv':
        return Icons.movie_filter_rounded;
      case 'playlet':
        return Icons.live_tv_rounded;
      case 'music':
        return Icons.podcasts_rounded;
      case 'read':
        return Icons.menu_book_rounded;
      default:
        return Icons.history_rounded;
    }
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
    required this.isPrimary,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final bool isPrimary;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final buttonSize = 34.w;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: buttonSize,
          height: buttonSize,
        ),
        style: IconButton.styleFrom(
          backgroundColor: isPrimary && enabled
              ? AppThemeColors.primary.withValues(alpha: 0.10)
              : AppThemeColors.surfaceSunken,
          disabledBackgroundColor: AppThemeColors.surfaceSunken.withValues(
            alpha: 0.65,
          ),
          foregroundColor: isPrimary
              ? AppThemeColors.primary
              : AppThemeColors.textSecondary,
          disabledForegroundColor: AppThemeColors.textDisabled,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11.r),
          ),
        ),
        icon: icon,
      ),
    );
  }
}

/// 播放中动态声波律动条
class _AnimatedAudioWave extends StatefulWidget {
  const _AnimatedAudioWave();

  @override
  State<_AnimatedAudioWave> createState() => _AnimatedAudioWaveState();
}

class _AnimatedAudioWaveState extends State<_AnimatedAudioWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(Icons.graphic_eq_rounded, size: 20.w, color: Colors.white);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * 2 * math.pi;
        const phases = [0.0, 1.3, 2.5, 3.8];

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(phases.length, (i) {
            final v = (math.sin(phase + phases[i]) + 1) / 2;
            final barHeight = (5.0 + 11.0 * v).h;
            return Container(
              width: 2.5.w,
              height: barHeight,
              margin: EdgeInsets.symmetric(horizontal: 1.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        );
      },
    );
  }
}
