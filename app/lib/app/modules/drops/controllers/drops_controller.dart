import 'dart:async';

import 'package:get/get.dart';

import '../../../data/api/dict.dart';
import '../../../data/models/dict_data_model.dart';
import '../../../data/api/drops.dart';
import '../../../data/models/drops_overview_model.dart';
import '../drops_catalog.dart';
import '../views/drops_event_form_view.dart';
import '../views/drops_item_form_view.dart';
import '../views/drops_reminder_view.dart';

class DropsController extends GetxController {
  DropsController({DropsApi? dropsApi, DictApi? dictApi})
    : _dropsApi = dropsApi ?? Get.find<DropsApi>(),
      _dictApi = dictApi ?? Get.find<DictApi>();

  final DropsApi _dropsApi;
  final DictApi _dictApi;

  static const String _scopeDictType = 'dropsScopeType';
  static const String _itemCategoryDictType = 'dropsItemCategory';
  static const String _eventTypeDictType = 'dropsEventType';
  static const String _calendarTypeDictType = 'dropsCalendarType';

  final overview = Rxn<DropsOverviewModel>();
  final loading = false.obs;
  final dictVersion = 0.obs;
  final dictLoading = false.obs;

  final Map<String, String> _scopeLabels = <String, String>{};
  final Map<String, String> _categoryLabels = <String, String>{};
  final Map<String, String> _eventTypeLabels = <String, String>{};
  final Map<String, String> _calendarLabels = <String, String>{};
  Completer<void>? _dictLoadingCompleter;
  bool _dictLoaded = false;

  @override
  void onInit() {
    super.onInit();
    refreshOverview();
    unawaited(ensureDictsLoaded());
  }

  Map<String, String> get scopeLabels =>
      Map.unmodifiable(_scopeLabels.isEmpty ? dropsScopeLabels : _scopeLabels);

  Map<String, String> get categoryLabels => Map.unmodifiable(
    _categoryLabels.isEmpty ? dropsCategoryLabels : _categoryLabels,
  );

  Map<String, String> get eventTypeLabels => Map.unmodifiable(
    _eventTypeLabels.isEmpty ? dropsEventTypeLabels : _eventTypeLabels,
  );

  Map<String, String> get calendarLabels => Map.unmodifiable(
    _calendarLabels.isEmpty ? dropsCalendarLabels : _calendarLabels,
  );

  String scopeLabel(String value) =>
      scopeLabels[value] ?? (value.trim().isEmpty ? '未知' : value);

  String categoryLabel(String value) =>
      categoryLabels[value] ?? (value.trim().isEmpty ? '未分类' : value);

  String eventTypeLabel(String value) =>
      eventTypeLabels[value] ?? (value.trim().isEmpty ? '未分类' : value);

  String calendarLabel(String value) =>
      calendarLabels[value] ?? (value.trim().isEmpty ? '未设置' : value);

  Future<void> ensureDictsLoaded() async {
    if (_dictLoaded) return;
    if (_dictLoadingCompleter != null) {
      await _dictLoadingCompleter!.future;
      return;
    }

    final completer = Completer<void>();
    _dictLoadingCompleter = completer;
    dictLoading.value = true;
    try {
      final results = await Future.wait<List<DictDataModel>>([
        _dictApi.getDataList(dictType: _scopeDictType),
        _dictApi.getDataList(dictType: _itemCategoryDictType),
        _dictApi.getDataList(dictType: _eventTypeDictType),
        _dictApi.getDataList(dictType: _calendarTypeDictType),
      ]);

      _replaceLabels(_scopeLabels, results[0], dropsScopeLabels);
      _replaceLabels(_categoryLabels, results[1], dropsCategoryLabels);
      _replaceLabels(_eventTypeLabels, results[2], dropsEventTypeLabels);
      _replaceLabels(_calendarLabels, results[3], dropsCalendarLabels);
      _dictLoaded = true;
    } catch (_) {
      _scopeLabels
        ..clear()
        ..addAll(dropsScopeLabels);
      _categoryLabels
        ..clear()
        ..addAll(dropsCategoryLabels);
      _eventTypeLabels
        ..clear()
        ..addAll(dropsEventTypeLabels);
      _calendarLabels
        ..clear()
        ..addAll(dropsCalendarLabels);
    } finally {
      dictLoading.value = false;
      dictVersion.value++;
      completer.complete();
      _dictLoadingCompleter = null;
    }
  }

  void _replaceLabels(
    Map<String, String> target,
    List<DictDataModel> items,
    Map<String, String> fallback,
  ) {
    target.clear();
    if (items.isEmpty) {
      target.addAll(fallback);
      return;
    }
    for (final item in items) {
      final value = item.value.trim();
      final label = item.label.trim();
      if (value.isEmpty || label.isEmpty) continue;
      target[value] = label;
    }
    if (target.isEmpty) {
      target.addAll(fallback);
    }
  }

  Future<void> refreshOverview() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final result = await _dropsApi.getOverview();
      overview.value = result;
    } catch (_) {
      return;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> openNewItem() async {
    await ensureDictsLoaded();
    final changed = await Get.to<bool>(() => const DropsItemFormView());
    if (changed == true) {
      await refreshOverview();
      return true;
    }
    return false;
  }

  Future<bool> openNewEvent() async {
    await ensureDictsLoaded();
    final changed = await Get.to<bool>(() => const DropsEventFormView());
    if (changed == true) {
      await refreshOverview();
      return true;
    }
    return false;
  }

  Future<void> openExpiringReminders() async {
    await Get.to<void>(
      () => const DropsReminderView(type: DropsReminderType.expiringItems),
    );
    await refreshOverview();
  }

  Future<void> openUpcomingReminders() async {
    await Get.to<void>(
      () => const DropsReminderView(type: DropsReminderType.upcomingEvents),
    );
    await refreshOverview();
  }
}
