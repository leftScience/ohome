import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/app_update_info.dart';
import '../../../data/models/user_model.dart';
import '../../../data/api/user.dart';
import '../../../routes/app_pages.dart';
import '../../../services/app_update_service.dart';
import '../../../services/auth_service.dart';

class PluginController extends GetxController {
  PluginController({
    AuthService? authService,
    AppUpdateService? appUpdateService,
    UserApi? userApi,
    ImagePicker? imagePicker,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _appUpdateService = appUpdateService ?? Get.find<AppUpdateService>(),
       _userApi = userApi ?? Get.find<UserApi>(),
       _imagePicker = imagePicker ?? ImagePicker();

  final AuthService _authService;
  final AppUpdateService _appUpdateService;
  final UserApi _userApi;
  final ImagePicker _imagePicker;

  final appUpdateChecking = false.obs;
  final avatarUploading = false.obs;
  final profileUpdating = false.obs;
  final quarkAdminMenuExpanded = false.obs;

  Rxn<UserModel> get user => _authService.user;

  bool get isSuperAdmin => user.value?.isSuperAdmin ?? false;

  void openUserManagement() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.USER_MANAGEMENT);
  }

  void openServerUpdate() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.SERVER_UPDATE);
  }

  void openQuarkLogin() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.QUARK_LOGIN);
  }

  void openQuarkSearchSettings() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.QUARK_SEARCH_SETTINGS);
  }

  void openQuarkStreamSettings() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.QUARK_STREAM_SETTINGS);
  }

  void openQuarkSync() {
    Get.toNamed(Routes.QUARK_SYNC);
  }

  void toggleQuarkAdminMenu() {
    if (!_ensureSuperAdmin()) return;
    quarkAdminMenuExpanded.toggle();
  }

  Future<void> logout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _authService.logout();
    Get.offAllNamed(Routes.LOGIN);
  }

  Future<void> uploadAvatar() async {
    if (avatarUploading.value) return;
    if (user.value == null) {
      Get.snackbar('提示', '请先登录');
      return;
    }

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (file == null) return;

    avatarUploading.value = true;
    try {
      await _userApi.uploadAvatar(file);
      await _authService.refreshProfile();
      Get.snackbar('提示', '头像更新成功');
    } catch (error) {
      Get.snackbar('提示', '头像上传失败：$error');
    } finally {
      avatarUploading.value = false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String realName,
  }) async {
    if (profileUpdating.value) return false;

    final currentUser = user.value;
    if (currentUser == null) {
      Get.snackbar('提示', '请先登录');
      return false;
    }

    final nextName = name.trim();
    final nextRealName = realName.trim();
    if (nextName.isEmpty) {
      Get.snackbar('提示', '请输入用户名');
      return false;
    }
    if (nextRealName.isEmpty) {
      Get.snackbar('提示', '请输入昵称');
      return false;
    }
    if (nextName == currentUser.name && nextRealName == currentUser.realName) {
      Get.snackbar('提示', '资料未发生变化');
      return false;
    }

    profileUpdating.value = true;
    try {
      await _userApi.updateUser(
        currentUser.copyWithRaw({'name': nextName, 'realName': nextRealName}),
      );
      await _authService.refreshProfile();
      Get.snackbar('提示', '资料已更新');
      return true;
    } catch (error) {
      Get.snackbar('提示', '资料更新失败：$error');
      return false;
    } finally {
      profileUpdating.value = false;
    }
  }

  Future<void> checkAppUpdate() async {
    if (appUpdateChecking.value || _appUpdateService.isUpdating.value) return;

    appUpdateChecking.value = true;
    try {
      final result = await _appUpdateService.checkForUpdate();
      switch (result.status) {
        case AppUpdateCheckStatus.disabledInDev:
          Get.snackbar('提示', '开发环境已禁用在线更新');
          return;
        case AppUpdateCheckStatus.unsupported:
          Get.snackbar('提示', '当前平台暂不支持在线更新');
          return;
        case AppUpdateCheckStatus.notConfigured:
          Get.snackbar('提示', '未配置更新地址，请先设置 appUpdateManifestUrl');
          return;
        case AppUpdateCheckStatus.upToDate:
          Get.snackbar('提示', '当前已是最新版本（${result.currentVersion}）');
          return;
        case AppUpdateCheckStatus.available:
          final info = result.info;
          if (info == null) {
            Get.snackbar('提示', '更新信息为空，请稍后重试');
            return;
          }
          await _showUpdateDialog(
            currentVersion: result.currentVersion,
            info: info,
          );
          return;
      }
    } catch (error) {
      Get.snackbar('提示', '检查更新失败：$error');
    } finally {
      appUpdateChecking.value = false;
    }
  }

  Future<void> _showUpdateDialog({
    required String currentVersion,
    required AppUpdateInfo info,
  }) async {
    final notes = (info.releaseNotes ?? '').trim();
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：$currentVersion'),
            const SizedBox(height: 8),
            Text('最新版本：${info.displayVersion}'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新内容：'),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('立即更新'),
          ),
        ],
      ),
      barrierDismissible: !info.forceUpdate,
    );
    if (confirm != true) return;

    await _startOtaUpdate(info);
  }

  Future<void> _startOtaUpdate(AppUpdateInfo info) async {
    Get.dialog<void>(
      PopScope(
        canPop: false,
        child: Obx(() {
          final progress = _appUpdateService.progress.value;
          final statusText = _appUpdateService.statusText.value;
          return AlertDialog(
            title: const Text('正在更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusText.isNotEmpty) Text(statusText),
                const SizedBox(height: 12),
                if (progress != null) ...[
                  LinearProgressIndicator(value: progress / 100),
                  const SizedBox(height: 8),
                  Text('${progress.toStringAsFixed(0)}%'),
                ] else
                  const LinearProgressIndicator(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _appUpdateService.cancelUpdate,
                child: const Text('取消'),
              ),
            ],
          );
        }),
      ),
      barrierDismissible: false,
    );

    try {
      await _appUpdateService.startUpdate(info);
      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
      Get.snackbar('提示', '安装包已准备完成，请按系统提示继续安装');
    } catch (error) {
      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
      Get.snackbar('提示', '$error');
    }
  }

  bool _ensureSuperAdmin() {
    if (isSuperAdmin) {
      return true;
    }
    Get.snackbar('提示', '仅超级管理员可访问');
    return false;
  }
}
