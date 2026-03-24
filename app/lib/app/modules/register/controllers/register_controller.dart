import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ohome/app/data/models/discovered_server.dart';
import 'package:ohome/app/services/discovery_service.dart';
import 'package:ohome/app/utils/app_env.dart';
import 'package:ohome/app/utils/http_client.dart';

import '../../../services/auth_service.dart';

class RegisterController extends GetxController {
  RegisterController({required DiscoveryService discoveryService})
    : _discoveryService = discoveryService;

  final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();
  final DiscoveryService _discoveryService;

  final autoValidateMode = AutovalidateMode.disabled.obs;

  late TextEditingController apiBaseUrlController;
  late TextEditingController nameController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  final isLoading = false.obs;
  final isCheckingRegisterStatus = false.obs;
  final isDiscovering = false.obs;
  final isManualEntryMode = true.obs;
  final registerEnabled = RxnBool();
  final registerStatusMessage = RxnString();
  final discoveryErrorMessage = RxnString();
  final discoveredServers = <DiscoveredServer>[].obs;
  final selectedServer = Rxn<DiscoveredServer>();

  var _manualApiBaseUrlEdited = false;
  var _isApplyingSelection = false;
  var _hasUserSelectedServer = false;
  var _discoveryRequestVersion = 0;

  @override
  void onInit() {
    super.onInit();
    apiBaseUrlController = TextEditingController(
      text: AppEnv.instance.apiBaseUrlInputValue,
    );
    apiBaseUrlController.addListener(_handleApiBaseUrlChanged);
    nameController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    Future<void>.microtask(refreshRegisterStatus);
  }

