import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/user.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_upsert_payload.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class UserManagementFormView extends StatefulWidget {
  const UserManagementFormView({super.key, this.initialUser});

  final UserModel? initialUser;

  @override
  State<UserManagementFormView> createState() => _UserManagementFormViewState();
}

class _UserManagementFormViewState extends State<UserManagementFormView> {
  static const List<_RoleOption> _roleOptions = [
    _RoleOption(code: 'user', label: '普通用户'),
    _RoleOption(code: 'super_admin', label: '超级管理员'),
  ];

  final _formKey = GlobalKey<FormState>();
  final UserApi _userApi = Get.find<UserApi>();
  final AuthService _authService = Get.find<AuthService>();

  late final TextEditingController _nameController;
  late final TextEditingController _realNameController;
  late String _selectedRoleCode;

  bool _submitting = false;

  bool get _isEdit => widget.initialUser != null;

  bool get _isCurrentUser =>
      _isEdit && widget.initialUser?.id == _authService.user.value?.id;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _realNameController = TextEditingController(text: user?.realName ?? '');
    _selectedRoleCode = user?.roleCode.isNotEmpty == true
        ? user!.roleCode
        : 'user';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _realNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(_isEdit ? '编辑角色' : '新增用户')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
            children: [
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: AppThemeColors.surface,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(color: AppThemeColors.border),
                  boxShadow: AppThemeColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEdit ? '修改用户角色' : '创建新用户',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _isEdit
                          ? '这里只保留角色调整，用户名和昵称请到个人资料处修改。'
                          : '新用户密码将使用系统默认密码，创建后可通过“重置密码”再次初始化。',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    if (!_isEdit) ...[
                      _buildField(
                        label: '用户名',
                        controller: _nameController,
                        hintText: '请输入用户名',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入用户名';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      _buildField(
                        label: '昵称',
                        controller: _realNameController,
                        hintText: '请输入昵称',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入昵称';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                    ],
                    _buildRoleField(),
                    if (_isCurrentUser) ...[
                      SizedBox(height: 8.h),
                      Text(
                        '修改当前登录用户角色后，将自动退出并重新登录。',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppThemeColors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: SizedBox(
          height: 52.h,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              disabledBackgroundColor: AppThemeColors.primary.withValues(
                alpha: 0.45,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEdit ? '保存角色' : '创建用户',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '角色',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppThemeColors.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _selectedRoleCode,
          items: _roleOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.code,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null || value.trim().isEmpty) return;
            setState(() {
              _selectedRoleCode = value;
            });
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请选择角色';
            }
            return null;
          },
          dropdownColor: AppThemeColors.surface,
          style: TextStyle(fontSize: 14.sp, color: AppThemeColors.textPrimary),
          iconEnabledColor: AppThemeColors.textSecondary,
          decoration: InputDecoration(
            hintText: '请选择角色',
            hintStyle: TextStyle(
              fontSize: 13.sp,
              color: AppThemeColors.textDisabled,
            ),
            filled: true,
            fillColor: AppThemeColors.surfaceMuted,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppThemeColors.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 13.sp,
              color: AppThemeColors.textDisabled,
            ),
            filled: true,
            fillColor: AppThemeColors.surfaceMuted,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppThemeColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = UserUpsertPayload(
      id: widget.initialUser?.id,
      name: _nameController.text,
      realName: _realNameController.text,
      roleCode: _selectedRoleCode,
      avatar: widget.initialUser?.avatar ?? '',
    );

    setState(() {
      _submitting = true;
    });

    try {
      if (_isEdit) {
        await _userApi.updateManagedUser(payload);
        final currentUserId = _authService.user.value?.id;
        if (currentUserId != null && currentUserId == payload.id) {
          final roleChanged =
              (widget.initialUser?.roleCode ?? '').trim() !=
              payload.roleCode.trim();
          if (roleChanged) {
            await _authService.logout();
            if (!mounted) return;
            Get.offAllNamed(Routes.LOGIN);
            Get.snackbar('提示', '角色已更新，请重新登录');
            return;
          }
          await _authService.saveUser(
            payload.toUserModel(base: widget.initialUser?.raw),
          );
        }
      } else {
        await _userApi.addUser(payload);
      }

      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('提示', _isEdit ? '用户信息已更新' : '用户已创建');
    } catch (_) {
      return;
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _RoleOption {
  const _RoleOption({required this.code, required this.label});

  final String code;
  final String label;
}
