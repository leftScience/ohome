class QuarkSharePreviewFile {
  const QuarkSharePreviewFile({
    required this.fid,
    required this.fileName,
    required this.isDir,
    required this.size,
    required this.updatedAt,
  });

  final String fid;
  final String fileName;
  final bool isDir;
  final int size;
  final int updatedAt;

  factory QuarkSharePreviewFile.fromJson(Map<String, dynamic> json) {
    return QuarkSharePreviewFile(
      fid: (json['fid'] as String?)?.trim() ?? '',
      fileName: (json['fileName'] as String?)?.trim() ?? '',
      isDir: json['isDir'] == true,
      size: _toInt(json['size']),
      updatedAt: _toInt(json['updatedAt']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class QuarkSharePreviewResult {
  const QuarkSharePreviewResult({
    required this.files,
    required this.pdirFid,
  });

  final List<QuarkSharePreviewFile> files;
  final String pdirFid;

  factory QuarkSharePreviewResult.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = rawFiles is List
        ? rawFiles
              .whereType<Map>()
              .map(
                (item) => QuarkSharePreviewFile.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <QuarkSharePreviewFile>[];
    return QuarkSharePreviewResult(
      files: files,
      pdirFid: (json['pdirFid'] as String?)?.trim() ?? '0',
    );
  }
}