import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

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
  final ScreenBrightness _screenBrightness = ScreenBrightness.instance;
  final VolumeController _volumeController = VolumeController.instance;

  Timer? _speedBoostTimer;
  int? _speedBoostPointer;
  Offset? _speedBoostStartPosition;
  bool _speedBoostActivated = false;
  double _gestureBrightness = 0.5;
  double _gestureVolume = 0.5;
  bool _gestureMediaLoaded = false;
  bool _gestureBrightnessChanged = false;

  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _speedBoostDelay = Duration(milliseconds: 260);
  static const double _speedBoostCancelMoveThreshold = 12;
  static const double _speedBoostZoneRatio = 0.66;
  static const double _episodeListItemExtent = 72;
  static const double _episodeDrawerItemExtent = 64;
  static const double _gestureExcludeTopRatio = 0.15;
  static const double _gestureExcludeBottomRatio = 0.18;

  @override
  void initState() {
    super.initState();
    _volumeController.showSystemUI = false;
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_loadFullscreenGestureMediaState());
    controller.handleRouteArguments(Get.arguments);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_resetGestureBrightness());
      if (controller.isFullscreen.value) return;
      unawaited(controller.stopPlayback());
    }
  }

  @override
  void dispose() {
    _cancelSpeedBoost();
    _volumeController.showSystemUI = true;
    unawaited(_resetGestureBrightness());
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
    _speedBoostStartPosition = null;
    if (_speedBoostActivated) {
      _speedBoostActivated = false;
      unawaited(controller.stopSpeedBoost());
    }
  }

  Future<void> _loadFullscreenGestureMediaState() async {
    double? brightness;
    double? volume;

    try {
      brightness = await _screenBrightness.application;
    } catch (_) {
      try {
        brightness = await _screenBrightness.system;
      } catch (_) {}
    }

    try {
      volume = await _volumeController.getVolume();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      if (brightness != null) {
        _gestureBrightness = brightness.clamp(0.0, 1.0);
      }
      if (volume != null) {
        _gestureVolume = volume.clamp(0.0, 1.0);
      }
      _gestureMediaLoaded = true;
    });
  }

  void _handleFullscreenBrightnessChanged(double value) {
    final safe = value.clamp(0.0, 1.0);
    _gestureBrightness = safe;
    _gestureBrightnessChanged = true;
    unawaited(_screenBrightness.setApplicationScreenBrightness(safe));
  }

  void _handleFullscreenVolumeChanged(double value) {
    final safe = value.clamp(0.0, 1.0);
    _gestureVolume = safe;
    unawaited(_volumeController.setVolume(safe));
  }

  Future<void> _resetGestureBrightness() async {
    if (!_gestureBrightnessChanged) return;
    _gestureBrightnessChanged = false;
    try {
      await _screenBrightness.resetApplicationScreenBrightness();
    } catch (_) {}
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

  Widget _buildFullscreenBackButton(VideoState state) {
    return Obx(() {
      final title = _fullscreenBackTitle();
      return Semantics(
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
    });
  }

  Widget _buildFullscreenEpisodeActions(BuildContext context) {
    return Obx(() {
      if (controller.episodes.isEmpty) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            onTap: () => _showEpisodeSheet(context, compact: true),
          ),
        ],
      );
    });
  }

  List<Widget> _buildFullscreenTopButtonBar(VideoState state) {
    final items = <Widget>[_buildFullscreenBackButton(state), const Spacer()];
    items.add(SizedBox(width: 8.w));
    items.add(_buildFullscreenEpisodeActions(state.context));
    items.add(SizedBox(width: 8.w));
    items.add(
      _buildActionIcon(
        enabled: true,
        icon: Icons.more_vert_rounded,
        onTap: () => _showFullscreenMoreDrawer(state.context, state),
      ),
    );

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
    _speedBoostStartPosition = local;
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
    final start = _speedBoostStartPosition;
    if (start != null) {
      final movedFar =
          (local.dx - start.dx).abs() > _speedBoostCancelMoveThreshold ||
          (local.dy - start.dy).abs() > _speedBoostCancelMoveThreshold;
      if (movedFar) {
        _speedBoostTimer?.cancel();
        _speedBoostTimer = null;
        _speedBoostPointer = null;
        _speedBoostStartPosition = null;
        if (mounted) setState(() {});
        return;
      }
    }
    if (local.dx >= width * _speedBoostZoneRatio) return;
    _speedBoostTimer?.cancel();
    _speedBoostTimer = null;
    _speedBoostPointer = null;
    _speedBoostStartPosition = null;
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

  void _scrollEpisodeSheetToCurrent(ScrollController scrollController) {
    final indices = controller.visibleEpisodeIndices;
    final selectedIndex = controller.currentIndex.value;
    final selectedVisibleIndex = indices.indexOf(selectedIndex);
    if (selectedVisibleIndex < 0) return;
    if (!scrollController.hasClients) return;
    const estimatedSeparatorHeight = 10.0;
    final target =
        (selectedVisibleIndex - 1) *
        (_episodeDrawerItemExtent.h + estimatedSeparatorHeight.h);
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
      return '$count 集';
    }
    final intro = controller.resourceIntro.value.trim();
    return intro.isNotEmpty ? intro : '更新中';
  }

  double _compactEpisodePanelWidth(MediaQueryData mediaQuery) {
    final screenWidth = mediaQuery.size.width;
    return math.min(420.0, math.max(280.0, screenWidth * 0.4));
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 13.sp,
      height: 1,
      fontWeight: FontWeight.w600,
    );
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16.sp, color: Colors.white70),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 160.w),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: textStyle.copyWith(color: Colors.white70),
                  ),
                  TextSpan(text: value, style: textStyle),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
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
    Widget buildEpisodePanel(
      BuildContext panelContext, {
      bool sidePanel = false,
    }) {
      final panelBody = Column(
        children: [
          Container(
            padding: sidePanel
                ? EdgeInsets.fromLTRB(14.w, 10.h, 6.w, 10.h)
                : EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 8.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选集',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _scrollEpisodeSheetToCurrent(scrollController),
                  icon: Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: compact ? 18 : 20,
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
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  );
                }),
                if (!sidePanel)
                  IconButton(
                    onPressed: () => Navigator.of(panelContext).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: compact ? 20 : 24,
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: sidePanel ? Colors.white12 : Colors.white24,
          ),
          Expanded(
            child: Obx(() {
              final indices = controller.visibleEpisodeIndices;
              final selectedIndex = controller.currentIndex.value;
              final fontSize = compact ? 13.0 : 15.0.sp;
              return ListView.separated(
                controller: scrollController,
                padding: sidePanel
                    ? EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h)
                    : EdgeInsets.all(16.w),
                itemCount: indices.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (context, i) {
                  final episodeIndex = indices[i];
                  final selected = episodeIndex == selectedIndex;
                  final theme = Theme.of(context);
                  final bg = selected
                      ? theme.colorScheme.primary
                      : sidePanel
                      ? Colors.white10
                      : Colors.white12;
                  return Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10.r),
                        border: sidePanel
                            ? Border.all(
                                color: selected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.28,
                                      )
                                    : Colors.white.withValues(alpha: 0.08),
                              )
                            : null,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10.r),
                        onTap: () async {
                          await controller.playAt(episodeIndex);
                          if (context.mounted) {
                            Navigator.of(panelContext).pop();
                          }
                        },
                        child: sidePanel
                            ? ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: _episodeDrawerItemExtent.h,
                                ),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: 14.r,
                                    end: 12.r,
                                    top: 10.h,
                                    bottom: 10.h,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _episodeLabel(episodeIndex),
                                          textAlign: TextAlign.start,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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
                                        SizedBox(width: 8.w),
                                        const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: _episodeDrawerItemExtent.h,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 40.w,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _episodeLabel(episodeIndex),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              fontSize: fontSize,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Positioned(
                                        right: 12.w,
                                        top: 0,
                                        bottom: 0,
                                        child: const Center(
                                          child: Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      );

      if (sidePanel) {
        return Material(
          clipBehavior: Clip.antiAlias,
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.horizontal(left: Radius.circular(20.r)),
          child: panelBody,
        );
      }

      return Container(
        height: 0.82.sh,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: panelBody,
      );
    }

    final future = compact
        ? showGeneralDialog<void>(
            context: context,
            useRootNavigator: true,
            barrierDismissible: true,
            barrierLabel: MaterialLocalizations.of(
              context,
            ).modalBarrierDismissLabel,
            barrierColor: Colors.black38,
            transitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (dialogContext, animation, secondaryAnimation) {
              final mediaQuery = MediaQuery.of(dialogContext);
              final data = mediaQuery.copyWith(
                textScaler: const TextScaler.linear(0.9),
              );
              final panelWidth = _compactEpisodePanelWidth(mediaQuery);
              return MediaQuery(
                data: data,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: panelWidth,
                      height: mediaQuery.size.height,
                      child: buildEpisodePanel(dialogContext, sidePanel: true),
                    ),
                  ),
                ),
              );
            },
            transitionBuilder:
                (dialogContext, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          )
        : showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              final mediaQuery = MediaQuery.of(context);
              final data = compact
                  ? mediaQuery.copyWith(
                      textScaler: const TextScaler.linear(0.9),
                    )
                  : mediaQuery;
              return MediaQuery(
                data: data,
                child: SafeArea(child: buildEpisodePanel(context)),
              );
            },
          );
    future.whenComplete(scrollController.dispose);
  }

  void _showSkipSettingsSheet(
    BuildContext context, {
    bool fullscreenDrawer = false,
  }) {
    const maxSeconds = 300.0;
    double introValue = controller.skipIntro.value.inSeconds
        .clamp(0, maxSeconds.toInt())
        .toDouble();
    double outroValue = controller.skipOutro.value.inSeconds
        .clamp(0, maxSeconds.toInt())
        .toDouble();

    Widget buildBody(
      BuildContext ctx,
      void Function(void Function()) setState,
    ) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSliderSheetSection(
            context: ctx,
            icon: Icons.subtitles_outlined,
            title: '跳过片头',
            valueText: '${introValue.round()} 秒',
            titleFontSize: 6.sp,
            valueFontSize: 4.sp,
            iconSize: 10.sp,
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
            slider: Slider(
              value: introValue,
              min: 0,
              max: maxSeconds,
              divisions: maxSeconds.toInt(),
              label: '${introValue.round()}s',
              onChanged: (value) {
                setState(() => introValue = value);
                unawaited(
                  controller.setSkipIntro(Duration(seconds: value.round())),
                );
              },
            ),
          ),
          SizedBox(height: 12.h),
          _buildSliderSheetSection(
            context: ctx,
            icon: Icons.notes_rounded,
            title: '跳过片尾',
            valueText: '${outroValue.round()} 秒',
            titleFontSize: 6.sp,
            valueFontSize: 4.sp,
            iconSize: 10.sp,
            slider: Slider(
              value: outroValue,
              min: 0,
              max: maxSeconds,
              divisions: maxSeconds.toInt(),
              label: '${outroValue.round()}s',
              onChanged: (value) {
                setState(() => outroValue = value);
                unawaited(
                  controller.setSkipOutro(Duration(seconds: value.round())),
                );
              },
            ),
          ),
        ],
      );
    }

    Widget buildContent(
      BuildContext ctx,
      void Function(void Function()) setState,
    ) {
      return _buildStandardBottomSheet(
        context: ctx,
        title: '跳过片头片尾',
        subtitle: '片头 ${introValue.round()} 秒 · 片尾 ${outroValue.round()} 秒',
        titleFontSize: 8.sp,
        subtitleFontSize: 5.sp,
        child: buildBody(ctx, setState),
      );
    }

    if (fullscreenDrawer) {
      _showFullscreenSideDrawer(
        context,
        childBuilder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setState) => _buildFullscreenDrawerContainer(
              child: _buildFullscreenDrawerSection(
                title: '跳过片头片尾',
                subtitle:
                    '片头 ${introValue.round()} 秒 · 片尾 ${outroValue.round()} 秒',
                titleFontSize: 8.sp,
                subtitleFontSize: 5.sp,
                child: buildBody(ctx, setState),
              ),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return buildContent(ctx, setState);
          },
        );
      },
    );
  }

  void _showPlaybackRateSheet(
    BuildContext context, {
    bool fullscreenDrawer = false,
  }) {
    Widget buildBody(BuildContext ctx, {bool compact = false}) {
      return Obx(() {
        final currentRate = controller.playbackRate.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _speeds
              .map((value) {
                final selected = (currentRate - value).abs() < 0.001;
                return _buildSheetOptionTile(
                  context: ctx,
                  title: _formatRate(value),
                  selected: selected,
                  titleFontSize: compact ? 6.sp : null,
                  subtitleFontSize: compact ? 4.sp : null,
                  trailingIconSize: compact ? 10.sp : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(controller.setPlaybackRate(value));
                  },
                );
              })
              .toList(growable: false),
        );
      });
    }

    Widget buildContent(BuildContext ctx) {
      return Obx(() {
        final currentRate = controller.playbackRate.value;
        return _buildStandardBottomSheet(
          context: ctx,
          title: '倍速',
          subtitle: '当前：${_formatRate(currentRate)}',
          child: buildBody(ctx),
        );
      });
    }

    if (fullscreenDrawer) {
      _showFullscreenSideDrawer(
        context,
        childBuilder: (ctx) => _buildFullscreenDrawerContainer(
          child: Obx(() {
            final currentRate = controller.playbackRate.value;
            return _buildFullscreenDrawerSection(
              title: '倍速',
              subtitle: '当前：${_formatRate(currentRate)}',
              child: buildBody(ctx, compact: true),
            );
          }),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return buildContent(ctx);
      },
    );
  }

  void _showAudioTrackSheet(
    BuildContext context, {
    bool fullscreenDrawer = false,
  }) {
    if (!controller.canSwitchAudioTrack) {
      Get.snackbar('提示', '当前视频未发现可切换音轨');
      return;
    }

    Widget buildBody(BuildContext ctx, {bool compact = false}) {
      return Obx(() {
        final options = controller.audioTrackOptions;
        final current = controller.currentAudioTrack.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((track) {
                final selected = current != null
                    ? current == track
                    : track.id == 'auto';
                return _buildSheetOptionTile(
                  context: ctx,
                  title: controller.audioTrackTitle(track),
                  subtitle: controller.audioTrackSubtitle(track),
                  selected: selected,
                  titleFontSize: compact ? 6.sp : null,
                  subtitleFontSize: compact ? 4.sp : null,
                  trailingIconSize: compact ? 10.sp : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(controller.setAudioTrackSelection(track));
                  },
                );
              })
              .toList(growable: false),
        );
      });
    }

    Widget buildContent(BuildContext ctx) {
      return Obx(() {
        final current = controller.currentAudioTrackDisplayLabel;
        return _buildStandardBottomSheet(
          context: ctx,
          title: '音轨',
          subtitle: '当前：$current',
          child: buildBody(ctx),
        );
      });
    }

    if (fullscreenDrawer) {
      _showFullscreenSideDrawer(
        context,
        childBuilder: (ctx) => _buildFullscreenDrawerContainer(
          child: Obx(() {
            final current = controller.currentAudioTrackDisplayLabel;
            return _buildFullscreenDrawerSection(
              title: '音轨',
              subtitle: '当前：$current',
              child: buildBody(ctx, compact: true),
            );
          }),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildContent(ctx),
    );
  }

  void _showSubtitleTrackSheet(
    BuildContext context, {
    bool fullscreenDrawer = false,
  }) {
    if (!controller.canSwitchSubtitleTrack) {
      Get.snackbar('提示', '当前视频未发现可切换字幕');
      return;
    }

    Widget buildBody(BuildContext ctx, {bool compact = false}) {
      return Obx(() {
        final options = controller.subtitleTrackOptions;
        final current = controller.currentSubtitleTrack.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((track) {
                final selected = current != null
                    ? current == track
                    : track.id == 'auto';
                return _buildSheetOptionTile(
                  context: ctx,
                  title: controller.subtitleTrackTitle(track),
                  subtitle: controller.subtitleTrackSubtitle(track),
                  selected: selected,
                  titleFontSize: compact ? 6.sp : null,
                  subtitleFontSize: compact ? 4.sp : null,
                  trailingIconSize: compact ? 10.sp : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(controller.setSubtitleTrackSelection(track));
                  },
                );
              })
              .toList(growable: false),
        );
      });
    }

    Widget buildContent(BuildContext ctx) {
      return Obx(() {
        final current = controller.currentSubtitleTrackDisplayLabel;
        return _buildStandardBottomSheet(
          context: ctx,
          title: '字幕',
          subtitle: '当前：$current',
          child: buildBody(ctx),
        );
      });
    }

    if (fullscreenDrawer) {
      _showFullscreenSideDrawer(
        context,
        childBuilder: (ctx) => _buildFullscreenDrawerContainer(
          child: Obx(() {
            final current = controller.currentSubtitleTrackDisplayLabel;
            return _buildFullscreenDrawerSection(
              title: '字幕',
              subtitle: '当前：$current',
              child: buildBody(ctx, compact: true),
            );
          }),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildContent(ctx),
    );
  }

  void _showPlaybackProxyModeSheet(
    BuildContext context, {
    bool fullscreenDrawer = false,
  }) {
    if (!controller.canSwitchCurrentPlaybackProxyMode) {
      Get.snackbar('提示', '当前视频不支持切换播放模式');
      return;
    }

    const options = <({String value, String title, String subtitle})>[
      (value: 'native_proxy', title: '本地代理', subtitle: '稳定，适合大多数播放场景'),
      (value: '302_redirect', title: '302', subtitle: '直连转码，仅本地播放；投屏不支持'),
    ];

    Widget buildBody(BuildContext ctx) {
      return Obx(() {
        final currentMode = controller.effectivePlaybackProxyMode;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((option) {
                final selected = currentMode == option.value;
                return _buildSheetOptionTile(
                  context: ctx,
                  title: option.title,
                  subtitle: option.subtitle,
                  selected: selected,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(
                      controller.setCurrentPlaybackProxyMode(option.value),
                    );
                  },
                );
              })
              .toList(growable: false),
        );
      });
    }

    Widget buildContent(BuildContext ctx) {
      return Obx(() {
        return _buildStandardBottomSheet(
          context: ctx,
          title: '当前播放模式',
          subtitle:
              '切换后会重载当前视频，并对后续选集生效 · 当前：${controller.effectivePlaybackProxyModeLabel}',
          child: buildBody(ctx),
        );
      });
    }

    if (fullscreenDrawer) {
      _showFullscreenSideDrawer(
        context,
        childBuilder: (ctx) => _buildFullscreenDrawerContainer(
          child: Obx(() {
            return _buildFullscreenDrawerSection(
              title: '当前播放模式',
              subtitle:
                  '切换后会重载当前视频，并对后续选集生效 · 当前：${controller.effectivePlaybackProxyModeLabel}',
              child: buildBody(ctx),
            );
          }),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildContent(ctx),
    );
  }

  void _showFullscreenMoreDrawer(BuildContext context, VideoState state) {
    _showFullscreenSideDrawer(
      context,
      childBuilder: (ctx) => _buildFullscreenMoreDrawerPanel(ctx, state),
    );
  }

  void _showFullscreenSideDrawer(
    BuildContext context, {
    required WidgetBuilder childBuilder,
  }) {
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final panelWidth = _compactEpisodePanelWidth(mediaQuery);
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: panelWidth,
              height: mediaQuery.size.height,
              child: childBuilder(dialogContext),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildFullscreenDrawerContainer({required Widget child}) {
    return Material(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.horizontal(left: Radius.circular(20.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 12.h),
        child: child,
      ),
    );
  }

  Widget _buildFullscreenDrawerSection({
    required String title,
    String? subtitle,
    required Widget child,
    double? titleFontSize,
    double? subtitleFontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 15.h),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize ?? 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 15.h),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: subtitleFontSize ?? 5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }

  Widget _buildFullscreenSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(icon, color: Colors.white60, size: 10.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 6.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 4.5.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 10.sp,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  Widget _buildFullscreenMoreDrawerPanel(
    BuildContext context,
    VideoState state,
  ) {
    return Obx(() {
      final isCover = controller.isFullscreenCover;
      final currentRate = controller.playbackRate.value;
      final currentPlaybackMode = controller.effectivePlaybackProxyModeLabel;
      final currentAudioTrack = controller.currentAudioTrackDisplayLabel;
      return _buildFullscreenDrawerContainer(
        child: _buildFullscreenDrawerSection(
          title: '更多设置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFullscreenSettingRow(
                icon: Icons.aspect_ratio_rounded,
                title: '画面模式',
                subtitle: isCover ? '铺满裁切' : '完整显示',
                onTap: () {
                  Navigator.of(context).pop();
                  controller.toggleFullscreenFitMode();
                  state.update(
                    fit: controller.isFullscreenCover
                        ? BoxFit.cover
                        : BoxFit.contain,
                  );
                },
              ),
              _buildFullscreenSettingRow(
                icon: Icons.route_rounded,
                title: '播放模式',
                subtitle: currentPlaybackMode,
                onTap: () {
                  Navigator.of(context).pop();
                  _showPlaybackProxyModeSheet(
                    state.context,
                    fullscreenDrawer: true,
                  );
                },
              ),
              if (controller.canSwitchAudioTrack)
                _buildFullscreenSettingRow(
                  icon: Icons.audiotrack_rounded,
                  title: '音轨',
                  subtitle: currentAudioTrack,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAudioTrackSheet(state.context, fullscreenDrawer: true);
                  },
                ),
              if (controller.canSwitchSubtitleTrack)
                _buildFullscreenSettingRow(
                  icon: Icons.subtitles_rounded,
                  title: '字幕',
                  subtitle: controller.currentSubtitleTrackDisplayLabel,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSubtitleTrackSheet(
                      state.context,
                      fullscreenDrawer: true,
                    );
                  },
                ),
              _buildFullscreenSettingRow(
                icon: Icons.speed_rounded,
                title: '倍速',
                subtitle: _formatRate(currentRate),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPlaybackRateSheet(state.context, fullscreenDrawer: true);
                },
              ),
              _buildFullscreenSettingRow(
                icon: Icons.skip_next_rounded,
                title: '跳过片头片尾',
                subtitle:
                    '片头 ${controller.skipIntro.value.inSeconds} 秒 · 片尾 ${controller.skipOutro.value.inSeconds} 秒',
                showDivider: false,
                onTap: () {
                  Navigator.of(context).pop();
                  _showSkipSettingsSheet(state.context, fullscreenDrawer: true);
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStandardBottomSheet({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    double? titleFontSize,
    double? subtitleFontSize,
    double? maxWidth,
  }) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 320.w),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 14.h),
                  Center(
                    child: Container(
                      width: 42.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleFontSize ?? 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: subtitleFontSize ?? 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOptionTile({
    required BuildContext context,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    double? titleFontSize,
    double? subtitleFontSize,
    double? trailingIconSize,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize ?? 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: subtitleFontSize ?? 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? primary : Colors.white38,
                  size: trailingIconSize ?? 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSheetSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String valueText,
    required Widget slider,
    Widget? trailing,
    double? titleFontSize,
    double? valueFontSize,
    double? iconSize,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: iconSize ?? 20.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize ?? 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '当前：$valueText',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: valueFontSize ?? 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3.2),
            child: slider,
          ),
        ],
      ),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
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

  Widget _buildFullscreenBottomControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return MaterialCustomButton(
      iconSize: 24,
      icon: Icon(icon, size: 24),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        toolbarHeight: 56,
        leadingWidth: 40,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        actions: [
          const SizedBox(width: 8),
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
                const SizedBox(width: 6),
                _buildAppBarActionIcon(
                  enabled: true,
                  icon: Icons.stop_screen_share_outlined,
                  tooltip: '停止投屏',
                  onTap: () => unawaited(controller.stopCasting()),
                ),
              ],
            );
          }),
          const SizedBox(width: 10),
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

            return Column(
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

                                final fullscreenTheme = (() {
                                  final fullscreenToolbarBottom = 14.h;
                                  final fullscreenToolbarHeight = 56.0;
                                  final fullscreenSeekGap = 10.h;
                                  return kDefaultMaterialVideoControlsThemeDataFullscreen
                                      .copyWith(
                                        initialBrightness: _gestureBrightness,
                                        onBrightnessChanged:
                                            _handleFullscreenBrightnessChanged,
                                        initialVolume: _gestureVolume,
                                        onVolumeChanged:
                                            _handleFullscreenVolumeChanged,
                                        topButtonBar:
                                            _buildFullscreenTopButtonBar(state),
                                        bottomButtonBar: [
                                          _buildNextEpisodeControlsButton(),
                                          SizedBox(width: 6.w),
                                          const MaterialPositionIndicator(),
                                          const Spacer(),
                                          _buildFullscreenBottomControlButton(
                                            icon: Icons.speed_rounded,
                                            onPressed: () =>
                                                _showPlaybackRateSheet(
                                                  state.context,
                                                  fullscreenDrawer: true,
                                                ),
                                          ),
                                          SizedBox(width: 6.w),
                                          const MaterialFullscreenButton(),
                                        ],
                                        bottomButtonBarMargin: EdgeInsets.only(
                                          left: 16.w,
                                          right: 8.w,
                                          bottom: fullscreenToolbarBottom,
                                        ),
                                        seekBarMargin: EdgeInsets.only(
                                          left: 16.w,
                                          right: 16.w,
                                          bottom:
                                              fullscreenToolbarBottom +
                                              fullscreenToolbarHeight +
                                              fullscreenSeekGap,
                                        ),
                                      );
                                })();
                                return MaterialVideoControlsTheme(
                                  normal: normalTheme,
                                  fullscreen: fullscreenTheme,
                                  child: KeyedSubtree(
                                    key: ValueKey(
                                      'player-fullscreen-gestures-${_gestureMediaLoaded ? 1 : 0}',
                                    ),
                                    child: AdaptiveVideoControls(state),
                                  ),
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
                  Expanded(
                    child: Obx(() {
                      if (controller.isFullscreen.value) {
                        return const SizedBox.shrink();
                      }
                      final currentRate = _formatRate(
                        controller.playbackRate.value,
                      );
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
                                if (controller
                                    .canSwitchCurrentPlaybackProxyMode)
                                  _buildInfoPill(
                                    icon: Icons.route_rounded,
                                    label: '播放',
                                    value: controller
                                        .effectivePlaybackProxyModeLabel,
                                    onTap: () =>
                                        _showPlaybackProxyModeSheet(context),
                                  ),
                                if (controller.canSwitchAudioTrack)
                                  _buildInfoPill(
                                    icon: Icons.audiotrack_rounded,
                                    label: '音轨',
                                    value: controller
                                        .currentAudioTrackDisplayLabel,
                                    onTap: () => _showAudioTrackSheet(context),
                                  ),
                                if (controller.canSwitchSubtitleTrack)
                                  _buildInfoPill(
                                    icon: Icons.subtitles_rounded,
                                    label: '字幕',
                                    value: controller
                                        .currentSubtitleTrackDisplayLabel,
                                    onTap: () =>
                                        _showSubtitleTrackSheet(context),
                                  ),
                                _buildInfoPill(
                                  icon: Icons.speed_rounded,
                                  label: '倍速',
                                  value: currentRate,
                                  onTap: () => _showPlaybackRateSheet(context),
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
                              Expanded(
                                child: Obx(() {
                                  final indices =
                                      controller.visibleEpisodeIndices;
                                  final selected =
                                      controller.currentIndex.value;
                                  return ListView.separated(
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
                                  );
                                }),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
