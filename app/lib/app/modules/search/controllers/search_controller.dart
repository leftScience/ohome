import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/douban_models.dart';
import '../../../data/models/pansou_resource_item.dart';
import '../../../data/api/douban.dart';
import '../../../data/api/pansou.dart';
import '../../../data/api/quark_transfer.dart';
import '../../../data/storage/search_history_storage.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/http_client.dart';

class SearchController extends GetxController {
  SearchController({
    PansouRepository? pansouRepository,
    QuarkTransferRepository? quarkTransferRepository,
    DoubanRepository? doubanRepository,
    SearchHistoryStorage? searchHistoryStorage,
  }) : _pansouRepository = pansouRepository ?? PansouRepository(),
       _quarkTransferRepository =
           quarkTransferRepository ?? QuarkTransferRepository(),
       _doubanRepository = doubanRepository ?? DoubanRepository(),
       _searchHistoryStorage = searchHistoryStorage ?? SearchHistoryStorage();

  final TextEditingController searchController = TextEditingController();
  final RxString keyword = ''.obs;

  final RxList<PansouResourceItem> panResources = <PansouResourceItem>[].obs;
  final RxBool searching = false.obs;
  final RxBool searched = false.obs;
  final RxSet<String> transferringUrls = <String>{}.obs;

  final PansouRepository _pansouRepository;
  final QuarkTransferRepository _quarkTransferRepository;
  final DoubanRepository _doubanRepository;
  final SearchHistoryStorage _searchHistoryStorage;
  int _searchToken = 0;
  static const int _maxHistoryCount = 12;
  final RxList<String> historyKeywords = <String>[].obs;

  final RxMap<String, String> quarkSavePathMap = <String, String>{}.obs;
  final RxBool quarkSavePathLoading = false.obs;

  final RxBool recommendLoading = false.obs;
  final RxString recommendError = ''.obs;
  final RxList<dynamic> hotMovies = <dynamic>[].obs;
  final RxList<dynamic> tvAnimes = <dynamic>[].obs;
  final RxList<dynamic> hotVarieties = <dynamic>[].obs;
  final RxList<dynamic> hotCnDramas = <dynamic>[].obs;
  int _recommendToken = 0;
  final RxInt recommendTabIndex = 0.obs;
  static const int _recommendPageSize = 20;
  static const int _recommendTabCount = 4;

  final RxList<bool> recommendHasMore = List<bool>.filled(
    _recommendTabCount,
    true,
  ).obs;
  final RxList<bool> recommendLoadingMore = List<bool>.filled(
    _recommendTabCount,
    false,
  ).obs;
  final RxList<String> recommendLoadMoreError = List<String>.filled(
    _recommendTabCount,
    '',
  ).obs;

  final List<int> _recommendPages = List<int>.filled(_recommendTabCount, 0);
  final List<_ResolvedRecommendTab?> _recommendResolved =
      List<_ResolvedRecommendTab?>.filled(_recommendTabCount, null);
  static const List<_RecommendTabSpec> _recommendSpecs = <_RecommendTabSpec>[
    _RecommendTabSpec(isMovie: true, group: '热门电影', sub: '全部'),
    _RecommendTabSpec(isMovie: false, group: '最近热门剧集', sub: '动画'),
    _RecommendTabSpec(isMovie: false, group: '最近热门综艺', sub: '综合'),
    _RecommendTabSpec(isMovie: false, group: '最近热门剧集', sub: '国产剧'),
  ];

  static const _quarkTargets = <_QuarkTarget>[
    _QuarkTarget(label: '影视', application: 'tv'),
    _QuarkTarget(label: '短剧', application: 'playlet'),
    _QuarkTarget(label: '音乐', application: 'music'),
    _QuarkTarget(label: '有声小说', application: 'xiaoshuo'),
  ];

  @override
  void onInit() {
    super.onInit();
    keyword.value = searchController.text.trim();
    searchController.addListener(_syncKeyword);
    unawaited(_loadHistoryKeywords());
    unawaited(loadRecommendations());
  }

