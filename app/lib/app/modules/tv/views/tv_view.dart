import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_file_entry.dart';
import '../../../widgets/resource_card_page.dart';
import '../../../widgets/video_folder_helper.dart';
import '../controllers/tv_controller.dart';

class TvView extends GetView<TvController> {
  const TvView({super.key});

  VideoFolderHelper get _videoHelper => VideoFolderHelper(
    applicationType: 'tv',
    playerRoute: '/player',
    streamUriBuilder: controller.buildStreamUri,
  );

  @override
  Widget build(BuildContext context) {
    return ResourceCardPage(
      title: '影视',
      controller: controller,
      iconBuilder: (entry) =>
          entry.isDir ? Icons.folder_rounded : Icons.play_circle_fill_rounded,
      iconColorBuilder: (entry) =>
          entry.isDir
              ? const Color(0xFFD97706)
              : const Color(0xFF0284C7),
      statusBuilder: (entry) => entry.isDir ? '文件夹' : '点击播放',
      onFolderTap: (entry, _, _) => _onFolderTap(entry),
      onFileTap: (entry, _, currentPath) => _onFileTap(entry, currentPath),
      shouldAutoOpen: (entries, _) => _videoHelper.shouldAutoOpen(entries),
      onAutoOpen: (_, path) => _onAutoOpen(path),
    );
  }

  Future<void> _onFolderTap(WebdavFileEntry entry) async {
    if (!entry.isDir) return;
    await controller.enterDir(entry);
  }

  Future<void> _onFileTap(WebdavFileEntry entry, String currentPath) async {
    if (!_videoHelper.isPlayableEntry(entry)) {
      Get.snackbar('提示', '不支持的文件类型');
      return;
    }
    await _videoHelper.openPlayer(
      folderPath: currentPath,
      folderTitle: _videoHelper.titleFromPath(currentPath, fallback: '影视'),
      preferredPath: entry.path,
    );
  }

  Future<void> _onAutoOpen(String path) async {
    final success = await _videoHelper.openPlayer(
      folderPath: path,
      folderTitle: _videoHelper.titleFromPath(path, fallback: '影视'),
    );
    if (success && controller.canGoBack) {
      await controller.popDir();
    }
  }
}
