import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/search_controller.dart' as search_controller;

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const _searchPlaceholder = 'assets/images/douban_default.png';

  late final search_controller.SearchController controller =
      Get.find<search_controller.SearchController>();
  late final PageController _pageController;
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: controller.recommendTabIndex.value,
    );
    _tabWorker = ever<int>(controller.recommendTabIndex, (index) {
      if (!_pageController.hasClients) return;
      final current = _pageController.page?.round();
      if (current == index) return;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isResultState() {
    return controller.keyword.value.trim().isNotEmpty;
  }

  void _handleBack() {
    if (_isResultState()) {
      FocusScope.of(context).unfocus();
      controller.resetToInitialState();
      return;
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canPop = !_isResultState();
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          FocusScope.of(context).unfocus();
          controller.resetToInitialState();
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            elevation: 0,
            titleSpacing: 0,
            leadingWidth: 48,
            leading: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _handleBack,
            ),
            title: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                height: 45.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22.r),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      const Color(0xFF448AFF).withValues(alpha: 0.15),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(1.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(21.r),
                  ),
                  child: TextField(
                    controller: controller.searchController,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.2,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索影视、短剧、播客、阅读...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 0,
                      ),
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        height: 1.2,
                        color: Colors.grey[500],
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey[400],
                        ),
                        onPressed: () => controller.performSearch(),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => controller.performSearch(),
                  ),
                ),
              ),
            ),
            actions: [
              Obx(() {
                final showCancel =
                    controller.searched.value && !controller.searching.value;
                if (!showCancel) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    controller.resetToInitialState();
                  },
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }),
            ],
          ),
          backgroundColor: const Color(0xFF121212),
          body: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: Obx(() {
              final showRecommend = controller.keyword.value.trim().isEmpty;
              if (showRecommend) {
                return _InitialArea(pageController: _pageController);
              }

              if (!controller.searched.value) return const SizedBox.shrink();
              if (controller.searching.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = controller.panResources;
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Text(
                      '暂无搜索结果',
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final textParts = item.textParts;
                  final title = textParts.title;
                  final description = textParts.description;
                  final itemUrl = item.url.trim();
                  final isTransferring = controller.transferringUrls.contains(
                    itemUrl,
                  );
                  final sourceRaw = item.source.trim();
                  final sourceName = sourceRaw.startsWith('tg:')
                      ? sourceRaw.substring(3)
                      : sourceRaw;
                  final hasSource = sourceName.isNotEmpty;
                  final dateStr = item.dateCnYmd.isNotEmpty
                      ? item.dateCnYmd
                      : item.datetime.trim();
                  final hasDate = dateStr.isNotEmpty;
                  final images = item.images;
                  final previewImage = images.isNotEmpty
                      ? images.first.trim()
                      : '';
                  final hasPreviewImage = previewImage.isNotEmpty;

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: SizedBox(
                                  width: 84.w,
                                  height: 112.h,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          _searchPlaceholder,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (hasPreviewImage)
                                        Positioned.fill(
                                          child: Image.network(
                                            previewImage,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) {
                                                  return Image.asset(
                                                    _searchPlaceholder,
                                                    fit: BoxFit.cover,
                                                  );
                                                },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: 112.h),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (hasSource || hasDate)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (hasSource)
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 8.w,
                                                          vertical: 4.h,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF7C4DFF,
                                                      ).withValues(alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999.r,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            const Color(
                                                              0xFF7C4DFF,
                                                            ).withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                top: 1.h,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .rocket_launch_rounded,
                                                            size: 10.w,
                                                            color: const Color(
                                                              0xFFB388FF,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 4.w),
                                                        Flexible(
                                                          child: Text(
                                                            sourceName,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 10.sp,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  const Color(
                                                                    0xFFB388FF,
                                                                  ),
                                                              height: 1.25,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (hasDate) ...[
                                              if (hasSource)
                                                SizedBox(width: 8.w),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    size: 11.w,
                                                    color: Colors.white38,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      color: Colors.white38,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      if (hasSource || hasDate)
                                        SizedBox(height: 10.h),
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          height: 1.45,
                                        ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        SizedBox(height: 6.h),
                                        Text(
                                          description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.white60,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 底部操作栏
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 复制链接
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: itemUrl),
                                    );
                                    Get.snackbar('提示', '已复制链接');
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    minimumSize: Size(0, 58.h),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16.r),
                                      ),
                                    ),
                                  ),
                                  icon: Icon(Icons.copy_rounded, size: 16.w),
                                  label: Text(
                                    '复制链接',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              // 竖分割
                              Container(
                                width: 1,
                                height: 30.h,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              // 转存按钮
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: isTransferring
                                      ? null
                                      : () => controller.transferQuark(item),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isTransferring
                                        ? Colors.white38
                                        : const Color(0xFFB388FF),
                                    minimumSize: Size(0, 58.h),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        bottomRight: Radius.circular(16.r),
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    isTransferring
                                        ? Icons.more_horiz_rounded
                                        : Icons.cloud_download_rounded,
                                    size: 16.w,
                                  ),
                                  label: Text(
                                    isTransferring ? '提交中...' : '一键转存',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ),
      );
    });
  }
}