  void _syncKeyword() {
    keyword.value = searchController.text.trim();
  }

  Future<List<PansouResourceItem>> performSearch() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return const <PansouResourceItem>[];
    unawaited(_recordKeyword(query));
    return searchQuarkPanResources(query);
  }

  void resetToInitialState() {
    _searchToken++;
    searching.value = false;
    searched.value = false;
    panResources.clear();
    recommendTabIndex.value = 0;
    searchController.text = '';
  }

  Future<List<PansouResourceItem>> searchQuarkPanResources(
    String query, {
    bool refresh = false,
  }) async {
    final kw = query.trim();
    if (kw.isEmpty) {
      panResources.clear();
      searched.value = false;
      return const <PansouResourceItem>[];
    }

    final token = ++_searchToken;
    searching.value = true;
    searched.value = true;
    try {
      final items = await _pansouRepository.searchQuark(kw, refresh: refresh);
      if (token != _searchToken) return items;
      panResources.assignAll(items);
      return items;
    } finally {
      if (token == _searchToken) {
        searching.value = false;
      }
    }
  }

  Future<void> ensureQuarkSavePathLoaded() async {
    if (quarkSavePathLoading.value) return;
    if (quarkSavePathMap.isNotEmpty) return;

    quarkSavePathLoading.value = true;
    try {
      final results = await Future.wait(
        _quarkTargets.map((t) async {
          try {
            final rootPath = await _quarkTransferRepository.getQuarkRootPath(
              t.application,
            );
            final savePath = _stripQuarkPrefixForStore(rootPath);
            return MapEntry(t.application, savePath);
          } catch (_) {
            return MapEntry(t.application, '');
          }
        }),
      );

      quarkSavePathMap.assignAll(<String, String>{
        for (final e in results)
          if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
      });
    } finally {
      quarkSavePathLoading.value = false;
    }
  }

  Future<void> transferQuark(PansouResourceItem item) async {
    final url = item.url.trim();
    if (url.isEmpty || transferringUrls.contains(url)) return;
    try {
      await ensureQuarkSavePathLoaded();

      final selected = await Get.bottomSheet<_QuarkTransferSelection?>(
        _QuarkTransferSheet(
          targets: _quarkTargets,
          savePathMap: quarkSavePathMap,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
      if (selected == null) return;

      transferringUrls.add(url);
      await _quarkTransferRepository.transferOnce(
        shareUrl: url,
        savePath: selected.savePath,
        application: selected.application,
        resourceName: _buildTransferResourceName(item),
      );
      Get.snackbar(
        '提示',
        '已加入转存任务',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } on ApiException catch (e) {
      Get.snackbar(
        '转存失败',
        e.message.trim().isEmpty ? '请稍后重试' : e.message,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    } catch (_) {
      Get.snackbar(
        '转存失败',
        '请稍后重试',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    } finally {
      transferringUrls.remove(url);
    }
  }

  void openTransferTasks() {
    Get.toNamed(Routes.QUARK_TRANSFER_TASKS);
  }

  static String _stripQuarkPrefixForStore(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll('\\', '/');
    normalized = normalized.replaceAll(RegExp(r'^/+'), '');
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');

    final lower = normalized.toLowerCase();
    final idx = lower.indexOf('quark/');
    if (idx > 0) normalized = normalized.substring(idx);
    normalized = normalized.replaceFirst(
      RegExp(r'^quark/?', caseSensitive: false),
      '',
    );

    normalized = normalized.replaceAll(RegExp(r'^/+'), '');
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    return normalized;
  }

  String _buildTransferResourceName(PansouResourceItem item) {
    final title = item.transferTitle;
    if (title.isNotEmpty) {
      return title;
    }
    final currentKeyword = keyword.value.trim();
    if (currentKeyword.isNotEmpty) {
      return currentKeyword;
    }
    return item.url.trim();
  }

  Future<void> loadRecommendations() async {
    final token = ++_recommendToken;
    recommendError.value = '';
    recommendLoading.value = true;
    _resetRecommendPaging();
    _clearRecommendItems();
    try {
      final categories = await _doubanRepository.getCategories();
      if (token != _recommendToken) return;

      for (var i = 0; i < _recommendTabCount; i++) {
        final spec = _recommendSpecs[i];
        final mapping = _findMapping(
          categories,
          isMovie: spec.isMovie,
          group: spec.group,
          sub: spec.sub,
        );
        _recommendResolved[i] = mapping == null
            ? null
            : _ResolvedRecommendTab(
                isMovie: spec.isMovie,
                category: mapping.category,
                type: mapping.type,
              );
      }

      final results = await Future.wait<List<dynamic>>([
        for (var i = 0; i < _recommendTabCount; i++)
          _fetchRecommendPage(i, page: 1, limit: _recommendPageSize),
      ]);
      if (token != _recommendToken) return;

      for (var i = 0; i < _recommendTabCount; i++) {
        _itemsByIndex(i).assignAll(results[i]);
        _recommendPages[i] = 1;
        recommendHasMore[i] = results[i].length >= _recommendPageSize;
        recommendLoadMoreError[i] = '';
      }
    } catch (e) {
      if (token != _recommendToken) return;
      recommendError.value = e.toString();
      _clearRecommendItems();
    } finally {
      if (token == _recommendToken) {
        recommendLoading.value = false;
      }
    }
  }

  void tryLoadMoreRecommendations(ScrollMetrics metrics) {
    tryLoadMoreRecommendationsForTab(recommendTabIndex.value, metrics);
  }

  Future<void> loadMoreRecommendations() async {
    await loadMoreRecommendationsForTab(recommendTabIndex.value);
  }

  void tryLoadMoreRecommendationsForTab(int tabIndex, ScrollMetrics metrics) {
    if (tabIndex < 0 || tabIndex >= _recommendTabCount) return;
    if (keyword.value.trim().isNotEmpty) return;
    if (recommendLoading.value) return;
    if (metrics.extentAfter > 240) return;
    unawaited(loadMoreRecommendationsForTab(tabIndex));
  }

  Future<void> loadMoreRecommendationsForTab(int tabIndex) async {
    if (tabIndex < 0 || tabIndex >= _recommendTabCount) return;
    if (keyword.value.trim().isNotEmpty) return;
    if (recommendLoading.value) return;
    if (recommendLoadingMore[tabIndex]) return;
    if (!recommendHasMore[tabIndex]) return;

    final resolved = _recommendResolved[tabIndex];
    if (resolved == null) {
      recommendHasMore[tabIndex] = false;
      return;
    }

    final token = _recommendToken;
    recommendLoadingMore[tabIndex] = true;
    recommendLoadMoreError[tabIndex] = '';
    try {
      final nextPage = _recommendPages[tabIndex] + 1;
      final records = await _fetchRecommendPage(
        tabIndex,
        page: nextPage,
        limit: _recommendPageSize,
      );
      if (token != _recommendToken) return;

      _recommendPages[tabIndex] = nextPage;
      if (records.isEmpty) {
        recommendHasMore[tabIndex] = false;
        return;
      }

      _itemsByIndex(tabIndex).addAll(records);
      if (records.length < _recommendPageSize) {
        recommendHasMore[tabIndex] = false;
      }
    } catch (e) {
      if (token != _recommendToken) return;
      recommendLoadMoreError[tabIndex] = e.toString();
    } finally {
      if (token == _recommendToken) {
        recommendLoadingMore[tabIndex] = false;
      }
    }
  }

  Future<List<dynamic>> _fetchRecommendPage(
    int tabIndex, {
    required int page,
    required int limit,
  }) async {
    final resolved = _recommendResolved[tabIndex];
    if (resolved == null) return const <dynamic>[];

    final resp = resolved.isMovie
        ? await _doubanRepository.getMovieRanking(
            category: resolved.category,
            type: resolved.type,
            page: page,
            limit: limit,
          )
        : await _doubanRepository.getTvRanking(
            category: resolved.category,
            type: resolved.type,
            page: page,
            limit: limit,
          );
    return resp.records;
  }

  RxList<dynamic> _itemsByIndex(int index) {
    switch (index) {
      case 0:
        return hotMovies;
      case 1:
        return tvAnimes;
      case 2:
        return hotVarieties;
      case 3:
        return hotCnDramas;
      default:
        return hotMovies;
    }
  }

  void _resetRecommendPaging() {
    for (var i = 0; i < _recommendTabCount; i++) {
      _recommendPages[i] = 0;
      _recommendResolved[i] = null;
      recommendHasMore[i] = true;
      recommendLoadingMore[i] = false;
      recommendLoadMoreError[i] = '';
    }
  }

  void _clearRecommendItems() {
    hotMovies.clear();
    tvAnimes.clear();
    hotVarieties.clear();
    hotCnDramas.clear();
  }

  static DoubanCategoryMapping? _findMapping(
    DoubanCategories categories, {
    required bool isMovie,
    required String group,
    required String sub,
  }) {
    final outer = isMovie ? categories.movie : categories.tv;
    DoubanCategoryMapping? mapping;
    final normGroup = _normLabel(group);
    final normSub = _normLabel(sub);

    Map<String, DoubanCategoryMapping>? inner = outer[group];
    if (inner == null && normGroup.isNotEmpty) {
      for (final entry in outer.entries) {
        final keyNorm = _normLabel(entry.key);
        if (keyNorm == normGroup ||
            keyNorm.contains(normGroup) ||
            normGroup.contains(keyNorm)) {
          inner = entry.value;
          break;
        }
      }
    }

    if (inner != null) {
      mapping = inner[sub];
      if (mapping == null && normSub.isNotEmpty) {
        for (final entry in inner.entries) {
          final keyNorm = _normLabel(entry.key);
          if (keyNorm == normSub ||
              keyNorm.contains(normSub) ||
              normSub.contains(keyNorm)) {
            mapping = entry.value;
            break;
          }
        }
      }
    }

    if (mapping == null && normSub.isNotEmpty) {
      for (final entry in outer.entries) {
        for (final subEntry in entry.value.entries) {
          final keyNorm = _normLabel(subEntry.key);
          if (keyNorm == normSub ||
              keyNorm.contains(normSub) ||
              normSub.contains(keyNorm)) {
            mapping = subEntry.value;
            break;
          }
        }
        if (mapping != null) break;
      }
    }

    if (mapping == null) return null;
    if (mapping.category.trim().isEmpty || mapping.type.trim().isEmpty) {
      return null;
    }
    return mapping;
  }

  static String _normLabel(String v) {
    return v.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), '');
  }

  Future<void> useHistoryKeyword(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    searchController.text = query;
    searchController.selection = TextSelection.collapsed(
      offset: searchController.text.length,
    );
    await performSearch();
  }

  Future<void> removeHistoryKeyword(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = historyKeywords
        .where((item) => item.trim().toLowerCase() != query.toLowerCase())
        .toList(growable: false);
    historyKeywords.assignAll(next);
    await _searchHistoryStorage.writeAll(next);
  }

  Future<void> clearHistoryKeywords() async {
    historyKeywords.clear();
    await _searchHistoryStorage.clear();
  }

  Future<void> _loadHistoryKeywords() async {
    try {
      final values = await _searchHistoryStorage.readAll();
      historyKeywords.assignAll(values.take(_maxHistoryCount));
    } catch (_) {}
  }

  Future<void> _recordKeyword(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final current = historyKeywords.toList(growable: true);
    current.removeWhere(
      (item) => item.trim().toLowerCase() == query.toLowerCase(),
    );
    current.insert(0, query);
    if (current.length > _maxHistoryCount) {
      current.removeRange(_maxHistoryCount, current.length);
    }
    historyKeywords.assignAll(current);
    try {
      await _searchHistoryStorage.writeAll(current);
    } catch (_) {}
  }

  @override
  void onClose() {
    searchController.removeListener(_syncKeyword);
    searchController.dispose();
    super.onClose();
  }
}

class _RecommendTabSpec {
  const _RecommendTabSpec({
    required this.isMovie,
    required this.group,
    required this.sub,
  });

  final bool isMovie;
  final String group;
  final String sub;
}

class _ResolvedRecommendTab {
  const _ResolvedRecommendTab({
    required this.isMovie,
    required this.category,
    required this.type,
  });

  final bool isMovie;
  final String category;
  final String type;
}

class _QuarkTarget {
  const _QuarkTarget({required this.label, required this.application});

  final String label;
  final String application;
}

class _QuarkTransferSelection {
  const _QuarkTransferSelection({
    required this.label,
    required this.application,
    required this.savePath,
  });

  final String label;
  final String application;
  final String savePath;
}

class _QuarkTransferSheet extends StatelessWidget {
  const _QuarkTransferSheet({required this.targets, required this.savePathMap});

  final List<_QuarkTarget> targets;
  final Map<String, String> savePathMap;

  @override
  Widget build(BuildContext context) {
    final available = targets
        .where((t) => (savePathMap[t.application] ?? '').trim().isNotEmpty)
        .toList(growable: false);
    final availableCount = available.length;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = math.min(screenHeight * 0.78, 620.h);

    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  _buildMetaChip(
                    icon: Icons.check_circle_rounded,
                    label: '已配置 $availableCount / ${targets.length}',
                    accent: availableCount > 0
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF59E0B),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '点击可用分类即可开始转存',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Expanded(
                child: available.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: targets.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final target = targets[index];
                          final savePath =
                              (savePathMap[target.application] ?? '').trim();
                          final enabled = savePath.isNotEmpty;
                          return _buildTargetTile(
                            context,
                            target: target,
                            savePath: savePath,
                            enabled: enabled,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14.w),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Icon(
                Icons.folder_off_rounded,
                color: const Color(0xFFF59E0B),
                size: 26.w,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              '暂无可用分类',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '未找到可用的 WebDAV 配置，请先在后台为对应应用配置 rootPath。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTile(
    BuildContext context, {
    required _QuarkTarget target,
    required String savePath,
    required bool enabled,
  }) {
    final accent = _targetAccent(target.application);
    final icon = _targetIcon(target.application);
    final selection = _QuarkTransferSelection(
      label: target.label,
      application: target.application,
      savePath: savePath,
    );
    final onSelect = enabled ? () => Get.back(result: selection) : null;

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onSelect,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: enabled
                      ? accent.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  icon,
                  color: enabled ? accent : Colors.white38,
                  size: 22.w,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            target.label,
                            style: TextStyle(
                              color: enabled ? Colors.white : Colors.white38,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: enabled
                                ? accent.withValues(alpha: 0.14)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Text(
                            enabled ? '可转存' : '未配置',
                            style: TextStyle(
                              color: enabled ? accent : Colors.white38,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 9.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            enabled
                                ? Icons.drive_folder_upload_rounded
                                : Icons.block_rounded,
                            color: enabled ? Colors.white70 : Colors.white30,
                            size: 16.w,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              enabled ? savePath : '请先配置 rootPath 后再使用',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: enabled
                                    ? Colors.white70
                                    : Colors.white30,
                                fontSize: 11.sp,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Icon(
                enabled
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.remove_rounded,
                color: enabled ? Colors.white38 : Colors.white24,
                size: enabled ? 16.w : 20.w,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _targetIcon(String application) {
    switch (application) {
      case 'playlet':
        return Icons.movie_filter_rounded;
      case 'music':
        return Icons.queue_music_rounded;
      case 'xiaoshuo':
        return Icons.headphones_rounded;
      case 'tv':
      default:
        return Icons.live_tv_rounded;
    }
  }

  Color _targetAccent(String application) {
    switch (application) {
      case 'playlet':
        return const Color(0xFFFB7185);
      case 'music':
        return const Color(0xFF22C55E);
      case 'xiaoshuo':
        return const Color(0xFFF59E0B);
      case 'tv':
      default:
        return AppThemeColors.primary;
    }
  }
}
