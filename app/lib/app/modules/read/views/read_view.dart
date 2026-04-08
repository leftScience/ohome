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
          : switch (_fileType(entry.name)) {
              _ReadFileType.epub => Icons.menu_book_rounded,
              _ReadFileType.txt => Icons.subject_rounded,
              _ReadFileType.pdf => Icons.picture_as_pdf_rounded,
              _ReadFileType.unsupported => Icons.insert_drive_file_rounded,
            },
      iconColorBuilder: (entry) => entry.isDir
          ? Colors.amber
          : switch (_fileType(entry.name)) {
              _ReadFileType.epub => const Color(0xFF34D399),
              _ReadFileType.txt => const Color(0xFF60A5FA),
              _ReadFileType.pdf => const Color(0xFFF87171),
              _ReadFileType.unsupported => Colors.blueGrey,
            },
      statusBuilder: (entry) => entry.isDir
          ? '文件夹'
          : switch (_fileType(entry.name)) {
              _ReadFileType.epub => 'EPUB 电子书',
              _ReadFileType.txt => 'TXT 文本',
              _ReadFileType.pdf => 'PDF 文档',
              _ReadFileType.unsupported => '不支持的文件类型',
            },
      onFolderTap: (entry, entries, currentPath) => _onFolderTap(entry),
      onFileTap: (entry, entries, currentPath) => _onFileTap(entry),
    );
  }

  Future<void> _onFolderTap(WebdavFileEntry entry) async {
    if (!entry.isDir) return;
    await controller.enterDir(entry);
  }

  Future<void> _onFileTap(WebdavFileEntry entry) async {
    if (_fileType(entry.name) == _ReadFileType.unsupported) {
      Get.snackbar('提示', '当前仅支持 EPUB、TXT、PDF 文件阅读');
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

  _ReadFileType _fileType(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.endsWith('.epub')) return _ReadFileType.epub;
    if (lower.endsWith('.txt')) return _ReadFileType.txt;
    if (lower.endsWith('.pdf')) return _ReadFileType.pdf;
    return _ReadFileType.unsupported;
  }
}

enum _ReadFileType { epub, txt, pdf, unsupported }
