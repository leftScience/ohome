import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../../data/models/user_model.dart';
import '../../../data/models/quark_account_status.dart';
import '../../../data/api/user.dart';
import '../../../data/api/quark_account.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../widgets/avatar_crop_sheet.dart';
import '../widgets/change_password_sheet.dart';

class MeController extends GetxController {
  MeController({
    AuthService? authService,
    UserApi? userApi,
    QuarkAccountApi? quarkAccountApi,
    ImagePicker? imagePicker,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _userApi = userApi ?? Get.find<UserApi>(),
       _quarkAccountApi = quarkAccountApi ?? Get.find<QuarkAccountApi>(),
       _imagePicker = imagePicker ?? ImagePicker();

  final AuthService _authService;
  final UserApi _userApi;
  final QuarkAccountApi _quarkAccountApi;
  final ImagePicker _imagePicker;

  final avatarUploading = false.obs;
  final profileUpdating = false.obs;
  final quarkAdminMenuExpanded = false.obs;
  final quarkAccountLoading = false.obs;
  final quarkPreferSaving = false.obs;
  final quarkSystemModeSaving = false.obs;
  final quarkAccountStatus = Rxn<QuarkAccountStatus>();

  Rxn<UserModel> get user => _authService.user;

  bool get isSuperAdmin => user.value?.isSuperAdmin ?? false;

  QuarkAccountStatus get accountStatus =>
      quarkAccountStatus.value ?? QuarkAccountStatus.fallback;

  bool get canOpenQuarkLogin =>
      isSuperAdmin || accountStatus.canManageCredentials;

  @override
  void onInit() {
    super.onInit();
    refreshQuarkAccountStatus();
  }

  Future<void> refreshQuarkAccountStatus() async {
    if (user.value == null) {
      quarkAccountStatus.value = null;
      return;
    }
    quarkAccountLoading.value = true;
    try {
      quarkAccountStatus.value = await _quarkAccountApi.getStatus(
        showErrorToast: false,
      );
    } catch (_) {
      quarkAccountStatus.value = QuarkAccountStatus.fallback;
    } finally {
      quarkAccountLoading.value = false;
    }
  }

  void openUserManagement() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.USER_MANAGEMENT);
  }

  void openServerUpdate() {
    Get.toNamed(Routes.SERVER_UPDATE);
  }

  void openChangePassword() {
    ChangePasswordSheet.show();
  }

  Future<void> openQuarkLogin() async {
    if (!canOpenQuarkLogin) {
      Get.snackbar('提示', '当前共享模式下无需个人夸克登录');
      return;
    }
    await Get.toNamed(Routes.QUARK_LOGIN);
    await refreshQuarkAccountStatus();
  }

  void openQuarkSearchSettings() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.QUARK_SEARCH_SETTINGS);
  }

  void openQuarkStreamSettings() {
    if (!_ensureSuperAdmin()) return;
    Get.toNamed(Routes.QUARK_STREAM_SETTINGS);
  }

  void toggleQuarkAdminMenu() {
    if (!_ensureSuperAdmin()) return;
    quarkAdminMenuExpanded.toggle();
  }

  Future<void> setSystemShareMode(String mode) async {
    if (!_ensureSuperAdmin() || quarkSystemModeSaving.value) return;
    final normalized = mode.trim().toLowerCase();
    if (normalized != 'shared' && normalized != 'exclusive') {
      Get.snackbar('提示', '共享状态无效');
      return;
    }
    if (accountStatus.systemMode == normalized) return;

    quarkSystemModeSaving.value = true;
    try {
      await _quarkAccountApi.setSystemMode(normalized);
      await refreshQuarkAccountStatus();
      Get.snackbar(
        '提示',
        normalized == 'shared' ? '已切换为共享夸克账号' : '已强制全员独享夸克账号',
      );
    } catch (_) {
      return;
    } finally {
      quarkSystemModeSaving.value = false;
    }
  }

  Future<void> setPreferExclusive(bool prefer) async {
    if (quarkPreferSaving.value) return;
    if (!accountStatus.canPreferExclusive) {
      Get.snackbar('提示', '管理员已强制独享，无法修改个人偏好');
      return;
    }
    quarkPreferSaving.value = true;
    try {
      await _quarkAccountApi.setPreferExclusive(prefer);
      await refreshQuarkAccountStatus();
      if (prefer) {
        Get.snackbar('提示', '已开启独享，请登录自己的夸克账号');
        await openQuarkLogin();
      } else {
        Get.snackbar('提示', '已关闭独享，将使用共享夸克数据');
      }
    } catch (_) {
      return;
    } finally {
      quarkPreferSaving.value = false;
    }
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

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (file == null) return;

      final imageBytes = await file.readAsBytes();
      final croppedBytes = await AvatarCropSheet.show(imageBytes: imageBytes);
      if (croppedBytes == null) return;

      final uploadFile = XFile.fromData(
        croppedBytes,
        name: _buildAvatarUploadFileName(file),
        mimeType: 'image/png',
      );

      avatarUploading.value = true;
      await _userApi.uploadAvatar(uploadFile);
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

  bool _ensureSuperAdmin() {
    if (isSuperAdmin) {
      return true;
    }
    Get.snackbar('提示', '仅超级管理员可访问');
    return false;
  }

  String _buildAvatarUploadFileName(XFile sourceFile) {
    final rawName = sourceFile.name.trim().isNotEmpty
        ? sourceFile.name.trim()
        : path.basename(sourceFile.path);
    final baseName = path.basenameWithoutExtension(rawName).trim();
    final normalizedBaseName = baseName.isNotEmpty ? baseName : 'avatar';
    return '${normalizedBaseName}_avatar.png';
  }
}
