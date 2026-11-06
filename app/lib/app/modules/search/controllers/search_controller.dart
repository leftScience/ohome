import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/config.dart';
import '../../../data/models/pan_web_engine.dart';
import '../../../data/models/pansou_resource_item.dart';
import '../../../data/api/pansou.dart';
import '../../../data/api/quark_transfer.dart';
import '../../../data/storage/search_history_storage.dart';
import '../../../utils/quark_transfer_helper.dart';

class SearchController extends GetxController {
  SearchController({
    PansouRepository? pansouRepository,
    QuarkTransferRepository? quarkTransferRepository,
    QuarkTransferHelper? quarkTransferHelper,
    SearchHistoryStorage? searchHistoryStorage,
    ConfigApi? configApi,
  }) : _pansouRepository = pansouRepository ?? PansouRepository(),
       _quarkTransferHelper =
           quarkTransferHelper ??
           QuarkTransferHelper(repository: quarkTransferRepository),
       _searchHistoryStorage = searchHistoryStorage ?? SearchHistoryStorage(),
       _configApi = configApi ?? Get.find<ConfigApi>();

  static const String panWebEnginesConfigKey = 'quark_search_web_engines';

  final TextEditingController searchController = TextEditingController();
  final RxString keyword = ''.obs;

  final RxList<PansouResourceItem> panResources = <PansouResourceItem>[].obs;
  final RxBool searching = false.obs;
  final RxBool searched = false.obs;
  final RxSet<String> transferringUrls = <String>{}.obs;

  final RxList<PanWebEngine> panWebEngines = <PanWebEngine>[].obs;
  final RxString selectedPanEngineId = PanWebEngine.defaultId.obs;
  final RxBool panWebEnginesLoading = false.obs;
  final RxString panWebSearchUrl = ''.obs;

  final PansouRepository _pansouRepository;
  final QuarkTransferHelper _quarkTransferHelper;
  final SearchHistoryStorage _searchHistoryStorage;
  final ConfigApi _configApi;
  int _searchToken = 0;
  int _panWebEngineToken = 0;
  Future<void>? _panWebEngineLoadFuture;
  bool _panWebEnginesLoaded = false;
  static const int _maxHistoryCount = 12;
  final RxList<String> historyKeywords = <String>[].obs;

  bool get isDefaultPanEngineSelected =>
      selectedPanEngineId.value.trim().isEmpty ||
      selectedPanEngineId.value == PanWebEngine.defaultId;

  bool get isPanWebEngineSelected =>
      panWebEngines.isNotEmpty && !isDefaultPanEngineSelected;

  PanWebEngine? get selectedPanWebEngine {
    final id = selectedPanEngineId.value.trim();
    if (id.isEmpty || id == PanWebEngine.defaultId) return null;
    for (final engine in panWebEngines) {
      if (engine.id == id) return engine;
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    keyword.value = searchController.text.trim();
    searchController.addListener(_syncKeyword);
    unawaited(_loadHistoryKeywords());
    unawaited(ensurePanWebEnginesLoaded());
  }

  void _syncKeyword() {
    keyword.value = searchController.text.trim();
  }

  Future<List<PansouResourceItem>> performSearch() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return const <PansouResourceItem>[];
    unawaited(_recordKeyword(query));
    await ensurePanWebEnginesLoaded();
    if (isPanWebEngineSelected) {
      await searchPanWebEngine(query);
      return const <PansouResourceItem>[];
    }
    return searchQuarkPanResources(query);
  }

  void resetToInitialState() {
    _searchToken++;
    searching.value = false;
    searched.value = false;
    panResources.clear();
    panWebSearchUrl.value = '';
    searchController.text = '';
  }

  Future<void> ensurePanWebEnginesLoaded({bool force = false}) {
    if (!force && _panWebEnginesLoaded) return Future<void>.value();
    final current = _panWebEngineLoadFuture;
    if (current != null) return current;

    final future = _loadPanWebEngines();
    _panWebEngineLoadFuture = future;
    return future.whenComplete(() {
      _panWebEngineLoadFuture = null;
    });
  }

  Future<void> _loadPanWebEngines() async {
    final token = ++_panWebEngineToken;
    panWebEnginesLoading.value = true;
    try {
      final config = await _configApi.findConfigByKey(
        panWebEnginesConfigKey,
        showErrorToast: false,
      );
      if (token != _panWebEngineToken) return;
      final engines = PanWebEngine.parseConfigValue(config?.value);
      panWebEngines.assignAll(engines);
      if (engines.isEmpty) {
        selectedPanEngineId.value = PanWebEngine.defaultId;
      } else if (selectedPanEngineId.value != PanWebEngine.defaultId &&
          !engines.any((e) => e.id == selectedPanEngineId.value)) {
        selectedPanEngineId.value = PanWebEngine.defaultId;
      }
      _panWebEnginesLoaded = true;
    } catch (_) {
      if (token != _panWebEngineToken) return;
      panWebEngines.clear();
      selectedPanEngineId.value = PanWebEngine.defaultId;
      _panWebEnginesLoaded = true;
    } finally {
      if (token == _panWebEngineToken) {
        panWebEnginesLoading.value = false;
      }
    }
  }

  Future<void> selectPanEngine(String engineId) async {
    final id = engineId.trim().isEmpty
        ? PanWebEngine.defaultId
        : engineId.trim();
    if (selectedPanEngineId.value == id) return;
    if (id != PanWebEngine.defaultId &&
        !panWebEngines.any((engine) => engine.id == id)) {
      return;
    }

    selectedPanEngineId.value = id;
    _searchToken++;
    searching.value = false;
    searched.value = false;
    panResources.clear();
    panWebSearchUrl.value = '';
    if (searchController.text.trim().isNotEmpty) {
      await performSearch();
    }
  }

  Future<void> searchPanWebEngine(String query) async {
    final kw = query.trim();
    if (kw.isEmpty) {
      panWebSearchUrl.value = '';
      searched.value = false;
      return;
    }

    final engine = selectedPanWebEngine;
    if (engine == null) {
      await searchQuarkPanResources(kw);
      return;
    }

    final token = ++_searchToken;
    searching.value = false;
    searched.value = true;
    panResources.clear();

    final url = engine.buildSearchUrl(kw);
    if (token != _searchToken) return;
    panWebSearchUrl.value = url;
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

  Future<void> transferQuark(PansouResourceItem item) async {
    final url = item.url.trim();
    if (url.isEmpty || transferringUrls.contains(url)) return;
    transferringUrls.add(url);
    try {
      await _settleFocusBeforeTransferSheet();
      await _quarkTransferHelper.transferOnce(
        shareUrl: url,
        resourceName: _buildTransferResourceName(item),
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
