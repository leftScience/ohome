import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/storage/app_env_storage.dart';

enum AppEnvironment {
  dev,
  prod;

  static AppEnvironment fromName(String value) {
    switch (value.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      default:
        return AppEnvironment.dev;
    }
  }
}

class AppEnv {
  AppEnv._({
    required this.environment,
    required String apiBaseUrl,
    required this.rawAppUpdateManifestUrl,
    this.appUpdateUrlProxyPrefix,
    this.appUpdateUsePackageInstaller = false,
    AppEnvStorage? storage,
  }) : _apiBaseUrl = apiBaseUrl,
       _storage = storage ?? AppEnvStorage();

  final String environment;
  final String? rawAppUpdateManifestUrl;
  final String? appUpdateUrlProxyPrefix;
  final bool appUpdateUsePackageInstaller;
  final AppEnvStorage _storage;

  String _apiBaseUrl;

  String get apiBaseUrl => _apiBaseUrl;

  String get apiBaseUrlInputValue {
    final uri = Uri.parse(_apiBaseUrl);
    final pathSegments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.length == 2 &&
        pathSegments[0] == 'api' &&
        pathSegments[1] == 'v1') {
      return apiServerOrigin;
    }
    return _apiBaseUrl.endsWith('/')
        ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
        : _apiBaseUrl;
  }

  String get apiServerOrigin {
    final uri = Uri.parse(_apiBaseUrl);
    final portText = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portText';
  }

  String? get appUpdateManifestUrl {
    final resolved = _resolveConfiguredUrl(rawAppUpdateManifestUrl);
    if (resolved == null || resolved.isEmpty) return null;
    return resolveAppUpdateUrl(resolved);
  }

  String resolveAppUpdateUrl(String value) {
    final resolved = _resolveConfiguredUrl(value) ?? value.trim();
    final proxyPrefix = _normalizedAppUpdateUrlProxyPrefix;
    if (resolved.isEmpty || proxyPrefix == null) return resolved;

    final uri = Uri.tryParse(resolved);
    if (uri == null || !_isGitHubHost(uri.host)) {
      return resolved;
    }

    return '$proxyPrefix$resolved';
  }

  static AppEnv? _instance;

  static AppEnv get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('AppEnv 未初始化，请在 runApp 之前调用 AppEnv.init()');
    }
    return instance;
  }

  static AppEnvironment get currentEnvironment => AppEnvironment.fromName(
    const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
  );

  static Future<void> init() async {
    if (_instance != null) return;

    final environment = currentEnvironment;
    final assetPath = 'assets/env/${environment.name}.json';
    final asset = await rootBundle.loadString(assetPath);
    final map = jsonDecode(asset);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('配置文件格式错误：根节点必须是 JSON Object');
    }

    final apiBaseUrlValue = map['apiBaseUrl'];
    if (apiBaseUrlValue is! String || apiBaseUrlValue.trim().isEmpty) {
      throw const FormatException('配置文件格式错误：apiBaseUrl 缺失');
    }
    final defaultApiBaseUrl = normalizeApiBaseUrlInput(apiBaseUrlValue);

    final storage = AppEnvStorage();
    var effectiveApiBaseUrl = defaultApiBaseUrl;
    final savedApiBaseUrl = await storage.readApiBaseUrlOverride();
    if (savedApiBaseUrl != null) {
      try {
        effectiveApiBaseUrl = normalizeApiBaseUrlInput(savedApiBaseUrl);
      } on FormatException {
        await storage.clearApiBaseUrlOverride();
      }
    }

    String? appUpdateManifestUrl;
    final updateManifestValue = map['appUpdateManifestUrl'];
    if (updateManifestValue is String &&
        updateManifestValue.trim().isNotEmpty) {
      appUpdateManifestUrl = updateManifestValue.trim();
    }

    String? appUpdateUrlProxyPrefix;
    final updateUrlProxyValue = map['appUpdateUrlProxyPrefix'];
    if (updateUrlProxyValue is String &&
        updateUrlProxyValue.trim().isNotEmpty) {
      appUpdateUrlProxyPrefix = updateUrlProxyValue.trim();
    }

    var appUpdateUsePackageInstaller = false;
    final packageInstallerValue = map['appUpdateUsePackageInstaller'];
    if (packageInstallerValue is bool) {
      appUpdateUsePackageInstaller = packageInstallerValue;
    } else if (packageInstallerValue is String) {
      final normalized = packageInstallerValue.trim().toLowerCase();
      appUpdateUsePackageInstaller = normalized == 'true' || normalized == '1';
    }

    _instance = AppEnv._(
      environment: environment.name,
      apiBaseUrl: effectiveApiBaseUrl,
      rawAppUpdateManifestUrl: appUpdateManifestUrl,
      appUpdateUrlProxyPrefix: appUpdateUrlProxyPrefix,
      appUpdateUsePackageInstaller: appUpdateUsePackageInstaller,
      storage: storage,
    );
  }

  Future<void> updateApiBaseUrl(String value) async {
    final normalized = normalizeApiBaseUrlInput(value);
    _apiBaseUrl = normalized;
    await _storage.writeApiBaseUrlOverride(normalized);
  }

  static String normalizeApiBaseUrlInput(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      throw const FormatException('请输入服务器地址');
    }

    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      throw const FormatException('服务器地址格式错误');
    }

    final scheme = uri.scheme.trim().toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const FormatException('服务器地址必须以 http:// 或 https:// 开头');
    }

    if (uri.query.trim().isNotEmpty || uri.fragment.trim().isNotEmpty) {
      throw const FormatException('服务器地址不能包含参数或锚点');
    }

    final pathSegments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: true);
    if (pathSegments.isEmpty) {
      pathSegments.addAll(const <String>['api', 'v1']);
    }

    final normalized = uri.replace(pathSegments: pathSegments).toString();
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  String? _resolveConfiguredUrl(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('/')) return raw;
    return '$apiBaseUrl${raw.substring(1)}';
  }

  String? get _normalizedAppUpdateUrlProxyPrefix {
    final raw = appUpdateUrlProxyPrefix?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.endsWith('/') ? raw : '$raw/';
  }

  bool _isGitHubHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'github.com' ||
        normalized == 'www.github.com' ||
        normalized == 'raw.githubusercontent.com' ||
        normalized.endsWith('.githubusercontent.com');
  }
}
