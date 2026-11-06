import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:ohome/app/utils/app_env.dart';
import 'package:ohome/app/utils/common_utils.dart';
import 'package:ohome/app/utils/http_interceptor.dart';
import 'package:ohome/app/utils/quark_error_helper.dart';

class HttpClient {
  HttpClient._(this._dio);
  static HttpClient? _instance;

  static HttpClient get instance {
    final client = _instance;

    if (client != null) return client;

    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.instance.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: 50000),
        receiveTimeout: const Duration(milliseconds: 50000),
        sendTimeout: const Duration(milliseconds: 50000),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(HttpInterceptor(dio));

    _instance = HttpClient._(dio);
    return _instance!;
  }

  static void syncBaseUrl() {
    final client = _instance;
    if (client == null) return;
    client._dio.options.baseUrl = AppEnv.instance.apiBaseUrl;
  }

  final Dio _dio;

  Future<T> request<T>(
    String path, {
    required String method,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool showErrorToast = true,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    T Function(dynamic data)? decoder,
  }) async {
    try {
      final response = await _dio.request(
        _normalizePath(path),
        data: data,
        queryParameters: queryParameters,
        options: _mergeOptions(options, method),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      final result = _unwrapBusinessResponse(response.data);
      if (decoder != null) return decoder(result);
      return result as T;
    } on DioException catch (e) {
      final error = ApiException(
        _dioExceptionMessage(e),
        code: e.response?.statusCode,
        reason: _dioExceptionReason(e),
      );
      _maybeToastError(error, showErrorToast);
      throw error;
    } on ApiException catch (e) {
      _maybeToastError(e, showErrorToast);
      rethrow;
    } catch (e) {
      final error = ApiException(e.toString());
      _maybeToastError(error, showErrorToast);
      throw error;
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool showErrorToast = true,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    T Function(dynamic data)? decoder,
  }) {
    return request<T>(
      path,
      method: 'GET',
      queryParameters: queryParameters,
      showErrorToast: showErrorToast,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      decoder: decoder,
    );
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool showErrorToast = true,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    T Function(dynamic data)? decoder,
  }) {
    return request<T>(
      path,
      method: 'POST',
      data: data,
      queryParameters: queryParameters,
      showErrorToast: showErrorToast,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      decoder: decoder,
    );
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool showErrorToast = true,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    T Function(dynamic data)? decoder,
  }) {
    return request<T>(
      path,
      method: 'PUT',
      data: data,
      queryParameters: queryParameters,
      showErrorToast: showErrorToast,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      decoder: decoder,
    );
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool showErrorToast = true,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    T Function(dynamic data)? decoder,
  }) {
    return request<T>(
      path,
      method: 'PATCH',
      data: data,
      queryParameters: queryParameters,
      showErrorToast: showErrorToast,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      decoder: decoder,
    );
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool showErrorToast = true,
    Options? options,
    CancelToken? cancelToken,
    T Function(dynamic data)? decoder,
  }) {
    return request<T>(
      path,
      method: 'DELETE',
      data: data,
      queryParameters: queryParameters,
      showErrorToast: showErrorToast,
      options: options,
      cancelToken: cancelToken,
      decoder: decoder,
    );
  }

  static dynamic _unwrapBusinessResponse(dynamic body) {
    if (body is! Map<String, dynamic>) return body;
    if (!body.containsKey('code')) return body;

    final code = CommonUtils.toInt(body['code']);
    final msg = (body['msg'] as String?)?.trim();
    if (code != null && code != 200) {
      throw ApiException(
        msg?.isNotEmpty == true ? msg! : '请求失败',
        code: code,
        reason: _businessReason(body),
      );
    }

    return body['data'];
  }

  /// 后端响应体顶层的机器可读原因码（如 QUARK_LOGIN_REQUIRED）。
  static String? _businessReason(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final reason = body['reason'];
    if (reason is String && reason.trim().isNotEmpty) return reason.trim();
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final errorCode = data['errorCode'];
      if (errorCode is String && errorCode.trim().isNotEmpty) {
        return errorCode.trim();
      }
    }
    return null;
  }

  static String? _dioExceptionReason(DioException e) {
    return _businessReason(e.response?.data);
  }

  static String _dioExceptionMessage(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final msg = responseData['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return e.message?.trim().isNotEmpty == true ? e.message!.trim() : '网络请求失败';
  }

  static void _maybeToastError(Object error, bool showErrorToast) {
    if (!showErrorToast) return;
    _toastError(error);
  }

  static void _toastError(Object error) {
    final text = QuarkErrorHelper.toFriendlyMessage(error);
    if (text.isEmpty) return;
    if (Get.overlayContext == null) return;

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    Get.snackbar('提示', text, duration: const Duration(seconds: 2));
  }

  static Options _mergeOptions(Options? options, String method) {
    final merged = options ?? Options();
    return merged.copyWith(method: method);
  }

  static String _normalizePath(String path) {
    if (path.isEmpty) return path;
    final lower = path.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return path;
    }
    return path.startsWith('/') ? path.substring(1) : path;
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.reason});

  final String message;
  final int? code;

  /// 后端业务原因码，用于前端做分支判断（不要靠中文文案匹配）。
  final String? reason;

  @override
  String toString() => message;
}
