import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';

import '../../../data/models/user_model.dart';
import '../../../theme/app_theme.dart';
import '../controllers/plugin_controller.dart';

class PluginView extends GetView<PluginController> {
  const PluginView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 108.h;

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220.h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeColors.primary.withValues(alpha: 0.32),
                    AppThemeColors.secondary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, bottomInset),
            children: [
              Text(
                '设置',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20.h),
              _buildProfileCard(),
              SizedBox(height: 24.h),
              Text(
                '基础管理',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(() {
                final isSuperAdmin = controller.isSuperAdmin;
                return Column(
                  children: [
                    if (isSuperAdmin) ...[
                      _SettingsMenuCard(
                        icon: Icons.group_outlined,
                        iconColor: const Color(0xFF80CBC4),
                        title: '用户管理',
                        subtitle: '新增、编辑、删除、重置密码',
                        onTap: controller.openUserManagement,
                      ),
                      SizedBox(height: 12.h),
                      _QuarkAdminMenuCard(
                        expanded: controller.quarkAdminMenuExpanded.value,
                        onTap: controller.toggleQuarkAdminMenu,
                        onLoginTap: controller.openQuarkLogin,
                        onSearchTap: controller.openQuarkSearchSettings,
                        onStreamTap: controller.openQuarkStreamSettings,
                      ),
                      SizedBox(height: 12.h),
                    ],
                    _SettingsMenuCard(
                      icon: Icons.sync_alt_rounded,
                      iconColor: const Color(0xFF81C784),
                      title: '夸克同步',
                      subtitle: '管理夸克自动转存同步任务',
                      onTap: controller.openQuarkSync,
                    ),
                  ],
                );
              }),
              SizedBox(height: 24.h),
              Text(
                '系统',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 12.h),
              _SettingsMenuCard(
                icon: Icons.lock_reset_rounded,
                iconColor: const Color(0xFFFFB74D),
                title: '修改密码',
                subtitle: '更新当前账号的登录密码',
                onTap: controller.openChangePassword,
              ),
              SizedBox(height: 12.h),
              Obx(
                () => _SettingsMenuCard(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF64B5F6),
                  title: '关于 oHome',
                  subtitle: controller.isSuperAdmin
                      ? '项目介绍、联系方式与 App / 服务端更新'
                      : '项目介绍、联系方式与 App 更新',
                  onTap: controller.openServerUpdate,
                ),
              ),
              SizedBox(height: 12.h),
              _SettingsMenuCard(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFE57373),
                title: '退出登录',
                subtitle: '退出当前账号并返回登录页',
                onTap: controller.logout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Obx(() {
      final user = controller.user.value;
      final uploading = controller.avatarUploading.value;
      final name = user?.realName.isNotEmpty == true
          ? user!.realName
          : user?.name ?? '未登录';
      final subTitle = user?.roleName.isNotEmpty == true
          ? user!.roleName
          : '移动端设置中心';
      final avatarUrl = user?.avatarUrl ?? '';
      final avatarText = user?.name.isNotEmpty == true
          ? user!.name.substring(0, 1).toUpperCase()
          : 'SZ';

      return Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: uploading ? null : controller.uploadAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: AppThemeColors.primary.withValues(
                      alpha: 0.16,
                    ),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            avatarText,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2.w,
                    bottom: -2.h,
                    child: Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Center(
                        child: uploading
                            ? SizedBox(
                                width: 10.w,
                                height: 10.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt_rounded,
                                size: 12.w,
                                color: Colors.white70,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                  ),
                  if (user != null) ...[
                    SizedBox(height: 6.h),
                    Text(
                      '点击更换头像',
                      style: TextStyle(fontSize: 11.sp, color: Colors.white38),
                    ),
                  ],
                ],
              ),
            ),
            if (user != null) ...[
              SizedBox(width: 12.w),
              _ProfileEditButton(
                loading: controller.profileUpdating.value,
                onTap: controller.profileUpdating.value
                    ? null
                    : () => Get.bottomSheet<void>(
                        _EditProfileSheet(
                          controller: controller,
                          initialUser: user,
                        ),
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                      ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _QuarkAdminMenuCard extends StatelessWidget {
  const _QuarkAdminMenuCard({
    required this.expanded,
    required this.onTap,
    required this.onLoginTap,
    required this.onSearchTap,
    required this.onStreamTap,
  });

  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onLoginTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onStreamTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(22.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64B5F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      Icons.folder_special_outlined,
                      color: const Color(0xFF64B5F6),
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '夸克配置',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '统一管理夸克登录、搜索和播放设置',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22.w,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: expanded
                    ? Padding(
                        padding: EdgeInsets.only(top: 14.h),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            children: [
                              _SettingsSubMenuTile(
                                icon: Icons.cookie_outlined,
                                iconColor: const Color(0xFFFFB74D),
                                title: '夸克登录',
                                subtitle: '设置 quark_cookies 参数',
                                onTap: onLoginTap,
                              ),
                              _buildDivider(),
                              _SettingsSubMenuTile(
                                icon: Icons.travel_explore_rounded,
                                iconColor: const Color(0xFF64B5F6),
                                title: '夸克搜索',
                                subtitle: '配置 HTTP 代理、HTTPS 代理、TG 频道和启用插件',
                                onTap: onSearchTap,
                              ),
                              _buildDivider(),
                              _SettingsSubMenuTile(
                                icon: Icons.smart_display_outlined,
                                iconColor: const Color(0xFFBA68C8),
                                title: '夸克播放',
                                subtitle: '配置 302 / 本地代理，更多代理参数请在后端配置文件设置',
                                onTap: onStreamTap,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1.h,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 16.w,
      endIndent: 16.w,
    );
  }
}

class _SettingsSubMenuTile extends StatelessWidget {
  const _SettingsSubMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.w),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.sp, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.w,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEditButton extends StatelessWidget {
  const _ProfileEditButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.edit_outlined, size: 15.w, color: Colors.white70),
            SizedBox(width: 6.w),
            Text(
              '修改资料',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.controller,
    required this.initialUser,
  });

  final PluginController controller;
  final UserModel initialUser;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _realNameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUser.name);
    _realNameController = TextEditingController(
      text: widget.initialUser.realName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _realNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final changed = await widget.controller.updateProfile(
      name: _nameController.text,
      realName: _realNameController.text,
    );
    if (changed && mounted) {
      Get.back<void>();
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
                          Icons.manage_accounts_rounded,
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
                              '修改资料',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '更新用户名和昵称',
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
                SizedBox(height: 18.h),
                _ProfileTextField(
                  label: '用户名',
                  controller: _nameController,
                  hintText: '请输入用户名',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 14.h),
                _ProfileTextField(
                  label: '昵称',
                  controller: _realNameController,
                  hintText: '请输入昵称',
                  icon: Icons.badge_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入昵称';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 22.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back<void>(),
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
                      child: Obx(
                        () => FilledButton(
                          onPressed: widget.controller.profileUpdating.value
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: Size.fromHeight(50.h),
                            backgroundColor: AppThemeColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: widget.controller.profileUpdating.value
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '保存',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
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

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
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
          style: TextStyle(fontSize: 14.sp, color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 13.sp, color: Colors.white38),
            prefixIcon: Icon(icon, color: Colors.white38, size: 20.w),
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

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(22.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: iconColor, size: 22.w),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.w,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
