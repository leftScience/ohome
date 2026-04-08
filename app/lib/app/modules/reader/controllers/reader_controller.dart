import 'package:get/get.dart';

import '../../../data/api/quark.dart';

class ReaderController extends GetxController {
  ReaderController({WebdavApi? webdavApi})
    : _webdavApi = webdavApi ?? Get.find<WebdavApi>();

  final WebdavApi _webdavApi;

  final title = '阅读'.obs;
  final filePath = ''.obs;
  final content = ''.obs;
  final loading = false.obs;
  final error = ''.obs;

  @override
  void onReady() {
    super.onReady();
    _applyArguments(Get.arguments);
    loadContent();
  }

  Future<void> loadContent() async {
    final path = filePath.value.trim();
    if (path.isEmpty) {
      error.value = '文件路径不能为空';
      return;
    }

    loading.value = true;
    error.value = '';
    try {
      final raw = await _webdavApi.fetchTextFileContent(
        applicationType: 'read',
        path: path,
      );
      final normalized = _normalizeText(raw);
      content.value = normalized;
      if (normalized.isEmpty) {
        error.value = '文本内容为空';
      }
    } catch (e) {
      error.value = '加载文本失败：$e';
      content.value = '';
    } finally {
      loading.value = false;
    }
  }

  void _applyArguments(dynamic arguments) {
    if (arguments is! Map) return;
    final nextTitle = (arguments['title'] ?? '').toString().trim();
    final nextPath = (arguments['filePath'] ?? '').toString().trim();
    if (nextTitle.isNotEmpty) {
      title.value = nextTitle;
    }
    filePath.value = nextPath;
  }

  String _normalizeText(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }
}
