import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';

class QuarkTagEditorView extends StatefulWidget {
  const QuarkTagEditorView({
    super.key,
    required this.title,
    required this.description,
    required this.inputHint,
    required this.addButtonText,
    required this.emptyStateText,
    required this.initialOptions,
    required this.initialSelected,
  });

  final String title;
  final String description;
  final String inputHint;
  final String addButtonText;
  final String emptyStateText;
  final List<String> initialOptions;
  final List<String> initialSelected;

  @override
  State<QuarkTagEditorView> createState() => _QuarkTagEditorViewState();
}

class _QuarkTagEditorViewState extends State<QuarkTagEditorView> {
  late final TextEditingController _tagController;
  late final List<String> _allTags;
  late final Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
    _allTags = _normalizeTags(<String>[
      ...widget.initialSelected,
      ...widget.initialOptions,
    ]);
    _selectedKeys = widget.initialSelected.map(_normalizeKey).toSet();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
        children: [
          _buildIntroCard(),
          SizedBox(height: 16.h),
          _buildAddCard(),
          SizedBox(height: 16.h),
          _buildTagsCard(),
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
          label: const Text('完成编辑'),
        ),
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
            widget.description,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppThemeColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildStatPill(
                label: '已选 $_selectedCount 个',
                color: AppThemeColors.primary,
              ),
              _buildStatPill(
                label: '共 ${_allTags.length} 个标签',
                color: const Color(0xFF00897B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
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
            '新增标签',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppThemeColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '新增后会自动选中。点按标签可切换选中状态，点右侧关闭图标可直接删除标签。',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppThemeColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  onSubmitted: (_) => _addTag(),
                  style: const TextStyle(color: AppThemeColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.inputHint,
                    hintStyle: const TextStyle(
                      color: AppThemeColors.textDisabled,
                    ),
                    filled: true,
                    fillColor: AppThemeColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: const BorderSide(
                        color: AppThemeColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: const BorderSide(
                        color: AppThemeColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: const BorderSide(
                        color: AppThemeColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              FilledButton.icon(
                onPressed: _addTag,
                style: FilledButton.styleFrom(
                  minimumSize: Size(0, 52.h),
                  backgroundColor: AppThemeColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(widget.addButtonText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCard() {
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
            '标签列表',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppThemeColors.textPrimary,
            ),
          ),
          if (_allTags.isEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              widget.emptyStateText,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppThemeColors.textSecondary,
              ),
            ),
          ],
          if (_allTags.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: _allTags
                  .map(
                    (tag) => _buildTagChip(
                      tag,
                      _selectedKeys.contains(_normalizeKey(tag)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppThemeColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, bool selected) {
    return InputChip(
      label: Text(tag),
      selected: selected,
      onSelected: (value) => _toggleTag(tag, value),
      onDeleted: () => _deleteTag(tag),
      selectedColor: AppThemeColors.primary.withValues(alpha: 0.18),
      checkmarkColor: AppThemeColors.primary,
      backgroundColor: AppThemeColors.surfaceMuted,
      deleteIconColor: AppThemeColors.textMuted,
      side: BorderSide(
        color: selected
            ? AppThemeColors.primary.withValues(alpha: 0.65)
            : AppThemeColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? AppThemeColors.primary : AppThemeColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      final key = _normalizeKey(tag);
      if (selected) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  void _deleteTag(String tag) {
    setState(() {
      final key = _normalizeKey(tag);
      _selectedKeys.remove(key);
      _allTags.removeWhere((item) => _normalizeKey(item) == key);
    });
  }

  void _addTag() {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) return;

    final key = _normalizeKey(raw);
    String? existing;
    for (final tag in _allTags) {
      if (_normalizeKey(tag) == key) {
        existing = tag;
        break;
      }
    }

    setState(() {
      if (existing == null) {
        _allTags.insert(0, raw);
      }
      _selectedKeys.add(key);
      _tagController.clear();
    });

    if (existing != null) {
      Get.snackbar('提示', '标签已存在，已帮你选中');
    }
  }

  void _submit() {
    Get.back(
      result: _allTags
          .where((tag) => _selectedKeys.contains(_normalizeKey(tag)))
          .toList(growable: false),
    );
  }

  int get _selectedCount {
    var count = 0;
    for (final tag in _allTags) {
      if (_selectedKeys.contains(_normalizeKey(tag))) {
        count += 1;
      }
    }
    return count;
  }

  static List<String> _normalizeTags(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final item in values) {
      final value = item.trim();
      if (value.isEmpty) continue;
      final key = _normalizeKey(value);
      if (!seen.add(key)) continue;
      result.add(value);
    }
    return result;
  }

  static String _normalizeKey(String value) => value.trim().toLowerCase();
}
