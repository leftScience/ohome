import 'dart:async';

import 'package:get/get.dart';

import '../../services/media_history_service.dart';
import '../../utils/media_path.dart';
import '../models/media_history_entry.dart';

class PlaybackProgress {
  const PlaybackProgress({
    required this.itemTitle,
    required this.position,
    this.duration,
    this.itemPath,
  });

  final String itemTitle;
  final Duration position;
  final Duration? duration;
  final String? itemPath;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemTitle': itemTitle,
    'itemPath': itemPath,
    'positionMs': position.inMilliseconds,
    'durationMs': duration?.inMilliseconds,
  };

  factory PlaybackProgress.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final positionMs = toInt(json['positionMs']);
    final durationMs = toInt(json['durationMs']);
    final rawTitle = (json['itemTitle'] as String?)?.trim() ?? '';
    final fallbackPath = MediaPath.normalize(json['itemPath'] as String?);
    return PlaybackProgress(
      itemTitle: rawTitle.isNotEmpty ? rawTitle : MediaPath.title(fallbackPath),
      position: Duration(milliseconds: positionMs > 0 ? positionMs : 0),
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      itemPath: fallbackPath.isEmpty ? null : fallbackPath,
    );
  }

  factory PlaybackProgress.fromEntry(MediaHistoryEntry entry) {
    final positionMs = entry.positionMs;
    final durationMs = entry.durationMs;
    final path = entry.itemPath.trim();
    return PlaybackProgress(
      itemTitle: entry.itemTitle,
      position: Duration(milliseconds: positionMs > 0 ? positionMs : 0),
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      itemPath: path.isEmpty ? null : path,
    );
  }

  String buildItemPath(String folderPath) {
    final direct = MediaPath.normalize(itemPath);
    if (direct.isNotEmpty) return direct;
    return MediaPath.join(folderPath, itemTitle);
  }
}

class PlaybackProgressStorage {
  PlaybackProgressStorage({
    required String applicationType,
    MediaHistoryService? historyService,
  }) : _applicationType = _normalizeApplicationType(applicationType),
       _historyService = historyService ?? _tryFindHistoryService();

  final String _applicationType;
  final MediaHistoryService? _historyService;

  static const Set<String> _supportedTypes = <String>{'tv', 'playlet', 'music'};

  static String _normalizeApplicationType(String value) {
    final normalized = value.trim().toLowerCase();
    if (_supportedTypes.contains(normalized)) return normalized;
    return 'tv';
  }

  static MediaHistoryService? _tryFindHistoryService() {
    if (!Get.isRegistered<MediaHistoryService>()) {
      return null;
    }
    return Get.find<MediaHistoryService>();
  }

  Future<void> saveProgress({
    required String folderPath,
    required String itemTitle,
    required Duration position,
    String? itemPath,
    Duration? duration,
    String? coverUrl,
    Map<String, dynamic>? extra,
  }) async {
    final service = _historyService;
    if (service == null) {
      return;
    }

    final folder = folderPath.trim();
    final normalizedPath = MediaPath.normalize(itemPath);
    var item = itemTitle.trim();
    if (item.isEmpty && normalizedPath.isNotEmpty) {
      item = MediaPath.title(normalizedPath);
    }
    if (folder.isEmpty || item.isEmpty) {
      return;
    }
    await service.saveProgress(
      applicationType: _applicationType,
      folderPath: folder,
      itemTitle: item,
      position: position,
      itemPath: normalizedPath,
      duration: duration,
      coverUrl: coverUrl,
      extra: extra,
    );
  }

  Future<PlaybackProgress?> readProgress(String folderPath) async {
    final service = _historyService;
    if (service == null) {
      return null;
    }

    final folder = folderPath.trim();
    if (folder.isEmpty) {
      return null;
    }

    try {
      final entry = await service.fetchByFolder(
        applicationType: _applicationType,
        folderPath: folder,
        preferFresh: true,
      );
      if (entry == null) {
        return null;
      }
      return PlaybackProgress.fromEntry(entry);
    } catch (error) {
      return null;
    }
  }

  Future<void> clearProgress(String folderPath) async {
    final service = _historyService;
    if (service == null) {
      return;
    }

    final folder = folderPath.trim();
    if (folder.isEmpty) {
      return;
    }

    try {
      await service.deleteByFolder(
        applicationType: _applicationType,
        folderPath: folder,
      );
    } catch (error) {
      return;
    }
  }
}
