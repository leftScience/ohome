import '../../utils/http_client.dart';
import '../models/app_message_list_result.dart';

class AppMessageApi {
  AppMessageApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<AppMessageListResult> getMessageList({
    String? source,
    bool? readOnly,
    int page = 1,
    int limit = 20,
    bool showErrorToast = true,
  }) {
    return _httpClient.post<AppMessageListResult>(
      '/appMessage/list',
      data: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (source?.trim().isNotEmpty ?? false) 'source': source!.trim(),
        'readOnly': ?readOnly,
      },
      showErrorToast: showErrorToast,
      decoder: (data) => AppMessageListResult.fromJson(_asMap(data)),
    );
  }

  Future<void> markMessageRead(int id) {
    return _httpClient.post<void>(
      '/appMessage/read',
      data: <String, dynamic>{'id': id},
      decoder: (_) {},
    );
  }

  Future<void> markAllMessagesRead() {
    return _httpClient.post<void>('/appMessage/readAll', decoder: (_) {});
  }

  Future<void> deleteMessage(int id) {
    return _httpClient.delete<void>('/appMessage/$id', decoder: (_) {});
  }

  Future<void> sendSystemMessage({
    required String title,
    required String content,
  }) {
    return _httpClient.post<void>(
      '/appMessage/sendSystem',
      data: <String, dynamic>{
        'title': title,
        'content': content,
      },
      decoder: (_) {},
    );
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw ApiException('响应格式错误');
  }
}
