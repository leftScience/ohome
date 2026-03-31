import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';

import '../../utils/http_client.dart';
import '../models/app_update_info.dart';

class AppUpdateApi {
  AppUpdateApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<AppUpdateInfo> fetchManifest({required String manifestUrl}) async {
    final candidates = _splitCandidateUrls(manifestUrl);
    if (candidates.isEmpty) {
      throw ApiException('未配置更新地址');
    }
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final Map<String, dynamic>? data = await _httpClient.get(
          candidate,
          decoder: _asMap,
        );
        if (data == null) {
          throw ApiException('更新配置格式错误');
        }
        return await _parseManifest(data);
      } catch (error) {
        lastError = error;
      }
    }
    throw ApiException('拉取更新配置失败：$lastError');
  }

  Future<AppUpdateInfo> _parseManifest(Map<String, dynamic> data) async {
    final payload = _pickPlatformPayload(data);
    final selectedArtifact = await _pickBestAndroidArtifact(payload);
    final sourcePayload = selectedArtifact?.payload ?? payload;
    final apkUrls = _readDownloadUrls(sourcePayload, payload);
    if (apkUrls.isEmpty) {
      throw ApiException('更新配置缺少 apkUrl');
    }
    final apkUrl = apkUrls.first;

    final versionName =
        _readFirstNonEmptyString(sourcePayload, const [
          'versionName',
          'version_name',
          'version',
          'latestVersion',
          'latest_version',
        ]) ??
        _readFirstNonEmptyString(payload, const [
          'versionName',
          'version_name',
          'version',
          'latestVersion',
          'latest_version',
        ]) ??
        '';
    final versionCode =
        _readFirstInt(sourcePayload, const [
          'versionCode',
          'version_code',
          'buildNumber',
          'build_number',
          'build',
        ]) ??
        _readFirstInt(payload, const [
          'versionCode',
          'version_code',
          'buildNumber',
          'build_number',
          'build',
        ]);
    final sha256 =
        _readFirstNonEmptyString(sourcePayload, const [
          'sha256',
          'sha256checksum',
          'checksum',
        ]) ??
        _readFirstNonEmptyString(payload, const [
          'sha256',
          'sha256checksum',
          'checksum',
        ]);
    final releaseNotes =
        _readFirstNonEmptyString(sourcePayload, const [
          'releaseNotes',
          'release_notes',
          'notes',
          'changelog',
        ]) ??
        _readFirstNonEmptyString(payload, const [
          'releaseNotes',
          'release_notes',
          'notes',
          'changelog',
        ]);
    final forceUpdate =
        _readFirstBool(sourcePayload, const [
          'forceUpdate',
          'force_update',
          'force',
        ]) ??
        _readFirstBool(payload, const ['forceUpdate', 'force_update', 'force']);

    return AppUpdateInfo(
      apkUrl: apkUrl,
      apkUrls: apkUrls,
      versionName: versionName,
      versionCode: versionCode,
      sha256checksum: sha256,
      artifactKey: selectedArtifact?.key,
      releaseNotes: releaseNotes,
      forceUpdate: forceUpdate ?? false,
    );
  }

  static Future<_SelectedArtifact?> _pickBestAndroidArtifact(
    Map<String, dynamic> payload,
  ) async {
    final artifacts = _readArtifactEntries(payload);
    if (artifacts.isEmpty) return null;

    final preferredAbis = await _readSupportedAndroidAbis();
    for (final abi in preferredAbis) {
      final artifact = artifacts[abi];
      if (artifact != null && _hasDownloadUrl(artifact)) {
        return _SelectedArtifact(key: abi, payload: artifact);
      }
    }

    for (final entry in artifacts.entries) {
      if (_hasDownloadUrl(entry.value)) {
        return _SelectedArtifact(key: entry.key, payload: entry.value);
      }
    }

    return null;
  }

  static Map<String, Map<String, dynamic>> _readArtifactEntries(
    Map<String, dynamic> payload,
  ) {
    final container =
        _asMap(payload['artifacts']) ??
        _asMap(payload['apks']) ??
        _asMap(payload['packages']);
    if (container == null || container.isEmpty) return const {};

    final result = <String, Map<String, dynamic>>{};
    for (final entry in container.entries) {
      final normalizedKey = _normalizeAbi(entry.key);
      if (normalizedKey == null) continue;
      final value = entry.value;
      final artifact = _artifactPayloadFromValue(value);
      if (artifact == null) continue;
      result[normalizedKey] = artifact;
    }
    return result;
  }

  static Map<String, dynamic>? _artifactPayloadFromValue(dynamic value) {
    if (value is String) {
      final url = value.trim();
      if (url.isEmpty) return null;
      return {'apkUrl': url};
    }
    return _asMap(value);
  }

  static Future<List<String>> _readSupportedAndroidAbis() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final rawAbis = <String>[
        ...androidInfo.supported64BitAbis,
        ...androidInfo.supported32BitAbis,
        ...androidInfo.supportedAbis,
      ];
      final normalized = <String>[];
      for (final abi in rawAbis) {
        final value = _normalizeAbi(abi);
        if (value == null || normalized.contains(value)) continue;
        normalized.add(value);
      }
      if (normalized.isNotEmpty) {
        return normalized;
      }
    } catch (_) {
      // ignore and use fallback order
    }

    return const ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
  }

  static String? _normalizeAbi(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'arm64-v8a':
      case 'aarch64':
        return 'arm64-v8a';
      case 'armeabi-v7a':
      case 'armv7':
      case 'arm-v7a':
        return 'armeabi-v7a';
      case 'x86-64':
      case 'x86_64':
      case 'amd64':
        return 'x86_64';
      case 'x86':
        return 'x86';
      default:
        return normalized.isEmpty ? null : normalized;
    }
  }

  static bool _hasDownloadUrl(Map<String, dynamic> payload) {
    return _readUrlsFromPayload(payload, const [
          'apkUrls',
          'apk_urls',
          'downloadUrls',
          'download_urls',
          'urls',
        ]).isNotEmpty ||
        _readFirstNonEmptyString(payload, const [
              'apkUrl',
              'apk_url',
              'downloadUrl',
              'download_url',
              'url',
            ]) !=
            null;
  }

  static List<String> _readDownloadUrls(
    Map<String, dynamic> sourcePayload,
    Map<String, dynamic> rootPayload,
  ) {
    final result = <String>[];
    void appendAll(Iterable<String> values) {
      for (final value in values) {
        final text = value.trim();
        if (text.isEmpty || result.contains(text)) continue;
        result.add(text);
      }
    }

    appendAll(
      _readUrlsFromPayload(sourcePayload, const [
        'apkUrls',
        'apk_urls',
        'downloadUrls',
        'download_urls',
        'urls',
      ]),
    );
    final sourcePrimary = _readFirstNonEmptyString(sourcePayload, const [
      'apkUrl',
      'apk_url',
      'downloadUrl',
      'download_url',
      'url',
    ]);
    if (sourcePrimary != null) appendAll([sourcePrimary]);

    appendAll(
      _readUrlsFromPayload(rootPayload, const [
        'apkUrls',
        'apk_urls',
        'downloadUrls',
        'download_urls',
        'urls',
      ]),
    );
    final rootPrimary = _readFirstNonEmptyString(rootPayload, const [
      'apkUrl',
      'apk_url',
      'downloadUrl',
      'download_url',
      'url',
    ]);
    if (rootPrimary != null) appendAll([rootPrimary]);

    return result;
  }

  static List<String> _readUrlsFromPayload(
    Map<String, dynamic> value,
    List<String> keys,
  ) {
    final result = <String>[];
    void append(String? raw) {
      final text = raw?.trim();
      if (text == null || text.isEmpty || result.contains(text)) return;
      result.add(text);
    }

    for (final key in keys) {
      final raw = value[key];
      if (raw is String) {
        for (final item in _splitCandidateUrls(raw)) {
          append(item);
        }
        continue;
      }
      if (raw is List) {
        for (final item in raw) {
          if (item is String) append(item);
        }
      }
    }
    return result;
  }

  static List<String> _splitCandidateUrls(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(';', ',')
        .replaceAll('\n', ',');
    final result = <String>[];
    for (final part in normalized.split(',')) {
      final candidate = part.trim();
      if (candidate.isEmpty || result.contains(candidate)) continue;
      result.add(candidate);
    }
    return result;
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

class _SelectedArtifact {
  const _SelectedArtifact({required this.key, required this.payload});

  final String key;
  final Map<String, dynamic> payload;
}
