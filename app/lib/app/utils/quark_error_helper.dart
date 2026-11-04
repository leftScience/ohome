/// 夸克网盘接口错误提示工具。
///
/// 后端会把夸克官方 API 的错误原样透传（例如 `token [st invalid,code:50051]`），
/// 直接展示给用户既不友好，也无法告诉用户下一步该做什么。
/// 这里集中识别「夸克登录态失效」类错误，并转换成可操作的提示。
class QuarkErrorHelper {
  QuarkErrorHelper._();

  static const String authErrorMessage = '夸克登录已失效';

      static const String loginRequiredMessage = '请先登录夸克';

  static const List<String> _loginRequiredMarkers = <String>[
    'quark_login_required',
    '请先登录夸克账号',
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

  /// 判断是否为夸克登录态失效（token / cookie 无效或过期）。
  static bool isQuarkLoginRequired(Object? error) {
    final text = error?.toString().toLowerCase().trim() ?? '';
    if (text.isEmpty) return false;
    return _loginRequiredMarkers.any(text.contains);
  }

  static bool isQuarkAuthError(Object? error) {
    final text = error?.toString().toLowerCase().trim() ?? '';
    if (text.isEmpty) return false;
    if (isQuarkLoginRequired(text)) return true;
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
    if (isQuarkLoginRequired(raw)) return loginRequiredMessage;
    if (!isQuarkAuthError(raw)) return raw;
    return authErrorMessage;
  }
}
