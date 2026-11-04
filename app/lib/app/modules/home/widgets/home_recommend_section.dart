import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/app_theme.dart';
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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
        _DoubanSectionData(
          title: '电影',
          icon: Icons.movie_creation_rounded,
          items: controller.hotMovies,
        ),
        _DoubanSectionData(
          title: '电视剧',
          icon: Icons.tv_rounded,
          items: controller.hotCnDramas,
        ),
        _DoubanSectionData(
          title: '短剧',
          icon: Icons.local_fire_department_rounded,
          items: controller.hotPlaylets,
        ),
        _DoubanSectionData(
          title: '有声书',
          icon: Icons.headphones_rounded,
          items: controller.hotAudiobooks,
        ),
      ];

      return Container(
        decoration: BoxDecoration(
          color: AppThemeColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: AppThemeColors.border, width: 1),
          boxShadow: AppThemeColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPanelHeader(tabs),
            Divider(height: 1, thickness: 1, color: AppThemeColors.divider),
            Expanded(child: _buildPanelContent(tabs)),
          ],
        ),
      );
    });
  }

  Widget _buildPanelHeader(List<_DoubanSectionData> tabs) {
    final sourceLabel = switch (controller.recommendTabIndex.value) {
      2 => '红果人气榜单',
      3 => '懒人听书榜单',
      _ => '豆瓣实时榜单',
    };
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              children: [
                Container(
                  width: 3.5.w,
                  height: 15.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99.r),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppThemeColors.primary, AppThemeColors.accent],
                    ),
                  ),
                ),
                SizedBox(width: 7.w),
                Text(
                  '热门推荐',
                  style: TextStyle(
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  sourceLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppThemeColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          _DoubanTabBar(
            index: controller.recommendTabIndex.value,
            tabs: tabs,
            onChanged: _handleTabChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(List<_DoubanSectionData> tabs) {
    final allEmpty = tabs.every((e) => e.items.isEmpty);
    if (allEmpty) {
      if (controller.recommendLoading.value) {
        return const _RecommendShimmerLoading();
      }
      final err = controller.recommendError.value.trim();
      if (err.isNotEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 32.w,
                  color: AppThemeColors.textDisabled,
                ),
                SizedBox(height: 8.h),
                Text(
                  '推荐加载失败',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
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
                SizedBox(height: 8.h),
                TextButton.icon(
                  onPressed: controller.loadRecommendations,
                  icon: Icon(Icons.refresh_rounded, size: 16.w),
                  label: const Text('重新加载'),
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

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
          : ListView.builder(
              primary: false,
              padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 12.h),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return _buildLoadMoreFooter();
                }

                final item = items[index];
                final name = _DoubanItem.title(item);
                final subtitle = _DoubanItem.subtitle(item);
                final rating = _DoubanItem.rating(item);
                final hot = _DoubanItem.hot(item);
                final remarks = _DoubanItem.remarks(item);
                final cover = _DoubanItem.cover(item).trim();
                final rank = index + 1;

                final rowWidget = _buildRankRow(
                  name: name,
                  subtitle: subtitle,
                  rating: rating,
                  hot: hot,
                  remarks: remarks,
                  cover: cover,
                  rank: rank,
                );

                if (disableAnimations || index >= 8) {
                  return rowWidget;
                }

                return TweenAnimationBuilder<double>(
                  key: ValueKey<String>('rec_${tabIndex}_$index'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + (index * 36)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 14),
                        child: child,
                      ),
                    );
                  },
                  child: rowWidget,
                );
              },
            ),
    );
  }

  Widget _buildLoadMoreFooter() {
    final err = loadMoreError.trim();
    if (err.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Center(
          child: TextButton(
            onPressed: onRetryLoadMore,
            child: Text('加载更多失败，点我重试', style: TextStyle(fontSize: 12.sp)),
          ),
        ),
      );
    }
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.w),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Center(
        child: Text(
          hasMore ? '继续上拉加载更多' : '已经到底啦',
          style: TextStyle(
            fontSize: 11.5.sp,
            color: AppThemeColors.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _buildRankRow({
    required String name,
    required String subtitle,
    required String rating,
    required String hot,
    required String remarks,
    required String cover,
    required int rank,
  }) {
    final isTopThree = rank <= 3;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: isTopThree
            ? AppThemeColors.primary.withValues(alpha: 0.028)
            : AppThemeColors.surfaceMuted.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: () => onTapItem(name),
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isTopThree
                    ? AppThemeColors.primary.withValues(alpha: 0.12)
                    : AppThemeColors.divider,
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPoster(cover: cover, rank: rank),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppThemeColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 5.h),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppThemeColors.textMuted,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (rating.isNotEmpty ||
                          hot.isNotEmpty ||
                          remarks.isNotEmpty) ...[
                        SizedBox(height: 7.h),
                        _buildMetaBadge(
                          rating: rating,
                          hot: hot,
                          remarks: remarks,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18.w,
                  color: AppThemeColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster({required String cover, required int rank}) {
    final isTopThree = rank <= 3;
    final badgeColors = switch (rank) {
      1 => const [Color(0xFFFF8A00), Color(0xFFFF3D57)],
      2 => const [Color(0xFF3B82F6), Color(0xFF6366F1)],
      _ => const [Color(0xFFD97706), Color(0xFFB45309)],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.shadowSoft.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: SizedBox(
          width: 56.w,
          height: 76.w,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(_placeholder, fit: BoxFit.cover),
              if (cover.isNotEmpty)
                Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) {
                    return Image.asset(_placeholder, fit: BoxFit.cover);
                  },
                ),
              if (isTopThree)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.5.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: badgeColors),
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'TOP $rank',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaBadge({
    required String rating,
    required String hot,
    required String remarks,
  }) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rating.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EB),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 13.w,
                  color: const Color(0xFFF59E0B),
                ),
                SizedBox(width: 2.5.w),
                Text(
                  rating,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: const Color(0xFFD97706),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        if (hot.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: const Color(0xFFFF4D4F).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 12.5.w,
                  color: const Color(0xFFF97316),
                ),
                SizedBox(width: 2.5.w),
                Text(
                  '人气 $hot',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFFEA580C),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        if (remarks.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppThemeColors.surfaceSunken,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              remarks,
              style: TextStyle(
                fontSize: 10.5.sp,
                color: AppThemeColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
      ],
    );
  }
}

/// 推荐加载中的流光骨架屏（Shimmer Skeleton）
class _RecommendShimmerLoading extends StatefulWidget {
  const _RecommendShimmerLoading();

  @override
  State<_RecommendShimmerLoading> createState() =>
      _RecommendShimmerLoadingState();
}

class _RecommendShimmerLoadingState extends State<_RecommendShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final t = _shimmerController.value;
        final baseColor = AppThemeColors.surfaceSunken;
        final highlightColor = AppThemeColors.surface;

        Widget shimmerBox({
          required double width,
          required double height,
          double radius = 10,
        }) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius.r),
              gradient: LinearGradient(
                begin: Alignment(-1.5 + 3.0 * t, -0.2),
                end: Alignment(-0.5 + 3.0 * t, 0.2),
                colors: [baseColor, highlightColor, baseColor],
              ),
            ),
          );
        }

        return ListView(
          primary: false,
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
          children: [
            for (int i = 0; i < 5; i++)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    shimmerBox(width: 56.w, height: 76.w, radius: 10),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shimmerBox(width: 140.w, height: 15.h, radius: 6),
                          SizedBox(height: 8.h),
                          shimmerBox(width: 200.w, height: 12.h, radius: 6),
                          SizedBox(height: 8.h),
                          shimmerBox(width: 90.w, height: 18.h, radius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
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
  final List<_DoubanSectionData> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: tabs.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, i) {
          final selected = i == index;
          final tab = tabs[i];
          return Semantics(
            button: true,
            selected: selected,
            label: tab.title,
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 5.h),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [
                            AppThemeColors.primary,
                            AppThemeColors.accent,
                          ],
                        )
                      : null,
                  color: selected ? null : AppThemeColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppThemeColors.primary.withValues(
                              alpha: 0.26,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 13.5.w,
                      color: selected
                          ? AppThemeColors.textOnAccent
                          : AppThemeColors.textMuted,
                    ),
                    SizedBox(width: 4.5.w),
                    Text(
                      tab.title,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: selected
                            ? AppThemeColors.textOnAccent
                            : AppThemeColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
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
  const _DoubanSectionData({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
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

  static String hot(dynamic item) {
    if (item is Map) {
      final v = item['hot'] ?? item['hits'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num && v > 0) {
        if (v >= 100000000) {
          return '${(v / 100000000).toStringAsFixed(1)}亿';
        }
        if (v >= 10000) {
          return '${(v / 10000).toStringAsFixed(1)}万';
        }
        return v.toInt().toString();
      }
    }
    return '';
  }

  static String remarks(dynamic item) {
    if (item is Map) {
      final v = item['remarks'] ?? item['episodes_info'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
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
