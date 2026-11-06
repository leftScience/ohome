import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../controllers/quark_search_settings_controller.dart';

class QuarkSearchSettingsView extends GetView<QuarkSearchSettingsController> {
  const QuarkSearchSettingsView({super.key});

  static const int _previewTagLimit = 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: const Text('夸克搜索')),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final channels = controller.selectedChannels.toList(growable: false);
        final plugins = controller.selectedPlugins.toList(growable: false);

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
          children: [
            _buildIntroCard(),
            SizedBox(height: 16.h),
            _buildProxyFieldCard(
              icon: Icons.language_rounded,
              title: 'HTTP 代理',
              description: '为夸克搜索请求设置 HTTP 代理地址，留空则直连。',
              hint: '例如：http://127.0.0.1:1080',
              controller: controller.httpProxyController,
              updatedAt: controller.updatedAtFor(
                QuarkSearchSettingsController.httpProxyKey,
              ),
            ),
            SizedBox(height: 12.h),
            _buildProxyFieldCard(
              icon: Icons.verified_user_outlined,
              title: 'HTTPS 代理',
              description: '为夸克搜索请求设置 HTTPS 代理地址，留空则直连。',
              hint: '例如：http://127.0.0.1:1080',
              controller: controller.httpsProxyController,
              updatedAt: controller.updatedAtFor(
                QuarkSearchSettingsController.httpsProxyKey,
              ),
            ),
            SizedBox(height: 12.h),
            _buildTagFieldCard(
              icon: Icons.alternate_email_rounded,
              title: 'TG 频道',
              description: '默认搜索时启用的 Telegram 频道。',
              actionText: '编辑频道',
              helper: '进入单独页面后可按标签选中、取消选中、新增和删除。',
              tags: channels,
              updatedAt: controller.updatedAtFor(
                QuarkSearchSettingsController.channelsKey,
              ),
              onTap: controller.openChannelsEditor,
            ),
            SizedBox(height: 12.h),
            _buildTagFieldCard(
              icon: Icons.extension_rounded,
              title: '启用插件',
              description: '选择夸克搜索时允许使用的插件。',
              actionText: '编辑插件',
              helper: controller.supportedPluginsHint,
              tags: plugins,
              updatedAt: controller.updatedAtFor(
                QuarkSearchSettingsController.enabledPluginsKey,
              ),
              onTap: controller.openPluginsEditor,
            ),
            SizedBox(height: 12.h),
            _buildWebEnginesCard(),
          ],
        );
      }),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: Obx(() {
          return FilledButton.icon(
            onPressed: controller.saving.value ? null : controller.save,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 50.h),
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            icon: controller.saving.value
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(controller.saving.value ? '保存中' : '保存配置'),
          );
        }),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '搜索运行配置',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppThemeColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '代理地址在当前页直接填写，TG 频道和插件改为独立标签编辑页，保存后下次搜索立即生效。',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppThemeColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebEnginesCard() {
    return Obx(() {
      final engines = controller.webEngines.toList(growable: false);
      return Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
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
                    color: AppThemeColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: AppThemeColors.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自定义搜索源',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppThemeColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _formatUpdatedAt(
                          controller.updatedAtFor(
                            QuarkSearchSettingsController.webEnginesKey,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppThemeColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.addWebEngine,
                  style: TextButton.styleFrom(
                    foregroundColor: AppThemeColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    minimumSize: Size(0, 32.h),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.add_rounded, size: 18.w),
                  label: Text('新增', style: TextStyle(fontSize: 12.sp)),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              '配置第三方网盘 Web 搜索引擎，配置后资源搜索页会出现对应标签，'
              '点选后以内嵌网页打开搜索结果。',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppThemeColors.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12.h),
            if (engines.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppThemeColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppThemeColors.border),
                ),
                child: Text(
                  '暂未配置自定义搜索源',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textMuted,
                  ),
                ),
              )
            else
              ...List.generate(engines.length, (index) {
                final engine = engines[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppThemeColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                engine.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppThemeColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                engine.urlTemplate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppThemeColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => controller.editWebEngine(index),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18.w,
                            color: AppThemeColors.textSecondary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => controller.removeWebEngine(index),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18.w,
                            color: AppThemeColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    });
  }

  Widget _buildProxyFieldCard({
    required IconData icon,
    required String title,
    required String description,
    required String hint,
    required TextEditingController controller,
    DateTime? updatedAt,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
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
                  color: AppThemeColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: AppThemeColors.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatUpdatedAt(updatedAt),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppThemeColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: controller,
            style: const TextStyle(color: AppThemeColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppThemeColors.textDisabled),
              filled: true,
              fillColor: AppThemeColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: AppThemeColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: AppThemeColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: AppThemeColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFieldCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required String helper,
    required List<String> tags,
    required VoidCallback onTap,
    DateTime? updatedAt,
  }) {
    final previewTags = tags.take(_previewTagLimit).toList(growable: false);
    final overflowCount = tags.length - previewTags.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Ink(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppThemeColors.surface,
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
                      color: AppThemeColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(icon, color: AppThemeColors.primary),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _formatUpdatedAt(updatedAt),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppThemeColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionText,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.primary,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18.w,
                          color: AppThemeColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppThemeColors.textSecondary,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppThemeColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppThemeColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sell_outlined,
                      size: 16.w,
                      color: AppThemeColors.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '已选 ${tags.length} 个',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              if (previewTags.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppThemeColors.border),
                  ),
                  child: Text(
                    '暂未选择',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppThemeColors.textMuted,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    ...previewTags.map(_buildPreviewTag),
                    if (overflowCount > 0) _buildOverflowTag(overflowCount),
                  ],
                ),
              SizedBox(height: 12.h),
              Text(
                helper,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppThemeColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTag(String tag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppThemeColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 12.sp, color: AppThemeColors.textSecondary),
      ),
    );
  }

  Widget _buildOverflowTag(int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppThemeColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: AppThemeColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppThemeColors.primary,
        ),
      ),
    );
  }

  static String _formatUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return '尚未保存';
    return '最近保存：${_formatDate(updatedAt)}';
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
