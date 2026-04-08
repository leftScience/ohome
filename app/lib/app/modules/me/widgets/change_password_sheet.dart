import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({
    super.key,
    this.initialOldPassword,
    this.lockOldPassword = false,
    this.title = '修改密码',
    this.description = '更新当前账号的登录密码',
    this.submitLabel = '保存',
  });

  final String? initialOldPassword;
  final bool lockOldPassword;
  final String title;
  final String description;
  final String submitLabel;

  static Future<bool?> show({
    String? initialOldPassword,
    bool lockOldPassword = false,
    String title = '修改密码',
    String description = '更新当前账号的登录密码',
    String submitLabel = '保存',
  }) {
    return Get.bottomSheet<bool>(
      ChangePasswordSheet(
        initialOldPassword: initialOldPassword,
        lockOldPassword: lockOldPassword,
        title: title,
        description: description,
        submitLabel: submitLabel,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _oldPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  var _submitting = false;
  var _obscureOldPassword = true;
  var _obscureNewPassword = true;
  var _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _oldPasswordController = TextEditingController(
      text: widget.initialOldPassword ?? '',
    );
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _effectiveOldPassword {
    return widget.lockOldPassword
        ? (widget.initialOldPassword ?? '')
        : _oldPasswordController.text;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    try {
      await Get.find<AuthService>().changePassword(
        oldPassword: _effectiveOldPassword,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('提示', '密码修改成功', duration: const Duration(seconds: 2));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(height: 20.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppThemeColors.primary.withValues(alpha: 0.18),
                        AppThemeColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46.w,
                        height: 46.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.lockOldPassword) ...[
                  SizedBox(height: 16.h),
                ] else ...[
                  SizedBox(height: 18.h),
                  _PasswordField(
                    label: '当前密码',
                    controller: _oldPasswordController,
                    hintText: '请输入当前密码',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureOldPassword,
                    onToggleObscure: () {
                      setState(() {
                        _obscureOldPassword = !_obscureOldPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入当前密码';
                      }
                      return null;
                    },
                  ),
                ],
                SizedBox(height: 14.h),
                _PasswordField(
                  label: '新密码',
                  controller: _newPasswordController,
                  hintText: '请输入新密码',
                  icon: Icons.password_rounded,
                  obscureText: _obscureNewPassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                  validator: (value) {
                    final nextPassword = value ?? '';
                    if (nextPassword.isEmpty) {
                      return '请输入新密码';
                    }
                    if (nextPassword == _effectiveOldPassword &&
                        _effectiveOldPassword.isNotEmpty) {
                      return '新密码不能与当前密码相同';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 14.h),
                _PasswordField(
                  label: '确认新密码',
                  controller: _confirmPasswordController,
                  hintText: '请再次输入新密码',
                  icon: Icons.task_alt_rounded,
                  obscureText: _obscureConfirmPassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请再次输入新密码';
                    }
                    if (value != _newPasswordController.text) {
                      return '两次输入的新密码不一致';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 22.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Get.back<void>(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(50.h),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(50.h),
                          backgroundColor: AppThemeColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: _submitting
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.submitLabel,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.obscureText,
    required this.onToggleObscure,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          style: TextStyle(fontSize: 14.sp, color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 13.sp, color: Colors.white38),
            prefixIcon: Icon(icon, color: Colors.white38, size: 20.w),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                size: 20.w,
                color: Colors.white38,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFF111111),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}
