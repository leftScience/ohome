import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/user_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_floating_action_button_position.dart';
import '../controllers/user_management_controller.dart';

class UserManagementView extends GetView<UserManagementController> {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户管理')),
      floatingActionButtonLocation:
          AppFloatingActionButtonPosition.scaffoldLocation,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.openCreatePage,
        backgroundColor: AppThemeColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增用户'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildSearchCard(),
          ),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '搜索用户',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          _buildSearchField(
            controller: controller.nameController,
            hintText: '按用户名搜索',
            prefixIcon: Icons.person_outline_rounded,
            onChanged: controller.onKeywordChanged,
            onSubmitted: (_) => controller.search(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13.sp, color: Colors.white38),
        prefixIcon: Icon(prefixIcon, size: 20.w, color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF101010),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppThemeColors.primary),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return Obx(() {
      final users = controller.users;
      final loading = controller.loading.value;
      final hasMore = controller.hasMore.value;
      final loadingMore = controller.loadingMore.value;

      if (loading && users.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: () => controller.loadUsers(refresh: true),
        child: users.isEmpty
            ? ListView(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.w, 64.h, 20.w, 120.h),
                children: [
                  Icon(
                    Icons.group_off_outlined,
                    size: 60.w,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 14.h),
                  Center(
                    child: Text(
                      '暂无用户数据',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: controller.scrollController,
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
                itemCount: users.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  if (index >= users.length) {
                    return loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }
                  final user = users[index];
                  return _UserCard(
                    user: user,
                    isCurrentUser: controller.isCurrentUser(user),
                    canDelete: controller.canDeleteUser(user),
                    onEdit: () => controller.openEditPage(user),
                    onResetPassword: () =>
                        controller.confirmResetPassword(user),
                    onDelete: () => controller.confirmDelete(user),
                  );
                },
              ),
      );
    });
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.canDelete,
    required this.onEdit,
    required this.onResetPassword,
    required this.onDelete,
  });

  final UserModel user;
  final bool isCurrentUser;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = user.realName.isNotEmpty ? user.realName : user.name;
    final subtitle = user.name.isNotEmpty ? '@${user.name}' : '未设置用户名';
    final avatarText = user.name.isNotEmpty
        ? user.name.substring(0, 1).toUpperCase()
        : '?';
    final actionWidth = 108.w;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isCurrentUser
              ? AppThemeColors.primary.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: AppThemeColors.primary.withValues(alpha: 0.18),
                child: Text(
                  avatarText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: actionWidth,
                    child: _HeaderActionButton(onTap: onEdit),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: actionWidth,
                    child: _ActionChip(
                      label: '重置密码',
                      color: const Color(0xFFFFB74D),
                      icon: Icons.lock_reset_outlined,
                      onTap: onResetPassword,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildBadge(
                label: user.roleName.isNotEmpty
                    ? user.roleName
                    : (user.isSuperAdmin ? '超级管理员' : '普通用户'),
                backgroundColor: user.isSuperAdmin
                    ? const Color(0xFFFFB74D).withValues(alpha: 0.16)
                    : const Color(0xFF90CAF9).withValues(alpha: 0.14),
                textColor: user.isSuperAdmin
                    ? const Color(0xFFFFCC80)
                    : const Color(0xFF90CAF9),
              ),
              if (isCurrentUser)
                _buildBadge(
                  label: '当前用户',
                  backgroundColor: AppThemeColors.primary.withValues(
                    alpha: 0.14,
                  ),
                  textColor: const Color(0xFF8AB6FF),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          _buildInfoRow(
            Icons.schedule_outlined,
            user.updatedAt == null
                ? '更新时间未知'
                : '更新于 ${_formatDate(user.updatedAt!)}',
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              if (canDelete)
                _ActionChip(
                  label: '删除',
                  color: const Color(0xFFE57373),
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.w, color: Colors.white38),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, color: Colors.white60),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              SizedBox(
                width: 16.w,
                child: Icon(
                  Icons.edit_outlined,
                  size: 16.w,
                  color: AppThemeColors.primary,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                '编辑角色',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppThemeColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              SizedBox(
                width: 16.w,
                child: Icon(icon, size: 16.w, color: color),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
