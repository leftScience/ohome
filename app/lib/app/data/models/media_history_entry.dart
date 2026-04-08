import '../../utils/media_path.dart';

class MediaHistoryEntry {
  const MediaHistoryEntry({
    this.id,
    this.userId,
    required this.applicationType,
    required this.folderPath,
    required this.itemTitle,
    required this.positionMs,
    required this.durationMs,
    String? itemPath,
    this.coverUrl,
    this.extra,
    this.lastPlayedAt,
  }) : _itemPath = itemPath;

  final int? id;
  final int? userId;
  final String applicationType;
  final String folderPath;
  final String itemTitle;
  final int positionMs;
  final int durationMs;
  final String? coverUrl;
  final Map<String, dynamic>? extra;
  final DateTime? lastPlayedAt;
  final String? _itemPath;

  String get itemPath {
    final direct = MediaPath.normalize(_itemPath);
    if (direct.isNotEmpty) return direct;
    return MediaPath.join(folderPath, itemTitle);
  }

  String get folderTitle => _resolveFolderTitle(folderPath);

  factory MediaHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
      return null;
    }

    Map<String, dynamic>? parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, dynamic val) => MapEntry(key.toString(), val));
      }
      return null;
    }

    String normalizeKey(Object key) {
      return key
          .toString()
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toLowerCase();
    }

    dynamic valueOf(String key) {
      if (json.containsKey(key)) return json[key];
      final target = normalizeKey(key);
      for (final entry in json.entries) {
        if (normalizeKey(entry.key) == target) {
          return entry.value;
        }
      }
      return null;
    }

    final parsedExtra = parseMap(valueOf('extra'));
    final parsedFolderPath = (valueOf('folderPath') as String?)?.trim() ?? '';
    final parsedItemTitle = (valueOf('itemTitle') as String?)?.trim() ?? '';
    final directItemPath = MediaPath.normalize(valueOf('itemPath') as String?);
    final resolvedItemPath = directItemPath.isNotEmpty
        ? directItemPath
        : MediaPath.join(parsedFolderPath, parsedItemTitle);
    final resolvedItemTitle = parsedItemTitle.isNotEmpty
        ? parsedItemTitle
        : MediaPath.title(resolvedItemPath);

    return MediaHistoryEntry(
      id: _parseInt(valueOf('id')),
      userId: _parseInt(valueOf('userId')),
      applicationType: (valueOf('applicationType') as String?)?.trim() ?? '',
      folderPath: parsedFolderPath,
      itemTitle: resolvedItemTitle,
      positionMs: _parseInt(valueOf('positionMs')) ?? 0,
      durationMs: _parseInt(valueOf('durationMs')) ?? 0,
      itemPath: resolvedItemPath.isEmpty ? null : resolvedItemPath,
      coverUrl: (valueOf('coverUrl') as String?)?.trim(),
      extra: parsedExtra,
      lastPlayedAt: parseDate(valueOf('lastPlayedAt')),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'applicationType': applicationType,
      'folderPath': folderPath,
      'itemTitle': itemTitle,
      'itemPath': itemPath,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'coverUrl': coverUrl,
      'extra': extra,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    };
  }

  static String _resolveFolderTitle(String folderPath) {
    final normalized = folderPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return '资源';
    final parts = normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return normalized;
    return parts.last;
  }
}
