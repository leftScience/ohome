import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/pan_web_engine.dart';
import '../../../theme/app_theme.dart';

/// 单个自定义网盘搜索源的编辑页，返回值为编辑后的 [PanWebEngine]。
class QuarkWebEngineEditorView extends StatefulWidget {
  const QuarkWebEngineEditorView({super.key, this.initial});

  final PanWebEngine? initial;

  @override
  State<QuarkWebEngineEditorView> createState() =>
      _QuarkWebEngineEditorViewState();
}

class _QuarkWebEngineEditorViewState extends State<QuarkWebEngineEditorView> {
  static const String _defaultName = 'KK搜';
  static const String _defaultUrl = 'https://kkso.net/s/{kw}.html';

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initial?.name ?? _defaultName,
    );
    _urlController = TextEditingController(
      text: widget.initial?.urlTemplate ?? _defaultUrl,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('提示', '请填写搜索源名称');
      return;
    }
    if (url.isEmpty) {
      Get.snackbar('提示', '请填写搜索链接');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      Get.snackbar('提示', '搜索链接需以 http:// 或 https:// 开头');
      return;
    }
    Get.back(
      result: PanWebEngine(
        id: widget.initial?.id ?? '',
        name: name,
        urlTemplate: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(widget.initial == null ? '新增搜索源' : '编辑搜索源')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
        children: [
          _buildFieldCard(
            title: '搜索源名称',
            hint: '例如：KK搜',
            controller: _nameController,
          ),
          SizedBox(height: 12.h),
          _buildFieldCard(
            title: '搜索链接',
            hint: '例如：https://kkso.net/s/{kw}.html',
            controller: _urlController,
            maxLines: 3,
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppThemeColors.surface,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppThemeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '链接中的 {kw}（兼容 {keyword}）会被替换为搜索关键词，'
                  '例如 https://kkso.net/s/{kw}.html。',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '配置后「资源搜索」页会多出对应的搜索源标签，点选后以内嵌网页方式打开搜索结果。',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: FilledButton.icon(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: Size(double.infinity, 50.h),
            backgroundColor: AppThemeColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          icon: const Icon(Icons.check_rounded),
          label: const Text('确定'),
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required String title,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
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
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppThemeColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: controller,
            maxLines: maxLines,
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
}
