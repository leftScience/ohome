import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/media_history_entry.dart';
import '../../../routes/app_pages.dart';
import '../../music_player/controllers/music_player_controller.dart';
import '../controllers/history_controller.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late final HistoryController controller;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HistoryController>();
    _pageController = PageController(
      initialPage: controller.selectedTabIndex.value,
    );
    controller.refreshCurrentTab();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3.w,
              height: 18.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2.r),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            const Text('历史记录'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: controller.tabCount,
              onPageChanged: controller.changeCategory,
              itemBuilder: (context, tabIndex) => _buildTabPage(tabIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Obx(() {
        final labels = controller.tabLabels;
        final selected = controller.selectedTabIndex.value;
        final children = <Widget>[];

        for (var index = 0; index < labels.length; index++) {
          final isSelected = selected == index;
          children.add(
            Expanded(
              child: GestureDetector(
                onTap: () {
                  controller.changeCategory(index);
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Stack(
                  children: [
                    // 底层：未选中背景
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w400,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ),
                    // 上层：选中渐变，通过 opacity 淡入淡出
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF7C4DFF,
                                ).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (index < labels.length - 1) {
            children.add(SizedBox(width: 10.w));
          }
        }
        return Row(children: children);
      }),
    );
  }

  static MusicPlayerController? _activeMusicController() {
    if (!Get.isRegistered<MusicPlayerController>()) return null;
    return Get.find<MusicPlayerController>();
  }

  Widget _buildTabPage(int tabIndex) {
    return Obx(() {
      final records = controller.historiesOf(tabIndex);
      final loading = controller.loadingOf(tabIndex).value;
      final loadingMore = controller.loadingMoreOf(tabIndex).value;
      final hasMore = controller.hasMoreOf(tabIndex).value;
      final openingKey = controller.openingEntryKey.value;

      // 正在播放中的音频 folderPath（用于标识当前正在播放的条目）
      final musicController = _activeMusicController();
      final activeFolderPath =
          (musicController != null &&
              musicController.tracks.isNotEmpty &&
              musicController.isPlaying.value)
          ? musicController.folderPath.value.trim()
          : '';

      if (loading && records.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: () =>
            controller.loadHistories(tabIndex: tabIndex, refresh: true),
        child: records.isEmpty
            ? ListView(
                controller: controller.scrollControllerOf(tabIndex),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 120.h),
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                        border: Border.all(
                          color: const Color(
                            0xFF7C4DFF,
                          ).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        size: 36.w,
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Center(
                    child: Text(
                      '暂无历史记录',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: controller.scrollControllerOf(tabIndex),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemBuilder: (context, index) {
                  if (index >= records.length) {
                    return loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }

                  final entry = records[index];
                  final loadingEntry =
                      openingKey != null &&
                      openingKey == controller.keyForEntry(entry);

                  final isNowPlaying =
                      activeFolderPath.isNotEmpty &&
                      entry.folderPath.trim() == activeFolderPath;

                  return _HistoryTile(
                    entry: entry,
                    isLoading: loadingEntry,
                    isNowPlaying: isNowPlaying,
                    onTap: loadingEntry
                        ? null
                        : isNowPlaying
                        ? () {
                            if (Get.currentRoute != Routes.MUSIC_PLAYER) {
                              Get.toNamed(Routes.MUSIC_PLAYER);
                            }
                          }
                        : () => controller.openEntry(entry),
                    onDelete: loadingEntry
                        ? null
                        : () => controller.deleteEntry(entry),
                  );
                },
                separatorBuilder: (_, _) => SizedBox(height: 10.h),
                itemCount: records.length + (hasMore ? 1 : 0),
              ),
      );
    });
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.isLoading,
    required this.isNowPlaying,
    required this.onTap,
    required this.onDelete,
  });

  final MediaHistoryEntry entry;
  final bool isLoading;
  final bool isNowPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final folderPath = _normalizePath(entry.folderPath);
    final type = _typeLabel(entry.applicationType);
    final playedAt = _formatDate(entry.lastPlayedAt);
    final iconData = _typeIcon(entry.applicationType);
    final iconColor = _typeColor(entry.applicationType);

    return Material(
      color: isNowPlaying ? const Color(0xFF1C1833) : const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isNowPlaying
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.5)
                  : const Color(0xFF2B2B2B),
              width: isNowPlaying ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              // 类型图标
              isLoading
                  ? SizedBox(
                      width: 42.w,
                      height: 42.w,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: isNowPlaying
                            ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                            : iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: isNowPlaying
                          ? const Icon(
                              Icons.equalizer_rounded,
                              color: Color(0xFF9C6FFF),
                            )
                          : Icon(iconData, color: iconColor, size: 22.w),
                    ),
              SizedBox(width: 12.w),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isNowPlaying
                            ? const Color(0xFFCEA8FF)
                            : Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      entry.itemTitle.trim().isEmpty ? '-' : entry.itemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        if (isNowPlaying) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                              ),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              '正在播放',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                        ] else ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: iconColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                        ],
                        Text(
                          playedAt,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 右侧：正在播放时显示进入图标，否则显示删除按钮
              if (isNowPlaying)
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.8),
                  size: 22.w,
                )
              else if (!isLoading)
                IconButton(
                  onPressed: onDelete,
                  iconSize: 20.w,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                )
              else
                SizedBox(
                  width: 36.w,
                  height: 36.w,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _typeColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'tv':
        return const Color(0xFFCE93D8);
      case 'playlet':
        return const Color(0xFFFFAB91);
      case 'music':
        return const Color(0xFF90CAF9);
      case 'read':
        return const Color(0xFFA5D6A7);
      default:
        return const Color(0xFF80CBC4);
    }
  }

  String _normalizePath(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return '/';
    if (normalized.startsWith('/')) return normalized;
    return '/$normalized';
  }

  String _typeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'tv':
        return '影视';
      case 'playlet':
        return '短剧';
      case 'music':
        return '播客';
      case 'read':
        return '阅读';
      default:
        return value;
    }
  }

  IconData _typeIcon(String value) {
    switch (value.trim().toLowerCase()) {
      case 'tv':
        return Icons.movie_rounded;
      case 'playlet':
        return Icons.smart_display_rounded;
      case 'music':
        return Icons.podcasts_rounded;
      case 'read':
        return Icons.menu_book_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '未知时间';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
