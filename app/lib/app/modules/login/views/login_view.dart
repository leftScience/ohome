import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/discovered_server.dart';
import '../../../theme/app_theme.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background base
          Container(color: const Color(0xFF0F172A)),
          // Gradient Orbs
          Positioned(
            top: -100.h,
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
          // Global Blur
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
                              40.h,
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
                                key: controller.loginFormKey,
                                autovalidateMode:
                                    controller.autoValidateMode.value,
                                child: Column(
                                  children: [
                                    const _Header(),
                                    SizedBox(height: 36.h),
                                    const _CredentialsFields(),
                                    SizedBox(height: 48.h),
                                    const _SubmitButton(),
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
                Positioned(
                  top: 16.h,
                  right: 24.w,
                  child: const _SettingsIconButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends GetView<LoginController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '欢迎回来',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '登录',
              style: TextStyle(
                fontSize: 34.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
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

class _SettingsIconButton extends GetView<LoginController> {
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
      const _ServerSettingsSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _ServerSettingsSheet extends GetView<LoginController> {
  const _ServerSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Obx(() {
            final servers = controller.discoveredServers;
            final errorText = controller.discoveryErrorMessage.value;
            final isDiscovering = controller.isDiscovering.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '服务器设置',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: isDiscovering
                          ? null
                          : controller.refreshDiscovery,
                      child: Text(isDiscovering ? '扫描中...' : '重新扫描'),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                if (errorText != null && errorText.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Text(
                      errorText,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.redAccent.shade100,
                      ),
                    ),
                  ),
                if (isDiscovering)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          '正在查找局域网服务...',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isDiscovering && servers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '暂未发现局域网服务，请检查网络后重试，或直接手动输入服务器地址。',
                      style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                    ),
                  ),
                if (servers.isNotEmpty)
                  ...servers.map(
                    (server) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _ServerCard(server: server),
                    ),
                  ),
                SizedBox(height: 12.h),
                Text(
                  '手动地址',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: controller.apiBaseUrlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'http://iosjk.xyz:18090',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16.sp,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 18.h,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18.r),
                      borderSide: BorderSide(color: Colors.grey.shade800),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18.r),
                      borderSide: const BorderSide(
                        color: AppThemeColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ServerCard extends GetView<LoginController> {
  const _ServerCard({required this.server});

  final DiscoveredServer server;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedServer.value;
      final isSelected =
          selected?.instanceId == server.instanceId &&
          selected?.origin == server.origin;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: () {
            controller.selectDiscoveredServer(server);
            Get.back<void>();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppThemeColors.primary.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: isSelected ? AppThemeColors.primary : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        server.serviceName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppThemeColors.primary,
                        size: 18.sp,
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  server.origin,
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _Tag(text: 'v${server.version}'),
                    ...server.sourceLabels.map((label) => _Tag(text: label)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _CredentialsFields extends GetView<LoginController> {
  const _CredentialsFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller.nameController,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: '输入用户名',
            hintStyle: TextStyle(color: Colors.white54, fontSize: 15.sp),
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: Colors.white54,
              size: 22.sp,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(
              vertical: 18.h,
              horizontal: 20.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(
                color: AppThemeColors.primary,
                width: 1.5,
              ),
            ),
            errorStyle: TextStyle(
              color: Colors.redAccent.shade100,
              fontSize: 12.sp,
            ),
          ),
          validator: controller.validateName,
        ),
        SizedBox(height: 20.h),
        TextFormField(
          controller: controller.passwordController,
          obscureText: true,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: '输入密码',
            hintStyle: TextStyle(color: Colors.white54, fontSize: 15.sp),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: Colors.white54,
              size: 22.sp,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(
              vertical: 18.h,
              horizontal: 20.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(
                color: AppThemeColors.primary,
                width: 1.5,
              ),
            ),
            errorStyle: TextStyle(
              color: Colors.redAccent.shade100,
              fontSize: 12.sp,
            ),
          ),
          validator: controller.validatePassword,
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.sp, color: Colors.white70),
      ),
    );
  }
}

class _SubmitButton extends GetView<LoginController> {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF2563EB),
          ], // Primary to slightly darker
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: controller.login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: Obx(
          () => controller.isLoading.value
              ? SizedBox(
                  width: 24.sp,
                  height: 24.sp,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  '立即登录',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}
