import '../../utils/http_client.dart';
import '../models/server_update_models.dart';

class ServerUpdateApi {
  ServerUpdateApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<ServerUpdateInfo> getInfo() {
    return _httpClient.get<ServerUpdateInfo>(
      '/system/update/info',
      decoder: _decodeInfo,
    );
  }

  Future<ServerUpdateCheckResult> check({String channel = 'stable'}) {
    return _httpClient.post<ServerUpdateCheckResult>(
      '/system/update/check',
      data: <String, dynamic>{'channel': channel},
      decoder: _decodeCheck,
    );
  }

  Future<ServerUpdateApplyResult> apply({
    String channel = 'stable',
    String? targetVersion,
  }) {
    return _httpClient.post<ServerUpdateApplyResult>(
      '/system/update/apply',
      data: <String, dynamic>{
        'channel': channel,
        if (targetVersion != null && targetVersion.trim().isNotEmpty)
          'targetVersion': targetVersion.trim(),
      },
      decoder: _decodeApply,
    );
  }

  Future<ServerUpdateTask> getTask(String taskId) {
    return _httpClient.get<ServerUpdateTask>(
      '/system/update/tasks/$taskId',
      decoder: _decodeTask,
    );
  }

  Future<ServerUpdateApplyResult> rollback({String? taskId}) {
    return _httpClient.post<ServerUpdateApplyResult>(
      '/system/update/rollback',
      data: <String, dynamic>{
        if (taskId != null && taskId.trim().isNotEmpty) 'taskId': taskId.trim(),
      },
      decoder: _decodeApply,
    );
  }

  static ServerUpdateInfo _decodeInfo(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ServerUpdateInfo.fromJson(data);
    }
    if (data is Map) {
      return ServerUpdateInfo.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('服务端更新信息响应格式错误');
  }

  static ServerUpdateCheckResult _decodeCheck(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ServerUpdateCheckResult.fromJson(data);
    }
    if (data is Map) {
      return ServerUpdateCheckResult.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('服务端检查更新响应格式错误');
  }

  static ServerUpdateApplyResult _decodeApply(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ServerUpdateApplyResult.fromJson(data);
    }
    if (data is Map) {
      return ServerUpdateApplyResult.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('服务端更新执行响应格式错误');
  }

  static ServerUpdateTask _decodeTask(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ServerUpdateTask.fromJson(data);
    }
    if (data is Map) {
      return ServerUpdateTask.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('服务端更新任务响应格式错误');
  }
}
