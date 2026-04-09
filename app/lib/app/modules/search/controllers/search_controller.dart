import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/douban_models.dart';
import '../../../data/models/pansou_resource_item.dart';
import '../../../data/api/douban.dart';
import '../../../data/api/pansou.dart';
import '../../../data/api/quark_transfer.dart';
import '../../../data/storage/search_history_storage.dart';
import '../../../utils/http_client.dart';
import '../../../widgets/selection_bottom_sheet.dart';

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

  static const _quarkTargets = <String>['tv', 'playlet', 'music', 'read'];

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
            final rootPath = await _quarkTransferRepository.getQuarkRootPath(t);
            final savePath = _stripQuarkPrefixForStore(rootPath);
            return MapEntry(t, savePath);
          } catch (_) {
            return MapEntry(t, '');
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
      await _settleFocusBeforeTransferSheet();
      await ensureQuarkSavePathLoaded();

      final selected = await _showQuarkTransferSheet();
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

  Future<void> _settleFocusBeforeTransferSheet() async {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null || !currentFocus.hasFocus) return;

    currentFocus.unfocus();
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<_QuarkTransferSelection?> _showQuarkTransferSheet() {
    final context = Get.overlayContext ?? Get.context;
    if (context == null) return Future.value(null);

    final availableCount = _quarkTargets
        .where((app) => (quarkSavePathMap[app] ?? '').trim().isNotEmpty)
        .length;

    return showSelectionBottomSheet<_QuarkTransferSelection>(
      context: context,
      meta: SelectionBottomSheetMeta(
        icon: Icons.check_circle_rounded,
        label: '已配置 $availableCount / ${_quarkTargets.length}',
        accent: availableCount > 0
            ? const Color(0xFF34D399)
            : const Color(0xFFF59E0B),
      ),
      helperText: '点击可用分类即可开始转存',
      emptyTitle: '暂无可用分类',
      emptyDescription: '未找到可用的 WebDAV 配置，请先在后台为对应应用配置 rootPath。',
      options: _quarkTargets
          .map((application) {
            final savePath = (quarkSavePathMap[application] ?? '').trim();
            final enabled = savePath.isNotEmpty;
            return SelectionBottomSheetOption<_QuarkTransferSelection>(
              value: _QuarkTransferSelection(
                application: application,
                savePath: savePath,
              ),
              title: quarkApplicationLabel(application),
              subtitle: enabled ? savePath : '请先配置 rootPath 后再使用',
              icon: quarkApplicationIcon(application),
              accent: quarkApplicationAccent(application),
              statusText: enabled ? '可转存' : '未配置',
              enabled: enabled,
            );
          })
          .toList(growable: false),
    );
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

class _QuarkTransferSelection {
  const _QuarkTransferSelection({
    required this.application,
    required this.savePath,
  });

  final String application;
  final String savePath;
}
