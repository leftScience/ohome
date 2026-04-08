import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/quark_file_entry.dart';
import '../../../routes/app_pages.dart';
import '../../../widgets/resource_card_page.dart';
import '../controllers/read_controller.dart';

class ReadView extends GetView<ReadController> {
  const ReadView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceCardPage(
      title: '阅读',
      controller: controller,
      iconBuilder: (entry) => entry.isDir
          ? Icons.folder_rounded
          : _isTxt(entry.name)
          ? Icons.description_rounded
          : Icons.insert_drive_file_rounded,
      iconColorBuilder: (entry) => entry.isDir
          ? Colors.amber
          : _isTxt(entry.name)
          ? const Color(0xFF34D399)
          : Colors.blueGrey,
      statusBuilder: (entry) =>
          entry.isDir ? '文件夹' : (_isTxt(entry.name) ? '点击阅读' : '不支持的文件类型'),
      onFolderTap: (entry, entries, currentPath) => _onFolderTap(entry),
      onFileTap: (entry, entries, currentPath) => _onFileTap(entry),
    );
  }

  Future<void> _onFolderTap(WebdavFileEntry entry) async {
    if (!entry.isDir) return;
    await controller.enterDir(entry);
  }

  Future<void> _onFileTap(WebdavFileEntry entry) async {
    if (!_isTxt(entry.name)) {
      Get.snackbar('提示', '当前仅支持 txt 文件阅读');
      return;
    }
    await Get.toNamed(
      Routes.READER,
      arguments: <String, dynamic>{
        'title': entry.name.trim().isEmpty ? '阅读' : entry.name.trim(),
        'filePath': entry.path,
        'applicationType': controller.applicationType,
      },
    );
  }

  bool _isTxt(String name) {
    return name.trim().toLowerCase().endsWith('.txt');
  }
}
