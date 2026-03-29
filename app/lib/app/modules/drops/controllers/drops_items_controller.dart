import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/drops.dart';
import '../../../data/models/drops_item_model.dart';
import 'drops_controller.dart';
import 'package:ohome/app/modules/drops/views/drops_item_detail_view.dart';
import 'package:ohome/app/modules/drops/views/drops_item_form_view.dart';

class DropsItemsController extends GetxController {
  DropsItemsController({DropsApi? dropsApi})
    : _dropsApi = dropsApi ?? Get.find<DropsApi>();

  static const int _pageSize = 20;

  final DropsApi _dropsApi;

  final keywordController = TextEditingController();
  final scrollController = ScrollController();
  final items = <DropsItemModel>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final scopeType = ''.obs;
  final category = ''.obs;

  int _page = 1;
  int _token = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_handleScroll);
    loadItems(refresh: true);
  }

  @override
  void onClose() {
    keywordController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadItems({required bool refresh}) async {
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
      final result = await _dropsApi.getItemList(
        scopeType: scopeType.value,
        category: category.value,
        keyword: keywordController.text,
        page: _page,
        limit: _pageSize,
      );
      if (token != _token) return;
      if (refresh) {
        items.assignAll(result.records);
      } else {
        items.addAll(result.records);
      }
      hasMore.value = items.length < result.total;
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

  Future<void> search() => loadItems(refresh: true);

  void updateScope(String value) {
    scopeType.value = value;
    search();
  }

  void updateCategory(String value) {
    category.value = value;
    search();
  }

  Future<void> openCreate() async {
    await Get.find<DropsController>().ensureDictsLoaded();
    final changed = await Get.to<bool>(() => const DropsItemFormView());
    if (changed == true) {
      await loadItems(refresh: true);
      await Get.find<DropsController>().refreshOverview();
    }
  }

  Future<void> openDetail(DropsItemModel item) async {
    final id = item.id;
    if (id == null) return;
    await Get.find<DropsController>().ensureDictsLoaded();
    final changed = await Get.to<bool>(() => DropsItemDetailView(itemId: id));
    if (changed == true) {
      await loadItems(refresh: true);
      await Get.find<DropsController>().refreshOverview();
    }
  }

  Future<void> deleteItem(DropsItemModel item) async {
    final id = item.id;
    if (id == null) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除物资'),
        content: Text('删除 ${item.name} 后，照片也会从 Quark 中清理。'),
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
    await _dropsApi.deleteItem(id);
    await loadItems(refresh: true);
    await Get.find<DropsController>().refreshOverview();
    Get.snackbar('提示', '物资已删除');
  }

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.maxScrollExtent - position.pixels < 200) {
      loadItems(refresh: false);
    }
  }
}
