import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/api/quark_transfer.dart';
import '../widgets/selection_bottom_sheet.dart';
import 'http_client.dart';
import 'quark_error_helper.dart';

class QuarkTransferSelection {
  const QuarkTransferSelection({
    required this.application,
    required this.savePath,
  });

  final String application;
  final String savePath;
}

class QuarkTransferHelper {
  QuarkTransferHelper({QuarkTransferRepository? repository})
    : _repository = repository ?? QuarkTransferRepository();

  static const targets = <String>['tv', 'playlet', 'music', 'read'];

  final QuarkTransferRepository _repository;
  final Map<String, String> savePathMap = <String, String>{};
  bool _loadingSavePaths = false;

  QuarkTransferRepository get repository => _repository;

  Future<void> ensureSavePathsLoaded() async {
    if (_loadingSavePaths) return;
    if (savePathMap.isNotEmpty) return;

    _loadingSavePaths = true;
    try {
      final results = await Future.wait(
        targets.map((t) async {
          try {
            final rootPath = await _repository.getQuarkRootPath(t);
            return MapEntry(t, stripQuarkPrefixForStore(rootPath));
          } catch (_) {
            return MapEntry(t, '');
          }
        }),
      );

      savePathMap
        ..clear()
        ..addEntries(results.where((e) => e.value.trim().isNotEmpty));
    } finally {
      _loadingSavePaths = false;
    }
  }

  Future<QuarkTransferSelection?> showTransferSheet() async {
    await ensureSavePathsLoaded();

    final context = Get.overlayContext ?? Get.context;
    if (context == null || !context.mounted) return null;

    final availableCount = targets
        .where((app) => (savePathMap[app] ?? '').trim().isNotEmpty)
        .length;

    return showSelectionBottomSheet<QuarkTransferSelection>(
      context: context,
      meta: SelectionBottomSheetMeta(
        icon: Icons.check_circle_rounded,
        label: '已配置 $availableCount / ${targets.length}',
        accent: availableCount > 0
            ? const Color(0xFF059669)
            : const Color(0xFFD97706),
      ),
      emptyTitle: '暂无可用分类',
      emptyDescription: '未找到可用的 WebDAV 配置，请先在后台为对应应用配置 rootPath。',
      options: targets
          .map((application) {
            final savePath = (savePathMap[application] ?? '').trim();
            final enabled = savePath.isNotEmpty;
            return SelectionBottomSheetOption<QuarkTransferSelection>(
              value: QuarkTransferSelection(
                application: application,
                savePath: savePath,
              ),
              title: quarkApplicationLabel(application),
              subtitle: enabled ? savePath : '请先配置 rootPath 后再使用',
              icon: quarkApplicationIcon(application),
              accent: quarkApplicationAccent(application),
              statusText: enabled ? '可转存' : '未配置',
              enabled: enabled,
            );
          })
          .toList(growable: false),
    );
  }

  Future<bool> transferOnce({
    required String shareUrl,
    required String resourceName,
    String passcode = '',
  }) async {
    final url = shareUrl.trim();
    if (url.isEmpty) return false;

    final selected = await showTransferSheet();
    if (selected == null) return false;

    try {
      await _repository.transferOnce(
        shareUrl: url,
        savePath: selected.savePath,
        application: selected.application,
        resourceName: resourceName.trim().isEmpty ? url : resourceName.trim(),
        passcode: passcode,
      );
      Get.snackbar(
        '提示',
        '已加入转存任务',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      return true;
    } on ApiException catch (e) {
      Get.snackbar(
        '转存失败',
        QuarkErrorHelper.toFriendlyMessage(
          e.message.trim().isEmpty ? '请稍后重试' : e.message,
        ),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
      return false;
    } catch (_) {
      Get.snackbar(
        '转存失败',
        '请稍后重试',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
      return false;
    }
  }

  static String stripQuarkPrefixForStore(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll('\\', '/');
    normalized = normalized.replaceAll(RegExp(r'^/+'), '');
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');

    final lower = normalized.toLowerCase();
    final idx = lower.indexOf('quark/');
    if (idx > 0) normalized = normalized.substring(idx);
    normalized = normalized.replaceFirst(
      RegExp(r'^quark/?', caseSensitive: false),
      '',
    );

    normalized = normalized.replaceAll(RegExp(r'^/+'), '');
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    return normalized;
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final digits = unitIndex == 0
        ? 0
        : (size >= 100 ? 0 : (size >= 10 ? 1 : 2));
    return '${size.toStringAsFixed(digits)} ${units[unitIndex]}';
  }
}