import 'package:get/get.dart';

import '../../../data/api/quark.dart';
import '../../../data/models/quark_file_entry.dart';
import '../../../utils/quark_error_helper.dart';

enum WebdavListSortType { updatedDesc, updatedAsc, nameAsc }

extension WebdavListSortTypeX on WebdavListSortType {
  String get apiValue {
    switch (this) {
      case WebdavListSortType.updatedDesc:
        return 'updated_desc';
      case WebdavListSortType.updatedAsc:
        return 'updated_asc';
      case WebdavListSortType.nameAsc:
        return 'name_asc';
    }
  }

  String get label {
    switch (this) {
      case WebdavListSortType.updatedDesc:
        return '最近更新';
      case WebdavListSortType.updatedAsc:
        return '最早更新';
      case WebdavListSortType.nameAsc:
        return '名称 A-Z';
    }
  }
}

class WebdavDeleteResult {
  const WebdavDeleteResult({
    required this.successPaths,
    required this.failedPaths,
  });

  final List<String> successPaths;
  final List<String> failedPaths;

  int get successCount => successPaths.length;
  int get failedCount => failedPaths.length;
}

class WebdavMoveResult {
  const WebdavMoveResult({
    required this.successPaths,
    required this.failedPaths,
  });

  final List<String> successPaths;
  final List<String> failedPaths;

  int get successCount => successPaths.length;
  int get failedCount => failedPaths.length;
}

abstract class WebdavFolderController extends GetxController {
  WebdavFolderController({required this.applicationType, WebdavApi? webdavApi})
    : _webdavApi = webdavApi ?? WebdavApi();

  static const int pageSize = 10;

  final String applicationType;
  final WebdavApi _webdavApi;

  final currentPath = '/'.obs;
  final entries = <WebdavFileEntry>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString();
  final loadMoreError = RxnString();
  final authError = false.obs;
  final deletingPaths = <String>{}.obs;
  final currentSort = WebdavListSortType.updatedDesc.obs;
  final _navigationStack = <String>[].obs;
  int _page = 1;
  int _loadToken = 0;

  bool get canGoBack => _navigationStack.isNotEmpty;

  @override
  void onReady() {
    super.onReady();
    refreshCurrent();
  }

  Future<void> refreshCurrent() =>
      _load(path: currentPath.value, refresh: true);

  Future<void> loadMoreCurrent() =>
      _load(path: currentPath.value, refresh: false);

  Future<void> changeSort(WebdavListSortType sortType) async {
    if (currentSort.value == sortType) return;
    currentSort.value = sortType;
    await refreshCurrent();
  }

  Future<void> enterDir(WebdavFileEntry entry) async {
    if (!entry.isDir) return;
    _navigationStack.add(currentPath.value);
    currentSort.value = _defaultSortForPath(entry.path);
    await _load(path: entry.path, refresh: true);
  }

  Future<void> popDir() async {
    if (_navigationStack.isEmpty) return;
    final previous = _navigationStack.removeLast();
    currentSort.value = _defaultSortForPath(previous);
    await _load(path: previous, refresh: true);
  }

  bool isDeletingPath(String path) => deletingPaths.contains(path.trim());

  Future<void> renameEntry({
    required String path,
    required String newName,
  }) async {
    await _webdavApi.renameEntry(
      applicationType: applicationType,
      path: path,
      newName: newName,
    );
    await refreshCurrent();
  }

  Future<List<QuarkConfigOption>> fetchMoveTargets() {
    return _webdavApi.fetchMoveTargets();
  }

  Future<WebdavDeleteResult> deleteEntries(List<String> paths) async {
    final targets = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (targets.isEmpty) {
      return const WebdavDeleteResult(successPaths: [], failedPaths: []);
    }

    final success = <String>[];
    final failed = <String>[];

    deletingPaths.addAll(targets);
    deletingPaths.refresh();
    for (final target in targets) {
      try {
        await _webdavApi.deleteEntry(
          applicationType: applicationType,
          path: target,
        );
        success.add(target);
      } catch (_) {
        failed.add(target);
      } finally {
        deletingPaths.remove(target);
        deletingPaths.refresh();
      }
    }

    if (success.isNotEmpty) {
      entries.removeWhere((entry) => success.contains(entry.path.trim()));
      entries.refresh();
      await refreshCurrent();
    }

    return WebdavDeleteResult(successPaths: success, failedPaths: failed);
  }

  Future<WebdavMoveResult> moveEntries(
    List<String> paths, {
    required String targetApplicationType,
  }) async {
    final targets = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (targets.isEmpty) {
      return const WebdavMoveResult(successPaths: [], failedPaths: []);
    }

    final success = <String>[];
    final failed = <String>[];

    final destinationApp = targetApplicationType.trim();
    if (destinationApp.isEmpty) {
      return const WebdavMoveResult(successPaths: [], failedPaths: []);
    }

    deletingPaths.addAll(targets);
    deletingPaths.refresh();
    for (final targetPath in targets) {
      try {
        await _webdavApi.moveEntry(
          applicationType: destinationApp,
          path: targetPath,
        );
        success.add(targetPath);
      } catch (_) {
        failed.add(targetPath);
      } finally {
        deletingPaths.remove(targetPath);
        deletingPaths.refresh();
      }
    }

    if (success.isNotEmpty) {
      entries.removeWhere((entry) => success.contains(entry.path.trim()));
      entries.refresh();
      await refreshCurrent();
    }

    return WebdavMoveResult(successPaths: success, failedPaths: failed);
  }

  Future<void> _load({required String path, required bool refresh}) async {
    late final int token;
    if (refresh) {
      token = ++_loadToken;
      _page = 1;
      hasMore.value = true;
      loading.value = true;
      loadingMore.value = false;
      error.value = null;
      loadMoreError.value = null;
      authError.value = false;
    } else {
      if (loading.value || loadingMore.value || !hasMore.value) {
        return;
      }
      token = _loadToken;
      loadingMore.value = true;
      loadMoreError.value = null;
    }

    try {
      final result = await _webdavApi.fetchFileList(
        applicationType: applicationType,
        path: path,
        page: _page,
        size: pageSize,
        sortType: currentSort.value.apiValue,
      );
      if (token != _loadToken) return;

      currentPath.value = path;
      if (refresh) {
        entries.assignAll(result);
      } else {
        entries.addAll(result);
      }

      final nextPageAvailable = result.length >= pageSize;
      hasMore.value = nextPageAvailable;
      if (nextPageAvailable) {
        _page += 1;
      }
    } catch (e) {
      if (token == _loadToken) {
        final isAuthError = QuarkErrorHelper.isQuarkAuthError(e);
        final friendlyMessage = QuarkErrorHelper.toFriendlyMessage(e);
        authError.value = isAuthError;
        if (refresh) {
          error.value = friendlyMessage;
        } else {
          loadMoreError.value = friendlyMessage;
        }
      }
    } finally {
      if (token == _loadToken) {
        if (refresh) {
          loading.value = false;
        } else {
          loadingMore.value = false;
        }
      }
    }
  }

  WebdavListSortType _defaultSortForPath(String path) {
    return path.trim() == '/'
        ? WebdavListSortType.updatedDesc
        : WebdavListSortType.nameAsc;
  }
}
