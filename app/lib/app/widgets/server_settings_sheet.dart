import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/models/discovered_server.dart';
import '../theme/app_theme.dart';

class ServerSettingsSheet extends StatelessWidget {
  const ServerSettingsSheet({
    super.key,
    required this.apiBaseUrlController,
    required this.servers,
    required this.isDiscovering,
    required this.isManualEntryMode,
    required this.onToggleManualEntryMode,
    required this.onRefreshDiscovery,
    required this.onSelectServer,
    this.errorText,
    this.selectedServer,
  });

  final TextEditingController apiBaseUrlController;
  final List<DiscoveredServer> servers;
  final String? errorText;
  final bool isDiscovering;
  final bool isManualEntryMode;
  final DiscoveredServer? selectedServer;
  final ValueChanged<bool> onToggleManualEntryMode;
  final VoidCallback onRefreshDiscovery;
  final ValueChanged<DiscoveredServer> onSelectServer;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isAutoSearchMode = !isManualEntryMode;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '自动搜索',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Switch.adaptive(
                        value: isAutoSearchMode,
                        activeThumbColor: AppThemeColors.primary,
                        activeTrackColor: AppThemeColors.primary.withValues(
                          alpha: 0.45,
                        ),
                        onChanged: (enabled) =>
                            onToggleManualEntryMode(!enabled),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              if (errorText != null && errorText!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.redAccent.shade100,
                    ),
                  ),
                ),
              if (!isManualEntryMode && !isDiscovering && servers.isEmpty)
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
                    '暂未发现服务，请重试或手动输入地址。',
                    style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                  ),
                ),
              if (!isManualEntryMode && servers.isNotEmpty)
                ...servers.map(
                  (server) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _ServerCard(
                      server: server,
                      isSelected:
                          selectedServer?.instanceId == server.instanceId &&
                          selectedServer?.origin == server.origin,
                      onTap: () => onSelectServer(server),
                    ),
                  ),
                ),
              if (isManualEntryMode) ...[
                SizedBox(height: 4.h),
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
                  controller: apiBaseUrlController,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: Colors.white, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'http://999576.xyz:18090',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 15.sp,
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
              if (!isManualEntryMode) ...[
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: isDiscovering ? null : onRefreshDiscovery,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: BorderSide(
                        color: isDiscovering
                            ? Colors.white24
                            : AppThemeColors.primary.withValues(alpha: 0.8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    child: Text(
                      isDiscovering ? '扫描中...' : '重新扫描',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isDiscovering
                            ? Colors.white54
                            : AppThemeColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  final DiscoveredServer server;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
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
