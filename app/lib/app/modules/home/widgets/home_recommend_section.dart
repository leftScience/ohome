import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/main_tab_content_insets.dart';
import '../controllers/home_recommend_controller.dart';

class HomeRecommendSection extends StatefulWidget {
  const HomeRecommendSection({super.key});

  @override
  State<HomeRecommendSection> createState() => _HomeRecommendSectionState();
}

class _HomeRecommendSectionState extends State<HomeRecommendSection> {
  late final HomeRecommendController controller;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeRecommendController>();
    _pageController = PageController(
      initialPage: controller.recommendTabIndex.value,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleTabChanged(int index) {
    controller.recommendTabIndex.value = index;
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openSearch(String name) async {
    final keyword = name.trim();
    if (keyword.isEmpty) return;
    await Get.toNamed(Routes.SEARCH, arguments: keyword);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tabs = <_DoubanSectionData>[
        _DoubanSectionData(title: '热门电影', items: controller.hotMovies),
        _DoubanSectionData(title: '动画', items: controller.tvAnimes),
        _DoubanSectionData(title: '热门综艺', items: controller.hotVarieties),
        _DoubanSectionData(title: '热门国产剧', items: controller.hotCnDramas),
      ];

      return Container(
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: AppThemeColors.border, width: 1.1),
          boxShadow: AppThemeColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildPanelHeader(tabs),
            Expanded(child: _buildPanelContent(tabs)),
          ],
        ),
      );
    });
  }

  Widget _buildPanelHeader(List<_DoubanSectionData> tabs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.w,
                height: 15.h,
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
                  color: AppThemeColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _DoubanTabBar(
            index: controller.recommendTabIndex.value,
            tabs: tabs.map((e) => e.title).toList(growable: false),
            onChanged: _handleTabChanged,
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildPanelContent(List<_DoubanSectionData> tabs) {
    final allEmpty = tabs.every((e) => e.items.isEmpty);
    if (allEmpty) {
      if (controller.recommendLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final err = controller.recommendError.value.trim();
      if (err.isNotEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '推荐加载失败',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textSecondary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  err,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppThemeColors.textMuted,
                  ),
                ),
                SizedBox(height: 6.h),
                TextButton(
                  onPressed: controller.loadRecommendations,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text(
          '暂无推荐内容',
          style: TextStyle(fontSize: 12.sp, color: AppThemeColors.textMuted),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
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
          onTapItem: _openSearch,
        );
      },
    );
  }
}

class _RecommendListPage extends GetView<HomeRecommendController> {
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
        if (notification.metrics.axis != Axis.vertical) return false;
        controller.tryLoadMoreRecommendationsForTab(
          tabIndex,
          notification.metrics,
        );
        return false;
      },
      child: items.isEmpty
          ? Center(
              child: Text(
                '暂无数据',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppThemeColors.textMuted,
                ),
              ),
            )
          : ListView.separated(
              primary: false,
              padding: EdgeInsets.fromLTRB(
                12.w,
                0,
                12.w,
                12.h + MainTabContentInsets.historyBannerOverlap,
              ),
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
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  );
                }

                final item = items[index];
                final name = _DoubanItem.title(item);
                final subtitle = _DoubanItem.subtitle(item);
                final rating = _DoubanItem.rating(item);
                final cover = _DoubanItem.cover(item).trim();

                return InkWell(
                  onTap: () => onTapItem(name),
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
                                  color: AppThemeColors.textMuted,
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
                        colors: [
                          AppThemeColors.primary,
                          AppThemeColors.primaryDeep,
                        ],
                      )
                    : null,
                color: selected ? null : AppThemeColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
                border: selected
                    ? null
                    : Border.all(color: AppThemeColors.border),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppThemeColors.primary.withValues(alpha: 0.28),
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
                    color: selected
                        ? AppThemeColors.textOnAccent
                        : AppThemeColors.textSecondary,
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

class _DoubanSectionData {
  const _DoubanSectionData({required this.title, required this.items});

  final String title;
  final List<dynamic> items;
}

class _DoubanItem {
  const _DoubanItem._();

  static String title(dynamic item) {
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

  static String subtitle(dynamic item) {
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

  static String rating(dynamic item) {
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

  static String cover(dynamic item) {
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