class _DoubanSectionData {
  const _DoubanSectionData({required this.title, required this.items});

  final String title;
  final List<dynamic> items;
}

class _InitialArea extends GetView<search_controller.SearchController> {
  const _InitialArea({required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasHistory = controller.historyKeywords.isNotEmpty;
      if (!hasHistory) {
        return _RecommendArea(pageController: pageController);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SearchHistorySection(),
          SizedBox(height: 8.h),
          Expanded(child: _RecommendArea(pageController: pageController)),
        ],
      );
    });
  }
}

class _SearchHistorySection
    extends GetView<search_controller.SearchController> {
  const _SearchHistorySection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final keywords = controller.historyKeywords;
      if (keywords.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => controller.clearHistoryKeywords(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0),
                  minimumSize: Size(0, 28.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '清空',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: keywords
                .map((item) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF232428),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF2C2D31),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => controller.useHistoryKeyword(item),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 10.w,
                              right: 6.w,
                              top: 6.h,
                              bottom: 6.h,
                            ),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => controller.removeHistoryKeyword(item),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 2.w,
                              right: 8.w,
                              top: 6.h,
                              bottom: 6.h,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14.w,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      );
    });
  }
}

class _RecommendArea extends GetView<search_controller.SearchController> {
  const _RecommendArea({required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tabs = <_DoubanSectionData>[
        _DoubanSectionData(title: '热门电影', items: controller.hotMovies),
        _DoubanSectionData(title: '动画', items: controller.tvAnimes),
        _DoubanSectionData(title: '热门综艺', items: controller.hotVarieties),
        _DoubanSectionData(title: '热门国产剧', items: controller.hotCnDramas),
      ];

      final allEmpty = tabs.every((e) => e.items.isEmpty);
      if (allEmpty) {
        if (controller.recommendLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.recommendError.value.trim();
        if (err.isNotEmpty) {
          return Align(
            alignment: Alignment.topLeft,
            child: Text(
              '推荐加载失败：$err',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
          );
        }
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.w,
                height: 16.h,
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
              Text(
                '热门推荐',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _DoubanTabBar(
            index: controller.recommendTabIndex.value,
            tabs: tabs.map((e) => e.title).toList(growable: false),
            onChanged: (i) => controller.recommendTabIndex.value = i,
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: tabs.length,
              onPageChanged: (i) => controller.recommendTabIndex.value = i,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                return _RecommendListPage(
                  tabIndex: index,
                  items: tab.items,
                  isLoadingMore: controller.recommendLoadingMore[index],
                  hasMore: controller.recommendHasMore[index],
                  loadMoreError: controller.recommendLoadMoreError[index],
                  onRetryLoadMore: () =>
                      controller.loadMoreRecommendationsForTab(index),
                  onTapItem: (name) async {
                    controller.searchController.text = name;
                    await controller.performSearch();
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _RecommendListPage extends GetView<search_controller.SearchController> {
  const _RecommendListPage({
    required this.tabIndex,
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
    required this.loadMoreError,
    required this.onRetryLoadMore,
    required this.onTapItem,
  });

  final int tabIndex;
  final List<dynamic> items;
  final bool isLoadingMore;
  final bool hasMore;
  final String loadMoreError;
  final VoidCallback onRetryLoadMore;
  final Future<void> Function(String name) onTapItem;

  static const _placeholder = 'assets/images/douban_default.png';

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        controller.tryLoadMoreRecommendationsForTab(
          tabIndex,
          notification.metrics,
        );
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: items.isEmpty
            ? Center(
                child: Text(
                  '暂无数据',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.all(12.w),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  if (index >= items.length) {
                    final err = loadMoreError.trim();
                    if (err.isNotEmpty) {
                      return Center(
                        child: TextButton(
                          onPressed: onRetryLoadMore,
                          child: Text(
                            '加载更多失败，点我重试',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      );
                    }
                    if (isLoadingMore) {
                      return Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.w),
                        ),
                      );
                    }
                    return Center(
                      child: Text(
                        hasMore ? '继续下拉加载更多' : '没有更多了',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  final item = items[index];
                  final name = _DoubanSection._title(item);
                  final subtitle = _DoubanSection._subtitle(item);
                  final rating = _DoubanSection._rating(item);
                  final cover = _DoubanSection._cover(item).trim();

                  return InkWell(
                    onTap: () async => onTapItem(name),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: SizedBox(
                            width: 52.w,
                            height: 72.w,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    _placeholder,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (cover.isNotEmpty)
                                  Positioned.fill(
                                    child: Image.network(
                                      cover,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, error, stackTrace) {
                                        assert(() {
                                          error.toString();
                                          stackTrace?.toString();
                                          return true;
                                        }());
                                        return Image.asset(
                                          _placeholder,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              if (rating.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14.w,
                                      color: Colors.orange[600],
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      rating,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.orange[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _DoubanTabBar extends StatelessWidget {
  const _DoubanTabBar({
    required this.index,
    required this.tabs,
    required this.onChanged,
  });

  final int index;
  final List<String> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, i) {
          final selected = i == index;
          return InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                      )
                    : null,
                color: selected ? null : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DoubanSection extends StatelessWidget {
  const _DoubanSection({
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
    required this.loadMoreError,
    required this.onRetryLoadMore,
    required this.onTapItem,
  });

  final List<dynamic> items;
  final bool isLoadingMore;
  final bool hasMore;
  final String loadMoreError;
  final VoidCallback onRetryLoadMore;
  final Future<void> Function(String name) onTapItem;

  static const _placeholder = 'assets/images/douban_default.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            Text(
              '暂无数据',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
          ...items.map((item) {
            final name = _title(item);
            final subtitle = _subtitle(item);
            final rating = _rating(item);
            final cover = _cover(item).trim();

            return InkWell(
              onTap: () async => onTapItem(name),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: SizedBox(
                        width: 44.w,
                        height: 62.w,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                _placeholder,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (cover.isNotEmpty)
                              Positioned.fill(
                                child: Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stackTrace) {
                                    assert(() {
                                      error.toString();
                                      stackTrace?.toString();
                                      return true;
                                    }());
                                    return Image.asset(
                                      _placeholder,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (rating.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14.w,
                                  color: Colors.orange[600],
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  rating,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (items.isNotEmpty) SizedBox(height: 8.h),
          if (items.isNotEmpty)
            Center(
              child: Builder(
                builder: (context) {
                  final err = loadMoreError.trim();
                  if (err.isNotEmpty) {
                    return TextButton(
                      onPressed: onRetryLoadMore,
                      child: Text(
                        '加载更多失败，点我重试',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    );
                  }
                  if (isLoadingMore) {
                    return SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.w),
                    );
                  }
                  if (hasMore) {
                    return Text(
                      '继续下拉加载更多',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    );
                  }
                  return Text(
                    '没有更多了',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _title(dynamic item) {
    if (item is Map) {
      final v = item['title'] ?? item['name'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      final subject = item['subject'];
      if (subject is Map) {
        final st = subject['title'];
        if (st is String && st.trim().isNotEmpty) return st.trim();
      }
    }
    return '-';
  }

  static String _subtitle(dynamic item) {
    if (item is Map) {
      final v =
          item['card_subtitle'] ??
          item['subtitle'] ??
          item['info'] ??
          item['brief'];
      if (v is String) return v.trim();
    }
    return '';
  }

  static String _rating(dynamic item) {
    if (item is Map) {
      final rating = item['rating'];
      if (rating is Map) {
        final v = rating['value'] ?? rating['average'];
        if (v is num) return v.toStringAsFixed(1);
        if (v is String) return v.trim();
      }
    }
    return '';
  }

  static String _cover(dynamic item) {
    if (item is Map) {
      final v = item['cover_url'] ?? item['cover'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      final pic = item['pic'];
      if (pic is Map) {
        final p = pic['normal'] ?? pic['large'];
        if (p is String && p.trim().isNotEmpty) return p.trim();
      }
      final images = item['images'];
      if (images is Map) {
        final p = images['small'] ?? images['large'];
        if (p is String && p.trim().isNotEmpty) return p.trim();
      }
      final subject = item['subject'];
      if (subject is Map) {
        final u = subject['cover_url'];
        if (u is String && u.trim().isNotEmpty) return u.trim();
        final subjectPic = subject['pic'];
        if (subjectPic is Map) {
          final p = subjectPic['normal'] ?? subjectPic['large'];
          if (p is String && p.trim().isNotEmpty) return p.trim();
        }
      }
    }
    return '';
  }
}
