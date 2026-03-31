import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/media_history_entry.dart';
import '../../../routes/app_pages.dart';
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

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBannerTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
              ),
              child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: hasActiveAudio || entry != null ? onContinue : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (hasActiveAudio &&
                                (musicController?.isPlaying.value ??
                                    false)) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C4DFF),
                                      Color(0xFF448AFF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: const Text(
                                  '正在播放',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: hasActiveAudio || entry != null
                      ? () {
                          if (hasActiveAudio) {
                            musicController!.togglePlayback();
                          } else {
                            onContinue();
                          }
                        }
                      : null,
                  iconSize: 28,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  color: Colors.white,
                  icon: Icon(
                    hasActiveAudio &&
                            (musicController?.isPlaying.value ?? false)
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    size: 26,
                  ),
                ),
                SizedBox(width: 4.w),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onList,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 26,
                      color: Colors.white70,
                    ),
                  ),
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

  static String _typeLabel(String applicationType) {
    switch (applicationType.trim().toLowerCase()) {
      case 'tv':
        return '影视';
      case 'music':
        return '音乐';
      case 'xiaoshuo':
        return '有声书';
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
