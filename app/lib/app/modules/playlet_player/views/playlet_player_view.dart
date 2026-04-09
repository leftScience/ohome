import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../widgets/media_player_header_title.dart';
import '../../player/controllers/player_controller.dart';

class PlayletPlayerView extends StatefulWidget {
  const PlayletPlayerView({super.key});

  @override
  State<PlayletPlayerView> createState() => _PlayletPlayerViewState();
}

class _PlayletPlayerViewState extends State<PlayletPlayerView>
    with WidgetsBindingObserver {
  static const double _tapMoveThreshold = 12;
  static const Duration _speedBoostDelay = Duration(milliseconds: 260);
  static const Duration _tapDurationThreshold = Duration(milliseconds: 260);

  final PlayerController controller = Get.find<PlayerController>();
  final GlobalKey _videoAreaKey = GlobalKey();
  late PageController _episodePageController;
  late int _episodePageInitialPage;
  Worker? _episodeIndexWorker;
  int? _controllerDrivenPageTarget;
  int? _pendingPageSwitchTarget;
  bool _switchingByPage = false;
  int? _activePointer;
  Offset? _swipeStart;
  Offset? _swipeLast;
  DateTime? _pointerDownAt;
  Timer? _speedBoostTimer;
  bool _speedBoostActive = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    _episodePageInitialPage = controller.currentIndex.value;
    _episodePageController = PageController(
      initialPage: _episodePageInitialPage,
    );
    _episodeIndexWorker = ever<int>(
      controller.currentIndex,
      _syncPageWithIndex,
    );
    controller.handleRouteArguments(Get.arguments);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopSpeedBoost();
      unawaited(controller.stopPlayback());
    }
  }

  @override
  void dispose() {
    _episodeIndexWorker?.dispose();
    _episodePageController.dispose();
    _stopSpeedBoost();
    unawaited(controller.stopPlayback());
    unawaited(SystemChrome.setPreferredOrientations([]));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _title() {
    final resource = controller.resourceTitle.value.trim();
    if (resource.isNotEmpty) return resource;
    final index = controller.currentIndex.value;
    if (index >= 0 && index < controller.episodes.length) {
      final title = controller.episodes[index].title.trim();
      if (title.isNotEmpty) return title;
    }
    return 'Playlet';
  }

  String _episodeSummary() {
    final total = controller.episodes.length;
    if (total <= 0) return '\u9009\u96c6';
    final current = (controller.currentIndex.value + 1).clamp(1, total);
    return '\u9009\u96c6 \u00b7 \u7b2c$current\u96c6 / \u5171$total\u96c6';
  }

  Future<void> _showEpisodeSheet(BuildContext context) async {
    if (controller.episodes.isEmpty) return;
    final scrollController = ScrollController();
    final future = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final width = MediaQuery.of(ctx).size.width;
        final crossAxisCount = width >= 420 ? 6 : 5;
        final horizontalPadding = 14.w;
        final crossSpacing = 10.w;
        final mainSpacing = 10.h;
        const cellAspectRatio = 1.1;

        void scrollToCurrentEpisode() {
          final total = controller.episodes.length;
          if (total <= 0) return;
          if (!scrollController.hasClients) return;

          final current = controller.currentIndex.value.clamp(0, total - 1);
          final gridContentWidth =
              width -
              horizontalPadding * 2 -
              crossSpacing * (crossAxisCount - 1);
          if (gridContentWidth <= 0) return;
          final cellWidth = gridContentWidth / crossAxisCount;
          final cellHeight = cellWidth / cellAspectRatio;
          final row = current ~/ crossAxisCount;
          final target = row * (cellHeight + mainSpacing);
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
          top: false,
          child: Container(
            height: 0.62.sh,
            decoration: BoxDecoration(
              color: const Color(0xFF17181C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
            ),
            child: Column(
              children: [
                SizedBox(height: 10.h),
                Container(
                  width: 52.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 10.w, 10.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => Text(
                            _episodeSummary(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '定位当前集',
                        onPressed: scrollToCurrentEpisode,
                        icon: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: Obx(() {
                    final total = controller.episodes.length;
                    final current = controller.currentIndex.value;
                    return GridView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14.h,
                        horizontalPadding,
                        14.h,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: mainSpacing,
                        crossAxisSpacing: crossSpacing,
                        childAspectRatio: cellAspectRatio,
                      ),
                      itemCount: total,
                      itemBuilder: (context, index) {
                        final selected = index == current;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: () async {
                            await controller.playAt(index);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(
                                      0xFFFF8E1F,
                                    ).withValues(alpha: 0.2)
                                  : const Color(0xFF23252A),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFFF8E1F)
                                    : Colors.white10,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFFFFA645)
                                    : Colors.white,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
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
        );
      },
    );
    await future.whenComplete(scrollController.dispose);
  }

  void _resetSwipe() {
    _activePointer = null;
    _swipeStart = null;
    _swipeLast = null;
    _pointerDownAt = null;
  }

  void _scheduleSpeedBoost(int pointer) {
    _speedBoostTimer?.cancel();
    _speedBoostTimer = Timer(_speedBoostDelay, () {
      if (!mounted) return;
      if (_activePointer != pointer) return;
      _speedBoostActive = true;
      unawaited(controller.startSpeedBoost(3.0));
    });
  }

  void _cancelSpeedBoostTimer() {
    _speedBoostTimer?.cancel();
    _speedBoostTimer = null;
  }

  void _stopSpeedBoost() {
    _cancelSpeedBoostTimer();
    if (!_speedBoostActive) return;
    _speedBoostActive = false;
    unawaited(controller.stopSpeedBoost());
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _swipeStart = event.localPosition;
    _swipeLast = event.localPosition;
    _pointerDownAt = DateTime.now();
    _scheduleSpeedBoost(event.pointer);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    _swipeLast = event.localPosition;

    final start = _swipeStart;
    if (start == null) return;
    final movingFar =
        (event.localPosition.dx - start.dx).abs() > _tapMoveThreshold ||
        (event.localPosition.dy - start.dy).abs() > _tapMoveThreshold;
    if (movingFar) {
      _cancelSpeedBoostTimer();
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      await controller.player.playOrPause();
    } catch (_) {}
  }

  void _recreateEpisodePageController(int initialPage) {
    _episodePageInitialPage = initialPage;
    _episodePageController.dispose();
    _episodePageController = PageController(initialPage: initialPage);
  }

  void _syncDetachedPageController(int index) {
    if (_episodePageController.hasClients) return;
    final total = controller.episodes.length;
    if (total <= 0) return;
    final safe = index.clamp(0, total - 1);
    if (_episodePageInitialPage == safe) return;
    _recreateEpisodePageController(safe);
  }

  void _jumpPageToIndex(int index) {
    if (!_episodePageController.hasClients) return;
    final total = controller.episodes.length;
    if (total <= 0) return;
    final safe = index.clamp(0, total - 1);
    final page = _episodePageController.page;
    final currentPage = (page ?? _episodePageController.initialPage.toDouble())
        .round();
    if (currentPage == safe) return;

    _controllerDrivenPageTarget = safe;
    _episodePageController.jumpToPage(safe);
    if (_controllerDrivenPageTarget == safe) {
      _controllerDrivenPageTarget = null;
    }
  }

  void _syncPageWithIndex(int index) {
    if (!mounted) return;
    if (!_episodePageController.hasClients) {
      _syncDetachedPageController(index);
      return;
    }
    final page = _episodePageController.page;
    final currentPage = (page ?? _episodePageController.initialPage.toDouble())
        .round();
    if (currentPage == index) return;

    _controllerDrivenPageTarget = index;
    _episodePageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (_controllerDrivenPageTarget == index) {
            _controllerDrivenPageTarget = null;
          }
        });
  }

  void _onEpisodePageChanged(int index) {
    if (_controllerDrivenPageTarget == index) {
      _controllerDrivenPageTarget = null;
      return;
    }
    _pendingPageSwitchTarget = index;
    if (_switchingByPage) return;
    unawaited(_drainPageSwitchQueue());
  }

  Future<void> _drainPageSwitchQueue() async {
    if (_switchingByPage) return;
    _switchingByPage = true;
    try {
      while (mounted) {
        final target = _pendingPageSwitchTarget;
        _pendingPageSwitchTarget = null;
        if (target == null) break;
        if (target == controller.currentIndex.value) continue;
        await controller
            .playAt(target)
            .timeout(const Duration(seconds: 8), onTimeout: () {});
        if (!mounted) return;
        if (controller.currentIndex.value != target) {
          _syncPageWithIndex(controller.currentIndex.value);
        }
      }
    } finally {
      _switchingByPage = false;
    }
  }

  Widget _buildEpisodePage({
    required int index,
    required bool active,
    required int total,
  }) {
    if (active) {
      return Listener(
        key: _videoAreaKey,
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: SizedBox.expand(
          child: Video(
            controller: controller.videoController,
            fit: BoxFit.cover,
            fill: const Color(0xFF111111),
            controls: (state) {
              final normalTheme = kDefaultMaterialVideoControlsThemeData
                  .copyWith(
                    primaryButtonBar: const [],
                    topButtonBar: const [],
                    bottomButtonBar: const [MaterialPositionIndicator()],
                  );
              return IgnorePointer(
                ignoring: true,
                child: MaterialVideoControlsTheme(
                  normal: normalTheme,
                  fullscreen: normalTheme,
                  child: AdaptiveVideoControls(state),
                ),
              );
            },
          ),
        ),
      );
    }

    final title = controller.episodes[index].title.trim();
    final hint = index + 1 >= total
        ? '\u5df2\u662f\u6700\u540e\u4e00\u96c6'
        : '\u4e0a\u6ed1\u5207\u6362\u4e0b\u4e00\u96c6';
    return Container(
      color: const Color(0xFF0C0C0C),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u7b2c${index + 1}\u96c6',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (title.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                ),
              ),
            ],
            SizedBox(height: 14.h),
            Text(
              hint,
              style: TextStyle(color: Colors.white38, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    final start = _swipeStart;
    final end = _swipeLast ?? event.localPosition;
    final pointerDownAt = _pointerDownAt;
    final speedBoostActive = _speedBoostActive;
    _stopSpeedBoost();
    _resetSwipe();
    if (speedBoostActive) return;
    if (start == null) return;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final movedFar =
        dx.abs() > _tapMoveThreshold || dy.abs() > _tapMoveThreshold;
    final elapsed = pointerDownAt == null
        ? _tapDurationThreshold + const Duration(milliseconds: 1)
        : DateTime.now().difference(pointerDownAt);
    if (movedFar || elapsed > _tapDurationThreshold) return;

    final ro = _videoAreaKey.currentContext?.findRenderObject();
    if (ro is RenderBox) {
      final height = ro.size.height;
      final bottomOverlayHeight =
          40.h + 12.h + MediaQuery.of(context).viewPadding.bottom;
      if (end.dy > height - bottomOverlayHeight) return;
    }

    unawaited(_togglePlayPause());
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _stopSpeedBoost();
    _resetSwipe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            if (controller.isLoadingPlaylist.value) {
              return const Center(child: CircularProgressIndicator());
            }
            final total = controller.episodes.length;
            if (total <= 0) {
              return Center(
                child: Text(
                  '\u6682\u65e0\u53ef\u64ad\u653e\u5267\u96c6',
                  style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                ),
              );
            }

            final current = controller.currentIndex.value.clamp(0, total - 1);
            _syncDetachedPageController(current);
            if (_episodePageController.hasClients) {
              final page = _episodePageController.page;
              final currentPage =
                  (page ?? _episodePageController.initialPage.toDouble())
                      .round();
              if (currentPage != current) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _jumpPageToIndex(current);
                });
              }
            }

            return PageView.builder(
              controller: _episodePageController,
              scrollDirection: Axis.vertical,
              dragStartBehavior: DragStartBehavior.down,
              physics: const PageScrollPhysics(),
              itemCount: total,
              onPageChanged: _onEpisodePageChanged,
              itemBuilder: (context, index) {
                return _buildEpisodePage(
                  index: index,
                  active: index == current,
                  total: total,
                );
              },
            );
          }),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 220.w),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Obx(
                          () => MediaPlayerHeaderTitle(
                            title: _title(),
                            titleColor: Colors.white,
                            fallbackTitle: '短剧',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(12.w, 0, 12.w, 6.h),
              child: Obx(() {
                final hasEpisodes = controller.episodes.isNotEmpty;
                return Opacity(
                  opacity: hasEpisodes ? 1.0 : 0.55,
                  child: GestureDetector(
                    onTap: hasEpisodes
                        ? () => _showEpisodeSheet(context)
                        : null,
                    child: Container(
                      width: double.infinity,
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _episodeSummary(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white70,
                            size: 22.w,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
