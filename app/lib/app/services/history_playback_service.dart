import 'package:get/get.dart';

import '../data/models/media_history_entry.dart';
import 'playback_entry_service.dart';

class HistoryPlaybackService extends GetxService {
  HistoryPlaybackService({PlaybackEntryService? entryService})
    : _entryService = entryService ?? Get.find<PlaybackEntryService>();

  final PlaybackEntryService _entryService;
  bool _openingEntry = false;

  Future<bool> navigateToEntry(MediaHistoryEntry entry) async {
    if (_openingEntry) {
      return false;
    }

    final folderPath = entry.folderPath.trim();
    if (folderPath.isEmpty) {
      Get.snackbar('提示', '当前记录没有有效的文件夹路径');
      return false;
    }

    final launch = await _entryService.buildFromHistoryEntry(entry);
    if (launch == null) {
      Get.snackbar('提示', '当前记录没有有效的打开路径');
      return false;
    }

    _openingEntry = true;
    try {
      await Get.toNamed(launch.route, arguments: launch.arguments);
      return true;
    } finally {
      _openingEntry = false;
    }
  }

  Future<bool> openEntry(MediaHistoryEntry entry) {
    return navigateToEntry(entry);
  }
}
