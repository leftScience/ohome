import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/quark.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/selection_bottom_sheet.dart';

typedef ManualTransferSheetSubmit =
    Future<bool> Function({
      required String title,
      required String shareUrl,
      required String savePath,
    });

typedef ManualTransferSavePathLoader =
    Future<List<QuarkConfigOption>> Function();

Future<void> showManualTransferTaskSheet({
  required BuildContext context,
  required ManualTransferSheetSubmit onSubmit,
  required ManualTransferSavePathLoader loadSavePathOptions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) {
      return Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _ManualTransferTaskSheet(
            onSubmit: onSubmit,
            loadSavePathOptions: loadSavePathOptions,
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: curve,
          child: child,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 36.h * (1 - curve.value)),
              child: child,
            );
          },
        ),
      );
    },
  );
}

class _ManualTransferTaskSheet extends StatefulWidget {
  const _ManualTransferTaskSheet({
    required this.onSubmit,
    required this.loadSavePathOptions,
  });

  final ManualTransferSheetSubmit onSubmit;
  final ManualTransferSavePathLoader loadSavePathOptions;

  @override
  State<_ManualTransferTaskSheet> createState() =>
      _ManualTransferTaskSheetState();
}

class _ManualTransferTaskSheetState extends State<_ManualTransferTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _shareUrlController;
  late final TextEditingController _savePathController;

  bool _submitting = false;
  bool _selectingPath = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _shareUrlController = TextEditingController();
    _savePathController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shareUrlController.dispose();
    _savePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = math.min(screenHeight * 0.86, 720.h);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        width: double.infinity,
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
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Container(
                        width: 42.w,
                        height: 42.w,
                        decoration: BoxDecoration(
                          color: AppThemeColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: AppThemeColors.primary,
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '新增转存任务',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '填写标题、分享链接和转存路径后立即开始转存',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  _buildField(
                    label: '标题',
                    child: TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontSize: 14.sp, color: Colors.white),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入标题';
                        }
                        return null;
                      },
                      decoration: _inputDecoration('请输入任务标题'),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildField(
                    label: '链接',
                    child: TextFormField(
                      controller: _shareUrlController,
                      minLines: 3,
                      maxLines: 5,
                      style: TextStyle(fontSize: 14.sp, color: Colors.white),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入分享链接';
                        }
                        return null;
                      },
                      decoration: _inputDecoration('请输入夸克分享链接'),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildField(
                    label: '转存路径',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _savePathController,
                          readOnly: true,
                          showCursor: false,
                          onTap: _selectingPath ? null : _selectConfiguredPath,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请选择转存路径';
                            }
                            if (_normalizeSavePath(value).isEmpty) {
                              return '请选择转存路径';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            '请选择已配置目录',
                            suffixIcon: IconButton(
                              tooltip: '选择已配置目录',
                              onPressed: _selectingPath
                                  ? null
                                  : _selectConfiguredPath,
                              icon: Icon(
                                _selectingPath
                                    ? Icons.hourglass_top_rounded
                                    : Icons.folder_open_rounded,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '转存路径只能从已配置目录中选择。',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white54,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
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
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeColors.primary,
                            disabledBackgroundColor: AppThemeColors.primary
                                .withValues(alpha: 0.45),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
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
                                  '确定',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
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
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13.sp, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF101010),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _selectConfiguredPath() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectingPath = true;
    });

    try {
      final configs = await widget.loadSavePathOptions();
      if (!mounted) return;

      final selected = await showSelectionBottomSheet<QuarkConfigOption>(
        context: context,
        meta: SelectionBottomSheetMeta(
          icon: Icons.folder_open_rounded,
          label: '已配置 ${configs.length} 个目录',
          accent: configs.isEmpty
              ? const Color(0xFFF59E0B)
              : AppThemeColors.primary,
        ),
        helperText: '点击目录后自动填入转存路径',
        emptyTitle: '暂无可用目录',
        emptyDescription: '还没有可用的已配置目录，请先在系统中配置目录。',
        options: configs
            .map((config) {
              final application = config.application.trim();
              final baseLabel = quarkApplicationLabel(application);
              final remark = config.remark.trim();
              final title = remark.isEmpty ? baseLabel : '$baseLabel · $remark';
              return SelectionBottomSheetOption<QuarkConfigOption>(
                value: config,
                title: title,
                subtitle: config.rootPath,
                icon: quarkApplicationIcon(application),
                accent: quarkApplicationAccent(application),
                statusText: '已配置',
              );
            })
            .toList(growable: false),
      );
      if (selected == null) return;

      final normalizedPath = _normalizeSavePath(selected.rootPath);
      _savePathController.value = TextEditingValue(
        text: normalizedPath,
        selection: TextSelection.collapsed(offset: normalizedPath.length),
      );
    } catch (_) {
      Get.snackbar('提示', '获取目录失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _selectingPath = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
    });

    final success = await widget.onSubmit(
      title: _titleController.text,
      shareUrl: _shareUrlController.text,
      savePath: _normalizeSavePath(_savePathController.text),
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
    });
    if (success) {
      Navigator.of(context).pop();
    }
  }

  static String _normalizeSavePath(String value) {
    final normalized = value.trim().replaceAll('\\', '/');
    return normalized.replaceAll(RegExp(r'^/+|/+$'), '');
  }
}
