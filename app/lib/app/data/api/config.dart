import '../../utils/http_client.dart';
import '../models/config_model.dart';
import '../models/config_upsert_payload.dart';

class ConfigApi {
  ConfigApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<ConfigModel?> findConfigByKey(
    String key, {
    bool showErrorToast = true,
  }) async {
    final response = await _httpClient.post<Map<String, dynamic>?>(
      '/config/list',
      data: <String, dynamic>{'key': key, 'page': 1, 'limit': 200},
      showErrorToast: showErrorToast,
      decoder: (data) {
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return data.cast<String, dynamic>();
        return null;
      },
    );
    if (response == null) return null;

    final rawRecords = response['records'];
    if (rawRecords is! List) return null;

    for (final item in rawRecords) {
      final config = _decodeConfig(item);
      if (config != null && config.key == key.trim()) {
        return config;
      }
    }
    return null;
  }

  Future<Map<String, ConfigModel>> findConfigsByKeys(
    List<String> keys, {
    bool showErrorToast = true,
  }) async {
    final normalized = keys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) {
      return <String, ConfigModel>{};
    }

    final response = await _httpClient.post<Map<String, dynamic>?>(
      '/config/list',
      data: <String, dynamic>{
        'keys': normalized,
        'page': 1,
        'limit': normalized.length,
      },
      showErrorToast: showErrorToast,
      decoder: (data) {
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return data.cast<String, dynamic>();
        return null;
      },
    );
    if (response == null) return <String, ConfigModel>{};

    final rawRecords = response['records'];
    if (rawRecords is! List) return <String, ConfigModel>{};

    final result = <String, ConfigModel>{};
    for (final item in rawRecords) {
      final config = _decodeConfig(item);
      if (config == null || config.key.isEmpty) continue;
      result[config.key] = config;
    }
    return result;
  }

  Future<void> saveConfig(ConfigUpsertPayload payload) {
    return _httpClient.put<void>(
      '/config/add',
      data: payload.toJson(),
      decoder: (_) {},
    );
  }

  static ConfigModel? _decodeConfig(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ConfigModel.fromJson(data);
    }
    if (data is Map) {
      return ConfigModel.fromJson(data.cast<String, dynamic>());
    }
    return null;
  }
}
