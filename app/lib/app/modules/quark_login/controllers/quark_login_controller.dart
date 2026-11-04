import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../data/api/config.dart';
import '../../../data/api/quark_tv_login.dart';
import '../../../data/models/config_model.dart';
import '../../../data/models/config_upsert_payload.dart';
import '../../../data/models/quark_tv_login_status.dart';
import '../views/quark_cookie_web_login_view.dart';
import '../views/quark_tv_qr_login_view.dart';

class QuarkLoginController extends GetxController {
  QuarkLoginController({ConfigApi? configApi, QuarkTvLoginApi? quarkTvLoginApi})
    : _configApi = configApi ?? Get.find<ConfigApi>(),
      _quarkTvLoginApi = quarkTvLoginApi ?? Get.find<QuarkTvLoginApi>();

  static const String _quarkCookiesKey = 'quark_cookies';
  static const String _quarkLogoutUrl =
      'https://pan.quark.cn/account/logout?callback=';
  static const String _quarkWebReferer = 'https://pan.quark.cn/';
  static const String _quarkUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

  final ConfigApi _configApi;
  final QuarkTvLoginApi _quarkTvLoginApi;

  final loading = false.obs;
  final cookieSaving = false.obs;
  final tvLoading = false.obs;
  final cookieConfig = Rxn<ConfigModel>();
  final tvStatus = Rxn<QuarkTvLoginStatus>();

  /// shared=维护全局共享凭证；personal=维护当前用户独享凭证；空则后端按 auto。
  String credentialTarget = '';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      credentialTarget = (args['credentialTarget'] ?? '').toString().trim();
    }
    loadData();
  }

  DateTime? get cookieUpdatedAt => cookieConfig.value?.updatedAt;

  bool get cookieConfigured =>
      cookieConfig.value?.value.trim().isNotEmpty == true;

  DateTime? get tvUpdatedAt => tvStatus.value?.updatedAt;

  bool get tvConfigured => tvStatus.value?.configured == true;

  bool get tvPending => tvStatus.value?.pending == true;

  Future<void> loadData() async {
    loading.value = true;
    try {
      await Future.wait<void>([loadCookieConfig(), loadTvStatus()]);
    } catch (_) {
      return;
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadCookieConfig() async {
    try {
      cookieConfig.value = await _configApi.findConfigByKey(
        _quarkCookiesKey,
        credentialTarget: credentialTarget.isEmpty ? null : credentialTarget,
      );
    } catch (_) {
      cookieConfig.value = null;
    }
  }

  Future<void> loadTvStatus() async {
    try {
      tvStatus.value = await _quarkTvLoginApi.getStatus(
        credentialTarget: credentialTarget.isEmpty ? null : credentialTarget,
        showErrorToast: false,
      );
    } catch (_) {
      tvStatus.value = const QuarkTvLoginStatus(
        configured: false,
        pending: false,
        updatedAt: null,
      );
    }
  }

  Future<void> openWebLogin() async {
    if (cookieSaving.value) return;
    final shouldResetSession = cookieConfigured;
    if (shouldResetSession) {
      await _logoutCurrentCookies();
    }
    final result = await Get.to<String>(
      () => QuarkCookieWebLoginView(resetSessionOnOpen: shouldResetSession),
    );
    final value = result?.trim() ?? '';
    if (value.isEmpty) {
      return;
    }
    await saveCookies(value);
  }

  Future<void> openTvLogin() async {
    if (tvLoading.value) return;
    tvLoading.value = true;
    try {
      final startResult = await _quarkTvLoginApi.startLogin(
        credentialTarget: credentialTarget.isEmpty ? null : credentialTarget,
      );
      if (startResult.qrData.isEmpty) {
        Get.snackbar('提示', '未获取到夸克TV二维码');
        return;
      }
      final success = await Get.to<bool>(
        () => QuarkTvQrLoginView(
          api: _quarkTvLoginApi,
          initialQrData: startResult.qrData,
          credentialTarget: credentialTarget.isEmpty ? null : credentialTarget,
        ),
      );
      await loadTvStatus();
      if (success == true) {
        Get.snackbar('提示', '夸克TV登录成功');
      }
    } catch (_) {
      return;
    } finally {
      tvLoading.value = false;
    }
  }

  Future<void> _logoutCurrentCookies() async {
    final existing = cookieConfig.value;
    final cookie = existing?.value.trim() ?? '';
    if (cookie.isEmpty) {
      return;
    }

    cookieSaving.value = true;
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
          headers: <String, String>{
            'Cookie': cookie,
            'Referer': _quarkWebReferer,
            'User-Agent': _quarkUserAgent,
          },
        ),
      );
      await dio.get<void>(_quarkLogoutUrl);
    } catch (_) {
      // Ignore logout request errors and still clear the locally stored cookie.
    } finally {
      await _clearSavedCookies();
      cookieSaving.value = false;
    }
  }

  Future<void> _clearSavedCookies() async {
    final existing = cookieConfig.value;
    if (existing == null) {
      cookieConfig.value = null;
      return;
    }
    await _configApi.saveConfig(
      ConfigUpsertPayload.fromConfig(
        existing,
        value: '',
        credentialTarget: credentialTarget.isEmpty ? null : credentialTarget,
      ),
    );
    await loadCookieConfig();
  }

  Future<void> saveCookies(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      Get.snackbar('提示', '未检测到可保存的夸克 Cookies');
      return;
    }

    cookieSaving.value = true;
    try {
      final existing = cookieConfig.value;
      final target = credentialTarget.isEmpty ? null : credentialTarget;
      final payload = existing != null
          ? ConfigUpsertPayload.fromConfig(
              existing,
              value: normalized,
              credentialTarget: target,
            )
          : ConfigUpsertPayload(
              name: '夸克cookies',
              key: _quarkCookiesKey,
              value: normalized,
              isLock: '1',
              remark: '',
              credentialTarget: target,
            );
      await _configApi.saveConfig(payload);
      Get.snackbar('提示', '夸克网页登录 Cookies 已保存');
      await loadCookieConfig();
    } catch (_) {
      return;
    } finally {
      cookieSaving.value = false;
    }
  }
}
