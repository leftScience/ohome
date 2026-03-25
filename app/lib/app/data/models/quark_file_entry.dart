import '../../utils/app_env.dart';

class WebdavFileEntry {
  const WebdavFileEntry({
    required this.name,
    required this.path,
    required this.streamUrl,
    required this.isDir,
    required this.size,
    required this.updatedAt,
  });

  final String name;
  final String path;
  final String streamUrl;
  final bool isDir;
  final int size;
  final int updatedAt;

  Uri? resolveStreamUri({String? applicationType}) {
    return _resolveProxyUri(
      rawUrl: streamUrl,
      fallbackPath: path,
      applicationType: applicationType,
    );
  }

  String resolveStreamUrl({String? applicationType}) {
    return resolveStreamUri(applicationType: applicationType)?.toString() ?? '';
  }

  factory WebdavFileEntry.fromJson(Map<String, dynamic> json) {
    return WebdavFileEntry(
      name: (json['name'] as String?)?.trim() ?? '',
      path: (json['path'] as String?)?.trim() ?? '',
      streamUrl: (json['streamUrl'] as String?)?.trim() ?? '',
      isDir: json['isDir'] == true,
      size: _toInt(json['size']),
      updatedAt: _toInt(json['updatedAt']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Uri? _resolveProxyUri({
    required String rawUrl,
    required String fallbackPath,
    String? applicationType,
  }) {
    if (isDir) return null;

    final base = Uri.parse(AppEnv.instance.apiBaseUrl);
    final providedProxyUri = _tryResolveProvidedProxyUri(base, rawUrl);
    if (providedProxyUri != null) {
      return providedProxyUri;
    }

    final normalizedApplication = applicationType?.trim() ?? '';
    if (normalizedApplication.isEmpty) return null;

    final normalizedPath = fallbackPath.trim().isEmpty
        ? '/'
        : fallbackPath.trim();
    final streamPath = _joinPath(
      base.path,
      'public/quarkFs/$normalizedApplication/files/stream',
    );
    return base.replace(
      path: streamPath,
      queryParameters: <String, dynamic>{'path': normalizedPath},
    );
  }

  static Uri? _tryResolveProvidedProxyUri(Uri base, String rawUrl) {
    final trimmedRawUrl = rawUrl.trim();
    if (trimmedRawUrl.isEmpty) return null;

    final uri = Uri.tryParse(trimmedRawUrl);
    if (uri == null) return null;

    final proxyPath = uri.path.trim();
    if (!_isLocalProxyPath(proxyPath)) return null;

    final relative = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final normalizedRelative = relative.startsWith('/')
        ? relative
        : '/$relative';
    return base.resolve(normalizedRelative);
  }

  static bool _isLocalProxyPath(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    return normalized.contains('/public/quarkFs/') &&
        normalized.endsWith('/files/stream');
  }

  static String _joinPath(String basePath, String child) {
    final normalizedBase = basePath.trim();
    if (normalizedBase.isEmpty) return '/$child';
    if (normalizedBase.endsWith('/')) return '$normalizedBase$child';
    return '$normalizedBase/$child';
  }
}
