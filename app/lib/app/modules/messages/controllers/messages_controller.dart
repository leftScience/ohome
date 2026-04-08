import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/app_message.dart';
import '../../../data/models/app_message_model.dart';
import '../../../data/models/app_message_push_event.dart';
import '../../../routes/app_pages.dart';
import '../../../services/app_message_push_service.dart';
import '../../drops/drops_catalog.dart';
import '../../drops/controllers/drops_controller.dart';
import '../../drops/views/drops_event_form_view.dart';
import '../../drops/views/drops_item_detail_view.dart';

class MessagesController extends GetxController {
  MessagesController({
    AppMessageApi? appMessageApi,
    AppMessagePushService? appMessagePushService,
  }) : _appMessageApi = appMessageApi ?? Get.find<AppMessageApi>(),
       _appMessagePushService =
           appMessagePushService ??
           (Get.isRegistered<AppMessagePushService>()
               ? Get.find<AppMessagePushService>()
               : null);

  static const int _pageSize = 20;
  static const List<String> tabSources = <String>[
    '',
    'drops',
    'quark',
    'system',
  ];

  final AppMessageApi _appMessageApi;
  final AppMessagePushService? _appMessagePushService;

  final scrollControllers = List<ScrollController>.generate(
    tabSources.length,
    (_) => ScrollController(),
  );
  final tabMessages = List<RxList<AppMessageModel>>.generate(
    tabSources.length,
    (_) => <AppMessageModel>[].obs,
  );
  final tabLoading = List<RxBool>.generate(tabSources.length, (_) => false.obs);
  final tabLoadingMore = List<RxBool>.generate(
    tabSources.length,
    (_) => false.obs,
  );
  final tabHasMore = List<RxBool>.generate(tabSources.length, (_) => true.obs);
  final unreadOnly = false.obs;
  final unreadCount = 0.obs;
  final sourceFilter = tabSources.first.obs;
  final selectedTabIndex = 0.obs;
  final deletingMessageIds = <int>{}.obs;

  final List<int> _pages = List<int>.filled(tabSources.length, 1);
  final List<int> _tokens = List<int>.filled(tabSources.length, 0);
  final List<bool> _hasLoaded = List<bool>.filled(tabSources.length, false);

  bool _pendingPushSync = false;
  bool _syncingFromPush = false;
  StreamSubscription<AppMessagePushEvent>? _pushSubscription;
  Timer? _pushSyncTimer;

  int get tabCount => tabSources.length;

