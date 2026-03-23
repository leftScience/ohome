import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../widgets/playlist_loading_view.dart';
import '../controllers/player_controller.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with WidgetsBindingObserver {
  final PlayerController controller = Get.find<PlayerController>();
  final ScrollController _episodeScrollController = ScrollController();

  Timer? _speedBoostTimer;
  int? _speedBoostPointer;
  bool _speedBoostActivated = false;

  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _speedBoostDelay = Duration(milliseconds: 260);
  static const double _speedBoostZoneRatio = 0.66;
  static const double _episodeListItemExtent = 72;
  static const double _gestureExcludeTopRatio = 0.15;
  static const double _gestureExcludeBottomRatio = 0.18;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    controller.handleRouteArguments(Get.arguments);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller.isFullscreen.value) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(controller.stopPlayback());
    }
  }

  @override
  void dispose() {
    _cancelSpeedBoost();
    unawaited(controller.stopPlayback());
    unawaited(SystemChrome.setPreferredOrientations([]));
    WidgetsBinding.instance.removeObserver(this);
    _episodeScrollController.dispose();
    super.dispose();
  }

  void _cancelSpeedBoost() {
    _speedBoostTimer?.cancel();
    _speedBoostTimer = null;
    _speedBoostPointer = null;
    if (_speedBoostActivated) {
      _speedBoostActivated = false;
      unawaited(controller.stopSpeedBoost());
    }
  }

  String _fullscreenBackTitle() {
    final index = controller.currentIndex.value;
    if (index >= 0 && index < controller.episodes.length) {
      final episode = controller.episodes[index];
      final title = episode.title.trim();
      if (title.isNotEmpty) return title;
      final subTitle = episode.subTitle.trim();
      if (subTitle.isNotEmpty) return subTitle;
    }
    final resource = controller.resourceTitle.value.trim();
    if (resource.isNotEmpty) return resource;
    return '返回';
  }

  List<Widget> _buildFullscreenTopButtonBar(VideoState state) {
    final title = _fullscreenBackTitle();
    final hasEpisodes = controller.episodes.isNotEmpty;

    final backButton = Semantics(
      button: true,
      label: '\u8fd4\u56de\uff1a$title',
      child: Material(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(24.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(24.r),
          onTap: () => unawaited(exitFullscreen(state.context)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                SizedBox(width: 4.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 280.w),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final items = <Widget>[backButton, const Spacer()];

    items.add(
      Obx(() {
        final rate = controller.playbackRate.value;
        return PopupMenuButton<double>(
          color: const Color(0xFF1A1A1A),
          initialValue: rate,
          onSelected: (value) => unawaited(controller.setPlaybackRate(value)),
          itemBuilder: (context) {
            return _speeds
                .map(
                  (value) => PopupMenuItem<double>(
                    value: value,
                    child: Text(
                      _formatRate(value),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(growable: false);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _formatRate(rate),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );

    items.add(SizedBox(width: 8.w));
    items.add(_buildFullscreenFitModeToggle(state));
    items.add(SizedBox(width: 8.w));

    if (!hasEpisodes) return items;

    items.addAll([
      _buildActionIcon(
        enabled: controller.canCastCurrentEpisode,
        icon: controller.isCasting ? Icons.cast_connected : Icons.cast,
        onTap: () => unawaited(controller.castCurrentEpisode()),
      ),
      SizedBox(width: 8.w),
      if (controller.isCasting) ...[
        _buildActionIcon(
          enabled: true,
          icon: Icons.stop_screen_share_outlined,
          onTap: () => unawaited(controller.stopCasting()),
        ),
        SizedBox(width: 8.w),
      ],
      _buildActionIcon(
        enabled: true,
        icon: Icons.format_list_bulleted,
        onTap: () => _showEpisodeSheet(state.context, compact: true),
      ),
      SizedBox(width: 8.w),
      _buildActionIcon(
        enabled: true,
        icon: Icons.access_time,
        onTap: () => _showSkipSettingsSheet(state.context),
      ),
    ]);

    return items;
  }

  void _onSpeedBoostPointerDown(VideoState state, PointerDownEvent event) {
    if (_speedBoostPointer != null) return;
    final ro = state.context.findRenderObject();
    if (ro is! RenderBox) return;
    final local = ro.globalToLocal(event.position);
    final width = ro.size.width;
    final height = ro.size.height;
    if (width <= 0) return;
    if (height <= 0) return;
    if (local.dx < width * _speedBoostZoneRatio) return;
    if (local.dy < height * _gestureExcludeTopRatio) return;
    if (local.dy > height * (1 - _gestureExcludeBottomRatio)) return;

    _speedBoostPointer = event.pointer;
    _speedBoostActivated = false;
    _speedBoostTimer?.cancel();
    _speedBoostTimer = Timer(_speedBoostDelay, () {
      if (_speedBoostPointer != event.pointer) return;
      _speedBoostActivated = true;
      unawaited(controller.startSpeedBoost(3.0));
    });
    if (mounted) setState(() {});
  }

  void _onSpeedBoostPointerMove(VideoState state, PointerMoveEvent event) {
    if (_speedBoostPointer != event.pointer) return;
    final ro = state.context.findRenderObject();
    if (ro is! RenderBox) return;
    final local = ro.globalToLocal(event.position);
    final width = ro.size.width;
    if (width <= 0) return;

    if (_speedBoostActivated) return;
    if (local.dx >= width * _speedBoostZoneRatio) return;
    _speedBoostTimer?.cancel();
    _speedBoostTimer = null;
    _speedBoostPointer = null;
    if (mounted) setState(() {});
  }

  void _onSpeedBoostPointerUp(PointerUpEvent event) {
    if (_speedBoostPointer != event.pointer) return;
    _cancelSpeedBoost();
    if (mounted) setState(() {});
  }

  void _onSpeedBoostPointerCancel(PointerCancelEvent event) {
    if (_speedBoostPointer != event.pointer) return;
    _cancelSpeedBoost();
    if (mounted) setState(() {});
  }

  void _scrollToCurrentEpisode() {
    if (!_episodeScrollController.hasClients) return;
    final indices = controller.visibleEpisodeIndices;
    final selected = controller.currentIndex.value;
    final visibleIndex = indices.indexOf(selected);
    if (visibleIndex < 0) return;
    final position = _episodeScrollController.position;
    final itemExtent = _episodeListItemExtent.h;
    final spacing = 10.0.h;
    final target = visibleIndex * (itemExtent + spacing);
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _episodeScrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _episodeLabel(int index) {
    if (index >= 0 && index < controller.episodes.length) {
      final title = controller.episodes[index].title.trim();
      if (title.isNotEmpty) return title;
    }
    return (index + 1).toString().padLeft(2, '0');
  }

  String _episodeCountLabel() {
    final count = controller.episodes.length;
    if (count > 0) {
      return '更新至 $count 集';
    }
    final intro = controller.resourceIntro.value.trim();
    return intro.isNotEmpty ? intro : '更新中';
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: Colors.white70),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: child,
    );
  }

  Widget _buildPortraitEpisodeTile({
    required int episodeIndex,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final episode = controller.episodes[episodeIndex];
    final title = episode.title.trim().isNotEmpty
        ? episode.title.trim()
        : '第 ${episodeIndex + 1} 集';
    final subtitle = episode.subTitle.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: _episodeListItemExtent.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white12,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${episodeIndex + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Icon(
                selected
                    ? Icons.play_circle_fill_rounded
                    : Icons.chevron_right_rounded,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white38,
                size: selected ? 22.sp : 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEpisodeSheet(BuildContext context, {bool compact = false}) {
    final scrollController = ScrollController();

    final future = showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final data = compact
            ? mediaQuery.copyWith(textScaler: const TextScaler.linear(0.9))
            : mediaQuery;
        final height = 0.82.sh;
        return MediaQuery(
          data: data,
          child: SafeArea(
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 8.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '选集',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 13 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Obx(() {
                          final asc = controller.episodesAscending.value;
                          return TextButton.icon(
                            onPressed: controller.toggleEpisodeOrder,
                            icon: Icon(
                              asc ? Icons.arrow_downward : Icons.arrow_upward,
                              color: Colors.white,
                              size: compact ? 16 : 18,
                            ),
                            label: Text(
                              asc ? '正序' : '倒序',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 12 : 14,
                              ),
                            ),
                          );
                        }),
                        IconButton(
                          onPressed: () {
                            final indices = controller.visibleEpisodeIndices;
                            final selectedIndex = controller.currentIndex.value;
                            final selectedVisibleIndex = indices.indexOf(
                              selectedIndex,
                            );
                            if (selectedVisibleIndex < 0) return;
                            if (!scrollController.hasClients) return;
                            const estimatedItemHeight = 56.0;
                            const estimatedSeparatorHeight = 10.0;
                            final target =
                                (selectedVisibleIndex - 1) *
                                (estimatedItemHeight.h +
                                    estimatedSeparatorHeight.h);
                            final position = scrollController.position;
                            final clamped = target.clamp(
                              position.minScrollExtent,
                              position.maxScrollExtent,
                            );
                            scrollController.animateTo(
                              clamped,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          icon: Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: compact ? 18 : 20,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: compact ? 20 : 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(
                    child: Obx(() {
                      final indices = controller.visibleEpisodeIndices;
                      final selectedIndex = controller.currentIndex.value;
                      final fontSize = compact ? 13.0 : 15.0.sp;
                      return ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.all(16.w),
                        itemCount: indices.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (context, i) {
                          final episodeIndex = indices[i];
                          final selected = episodeIndex == selectedIndex;
                          final theme = Theme.of(context);
                          final bg = selected
                              ? theme.colorScheme.primary
                              : Colors.white12;
                          return Material(
                            color: bg,
                            borderRadius: BorderRadius.circular(10.r),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10.r),
                              onTap: () async {
                                await controller.playAt(episodeIndex);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _episodeLabel(episodeIndex),
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          fontSize: fontSize,
                                        ),
                                      ),
                                    ),
                                    if (selected) ...[
                                      SizedBox(width: 10.w),
                                      const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    future.whenComplete(scrollController.dispose);
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
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: SingleChildScrollView(
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
                      trailing: TextButton(
                        onPressed: () async {
                          await controller.clearSkipSettings();
                          setState(() {
                            introValue = 0;
                            outroValue = 0;
                          });
                        },
                        child: const Text('清除'),
                      ),
                    ),
                    Slider(
                      value: introValue,
                      min: 0,
                      max: maxSeconds,
                      divisions: maxSeconds.toInt(),
                      label: '${introValue.round()}s',
                      onChanged: (value) {
                        setState(() => introValue = value);
                        unawaited(
                          controller.setSkipIntro(
                            Duration(seconds: value.round()),
                          ),
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
                        unawaited(
                          controller.setSkipOutro(
                            Duration(seconds: value.round()),
                          ),
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

  String _formatRate(double rate) {
    if ((rate - rate.roundToDouble()).abs() < 0.001) {
      return '${rate.toStringAsFixed(0)}x';
    }
    return '${rate.toStringAsFixed(2)}x';
  }

  Widget _buildActionIcon({
    required bool enabled,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(24.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(24.r),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarActionIcon({
    required bool enabled,
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Icon(icon, color: Colors.white, size: 18.sp),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildFullscreenFitModeToggle(VideoState state) {
    return Obx(() {
      final isCover = controller.isFullscreenCover;
      final nextMode = isCover ? '完整显示' : '铺满裁切';
      final icon = isCover ? Icons.fit_screen : Icons.crop_free;
      return Semantics(
        button: true,
        label: '画面模式，点击切换到$nextMode',
        child: Tooltip(
          message: nextMode,
          child: Material(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(24.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(24.r),
              onTap: () {
                controller.toggleFullscreenFitMode();
                state.update(
                  fit: controller.isFullscreenCover
                      ? BoxFit.cover
                      : BoxFit.contain,
                );
              },
              child: Padding(
                padding: EdgeInsets.all(10.r),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNextEpisodeControlsButton() {
    return Obx(() {
      final hasNext =
          controller.currentIndex.value + 1 < controller.episodes.length;
      return IgnorePointer(
        ignoring: !hasNext,
        child: Opacity(
          opacity: hasNext ? 1.0 : 0.45,
          child: MaterialCustomButton(
            icon: const Icon(Icons.skip_next_rounded, size: 30),
            onPressed: () => unawaited(controller.playNextEpisode()),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        toolbarHeight: 56.h,
        leadingWidth: 40.w,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
        ),
        titleSpacing: 0,
        title: Obx(
          () => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              controller.resourceTitle.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        actions: [
          Obx(() {
            final rate = controller.playbackRate.value;
            return PopupMenuButton<double>(
              color: const Color(0xFF1A1A1A),
              initialValue: rate,
              tooltip: '倍速 ${_formatRate(rate)}',
              onSelected: (value) {
                unawaited(controller.setPlaybackRate(value));
              },
              itemBuilder: (context) {
                return _speeds
                    .map(
                      (value) => PopupMenuItem<double>(
                        value: value,
                        child: Text(
                          _formatRate(value),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(growable: false);
              },
              child: IgnorePointer(
                child: _buildAppBarActionIcon(
                  enabled: true,
                  icon: Icons.speed_rounded,
                  tooltip: '倍速 ${_formatRate(rate)}',
                  onTap: () {},
                ),
              ),
            );
          }),
          SizedBox(width: 6.w),
          Obx(() {
            return _buildAppBarActionIcon(
              enabled: controller.canCastCurrentEpisode,
              icon: controller.isCasting ? Icons.cast_connected : Icons.cast,
              tooltip: controller.isCasting ? '投屏中' : '投屏',
              onTap: () => unawaited(controller.castCurrentEpisode()),
            );
          }),
          Obx(() {
            if (!controller.isCasting) return const SizedBox.shrink();
            return Row(
              children: [
                SizedBox(width: 6.w),
                _buildAppBarActionIcon(
                  enabled: true,
                  icon: Icons.stop_screen_share_outlined,
                  tooltip: '停止投屏',
                  onTap: () => unawaited(controller.stopCasting()),
                ),
              ],
            );
          }),
          SizedBox(width: 10.w),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            final isCompactHeight =
                maxWidth > maxHeight && maxHeight.isFinite && maxHeight > 0;
            final preferredVideoHeight = maxWidth * 9.0 / 16.0;
            final videoHeight = maxHeight.isFinite && maxHeight > 0
                ? math.min(preferredVideoHeight, maxHeight)
                : preferredVideoHeight;

            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: maxWidth,
                    height: videoHeight,
                    child: Obx(() {
                      if (controller.isLoadingPlaylist.value) {
                        return Container(
                          color: const Color(0xFF111111),
                          child: const PlaylistLoadingView(
                            message: '正在加载播放列表...',
                            accentColor: Color(0xFF2563FF),
                          ),
                        );
                      }
                      if (controller.episodes.isEmpty) {
                        return Container(
                          color: const Color(0xFF111111),
                          child: const Center(
                            child: Text(
                              '播放列表为空',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }
                      final useFullscreenFitMode =
                          controller.isFullscreen.value || isCompactHeight;
                      final fit = useFullscreenFitMode
                          ? (controller.isFullscreenCover
                                ? BoxFit.cover
                                : BoxFit.contain)
                          : BoxFit.contain;
                      return Video(
                        controller: controller.videoController,
                        fit: fit,
                        fill: const Color(0xFF111111),
                        controls: (state) {
                          return Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) {
                              _onSpeedBoostPointerDown(state, event);
                            },
                            onPointerMove: (event) =>
                                _onSpeedBoostPointerMove(state, event),
                            onPointerUp: _onSpeedBoostPointerUp,
                            onPointerCancel: _onSpeedBoostPointerCancel,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Obx(() {
                                  if (controller.isSpeedBoosting.value) {
                                    return const SizedBox.shrink();
                                  }
                                  final normalTheme =
                                      kDefaultMaterialVideoControlsThemeData
                                          .copyWith(
                                            bottomButtonBar: [
                                              _buildNextEpisodeControlsButton(),
                                              SizedBox(width: 6.w),
                                              const MaterialPositionIndicator(),
                                              const Spacer(),
                                              const MaterialFullscreenButton(),
                                            ],
                                          );

                                  final fullscreenTheme =
                                      kDefaultMaterialVideoControlsThemeDataFullscreen
                                          .copyWith(
                                            topButtonBar:
                                                _buildFullscreenTopButtonBar(
                                                  state,
                                                ),
                                            bottomButtonBar: [
                                              _buildNextEpisodeControlsButton(),
                                              SizedBox(width: 6.w),
                                              const MaterialPositionIndicator(),
                                              const Spacer(),
                                              const MaterialFullscreenButton(),
                                            ],
                                          );
                                  return MaterialVideoControlsTheme(
                                    normal: normalTheme,
                                    fullscreen: fullscreenTheme,
                                    child: AdaptiveVideoControls(state),
                                  );
                                }),
                                const SizedBox.shrink(),
                              ],
                            ),
                          );
                        },
                        onEnterFullscreen: () async {
                          controller.isFullscreen.value = true;
                          await defaultEnterNativeFullscreen();
                        },
                        onExitFullscreen: () async {
                          controller.isFullscreen.value = false;
                          await defaultExitNativeFullscreen();
                          await SystemChrome.setPreferredOrientations(const [
                            DeviceOrientation.portraitUp,
                          ]);
                        },
                      );
                    }),
                  ),
                  if (!isCompactHeight) SizedBox(height: 10.h),
                  if (!isCompactHeight)
                    Obx(() {
                      if (controller.isFullscreen.value) {
                        return const SizedBox.shrink();
                      }
                      final currentRate = _formatRate(
                        controller.playbackRate.value,
                      );
                      final maxListHeight = maxHeight.isFinite && maxHeight > 0
                          ? (maxHeight - videoHeight - 210.h)
                                .clamp(220.h, 420.h)
                                .toDouble()
                          : 320.h;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: [
                                _buildInfoPill(
                                  icon: Icons.update_rounded,
                                  label: '更新',
                                  value: _episodeCountLabel(),
                                ),
                                _buildInfoPill(
                                  icon: Icons.speed_rounded,
                                  label: '倍速',
                                  value: currentRate,
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Text(
                                  '选集',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Obx(() {
                                  final asc =
                                      controller.episodesAscending.value;
                                  return TextButton.icon(
                                    onPressed: controller.toggleEpisodeOrder,
                                    icon: Icon(
                                      asc
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    label: Text(
                                      asc ? '正序' : '倒序',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 8.h,
                                      ),
                                      foregroundColor: Colors.white,
                                    ),
                                  );
                                }),
                                SizedBox(width: 4.w),
                                TextButton.icon(
                                  onPressed: controller.episodes.isEmpty
                                      ? null
                                      : _scrollToCurrentEpisode,
                                  icon: Icon(
                                    Icons.my_location_rounded,
                                    color: Colors.white70,
                                    size: 18.sp,
                                  ),
                                  label: Text(
                                    '定位',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 8.h,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            if (controller.episodes.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 24.h),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  '暂无选集',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              )
                            else
                              Obx(() {
                                final indices =
                                    controller.visibleEpisodeIndices;
                                final selected = controller.currentIndex.value;
                                final contentHeight =
                                    indices.length * _episodeListItemExtent.h +
                                    math.max(0, indices.length - 1) * 10.h;
                                final viewportHeight = math.min(
                                  maxListHeight,
                                  contentHeight,
                                );
                                return SizedBox(
                                  height: viewportHeight,
                                  child: ListView.separated(
                                    controller: _episodeScrollController,
                                    padding: EdgeInsets.zero,
                                    itemCount: indices.length,
                                    separatorBuilder: (_, _) =>
                                        SizedBox(height: 10.h),
                                    itemBuilder: (context, i) {
                                      final episodeIndex = indices[i];
                                      return _buildPortraitEpisodeTile(
                                        episodeIndex: episodeIndex,
                                        selected: episodeIndex == selected,
                                        onTap: () => unawaited(
                                          controller.playAt(episodeIndex),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
