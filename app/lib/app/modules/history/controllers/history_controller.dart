import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/media_history_entry.dart';
import '../../../data/models/media_history_list.dart';
import '../../../services/history_playback_service.dart';
import '../../../services/media_history_service.dart';

class HistoryController extends GetxController {
  HistoryController({
    MediaHistoryService? historyService,
    HistoryPlaybackService? playbackService,
  }) : _historyService = historyService ?? Get.find<MediaHistoryService>(),
       _playbackService = playbackService ?? Get.find<HistoryPlaybackService>();

  final MediaHistoryService _historyService;
  final HistoryPlaybackService _playbackService;

  static const int _pageSize = 20;
  static const List<_HistoryCategory> _categories = <_HistoryCategory>[
    _HistoryCategory(label: '影视', value: 'tv'),
    _HistoryCategory(label: '短剧', value: 'playlet'),
    _HistoryCategory(label: '播客', value: 'music'),
    _HistoryCategory(label: '阅读', value: 'read'),
  ];

  final selectedTabIndex = 0.obs;
  final openingEntryKey = RxnString();

  late final List<RxList<MediaHistoryEntry>> _historiesByTab;
  late final List<RxBool> _loadingByTab;
  late final List<RxBool> _loadingMoreByTab;
  late final List<RxBool> _hasMoreByTab;
  late final List<ScrollController> _scrollControllers;
  late final List<int> _pages;
  late final List<int> _loadTokens;

  List<String> get tabLabels =>
      _categories.map((category) => category.label).toList(growable: false);

  int get tabCount => _categories.length;

  RxList<MediaHistoryEntry> historiesOf(int tabIndex) =>
      _historiesByTab[_normalizeTabIndex(tabIndex)];

  RxBool loadingOf(int tabIndex) => _loadingByTab[_normalizeTabIndex(tabIndex)];

  RxBool loadingMoreOf(int tabIndex) =>
      _loadingMoreByTab[_normalizeTabIndex(tabIndex)];

  RxBool hasMoreOf(int tabIndex) => _hasMoreByTab[_normalizeTabIndex(tabIndex)];

  ScrollController scrollControllerOf(int tabIndex) =>
      _scrollControllers[_normalizeTabIndex(tabIndex)];

  @override
  void onInit() {
    super.onInit();

    final totalTabs = _categories.length;
    _historiesByTab = List.generate(
      totalTabs,
      (_) => <MediaHistoryEntry>[].obs,
    );
    _loadingByTab = List.generate(totalTabs, (_) => false.obs);
    _loadingMoreByTab = List.generate(totalTabs, (_) => false.obs);
    _hasMoreByTab = List.generate(totalTabs, (_) => true.obs);
    _pages = List<int>.filled(totalTabs, 1);
    _loadTokens = List<int>.filled(totalTabs, 0);
    _scrollControllers = List.generate(totalTabs, (tabIndex) {
      final controller = ScrollController();
      controller.addListener(() => _onScroll(tabIndex));
      return controller;
    });

    refreshCurrentTab();
  }

  Future<void> refreshCurrentTab() {
    return loadHistories(tabIndex: selectedTabIndex.value, refresh: true);
  }

  void changeCategory(int index) {
    if (index < 0 || index >= _categories.length) return;
    if (selectedTabIndex.value == index) return;

    selectedTabIndex.value = index;
    if (historiesOf(index).isEmpty) {
      loadHistories(tabIndex: index, refresh: true);
    }
  }

  Future<void> loadHistories({
    required int tabIndex,
    bool refresh = false,
  }) async {
    final safeIndex = _normalizeTabIndex(tabIndex);
    final histories = _historiesByTab[safeIndex];
    final loading = _loadingByTab[safeIndex];
    final loadingMore = _loadingMoreByTab[safeIndex];
    final hasMore = _hasMoreByTab[safeIndex];

    late final int token;
    if (refresh) {
      token = ++_loadTokens[safeIndex];
      _pages[safeIndex] = 1;
      hasMore.value = true;
      loading.value = true;
      loadingMore.value = false;
    } else {
      if (loading.value || loadingMore.value || !hasMore.value) {
        return;
      }
      token = _loadTokens[safeIndex];
      loadingMore.value = true;
    }

    try {
      final MediaHistoryListResult result = await _historyService
          .fetchUserHistory(
            page: _pages[safeIndex],
            limit: _pageSize,
            applicationType: _categories[safeIndex].value,
          );

      if (token != _loadTokens[safeIndex]) {
        return;
      }

      if (refresh) {
        histories.assignAll(result.records);
      } else {
        histories.addAll(result.records);
      }

      hasMore.value = histories.length < result.total;
      if (hasMore.value) {
        _pages[safeIndex] += 1;
      }
    } catch (error) {
      if (token == _loadTokens[safeIndex]) {
        Get.snackbar('Tip', error.toString());
      }
    } finally {
      if (token == _loadTokens[safeIndex]) {
        if (refresh) {
          loading.value = false;
        } else {
          loadingMore.value = false;
        }
      }
    }
  }

  Future<void> openEntry(MediaHistoryEntry entry) async {
    final entryKey = keyForEntry(entry);
    if (entryKey.isEmpty) return;
    if (openingEntryKey.value != null) return;

    openingEntryKey.value = entryKey;
    try {
      await _playbackService.navigateToEntry(entry);
    } finally {
      if (openingEntryKey.value == entryKey) {
        openingEntryKey.value = null;
      }
    }
  }

  Future<void> deleteEntry(MediaHistoryEntry entry) async {
    final id = entry.id;
    if (id == null) return;

    try {
      await _historyService.deleteById(id);
      final currentTab = selectedTabIndex.value;
      final list = historiesOf(currentTab);
      list.removeWhere((item) => item.id == id);
      if (list.isEmpty) {
        hasMoreOf(currentTab).value = false;
      }
    } catch (error) {
      Get.snackbar('Tip', error.toString());
    }
  }

  String keyForEntry(MediaHistoryEntry entry) {
    final id = entry.id;
    if (id != null) {
      return 'id:$id';
    }
    final app = entry.applicationType.trim();
    final folder = entry.folderPath.trim();
    final item = entry.itemPath.trim();
    return 'path:$app|$folder|$item';
  }

  int _normalizeTabIndex(int value) {
    if (_categories.isEmpty) return 0;
    return value.clamp(0, _categories.length - 1);
  }

  void _onScroll(int tabIndex) {
    final safeIndex = _normalizeTabIndex(tabIndex);
    final scrollController = _scrollControllers[safeIndex];

    if (!scrollController.hasClients ||
        _loadingByTab[safeIndex].value ||
        _loadingMoreByTab[safeIndex].value ||
        !_hasMoreByTab[safeIndex].value) {
      return;
    }

    final position = scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 200) {
      loadHistories(tabIndex: safeIndex, refresh: false);
    }
  }

  @override
  void onClose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.onClose();
  }
}

class _HistoryCategory {
  const _HistoryCategory({required this.label, required this.value});

  final String label;
  final String value;
}
