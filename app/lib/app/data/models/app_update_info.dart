class AppUpdateInfo {
  AppUpdateInfo({
    required this.apkUrl,
    List<String>? apkUrls,
    required this.versionName,
    this.versionCode,
    this.sha256checksum,
    this.artifactKey,
    this.forceUpdate = false,
    this.releaseNotes,
  }) : apkUrls = _normalizeApkUrls(apkUrl, apkUrls);

  final String apkUrl;
  final List<String> apkUrls;
  final String versionName;
  final int? versionCode;
  final String? sha256checksum;
  final String? artifactKey;
  final bool forceUpdate;
  final String? releaseNotes;

  String get displayVersion {
    final version = versionName.trim();
    if (versionCode == null) return version;
    if (version.isEmpty) return versionCode.toString();
    return '$version+$versionCode';
  }

  String buildDestinationFilename({String prefix = 'ohome'}) {
    final safeVersion = versionName.trim().isEmpty
        ? 'latest'
        : versionName.trim().replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final safeArtifact = artifactKey?.trim().isNotEmpty == true
        ? artifactKey!.trim().replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_')
        : null;
    final artifactSuffix = safeArtifact == null ? '' : '_$safeArtifact';
    return '${prefix}_$safeVersion$artifactSuffix.apk';
  }

  static List<String> _normalizeApkUrls(
    String primary,
    List<String>? candidates,
  ) {
    final result = <String>[];
    void append(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty || result.contains(text)) return;
      result.add(text);
    }

    append(primary);
    for (final item in candidates ?? const <String>[]) {
      append(item);
    }
    return List.unmodifiable(result);
  }
}
