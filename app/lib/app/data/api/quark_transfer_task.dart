import '../../utils/http_client.dart';
import '../models/quark_transfer_task_list_result.dart';

class QuarkTransferTaskApi {
  QuarkTransferTaskApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<QuarkTransferTaskListResult> getTaskList({
    String? keyword,
    String? status,
    String? sourceType,
    int page = 1,
    int limit = 20,
    bool showErrorToast = true,
  }) {
    final payload = <String, dynamic>{'page': page, 'limit': limit};
    if (keyword != null && keyword.trim().isNotEmpty) {
      payload['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      payload['status'] = status.trim();
    }
    if (sourceType != null && sourceType.trim().isNotEmpty) {
      payload['sourceType'] = sourceType.trim();
    }

    return _httpClient.post<QuarkTransferTaskListResult>(
      '/quarkTransferTask/list',
      data: payload,
      showErrorToast: showErrorToast,
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return QuarkTransferTaskListResult.fromJson(data);
        }
        if (data is Map) {
          return QuarkTransferTaskListResult.fromJson(
            data.cast<String, dynamic>(),
          );
        }
        throw ApiException('转存任务列表响应格式错误');
      },
    );
  }

  Future<void> deleteTask(int id) {
    return _httpClient.delete<void>('/quarkTransferTask/$id', decoder: (_) {});
  }
}