  String? validateApiBaseUrl(String? value) {
    try {
      AppEnv.normalizeApiBaseUrlInput(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message.toString();
    }
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入用户名';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请再次输入密码';
    }
    if (value != passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  bool get hasFoundServer =>
      selectedServer.value != null || discoveredServers.isNotEmpty;

  bool get isRegisterExplicitlyDisabled => registerEnabled.value == false;

  Future<void> register() async {
    autoValidateMode.value = AutovalidateMode.onUserInteraction;
    final apiBaseUrlInput = _prepareApiBaseUrlInput(showSnackbar: true);
    if (apiBaseUrlInput == null) {
      return;
    }

    if (!registerFormKey.currentState!.validate()) {
      return;
    }

    try {
      isLoading.value = true;
      await _syncApiBaseUrl(apiBaseUrlInput);
      final status = await refreshRegisterStatus(showSnackbarOnFailure: true);
      if (status != true) {
        return;
      }

      final auth = Get.find<AuthService>();
      await auth.register(
        name: nameController.text.trim(),
        password: passwordController.text,
      );
      await _rememberSuccessfulServer();
      Get.snackbar('提示', '注册成功，请登录', duration: const Duration(seconds: 2));
      Get.back<String>(result: nameController.text.trim());
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool?> refreshRegisterStatus({
    bool showSnackbarOnFailure = false,
  }) async {
    final apiBaseUrlInput = _prepareApiBaseUrlInput(
      showSnackbar: showSnackbarOnFailure,
    );
    if (apiBaseUrlInput == null) {
      registerEnabled.value = null;
      registerStatusMessage.value = '请先设置地址';
      return null;
    }

    try {
      isCheckingRegisterStatus.value = true;
      registerStatusMessage.value = null;
      await _syncApiBaseUrl(apiBaseUrlInput);
      final status = await Get.find<AuthService>().getRegisterStatus();
      registerEnabled.value = status.enabled;
      registerStatusMessage.value = status.enabled ? '可注册' : '未开放注册';
      return status.enabled;
    } catch (error) {
      registerEnabled.value = null;
      registerStatusMessage.value = error.toString();
      if (showSnackbarOnFailure) {
        Get.snackbar(
          '提示',
          error.toString(),
          duration: const Duration(seconds: 2),
        );
      }
      return null;
    } finally {
      isCheckingRegisterStatus.value = false;
    }
  }

  Future<void> refreshDiscovery() async {
    if (isManualEntryMode.value) {
      isDiscovering.value = false;
      discoveryErrorMessage.value = null;
      return;
    }

    final requestVersion = ++_discoveryRequestVersion;
    try {
      isDiscovering.value = true;
      discoveryErrorMessage.value = null;

      final servers = await _discoveryService.discoverServers();
      if (_shouldIgnoreDiscoveryResult(requestVersion)) {
        return;
      }
      discoveredServers.assignAll(servers);

      final selected = selectedServer.value;
      if (selected != null) {
        final stillExists = servers.any(
          (server) =>
              server.instanceId == selected.instanceId &&
              server.origin == selected.origin,
        );
        if (!stillExists) {
          selectedServer.value = null;
        }
      }

      if (servers.isEmpty) {
        return;
      }

      if (servers.length == 1 &&
          !_manualApiBaseUrlEdited &&
          !_hasUserSelectedServer) {
        _applySelectedServer(servers.first, userInitiated: false);
        return;
      }

      if (_manualApiBaseUrlEdited || _hasUserSelectedServer) {
        return;
      }
    } catch (error) {
      if (_shouldIgnoreDiscoveryResult(requestVersion)) {
        return;
      }
      discoveryErrorMessage.value = error.toString();
    } finally {
      if (!_shouldIgnoreDiscoveryResult(requestVersion)) {
        isDiscovering.value = false;
      }
    }
  }

  void selectDiscoveredServer(DiscoveredServer server) {
    _applySelectedServer(server, userInitiated: true);
    Future<void>.microtask(refreshRegisterStatus);
  }

  void toggleManualEntryMode(bool enabled) {
    if (enabled == isManualEntryMode.value) {
      return;
    }

    isManualEntryMode.value = enabled;
    _discoveryRequestVersion++;

    if (enabled) {
      isDiscovering.value = false;
      discoveryErrorMessage.value = null;
      discoveredServers.clear();
      selectedServer.value = null;
      _hasUserSelectedServer = false;
      _manualApiBaseUrlEdited = true;
      registerEnabled.value = null;
      registerStatusMessage.value = '地址已变更';
      return;
    }

    _hasUserSelectedServer = false;
    _manualApiBaseUrlEdited = false;
    selectedServer.value = null;
    Future<void>.microtask(refreshDiscovery);
  }

  void _applySelectedServer(
    DiscoveredServer server, {
    required bool userInitiated,
  }) {
    selectedServer.value = server;
    _isApplyingSelection = true;
    apiBaseUrlController.text = server.origin;
    _isApplyingSelection = false;
    if (userInitiated) {
      _manualApiBaseUrlEdited = false;
      _hasUserSelectedServer = true;
    }
  }

  void _handleApiBaseUrlChanged() {
    if (_isApplyingSelection) {
      return;
    }

    final current = apiBaseUrlController.text.trim();
    final selected = selectedServer.value;
    if (selected != null && current == selected.origin) {
      return;
    }

    _manualApiBaseUrlEdited = true;
    _hasUserSelectedServer = false;
    selectedServer.value = null;
    registerEnabled.value = null;
    registerStatusMessage.value = '地址已变更';
  }

  bool _shouldIgnoreDiscoveryResult(int requestVersion) {
    return isManualEntryMode.value ||
        requestVersion != _discoveryRequestVersion;
  }

  String? _prepareApiBaseUrlInput({required bool showSnackbar}) {
    if (isManualEntryMode.value) {
      final apiBaseUrlError = validateApiBaseUrl(apiBaseUrlController.text);
      if (apiBaseUrlError != null) {
        if (showSnackbar) {
          Get.snackbar(
            '提示',
            apiBaseUrlError,
            duration: const Duration(seconds: 2),
          );
        }
        return null;
      }
      return apiBaseUrlController.text.trim();
    }

    final selected = selectedServer.value;
    if (selected == null) {
      if (showSnackbar) {
        Get.snackbar(
          '提示',
          '请先选择扫描到的服务器，或打开手动输入',
          duration: const Duration(seconds: 2),
        );
      }
      return null;
    }

    _isApplyingSelection = true;
    apiBaseUrlController.text = selected.origin;
    _isApplyingSelection = false;
    return apiBaseUrlController.text.trim();
  }

  Future<void> _syncApiBaseUrl(String apiBaseUrlInput) async {
    await AppEnv.instance.updateApiBaseUrl(apiBaseUrlInput);
    HttpClient.syncBaseUrl();
  }

  Future<void> _rememberSuccessfulServer() {
    return _discoveryService.rememberSuccessfulServer(
      apiBaseUrlInput: apiBaseUrlController.text,
      selectedServer: selectedServer.value,
    );
  }

  @override
  void onClose() {
    apiBaseUrlController.removeListener(_handleApiBaseUrlChanged);
    apiBaseUrlController.dispose();
    nameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
