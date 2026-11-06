import 'package:ohome/app/utils/http_client.dart';

/// 夸克网盘接口错误提示工具。
///
/// 后端会把夸克官方 API 的错误原样透传（例如 `token [st invalid,code:50051]`），
/// 直接展示给用户既不友好，也无法告诉用户下一步该做什么。
/// 这里集中识别「夸克登录态失效」类错误，并转换成可操作的提示。
///
/// 判定优先使用后端下发的业务原因码（[ApiException.reason]），
/// 文案匹配仅作为老版本后端的兜底，避免后端改文案就让前端分支失效。
class QuarkErrorHelper {
  QuarkErrorHelper._();

  /// 独享模式：用户自己的夸克凭证缺失/失效，可自行重新登录修复。
  static const String reasonLoginRequired = 'QUARK_LOGIN_REQUIRED';

  /// 共享模式：全局夸克凭证缺失/失效，普通用户无法自行修复。
  static const String reasonSharedCredentialUnavailable =
      'QUARK_SHARED_CREDENTIAL_UNAVAILABLE';

  /// 共享模式下尝试维护个人凭证，属于非法请求。
  static const String reasonPersonalCredentialBlocked =
      'QUARK_PERSONAL_CREDENTIAL_BLOCKED';

  static const String authErrorMessage = '夸克登录已失效';
  static const String loginRequiredMessage = '请先登录夸克';
  static const String sharedCredentialMessage = '共享夸克账号未登录或已失效，请联系管理员';

  static const List<String> _loginRequiredMarkers = <String>[
    'quark_login_required',
    '请先登录夸克账号',
    // toFriendlyMessage 转换后的文案（UI 只拿到字符串时仍能识别）
    '请先登录夸克',
  ];

  static const List<String> _sharedCredentialMarkers = <String>[
    'quark_shared_credential_unavailable',
    '共享夸克账号未登录或已失效',
  ];

  static const List<String> _authErrorMarkers = <String>[
    '50051',
    'st invalid',
    'token invalid',
    'token is invalid',
    'invalid token',
    'token失效',
    'token 失效',
    'token过期',
    'token 过期',
    '登录已失效',
    '登录状态已失效',
    '登录状态失效',
    'cookie失效',
    'cookie 失效',
    'cookie过期',
    'cookie 过期',
    '未登录',
    '请先登录',
  ];

  static String? _reasonOf(Object? error) {
    final reason = error is ApiException ? error.reason : null;
    final trimmed = reason?.trim();
    return trimmed?.isNotEmpty == true ? trimmed : null;
  }

  static String _textOf(Object? error) =>
      error?.toString().toLowerCase().trim() ?? '';

  /// 独享模式下用户需要自己重新登录夸克。
  static bool isQuarkLoginRequired(Object? error) {
    final reason = _reasonOf(error);
    if (reason != null) return reason == reasonLoginRequired;
    final text = _textOf(error);
    if (text.isEmpty) return false;
    return _loginRequiredMarkers.any(text.contains);
  }

  /// 共享夸克账号不可用，只能由管理员修复。
  static bool isQuarkSharedCredentialUnavailable(Object? error) {
    final reason = _reasonOf(error);
    if (reason != null) return reason == reasonSharedCredentialUnavailable;
    final text = _textOf(error);
    if (text.isEmpty) return false;
    return _sharedCredentialMarkers.any(text.contains);
  }

  /// 是否为夸克登录态失效（token / cookie 无效或过期）。
  static bool isQuarkAuthError(Object? error) {
    final reason = _reasonOf(error);
    if (reason != null) {
      return reason == reasonLoginRequired ||
          reason == reasonSharedCredentialUnavailable;
    }
    final text = _textOf(error);
    if (text.isEmpty) return false;
    if (isQuarkLoginRequired(text)) return true;
    if (isQuarkSharedCredentialUnavailable(text)) return true;
    return _authErrorMarkers.any(text.contains);
  }

  /// 把原始错误转换为用户能理解的提示。
  ///
  /// 非夸克登录类错误保持原样，避免吞掉后端其它有效错误信息。
  static String toFriendlyMessage(
    Object? error, {
    String fallback = '请求失败，请稍后重试',
  }) {
    final raw = error?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;
    if (isQuarkSharedCredentialUnavailable(error)) {
      return sharedCredentialMessage;
    }
    if (isQuarkLoginRequired(error)) return loginRequiredMessage;
    if (!isQuarkAuthError(error)) return raw;
    return authErrorMessage;
  }
}