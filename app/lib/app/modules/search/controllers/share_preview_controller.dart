import 'dart:async';

import 'package:get/get.dart';

import '../../../data/api/quark_transfer.dart';
import '../../../data/models/quark_share_preview_file.dart';
import '../../../utils/http_client.dart';
import '../../../utils/quark_error_helper.dart';
import '../../../utils/quark_transfer_helper.dart';

class _SharePreviewNavEntry {
  const _SharePreviewNavEntry({required this.pdirFid, required this.title});

  final String pdirFid;
  final String title;
}

class SharePreviewController extends GetxController {
  SharePreviewController({
    QuarkTransferRepository? repository,
    QuarkTransferHelper? transferHelper,
  }) : _repository = repository ?? QuarkTransferRepository(),
       _transferHelper =
           transferHelper ?? QuarkTransferHelper(repository: repository);

  final QuarkTransferRepository _repository;
  final QuarkTransferHelper _transferHelper;

  late final String shareUrl;
  late final String resourceTitle;
  late final String passcode;

  final files = <QuarkSharePreviewFile>[].obs;
  final loading = false.obs;
  final transferring = false.obs;
  final error = RxnString();
  final currentTitle = ''.obs;
  final navigationStack = <_SharePreviewNavEntry>[].obs;

  int _loadToken = 0;

  bool get canGoBack => navigationStack.length > 1;

  String get displayTitle => currentTitle.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    var url = '';
    var title = '';
    var code = '';
    if (args is Map) {
      url = (args['shareUrl'] as String?)?.trim() ?? '';
      title = (args['title'] as String?)?.trim() ?? '';
      code = (args['passcode'] as String?)?.trim() ?? '';
    }
    shareUrl = url;
    resourceTitle = title.isEmpty ? '分享内容' : title;
    passcode = code;
    currentTitle.value = resourceTitle;
    navigationStack.assignAll([
      _SharePreviewNavEntry(pdirFid: '', title: resourceTitle),
    ]);
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(refreshCurrent());
  }

  Future<void> refreshCurrent() {
    final current = navigationStack.isEmpty
        ? const _SharePreviewNavEntry(pdirFid: '', title: '分享内容')
        : navigationStack.last;
    return _load(pdirFid: current.pdirFid);
  }

  Future<void> enterDir(QuarkSharePreviewFile entry) async {
    if (!entry.isDir || entry.fid.trim().isEmpty) return;
    navigationStack.add(
      _SharePreviewNavEntry(
        pdirFid: entry.fid.trim(),
        title: entry.fileName.trim().isEmpty ? '文件夹' : entry.fileName.trim(),
      ),
    );
    currentTitle.value = navigationStack.last.title;
    await _load(pdirFid: entry.fid.trim());
  }

  Future<void> popDir() async {
    if (!canGoBack) {
      Get.back();
      return;
    }
    navigationStack.removeLast();
    final current = navigationStack.last;
    currentTitle.value = current.title;
    await _load(pdirFid: current.pdirFid);
  }

  void handleBack() {
    popDir();
  }

  Future<void> transferCurrent() async {
    if (shareUrl.trim().isEmpty || transferring.value) return;
    transferring.value = true;
    try {
      await _transferHelper.transferOnce(
        shareUrl: shareUrl,
        resourceName: resourceTitle,
        passcode: passcode,
      );
    } finally {
      transferring.value = false;
    }
  }

  Future<void> _load({required String pdirFid}) async {
    if (shareUrl.trim().isEmpty) {
      error.value = '分享链接为空';
      files.clear();
      return;
    }

    final token = ++_loadToken;
    loading.value = true;
    error.value = null;
    try {
      final result = await _repository.sharePreview(
        shareUrl: shareUrl,
        passcode: passcode,
        pdirFid: pdirFid,
      );
      if (token != _loadToken) return;
      final sorted = result.files.toList(growable: true)
        ..sort((a, b) {
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        });
      files.assignAll(sorted);
    } catch (e) {
      if (token != _loadToken) return;
      files.clear();
      error.value = _errorMessage(e);
    } finally {
      if (token == _loadToken) {
        loading.value = false;
      }
    }
  }

  static String _errorMessage(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return QuarkErrorHelper.toFriendlyMessage(error.message.trim());
    }
    final message = error.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
    return message.trim().isEmpty ? '预览失败，请稍后重试' : message.trim();
  }
}