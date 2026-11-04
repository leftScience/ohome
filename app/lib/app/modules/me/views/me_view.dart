import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';

import '../../../data/models/user_model.dart';
import '../../../data/models/quark_account_status.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/home_style_backdrop.dart';
import '../controllers/me_controller.dart';

class MeView extends GetView<MeController> {
  const MeView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 108.h;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          const HomeStyleBackdrop(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                child: SizedBox(
                  height: 42.w,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 22.sp,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppThemeColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomInset),
                  children: [
                    _buildProfileCard(),
                    SizedBox(height: 24.h),
                    Obx(() {
                      final status = controller.accountStatus;
                      final children = <Widget>[
                        Text(
                          '夸克账户',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _QuarkAccountCard(
                          status: status,
                          loading: controller.quarkAccountLoading.value,
                          preferSaving: controller.quarkPreferSaving.value,
                          onPreferChanged: controller.setPreferExclusive,
                          onLoginTap: controller.canOpenQuarkLogin
                              ? controller.openQuarkLogin
                              : null,
                        ),
                      ];

                      if (controller.isSuperAdmin) {
                        children.addAll([
                          SizedBox(height: 24.h),
                          Text(
                            '基础管理',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppThemeColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _SettingsMenuCard(
                            icon: Icons.group_outlined,
                            iconColor: const Color(0xFF00897B),
                            title: '用户管理',
                            onTap: controller.openUserManagement,
                          ),
                          SizedBox(height: 12.h),
                          _QuarkAdminMenuCard(
                            expanded: controller.quarkAdminMenuExpanded.value,
                            systemMode: status.systemMode,
                            systemModeSaving:
                                controller.quarkSystemModeSaving.value,
                            onTap: controller.toggleQuarkAdminMenu,
                            onSystemModeChanged: controller.setSystemShareMode,
                            onLoginTap: controller.openQuarkLogin,
                            onSearchTap: controller.openQuarkSearchSettings,
                            onStreamTap: controller.openQuarkStreamSettings,
                          ),
                        ]);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      );
                    }),
                    SizedBox(height: 24.h),
                    Text(
                      '系统',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _SettingsMenuCard(
                      icon: Icons.lock_reset_rounded,
                      iconColor: const Color(0xFFF57C00),
                      title: '修改密码',
                      onTap: controller.openChangePassword,
                    ),
                    SizedBox(height: 12.h),
                    _SettingsMenuCard(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF1E88E5),
                      title: '关于wpan',
                      onTap: controller.openServerUpdate,
                    ),
                    SizedBox(height: 12.h),
                    _SettingsMenuCard(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFE53935),
                      title: '退出登录',
                      onTap: controller.logout,
                    ),
                  ],
                ),
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
          : '个人中心';
      final avatarUrl = user?.avatarUrl ?? '';
      final avatarText = user?.name.isNotEmpty == true
          ? user!.name.substring(0, 1).toUpperCase()
          : 'SZ';

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.primary.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2496C7),
                  Color(0xFF1565C0),
                  Color(0xFF0B1F5E),
                ],
              ),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: -30.w,
                  bottom: -42.h,
                  child: IgnorePointer(
                    child: Container(
                      width: 130.w,
                      height: 130.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -18.h,
                  right: -10.w,
                  child: IgnorePointer(
                    child: Container(
                      width: 88.w,
                      height: 88.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF9BE7FF).withValues(alpha: 0.34),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: uploading ? null : controller.uploadAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 28.r,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
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
                                color: const Color(0xFF123A8E),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
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
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
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
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _QuarkAccountCard extends StatelessWidget {
  const _QuarkAccountCard({
    required this.status,
    required this.loading,
    required this.preferSaving,
    required this.onPreferChanged,
    required this.onLoginTap,
  });

  final QuarkAccountStatus status;
  final bool loading;
  final bool preferSaving;
  final ValueChanged<bool> onPreferChanged;
  final VoidCallback? onLoginTap;

  @override
  Widget build(BuildContext context) {
    final canPrefer = status.canPreferExclusive == true;
    final preferExclusive = status.preferExclusive == true;
    final forcedExclusive = status.systemMode == 'exclusive';
    final effectiveExclusive = status.effectiveMode == 'exclusive';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Material(
          color: AppThemeColors.surface,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: AppThemeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.share_outlined,
                        color: const Color(0xFF00897B),
                        size: 22.w,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '夸克数据范围',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppThemeColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            forcedExclusive
                                ? '管理员已强制独享，请登录自己的夸克账号'
                                : (effectiveExclusive
                                    ? '当前使用你自己的夸克账号与目录'
                                    : '当前使用家庭共享夸克账号与目录'),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppThemeColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (canPrefer) ...[
                  SizedBox(height: 12.h),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '使用独享夸克账号',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      preferExclusive
                          ? '已开启：读写你自己的 WP/类型/用户目录'
                          : '关闭时跟随共享库，无需个人登录',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                    value: preferExclusive,
                    onChanged: preferSaving ? null : onPreferChanged,
                  ),
                ],
                if (effectiveExclusive && onLoginTap != null) ...[
                  SizedBox(height: 4.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onLoginTap,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(
                        status.cookieConfigured == true ? '管理夸克登录' : '去登录夸克',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuarkAdminMenuCard extends StatelessWidget {
  const _QuarkAdminMenuCard({
    required this.expanded,
    required this.systemMode,
    required this.systemModeSaving,
    required this.onTap,
    required this.onSystemModeChanged,
    required this.onLoginTap,
    required this.onSearchTap,
    required this.onStreamTap,
  });

  final bool expanded;
  final String systemMode;
  final bool systemModeSaving;
  final VoidCallback? onTap;
  final ValueChanged<String> onSystemModeChanged;
  final VoidCallback? onLoginTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onStreamTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Material(
          color: AppThemeColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: AppThemeColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E88E5,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(
                          Icons.folder_special_outlined,
                          color: const Color(0xFF1E88E5),
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
                                color: AppThemeColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '统一管理共享状态、登录、搜索和播放设置',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppThemeColors.textMuted,
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
                          color: AppThemeColors.textDisabled,
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
                                color: AppThemeColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(18.r),
                                border: Border.all(
                                  color: AppThemeColors.border,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      14.w,
                                      12.h,
                                      14.w,
                                      8.h,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '共享状态',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppThemeColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          '共享：默认全家共用；独享：强制每人登录自己的夸克',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: AppThemeColors.textMuted,
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        SegmentedButton<String>(
                                          segments: const [
                                            ButtonSegment<String>(
                                              value: 'shared',
                                              label: Text('共享'),
                                              icon: Icon(Icons.groups_outlined),
                                            ),
                                            ButtonSegment<String>(
                                              value: 'exclusive',
                                              label: Text('独享'),
                                              icon: Icon(Icons.person_outline),
                                            ),
                                          ],
                                          selected: {systemMode},
                                          onSelectionChanged: systemModeSaving
                                              ? null
                                              : (values) {
                                                  if (values.isEmpty) return;
                                                  onSystemModeChanged(
                                                    values.first,
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildDivider(),
                                  _SettingsSubMenuTile(
                                    icon: Icons.cookie_outlined,
                                    iconColor: const Color(0xFFF57C00),
                                    title: '夸克登录',
                                    subtitle: systemMode == 'exclusive'
                                        ? '维护当前账号自己的夸克凭证'
                                        : '维护共享夸克 Cookie / TV 登录',
                                    onTap: onLoginTap,
                                  ),
                                  _buildDivider(),
                                  _SettingsSubMenuTile(
                                    icon: Icons.travel_explore_rounded,
                                    iconColor: const Color(0xFF1E88E5),
                                    title: '夸克搜索',
                                    subtitle: '配置 HTTP 代理、HTTPS 代理、TG 频道和启用插件',
                                    onTap: onSearchTap,
                                  ),
                                  _buildDivider(),
                                  _SettingsSubMenuTile(
                                    icon: Icons.smart_display_outlined,
                                    iconColor: const Color(0xFF8E24AA),
                                    title: '夸克播放',
                                    subtitle:
                                        '配置 302 / 本地代理，更多代理参数请在后端配置文件设置',
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
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1.h,
      thickness: 1,
      color: AppThemeColors.divider,
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
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.w,
                color: AppThemeColors.textDisabled,
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
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

  final MeController controller;
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
        color: AppThemeColors.surface,
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
                      color: AppThemeColors.borderStrong,
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
                    border: Border.all(color: AppThemeColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46.w,
                        height: 46.w,
                        decoration: BoxDecoration(
                          color: AppThemeColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          Icons.manage_accounts_rounded,
                          color: AppThemeColors.primary,
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
                                color: AppThemeColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '更新用户名和昵称',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppThemeColors.textSecondary,
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
                          side: BorderSide(color: AppThemeColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.textSecondary,
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
                                    color: AppThemeColors.textOnAccent,
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
            color: AppThemeColors.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(fontSize: 14.sp, color: AppThemeColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 13.sp,
              color: AppThemeColors.textDisabled,
            ),
            prefixIcon: Icon(
              icon,
              color: AppThemeColors.textDisabled,
              size: 20.w,
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
}

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: AppThemeColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Material(
          color: AppThemeColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: AppThemeColors.border),
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
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.w,
                    color: AppThemeColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
