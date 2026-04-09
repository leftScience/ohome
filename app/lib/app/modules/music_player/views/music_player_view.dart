import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../widgets/media_player_header_title.dart';
import '../../../widgets/playlist_loading_view.dart';
import '../controllers/music_player_controller.dart';

class MusicPlayerView extends StatefulWidget {
  const MusicPlayerView({super.key});

  static const double _playlistItemExtent = 74;

  @override
  State<MusicPlayerView> createState() => _MusicPlayerViewState();
}

class _MusicPlayerViewState extends State<MusicPlayerView> {
  final MusicPlayerController controller = Get.find<MusicPlayerController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.handleRouteArguments(Get.arguments);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Obx(
          () => MediaPlayerHeaderTitle(
            title: controller.playlistTitle.value,
            titleColor: Colors.white,
            fallbackTitle: '播客',
          ),
        ),
        actions: [
          _buildSkipSettingsAction(context),
          _buildSleepTimerAction(context),
          _buildVolumeAction(context),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F1144), Color(0xFF06030F)],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoadingPlaylist.value) {
              return const PlaylistLoadingView(
                message: '正在加载播放列表...',
                accentColor: Color(0xFF2563FF),
              );
            }
            if (controller.tracks.isEmpty) {
              return const Center(
                child: Text('播放列表为空', style: TextStyle(color: Colors.white70)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 48.h),
                Expanded(child: _buildPlaybackInfoArea(context)),
                SizedBox(height: 24.h),
                _buildControlsCard(context),
                SizedBox(height: 24.h),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPlaybackInfoArea(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildArtworkSection(context),
        SizedBox(height: 24.h),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNowPlayingMeta(context),
                SizedBox(height: 12.h),
                _buildProgressCard(context),
                _buildSleepTimerInfo(),
                _buildSkipInfo(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkSection(BuildContext context) {
    return Obx(() {
      final track = controller.currentTrack;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        child: Column(
          children: [
            Container(
              width: 160.w,
              height: 160.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.r),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .35),
                    Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: .35),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.music_note, size: 110.r, color: Colors.white),
            ),
            SizedBox(height: 24.h),
            Text(
              track?.title ?? '未选择音频',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNowPlayingMeta(BuildContext context) {
    return Obx(() {
      final track = controller.currentTrack;
      final path = track?.path ?? '';
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '\u6b63\u5728\u64ad\u653e',
                    style: TextStyle(
                      fontSize: 11.sp,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${controller.currentIndex.value + 1}/${controller.tracks.length}',
                  style: TextStyle(color: Colors.white60, fontSize: 12.sp),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            if (path.isNotEmpty)
              Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildProgressCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: _buildProgressSection(context),
    );
  }

  Widget _buildControlsCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: _buildControls(context),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Obx(() {
      final total = controller.duration.value;
      final totalMs = total.inMilliseconds;
      final position = controller.position.value;
      final currentMs = position.inMilliseconds;
      final double sliderMax = totalMs > 0 ? totalMs.toDouble() : 1.0;
      final double sliderValue = totalMs > 0
          ? currentMs.clamp(0, totalMs).toDouble()
          : currentMs.toDouble().clamp(0.0, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: sliderValue,
              min: 0,
              max: sliderMax,
              onChanged: totalMs > 0
                  ? (value) =>
                        controller.seekTo(Duration(milliseconds: value.round()))
                  : null,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                controller.formatDuration(position),
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
              Text(
                controller.formatDuration(total),
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildControls(BuildContext context) {
    return Obx(() {
      final playing = controller.isPlaying.value;
      final buffering = controller.isBuffering.value;
      final canSkip = controller.tracks.length > 1 && !buffering;
      final skipIconSize = 28.w;
      final actionSpacing = 14.w;
      final mainButtonSize = 68.w;
      final indicatorSize = mainButtonSize * 0.35;
      return Row(
        children: [
          _buildPlayModeButton(),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: skipIconSize,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minHeight: skipIconSize + 12.w,
                        minWidth: skipIconSize + 12.w,
                      ),
                      onPressed: canSkip ? controller.playPrevious : null,
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: actionSpacing),
                    SizedBox(
                      width: mainButtonSize,
                      height: mainButtonSize,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: buffering ? null : controller.togglePlayback,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: buffering
                              ? SizedBox(
                                  width: indicatorSize,
                                  height: indicatorSize,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey<bool>(playing),
                                  size: mainButtonSize * 0.5,
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: actionSpacing),
                    IconButton(
                      iconSize: skipIconSize,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minHeight: skipIconSize + 12.w,
                        minWidth: skipIconSize + 12.w,
                      ),
                      onPressed: canSkip
                          ? () => controller.playNext(fromAutoComplete: false)
                          : null,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          _buildPlaylistButton(context),
        ],
      );
    });
  }

  Widget _buildSleepTimerInfo() {
    return Obx(() {
      final remaining = controller.sleepRemaining.value;
      if (remaining == null) {
        return SizedBox(height: 4.h);
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 0),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 18.r, color: Colors.white70),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                '将在 ${controller.formatDuration(remaining)} 后停止播放',
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
              onPressed: controller.cancelSleepTimer,
              child: const Text('取消'),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSkipInfo() {
    return Obx(() {
      final intro = controller.skipIntro.value;
      final outro = controller.skipOutro.value;
      final chips = <Widget>[];
      if (intro > Duration.zero) {
        chips.add(_buildInfoTag('跳过片头 ${_formatBrief(intro)}'));
      }
      if (outro > Duration.zero) {
        chips.add(_buildInfoTag('跳过片尾 ${_formatBrief(outro)}'));
      }
      if (chips.isEmpty) return SizedBox(height: 4.h);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8.w, runSpacing: 6.h, children: chips),
        ),
      );
    });
  }

  Widget _buildSleepTimerAction(BuildContext context) {
    return Obx(() {
      final remaining = controller.sleepRemaining.value;
      final isActive = remaining != null;
      final tooltip = isActive
          ? '定时关闭：${controller.formatDuration(remaining)} 后'
          : '设置定时关闭';
      final baseColor = Colors.white.withValues(alpha: 0.12);
      final activeColor = Colors.amberAccent.withValues(alpha: 0.25);
      final enabled = controller.actionsReady.value;
      return Padding(
        padding: EdgeInsets.only(right: 6.w),
        child: IconButton(
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: isActive ? activeColor : baseColor,
            foregroundColor: Colors.white,
            minimumSize: Size(42.w, 42.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          onPressed: enabled ? () => _showSleepTimerSheet(context) : null,
          icon: Icon(
            Icons.timer_outlined,
            color: isActive ? Colors.amberAccent : Colors.white,
          ),
        ),
      );
    });
  }

  Widget _buildSkipSettingsAction(BuildContext context) {
    return Obx(() {
      final intro = controller.skipIntro.value;
      final outro = controller.skipOutro.value;
      final isActive = intro > Duration.zero || outro > Duration.zero;
      final tooltip = isActive
          ? '跳过片头${intro > Duration.zero ? ' ${_formatBrief(intro)}' : ''} / 片尾${outro > Duration.zero ? ' ${_formatBrief(outro)}' : ''}'
          : '设置跳过片头/片尾';
      final baseColor = Colors.white.withValues(alpha: 0.12);
      final activeColor = Colors.lightBlueAccent.withValues(alpha: 0.25);
      final enabled = controller.actionsReady.value;
      return Padding(
        padding: EdgeInsets.only(right: 6.w),
        child: IconButton(
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: isActive ? activeColor : baseColor,
            foregroundColor: Colors.white,
            minimumSize: Size(42.w, 42.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          onPressed: enabled ? () => _showSkipSettingsSheet(context) : null,
          icon: Icon(
            Icons.content_cut_rounded,
            color: isActive ? Colors.lightBlueAccent : Colors.white,
          ),
        ),
      );
    });
  }

  Widget _buildVolumeAction(BuildContext context) {
    return Obx(() {
      final vol = controller.volume.value.clamp(0.0, 1.0);
      final enabled = controller.actionsReady.value;
      final icon = vol == 0
          ? Icons.volume_off_rounded
          : vol < 0.5
          ? Icons.volume_down_rounded
          : Icons.volume_up_rounded;
      return Padding(
        padding: EdgeInsets.only(right: 6.w),
        child: IconButton(
          tooltip: '音量',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
            minimumSize: Size(42.w, 42.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          onPressed: enabled ? () => _showVolumeSheet(context) : null,
          icon: Icon(icon, color: Colors.white),
        ),
      );
    });
  }

  void _showVolumeSheet(BuildContext context) {
    double value = (controller.volume.value.clamp(0.0, 1.0) * 100)
        .roundToDouble();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 16.w,
                  top: 12.h,
                  bottom: 12.h + MediaQuery.of(ctx).viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '音量 ${value.round()}%',
                          style:
                              Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ) ??
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: value,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '${value.round()}%',
                        onChanged: (v) {
                          setState(() => value = v);
                          controller.setVolume(v / 100, persist: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    final options = <Duration>[
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(hours: 1),
      const Duration(hours: 2),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final remaining = controller.sleepRemaining.value;
        final isActive = controller.isSleepTimerActive && remaining != null;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('定时关闭'),
                subtitle: Text(
                  isActive
                      ? '将在 ${controller.formatDuration(remaining)} 后执行'
                      : '未开启定时关闭',
                ),
              ),
              const Divider(height: 1),
              ...options.map(
                (duration) => ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text('${duration.inMinutes} 分钟后停止'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.startSleepTimer(duration);
                  },
                ),
              ),
              if (isActive) const Divider(height: 1),
              if (isActive)
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('取消定时'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.cancelSleepTimer();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSkipSettingsSheet(BuildContext context) {
    const maxSeconds = 300.0;
    double introValue = controller.skipIntro.value.inSeconds
        .clamp(0, maxSeconds.toInt())
        .toDouble();
    double outroValue = controller.skipOutro.value.inSeconds
        .clamp(0, maxSeconds.toInt())
        .toDouble();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    ListTile(
                      leading: const Icon(Icons.subtitles_outlined),
                      title: const Text('跳过片头'),
                      subtitle: Text('当前：${introValue.round()} 秒'),
                    ),
                    Slider(
                      value: introValue,
                      min: 0,
                      max: maxSeconds,
                      divisions: maxSeconds.toInt(),
                      label: '${introValue.round()}s',
                      onChanged: (value) {
                        setState(() => introValue = value);
                        controller.setSkipIntro(
                          Duration(seconds: value.round()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.notes_rounded),
                      title: const Text('跳过片尾'),
                      subtitle: Text('当前：${outroValue.round()} 秒'),
                    ),
                    Slider(
                      value: outroValue,
                      min: 0,
                      max: maxSeconds,
                      divisions: maxSeconds.toInt(),
                      label: '${outroValue.round()}s',
                      onChanged: (value) {
                        setState(() => outroValue = value);
                        controller.setSkipOutro(
                          Duration(seconds: value.round()),
                        );
                      },
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylist(
    BuildContext context, {
    required ScrollController scrollController,
  }) {
    return Obx(() {
      final current = controller.currentIndex.value;
      final playing = controller.isPlaying.value;
      final buffering = controller.isBuffering.value;
      final total = controller.tracks.length;
      final itemExtent = MusicPlayerView._playlistItemExtent.h;
      final rowExtent = itemExtent + 1;
      return ListView.builder(
        padding: EdgeInsets.only(bottom: 16.h),
        controller: scrollController,
        itemExtent: rowExtent,
        cacheExtent: rowExtent * 8,
        addAutomaticKeepAlives: false,
        itemCount: total,
        itemBuilder: (context, index) {
          final item = controller.tracks[index];
          final isCurrent = index == current;
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              height: itemExtent,
              child: ListTile(
                onTap: () => controller.playAt(index),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w),
                minVerticalPadding: 0,
                minTileHeight: itemExtent,
                leading: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.equalizer_rounded
                        : Icons.music_note_outlined,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white70,
                  ),
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: item.path.isEmpty
                    ? null
                    : Text(
                        item.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white60,
                        ),
                      ),
                trailing: SizedBox(
                  width: 36.w,
                  height: 36.w,
                  child: Center(
                    child: isCurrent && buffering
                        ? SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : isCurrent
                        ? Icon(
                            playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () => controller.playAt(index),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildPlayModeButton() {
    return Obx(() {
      final mode = controller.playMode.value;
      final icon = _playModeIcon(mode);
      final label = _playModeLabel(mode);
      return IconButton(
        tooltip: '播放顺序：$label',
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          minimumSize: Size(46.w, 46.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        onPressed: controller.cyclePlayMode,
        icon: Icon(icon),
      );
    });
  }

  Widget _buildPlaylistButton(BuildContext context) {
    return IconButton(
      tooltip: '播放列表',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        minimumSize: Size(46.w, 46.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
      onPressed: () => _showPlaylistSheet(context),
      icon: const Icon(Icons.queue_music_rounded),
    );
  }

  void _showPlaylistSheet(BuildContext context) {
    final itemExtent = MusicPlayerView._playlistItemExtent.h;
    final rowExtent = itemExtent + 1;
    final scrollController = ScrollController(
      initialScrollOffset: controller.playlistSheetInitialOffset,
    );

    void persistPlaylistOffset({bool allowInitial = false}) {
      if (scrollController.hasClients) {
        controller.savePlaylistSheetOffset(scrollController.offset);
        return;
      }
      if (allowInitial) {
        controller.savePlaylistSheetOffset(
          scrollController.initialScrollOffset,
        );
      }
    }

    scrollController.addListener(persistPlaylistOffset);
    final sheetFuture = showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      isScrollControlled: true,
      builder: (ctx) {
        void scrollToCurrentTrack() {
          final total = controller.tracks.length;
          if (total <= 0) return;
          if (!scrollController.hasClients) return;

          final current = controller.currentIndex.value.clamp(0, total - 1);
          final target = current * rowExtent;
          final position = scrollController.position;
          final clamped = target.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          scrollController.animateTo(
            clamped,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music, color: Colors.white),
                      SizedBox(width: 8.w),
                      Text(
                        '播放列表',
                        style: Theme.of(
                          ctx,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '定位当前音频',
                        onPressed: scrollToCurrentTrack,
                        icon: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                Expanded(
                  child: _buildPlaylist(
                    ctx,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    sheetFuture.whenComplete(() {
      persistPlaylistOffset(allowInitial: true);
      scrollController.removeListener(persistPlaylistOffset);
      scrollController.dispose();
    });
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.sequential:
        return Icons.repeat_rounded;
    }
  }

  String _playModeLabel(PlayMode mode) {
    switch (mode) {
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.sequential:
        return '顺序播放';
    }
  }

  Widget _buildInfoTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.sp, color: Colors.white),
      ),
    );
  }

  String _formatBrief(Duration duration) {
    if (duration.inMinutes == 0) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60 && duration.inSeconds % 60 == 0) {
      return '${duration.inMinutes}m';
    }
    return controller.formatDuration(duration);
  }
}
