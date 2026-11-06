import 'package:get/get.dart';

import '../../../data/api/quark_transfer.dart';
import '../../../data/models/quark_share_preview_file.dart';
import '../../../utils/http_client.dart';
import '../../../utils/quark_error_helper.dart';

class SharePreviewController extends GetxController {
  SharePreviewController({QuarkTransferRepository? repository})
    : _repository = repository ?? QuarkTransferRepository();

  final QuarkTransferRepository _repository;

  final RxList<QuarkSharePreviewFile> files = <QuarkSharePreviewFile>[].obs;
  final RxBool loading = false.obs;
  final RxString errorMessage = ''.obs;

  late final String shareUrl;
  final RxString title = ''.obs;
  String passcode = '';

  final RxList<_PreviewDirLevel> _stack = <_PreviewDirLevel>[].obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    var rawTitle = '';
    if (args is Map) {
      shareUrl = (args['shareUrl'] as String?)?.trim() ?? '';
      rawTitle = (args['title'] as String?)?.trim() ?? '';
      passcode = (args['passcode'] as String?)?.trim() ?? '';
    } else {
      shareUrl = '';
    }
    if (rawTitle.isEmpty) {
      final uri = Uri.tryParse(shareUrl);
      rawTitle = uri != null && uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '资源预览';
    }
    title.value = rawTitle.isEmpty ? '资源预览' : rawTitle;
    refreshCurrent();
  }

  bool get canGoBack => _stack.length > 1;

  String get currentDirName => _stack.isEmpty ? '' : _stack.last.name;

  String get displayTitle {
    final dirName = currentDirName;
    if (dirName.isNotEmpty) return dirName;
    return title.value.isEmpty ? '资源预览' : title.value;
  }

  Future<void> refreshCurrent() async {
    if (shareUrl.isEmpty) {
      errorMessage.value = '分享链接无效';
      files.clear();
      return;
    }
    final pdirFid = _stack.isEmpty
        ? ''
        : _stack.last.fid;
    loading.value = true;
    errorMessage.value = '';
    try {
      final result = await _repository.sharePreview(
        shareUrl: shareUrl,
        passcode: passcode,
        pdirFid: pdirFid,
      );
      final sorted = List<QuarkSharePreviewFile>.of(result.files)
        ..sort((a, b) {
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        });
      files.assignAll(sorted);
      if (_stack.isEmpty) {
        _stack.add(_PreviewDirLevel(fid: result.pdirFid, name: ''));
      }
    } on ApiException catch (e) {
      errorMessage.value = QuarkErrorHelper.toFriendlyMessage(
        e.message.trim().isEmpty ? '预览失败，请稍后重试' : e.message,
      );
      files.clear();
    } catch (_) {
      errorMessage.value = '预览失败，请稍后重试';
      files.clear();
    } finally {
      loading.value = false;
    }
  }

  Future<void> enterDir(QuarkSharePreviewFile item) async {
    if (!item.isDir) return;
    _stack.add(_PreviewDirLevel(fid: item.fid, name: item.fileName));
    await refreshCurrent();
  }

  Future<void> popDir() async {
    if (_stack.length <= 1) return;
    _stack.removeLast();
    await refreshCurrent();
  }

  /// 有上级目录时回到上一级，否则退出预览页。
  void handleBack() {
    if (canGoBack) {
      popDir();
      return;
    }
    Get.back();
  }
}

class _PreviewDirLevel {
  const _PreviewDirLevel({required this.fid, required this.name});

  final String fid;
  final String name;
}