import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/drops.dart';
import '../../../data/models/drops_event_model.dart';
import 'drops_controller.dart';
import 'package:ohome/app/modules/drops/views/drops_event_form_view.dart';

class DropsEventsController extends GetxController {
  DropsEventsController({DropsApi? dropsApi})
    : _dropsApi = dropsApi ?? Get.find<DropsApi>();

  static const int _pageSize = 20;

  final DropsApi _dropsApi;

  final keywordController = TextEditingController();
  final scrollController = ScrollController();
  final events = <DropsEventModel>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final scopeType = ''.obs;
  final eventType = ''.obs;

  int _page = 1;
  int _token = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_handleScroll);
    loadEvents(refresh: true);
  }

  @override
  void onClose() {
    keywordController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadEvents({required bool refresh}) async {
    late final int token;
    if (refresh) {
      token = ++_token;
      _page = 1;
      hasMore.value = true;
      loading.value = true;
      loadingMore.value = false;
    } else {
      if (loading.value || loadingMore.value || !hasMore.value) return;
      token = _token;
      loadingMore.value = true;
    }

    try {
      final result = await _dropsApi.getEventList(
        scopeType: scopeType.value,
        eventType: eventType.value,
        keyword: keywordController.text,
        page: _page,
        limit: _pageSize,
      );
      if (token != _token) return;
      if (refresh) {
        events.assignAll(result.records);
      } else {
        events.addAll(result.records);
      }
      hasMore.value = events.length < result.total;
      if (hasMore.value) {
        _page += 1;
      }
    } catch (_) {
      return;
    } finally {
      if (token == _token) {
        if (refresh) {
          loading.value = false;
        } else {
          loadingMore.value = false;
        }
      }
    }
  }

  Future<void> search() => loadEvents(refresh: true);

  void updateScope(String value) {
    scopeType.value = value;
    search();
  }

  void updateType(String value) {
    eventType.value = value;
    search();
  }

  Future<void> openCreate() async {
    await Get.find<DropsController>().ensureDictsLoaded();
    final changed = await Get.to<bool>(() => const DropsEventFormView());
    if (changed == true) {
      await loadEvents(refresh: true);
      await Get.find<DropsController>().refreshOverview();
    }
  }

  Future<void> openEdit(DropsEventModel event) async {
    await Get.find<DropsController>().ensureDictsLoaded();
    final changed = await Get.to<bool>(
      () => DropsEventFormView(initialEventId: event.id),
    );
    if (changed == true) {
      await loadEvents(refresh: true);
      await Get.find<DropsController>().refreshOverview();
    }
  }

  Future<void> deleteEvent(DropsEventModel event) async {
    final id = event.id;
    if (id == null) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除重要日期'),
        content: Text('确定删除 ${event.title} 吗？'),
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
    await _dropsApi.deleteEvent(id);
    await loadEvents(refresh: true);
    await Get.find<DropsController>().refreshOverview();
    Get.snackbar('提示', '重要日期已删除');
  }

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.maxScrollExtent - position.pixels < 200) {
      loadEvents(refresh: false);
    }
  }
}
