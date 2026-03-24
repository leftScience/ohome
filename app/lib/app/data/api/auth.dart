import 'package:ohome/app/utils/http_client.dart';
import 'package:ohome/app/data/models/token_pair.dart';
import 'package:ohome/app/data/models/login_result.dart';
import 'package:ohome/app/data/models/register_status.dart';

class AuthApi {
  AuthApi({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<LoginResult> login({required String name, required String password}) {
    return _httpClient.post<LoginResult>(
      'public/login',
      data: <String, dynamic>{'name': name, 'password': password},
      decoder: (data) {
        if (data is Map<String, dynamic>) return LoginResult.fromJson(data);
        throw ApiException('登录响应格式错误');
      },
    );
  }

  Future<TokenPair> refreshToken({required String refreshToken}) {
    return _httpClient.get<TokenPair>(
      'public/refreshToken',
      queryParameters: <String, dynamic>{'token': refreshToken},
      decoder: (data) {
        if (data is Map<String, dynamic>) return TokenPair.fromJson(data);
        throw ApiException('刷新 Token 响应格式错误');
      },
    );
  }

  Future<void> register({required String name, required String password}) {
    return _httpClient.post<void>(
      'public/register',
      data: <String, dynamic>{'name': name, 'password': password},
      decoder: (_) {},
    );
  }

  Future<RegisterStatus> getRegisterStatus() {
    return _httpClient.get<RegisterStatus>(
      'public/register/status',
      showErrorToast: false,
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return RegisterStatus.fromJson(data);
        }
        if (data is Map) {
          return RegisterStatus.fromJson(data.cast<String, dynamic>());
        }
        throw ApiException('注册状态响应格式错误');
      },
    );
  }
}
