import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/app_env.dart';
import '../../../widgets/backend_address_badge.dart';
import '../../../widgets/server_settings_sheet.dart';
import '../controllers/register_controller.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F172A)),
          Positioned(
            top: -140.h,
            right: -50.w,
            child: Container(
              width: 300.w,
              height: 300.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -50.h,
            left: -100.w,
            child: Container(
              width: 250.w,
              height: 250.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: viewInsets.bottom),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80.h, bottom: 24.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32.r),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 340.w,
                            padding: EdgeInsets.fromLTRB(
                              32.w,
                              40.h,
                              32.w,
                              32.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(32.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Obx(
                              () => Form(
                                key: controller.registerFormKey,
                                autovalidateMode:
                                    controller.autoValidateMode.value,
                                child: Column(
                                  children: [
                                    const _Header(),
                                    SizedBox(height: 24.h),
                                    const _CredentialsFields(),
                                    SizedBox(height: 28.h),
                                    const _SubmitButton(),
                                    SizedBox(height: 14.h),
                                    const _BackToLoginButton(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(top: 16.h, left: 24.w, child: const _BackButton()),
                Positioned(
                  top: 16.h,
                  right: 24.w,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller.apiBaseUrlController,
                    builder: (context, value, _) {
                      final address = value.text.trim().isEmpty
                          ? AppEnv.instance.apiBaseUrlInputValue
                          : value.text.trim();
                      return Row(
                        children: [
                          BackendAddressBadge(address: address),
                          SizedBox(width: 12.w),
                          const _SettingsIconButton(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Get.back<void>,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 22.sp, color: Colors.white),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '创建你的家庭账号',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '注册',
                style: TextStyle(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.asset(
              'assets/images/logo.png',
              width: 56.w,
              height: 56.w,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsIconButton extends GetView<RegisterController> {
  const _SettingsIconButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasFoundServer = controller.hasFoundServer;

      return GestureDetector(
        onTap: () => _openServerSettingsSheet(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(
                Icons.settings_rounded,
                size: 22.sp,
                color: Colors.white,
              ),
            ),
            if (hasFoundServer)
              Positioned(
                top: -4.h,
                right: -4.w,
                child: Container(
                  width: 18.w,
                  height: 18.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF21C47B),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: const Color(0xFF1E1E1E),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 10.sp,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _openServerSettingsSheet(BuildContext context) {
    return Get.bottomSheet<void>(
      Obx(
        () => ServerSettingsSheet(
          apiBaseUrlController: controller.apiBaseUrlController,
          servers: controller.discoveredServers,
          errorText: controller.discoveryErrorMessage.value,
          isDiscovering: controller.isDiscovering.value,
          isManualEntryMode: controller.isManualEntryMode.value,
          selectedServer: controller.selectedServer.value,
          onToggleManualEntryMode: controller.toggleManualEntryMode,
          onRefreshDiscovery: controller.refreshDiscovery,
          onSelectServer: (server) {
            controller.selectDiscoveredServer(server);
            Get.back<void>();
          },
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _CredentialsFields extends GetView<RegisterController> {
  const _CredentialsFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller.nameController,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: _fieldDecoration(
            hintText: '设置用户名',
            icon: Icons.person_outline_rounded,
          ),
          validator: controller.validateName,
        ),
        SizedBox(height: 18.h),
        TextFormField(
          controller: controller.passwordController,
          obscureText: true,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: _fieldDecoration(
            hintText: '设置密码',
            icon: Icons.lock_outline_rounded,
          ),
          validator: controller.validatePassword,
        ),
        SizedBox(height: 18.h),
        TextFormField(
          controller: controller.confirmPasswordController,
          obscureText: true,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: _fieldDecoration(
            hintText: '再次输入密码',
            icon: Icons.verified_user_outlined,
          ),
          validator: controller.validateConfirmPassword,
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white54, fontSize: 15.sp),
      prefixIcon: Icon(icon, color: Colors.white54, size: 22.sp),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: AppThemeColors.primary, width: 1.5),
      ),
      errorStyle: TextStyle(color: Colors.redAccent.shade100, fontSize: 12.sp),
    );
  }
}

class _SubmitButton extends GetView<RegisterController> {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final isBusy =
        controller.isLoading.value || controller.isCheckingRegisterStatus.value;
    final isDisabled =
        controller.isLoading.value || controller.isRegisterExplicitlyDisabled;

    return Container(
      width: double.infinity,
      height: 52.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          colors: isDisabled
              ? const [Color(0xFF4B5563), Color(0xFF374151)]
              : const [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isDisabled ? const Color(0xFF4B5563) : const Color(0xFF3B82F6))
                    .withValues(alpha: 0.3),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isDisabled ? null : controller.register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: isBusy
            ? SizedBox(
                width: 24.sp,
                height: 24.sp,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '创建账号',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: Get.back<void>,
        style: TextButton.styleFrom(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            children: const [
              TextSpan(text: '已有账号？ '),
              TextSpan(
                text: '立即登录',
                style: TextStyle(
                  color: AppThemeColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
