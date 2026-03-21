import 'dart:convert';

import '../../utils/app_env.dart';
import '../../utils/http_client.dart';
import '../models/app_update_info.dart';

class AppUpdateApi {
  AppUpdateApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<AppUpdateInfo> fetchManifest({required String manifestUrl}) async {
    final Map<String, dynamic>? data = await _httpClient.get(
      manifestUrl,
      decoder: _asMap,
    );
    if (data == null) {
      throw ApiException('更新配置格式错误');
    }
    final payload = _pickPlatformPayload(data);
    final apkUrl = _readFirstNonEmptyString(payload, const [
      'apkUrl',
      'apk_url',
      'downloadUrl',
      'download_url',
      'url',
    ]);
    if (apkUrl == null) {
      throw ApiException('更新配置缺少 apkUrl');
    }

    final versionName =
        _readFirstNonEmptyString(payload, const [
          'versionName',
          'version_name',
          'version',
          'latestVersion',
          'latest_version',
        ]) ??
        '';
    final versionCode = _readFirstInt(payload, const [
      'versionCode',
      'version_code',
      'buildNumber',
      'build_number',
      'build',
    ]);
    final sha256 = _readFirstNonEmptyString(payload, const [
      'sha256',
      'sha256checksum',
      'checksum',
    ]);
    final releaseNotes = _readFirstNonEmptyString(payload, const [
      'releaseNotes',
      'release_notes',
      'notes',
      'changelog',
    ]);
    final forceUpdate = _readFirstBool(payload, const [
      'forceUpdate',
      'force_update',
      'force',
    ]);

    return AppUpdateInfo(
      apkUrl: AppEnv.instance.resolveAppUpdateUrl(apkUrl),
      versionName: versionName,
      versionCode: versionCode,
      sha256checksum: sha256,
      releaseNotes: releaseNotes,
      forceUpdate: forceUpdate ?? false,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    }
    if (value is List<int>) {
      final decoded = jsonDecode(utf8.decode(value));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    }
    return null;
  }

  static Map<String, dynamic> _pickPlatformPayload(Map<String, dynamic> value) {
    final android = _asMap(value['android']);
    if (android != null) return android;

    final platforms = _asMap(value['platforms']);
    final platformAndroid = platforms == null
        ? null
        : _asMap(platforms['android']);
    if (platformAndroid != null) return platformAndroid;

    return value;
  }

  static String? _readFirstNonEmptyString(
    Map<String, dynamic> value,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is! String) continue;
      final text = raw.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _readFirstInt(Map<String, dynamic> value, List<String> keys) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool? _readFirstBool(Map<String, dynamic> value, List<String> keys) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final text = raw.trim().toLowerCase();
        if (text == 'true' || text == '1') return true;
        if (text == 'false' || text == '0') return false;
      }
    }
    return null;
  }
}