  List<String> get tabLabels =>
      tabSources.map(sourceFilterLabel).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    for (var index = 0; index < scrollControllers.length; index++) {
      final tabIndex = index;
      scrollControllers[index].addListener(() => _handleScroll(tabIndex));
    }
    _pushSubscription = _appMessagePushService?.events.listen(_handlePushEvent);
    loadMessages(refresh: true, tabIndex: selectedTabIndex.value);
  }

  @override
  void onClose() {
    _pushSubscription?.cancel();
    _pushSyncTimer?.cancel();
    for (final controller in scrollControllers) {
      controller.dispose();
    }
    super.onClose();
  }

  Future<void> ensureTabLoaded(int tabIndex) async {
    if (_hasLoaded[tabIndex] || tabLoading[tabIndex].value) {
      return;
    }
    await loadMessages(refresh: true, tabIndex: tabIndex);
  }

  Future<void> loadMessages({
    required bool refresh,
    int? tabIndex,
    bool showErrorToast = true,
  }) async {
    final index = tabIndex ?? selectedTabIndex.value;
    if (index < 0 || index >= tabCount) {
      return;
    }

    late final int token;
    final loading = tabLoading[index];
    final loadingMore = tabLoadingMore[index];
    final hasMore = tabHasMore[index];
    final records = tabMessages[index];

    if (refresh) {
      token = ++_tokens[index];
      _pages[index] = 1;
      hasMore.value = true;
      loading.value = true;
      loadingMore.value = false;
    } else {
      if (loading.value || loadingMore.value || !hasMore.value) {
        return;
      }
      token = _tokens[index];
      loadingMore.value = true;
    }

    try {
      final source = tabSources[index];
      final result = await _appMessageApi.getMessageList(
        source: source.isEmpty ? null : source,
        readOnly: unreadOnly.value ? false : null,
        page: _pages[index],
        limit: _pageSize,
        showErrorToast: showErrorToast,
      );
      if (token != _tokens[index]) {
        return;
      }

      unreadCount.value = result.unreadCount;
      if (refresh) {
        records.assignAll(result.records);
      } else {
        records.addAll(result.records);
      }

      hasMore.value = records.length < result.total;
      if (hasMore.value) {
        _pages[index] += 1;
      }
      _hasLoaded[index] = true;
    } catch (_) {
      return;
    } finally {
      if (token == _tokens[index]) {
        if (refresh) {
          loading.value = false;
        } else {
          loadingMore.value = false;
        }
        if (_pendingPushSync && !_isCurrentTabBusy()) {
          _schedulePushSync();
        }
      }
    }
  }

  void toggleUnreadOnly(bool value) {
    if (unreadOnly.value == value) return;
    unreadOnly.value = value;
    _invalidateTabs(clearData: true);
    loadMessages(refresh: true, tabIndex: selectedTabIndex.value);
  }

  void changeSourceFilter(String value) {
    changeTab(indexOfSource(value));
  }

  void changeTab(int index) {
    if (index < 0 || index >= tabCount) {
      return;
    }
    selectedTabIndex.value = index;
    sourceFilter.value = tabSources[index];
    if (!_hasLoaded[index]) {
      unawaited(loadMessages(refresh: true, tabIndex: index));
    }
  }

  int indexOfSource(String source) {
    final normalized = source.trim().toLowerCase();
    final index = tabSources.indexOf(normalized);
    return index >= 0 ? index : 0;
  }

  Future<void> markAllRead() async {
    await _appMessageApi.markAllMessagesRead();
    _invalidateTabs(clearData: true);
    await loadMessages(refresh: true, tabIndex: selectedTabIndex.value);
    _refreshDropsOverviewIfNeeded();
    Get.snackbar('提示', '消息已全部标记为已读');
  }

  bool isDeleting(int? id) => id != null && deletingMessageIds.contains(id);

  Future<void> deleteMessage(AppMessageModel message) async {
    final id = message.id;
    if (id == null || isDeleting(id)) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除消息'),
        content: Text(
          message.title.isEmpty ? '确定删除这条消息吗？' : '确定删除「${message.title}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    deletingMessageIds.add(id);
    try {
      await _appMessageApi.deleteMessage(id);
      _invalidateTabs(clearData: true);
      await loadMessages(refresh: true, tabIndex: selectedTabIndex.value);
      _refreshDropsOverviewIfNeeded();
      Get.snackbar('提示', '消息已删除');
    } catch (_) {
      return;
    } finally {
      deletingMessageIds.remove(id);
    }
  }

  Future<void> openMessage(AppMessageModel message) async {
    final id = message.id;
    if (id != null && !message.read) {
      await _appMessageApi.markMessageRead(id);
    }

    if (message.source == 'drops' &&
        message.bizType == 'item' &&
        message.bizId != null) {
      await Get.to<bool>(() => DropsItemDetailView(itemId: message.bizId!));
    } else if (message.source == 'drops' &&
        message.bizType == 'event' &&
        message.bizId != null) {
      await Get.to<bool>(
        () => DropsEventFormView(initialEventId: message.bizId),
      );
    } else if (message.source == 'quark') {
      await Get.toNamed(Routes.QUARK_TRANSFER_TASKS);
    }

    _invalidateTabs(clearData: true);
    await loadMessages(refresh: true, tabIndex: selectedTabIndex.value);
    _refreshDropsOverviewIfNeeded();
  }

  RxList<AppMessageModel> messagesOf(int tabIndex) => tabMessages[tabIndex];

  RxBool loadingOf(int tabIndex) => tabLoading[tabIndex];

  RxBool loadingMoreOf(int tabIndex) => tabLoadingMore[tabIndex];

  RxBool hasMoreOf(int tabIndex) => tabHasMore[tabIndex];

  ScrollController scrollControllerOf(int tabIndex) =>
      scrollControllers[tabIndex];

  String sourceLabelOf(AppMessageModel message) {
    return sourceLabel(message.source);
  }

  String sourceLabel(String source) {
    switch (source.trim().toLowerCase()) {
      case 'drops':
        return '点滴';
      case 'quark':
        return '夸克';
      case 'system':
        return '系统';
      default:
        return '通知';
    }
  }

  String sourceFilterLabel(String source) {
    switch (source.trim().toLowerCase()) {
      case '':
        return '全部';
      case 'drops':
        return '点滴';
      case 'quark':
        return '夸克';
      case 'system':
        return '系统';
      default:
        return sourceLabel(source);
    }
  }

  Color sourceColorOf(AppMessageModel message) {
    return sourceColor(message.source);
  }

  Color sourceColor(String source) {
    switch (source.trim().toLowerCase()) {
      case 'drops':
        return const Color(0xFFBB86FC);
      case 'quark':
        return const Color(0xFF42A5F5);
      case 'system':
        return const Color(0xFF26A69A);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String emptyStateTextOf(int tabIndex) {
    switch (tabSources[tabIndex]) {
      case 'drops':
        return '暂无点滴消息';
      case 'quark':
        return '暂无夸克消息';
      case 'system':
        return '暂无系统消息';
      default:
        return '暂无消息通知';
    }
  }

  String summaryOf(AppMessageModel message) {
    final summary = message.summary;
    if (summary.isEmpty) {
      return '点击查看详情';
    }
    if (message.source.trim().toLowerCase() != 'drops') {
      return summary;
    }
    return _translateDropsSummary(summary);
  }

  void _handleScroll(int tabIndex) {
    if (selectedTabIndex.value != tabIndex) return;
    final controller = scrollControllers[tabIndex];
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.maxScrollExtent - position.pixels < 200) {
      loadMessages(refresh: false, tabIndex: tabIndex);
    }
  }

  void _handlePushEvent(AppMessagePushEvent event) {
    final unread = event.unreadCount;
    if (unreadCount.value != unread) {
      unreadCount.value = unread;
    }
    _schedulePushSync();
  }

  void _schedulePushSync() {
    if (isClosed) return;
    _pushSyncTimer?.cancel();
    _pushSyncTimer = Timer(const Duration(milliseconds: 250), () {
      _pushSyncTimer = null;
      unawaited(_syncMessagesFromPush());
    });
  }

  Future<void> _syncMessagesFromPush() async {
    if (_syncingFromPush || _isCurrentTabBusy()) {
      _pendingPushSync = true;
      return;
    }

    _pendingPushSync = false;
    _syncingFromPush = true;
    final index = selectedTabIndex.value;
    final token = ++_tokens[index];
    final records = tabMessages[index];
    final currentLimit = records.length > _pageSize
        ? records.length
        : _pageSize;

    try {
      final source = tabSources[index];
      final result = await _appMessageApi.getMessageList(
        source: source.isEmpty ? null : source,
        readOnly: unreadOnly.value ? false : null,
        page: 1,
        limit: currentLimit,
        showErrorToast: false,
      );
      if (token != _tokens[index]) return;

      unreadCount.value = result.unreadCount;
      records.assignAll(result.records);
      tabHasMore[index].value = records.length < result.total;
      final loadedPages = (records.length / _pageSize).ceil();
      _pages[index] = loadedPages + 1;
      _hasLoaded[index] = true;

      for (var tabIndex = 0; tabIndex < tabCount; tabIndex++) {
        if (tabIndex == index) continue;
        _hasLoaded[tabIndex] = false;
        tabMessages[tabIndex].clear();
        tabHasMore[tabIndex].value = true;
      }
    } finally {
      if (token == _tokens[index]) {
        _syncingFromPush = false;
        if (_pendingPushSync) {
          _schedulePushSync();
        }
      }
    }
  }

  bool _isCurrentTabBusy() {
    final index = selectedTabIndex.value;
    return tabLoading[index].value || tabLoadingMore[index].value;
  }

  void _invalidateTabs({required bool clearData}) {
    for (var index = 0; index < tabCount; index++) {
      _tokens[index] += 1;
      _pages[index] = 1;
      _hasLoaded[index] = false;
      tabLoading[index].value = false;
      tabLoadingMore[index].value = false;
      tabHasMore[index].value = true;
      if (clearData) {
        tabMessages[index].clear();
      }
    }
  }

  void _refreshDropsOverviewIfNeeded() {
    if (Get.isRegistered<DropsController>()) {
      Get.find<DropsController>().refreshOverview();
    }
  }

  Future<void> sendSystemMessage({
    required String title,
    required String content,
  }) async {
    try {
      await _appMessageApi.sendSystemMessage(
        title: title,
        content: content,
      );
      Get.snackbar('提示', '系统消息已发送');
    } catch (e) {
      Get.snackbar('错误', '发送失败: $e');
    }
  }

  String _translateDropsSummary(String summary) {
    var result = summary;
    final replacements = <String, String>{
      'birthday': dropsEventTypeLabel('birthday'),
      'anniversary': dropsEventTypeLabel('anniversary'),
      'custom': dropsEventTypeLabel('custom'),
      'solar': dropsCalendarLabel('solar'),
      'lunar': dropsCalendarLabel('lunar'),
      'kitchen': dropsCategoryLabel('kitchen'),
      'food': dropsCategoryLabel('food'),
      'medicine': dropsCategoryLabel('medicine'),
      'clothing': dropsCategoryLabel('clothing'),
      'other': dropsCategoryLabel('other'),
    };

    replacements.forEach((raw, label) {
      result = result.replaceAll(RegExp('\\b${RegExp.escape(raw)}\\b'), label);
    });
    return result;
  }
}
