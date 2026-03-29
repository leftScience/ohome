import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/http_client.dart';
import '../models/password_status.dart';
import '../models/user_model.dart';
import '../models/user_list_result.dart';
import '../models/user_upsert_payload.dart';

class UserApi {
  UserApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<UserListResult> getUserList({
    String? name,
    int page = 1,
    int limit = 20,
  }) {
    final payload = <String, dynamic>{'page': page, 'limit': limit};
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }

    return _httpClient.post<UserListResult>(
      '/user/list',
      data: payload,
      decoder: _decodeUserListOrThrow,
    );
  }

  Future<UserModel> getUserById(int id) {
    return _httpClient.get<UserModel>('/user/$id', decoder: _decodeUserOrThrow);
  }

  Future<UserModel> getProfile() {
    return _httpClient.get<UserModel>(
      '/user/profile',
      decoder: _decodeUserOrThrow,
    );
  }

  Future<PasswordStatus> getPasswordStatus({bool showErrorToast = true}) {
    return _httpClient.get<PasswordStatus>(
      '/user/password/status',
      showErrorToast: showErrorToast,
      decoder: _decodePasswordStatusOrThrow,
    );
  }

  Future<bool> updateUser(UserModel user) async {
    final id = user.id;
    if (id == null) throw ApiException('用户ID无效');

    await _httpClient.put<dynamic>(
      '/user/$id',
      data: UserUpsertPayload.fromUser(user).toJson(),
    );
    return true;
  }

  Future<void> addUser(UserUpsertPayload payload) {
    return _httpClient.post<void>(
      '/user/add',
      data: payload.toJson(includeId: false),
      decoder: (_) {},
    );
  }

  Future<void> updateManagedUser(UserUpsertPayload payload) {
    final id = payload.id;
    if (id == null) throw ApiException('用户ID无效');
    return _httpClient.put<void>(
      '/user/$id',
      data: payload.toJson(),
      decoder: (_) {},
    );
  }

  Future<void> deleteUser(int id) {
    return _httpClient.delete<void>('/user/$id', decoder: (_) {});
  }

  Future<void> resetPassword(int id) {
    return _httpClient.post<void>(
      '/user/resetPwd',
      data: <String, dynamic>{'id': id},
      decoder: (_) {},
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _httpClient.post<void>(
      '/user/changePwd',
      data: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
      decoder: (_) {},
    );
  }

  Future<bool> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    final fileName = file.name.trim().isNotEmpty ? file.name.trim() : 'avatar';
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    await _httpClient.post<dynamic>(
      '/user/updateAvatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return true;
  }

  static UserModel _decodeUserOrThrow(dynamic data) {
    if (data is Map<String, dynamic>) return UserModel.fromJson(data);
    if (data is Map) {
      return UserModel.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('用户信息响应格式错误');
  }

  static UserListResult _decodeUserListOrThrow(dynamic data) {
    if (data is Map<String, dynamic>) return UserListResult.fromJson(data);
    if (data is Map) {
      return UserListResult.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('用户列表响应格式错误');
  }

  static PasswordStatus _decodePasswordStatusOrThrow(dynamic data) {
    if (data is Map<String, dynamic>) return PasswordStatus.fromJson(data);
    if (data is Map) {
      return PasswordStatus.fromJson(data.cast<String, dynamic>());
    }
    throw ApiException('密码状态响应格式错误');
  }
}
