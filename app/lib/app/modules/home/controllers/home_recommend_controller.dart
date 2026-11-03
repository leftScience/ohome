import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/douban.dart';
import '../../../data/models/douban_models.dart';

class HomeRecommendController extends GetxController {
  HomeRecommendController({DoubanRepository? doubanRepository})
    : _doubanRepository = doubanRepository ?? DoubanRepository();

  final DoubanRepository _doubanRepository;

  final RxBool recommendLoading = false.obs;
  final RxString recommendError = ''.obs;
  final RxList<dynamic> hotMovies = <dynamic>[].obs;
  final RxList<dynamic> hotCnDramas = <dynamic>[].obs;
  final RxList<dynamic> hotPlaylets = <dynamic>[].obs;
  final RxList<dynamic> hotAudiobooks = <dynamic>[].obs;
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
    _RecommendTabSpec(
      kind: _RecommendKind.movie,
      group: '热门电影',
      sub: '全部',
      fallbackCategory: '热门',
      fallbackType: '全部',
    ),
    _RecommendTabSpec(
      kind: _RecommendKind.tv,
      group: '最近热门剧集',
      sub: '综合',
      fallbackCategory: 'tv',
      fallbackType: 'tv',
    ),
    _RecommendTabSpec(
      kind: _RecommendKind.playlet,
      group: '热门短剧',
      sub: '总榜',
      fallbackCategory: 'rank',
      fallbackType: 'all',
    ),
    _RecommendTabSpec(
      kind: _RecommendKind.audiobook,
      group: '热门有声书',
      sub: '周榜',
      fallbackCategory: 'hot',
      fallbackType: 'week',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    unawaited(loadRecommendations());
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
          kind: spec.kind,
          group: spec.group,
          sub: spec.sub,
        );
        _recommendResolved[i] = mapping == null
            ? _ResolvedRecommendTab(
                kind: spec.kind,
                category: spec.fallbackCategory,
                type: spec.fallbackType,
              )
            : _ResolvedRecommendTab(
                kind: spec.kind,
                category: mapping.category,
                type: mapping.type,
              );
      }

      Object? firstTabError;
      var anySuccess = false;
      final results = await Future.wait<List<dynamic>>([
        for (var i = 0; i < _recommendTabCount; i++)
          _fetchRecommendPage(i, page: 1, limit: _recommendPageSize).then(
            (records) {
              anySuccess = true;
              return records;
            },
            onError: (Object err) {
              firstTabError ??= err;
              return const <dynamic>[];
            },
          ),
      ]);
      if (token != _recommendToken) return;

      if (!anySuccess && firstTabError != null) {
        throw firstTabError!;
      }

      for (var i = 0; i < _recommendTabCount; i++) {
        _itemsByIndex(i).assignAll(results[i]);
        _recommendPages[i] = results[i].isEmpty ? 0 : 1;
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

  void tryLoadMoreRecommendationsForTab(int tabIndex, ScrollMetrics metrics) {
    if (tabIndex < 0 || tabIndex >= _recommendTabCount) return;
    if (recommendLoading.value) return;
    if (metrics.extentAfter > 240) return;
    unawaited(loadMoreRecommendationsForTab(tabIndex));
  }

  Future<void> loadMoreRecommendationsForTab(int tabIndex) async {
    if (tabIndex < 0 || tabIndex >= _recommendTabCount) return;
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

    final DoubanRankingResponse resp;
    switch (resolved.kind) {
      case _RecommendKind.movie:
        resp = await _doubanRepository.getMovieRanking(
          category: resolved.category,
          type: resolved.type,
          page: page,
          limit: limit,
        );
      case _RecommendKind.tv:
        resp = await _doubanRepository.getTvRanking(
          category: resolved.category,
          type: resolved.type,
          page: page,
          limit: limit,
        );
      case _RecommendKind.playlet:
        resp = await _doubanRepository.getPlayletRanking(
          category: resolved.category,
          type: resolved.type,
          page: page,
          limit: limit,
        );
      case _RecommendKind.audiobook:
        resp = await _doubanRepository.getAudiobookRanking(
          category: resolved.category,
          type: resolved.type,
          page: page,
          limit: limit,
        );
    }
    return resp.records;
  }

  RxList<dynamic> _itemsByIndex(int index) {
    switch (index) {
      case 0:
        return hotMovies;
      case 1:
        return hotCnDramas;
      case 2:
        return hotPlaylets;
      case 3:
        return hotAudiobooks;
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
    hotCnDramas.clear();
    hotPlaylets.clear();
    hotAudiobooks.clear();
  }

  static DoubanCategoryMapping? _findMapping(
    DoubanCategories categories, {
    required _RecommendKind kind,
    required String group,
    required String sub,
  }) {
    final outer = switch (kind) {
      _RecommendKind.movie => categories.movie,
      _RecommendKind.tv => categories.tv,
      _RecommendKind.playlet => categories.playlet,
      _RecommendKind.audiobook => categories.audiobook,
    };
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
    return v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}

enum _RecommendKind { movie, tv, playlet, audiobook }

class _RecommendTabSpec {
  const _RecommendTabSpec({
    required this.kind,
    required this.group,
    required this.sub,
    required this.fallbackCategory,
    required this.fallbackType,
  });

  final _RecommendKind kind;
  final String group;
  final String sub;
  final String fallbackCategory;
  final String fallbackType;
}

class _ResolvedRecommendTab {
  const _ResolvedRecommendTab({
    required this.kind,
    required this.category,
    required this.type,
  });

  final _RecommendKind kind;
  final String category;
  final String type;
}
