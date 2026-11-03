import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/drops.dart';
import '../../../theme/app_theme.dart';
import '../controllers/drops_controller.dart';

class DropsEventFormView extends StatefulWidget {
  const DropsEventFormView({super.key, this.initialEventId});

  final int? initialEventId;

  bool get isEdit => initialEventId != null;

  @override
  State<DropsEventFormView> createState() => _DropsEventFormViewState();
}

class _DropsEventFormViewState extends State<DropsEventFormView> {
  final _formKey = GlobalKey<FormState>();
  final _api = Get.find<DropsApi>();
  final _dropsController = Get.find<DropsController>();

  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _remarkController = TextEditingController();

  String _scopeType = 'shared';
  String _eventType = 'birthday';
  String _calendarType = 'solar';
  bool _repeatYearly = true;
  bool _enabled = true;
  int _eventMonth = 1;
  int _eventDay = 1;
  bool _isLeapMonth = false;
  DateTime? _solarDate;
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dropsController.ensureDictsLoaded();
    if (widget.isEdit) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final id = widget.initialEventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final detail = await _api.getEventDetail(id);
      if (!mounted) return;
      setState(() {
        _scopeType = detail.scopeType.isEmpty ? 'shared' : detail.scopeType;
        _eventType = detail.eventType.isEmpty ? 'birthday' : detail.eventType;
        _calendarType = detail.calendarType.isEmpty
            ? 'solar'
            : detail.calendarType;
        _repeatYearly = detail.repeatYearly;
        _enabled = detail.enabled;
        _eventMonth = detail.eventMonth <= 0 ? 1 : detail.eventMonth;
        _eventDay = detail.eventDay <= 0 ? 1 : detail.eventDay;
        _isLeapMonth = detail.isLeapMonth;
        _titleController.text = detail.title;
        _yearController.text = detail.eventYear == 0
            ? ''
            : '${detail.eventYear}';
        _remarkController.text = detail.remark;
        if (_calendarType == 'solar' && detail.eventYear > 0) {
          _solarDate = DateTime(detail.eventYear, _eventMonth, _eventDay);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickSolarDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _solarDate ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 50),
    );
    if (result == null || !mounted) return;
    setState(() {
      _solarDate = result;
      _eventMonth = result.month;
      _eventDay = result.day;
      _yearController.text = '${result.year}';
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_calendarType == 'solar' && _solarDate == null) {
      Get.snackbar('提示', '请选择公历日期');
      return;
    }

    final eventYear = int.tryParse(_yearController.text.trim()) ?? 0;
    final payload = <String, dynamic>{
      if (widget.initialEventId != null) 'id': widget.initialEventId,
      'scopeType': _scopeType,
      'title': _titleController.text.trim(),
      'eventType': _eventType,
      'calendarType': _calendarType,
      'eventYear': _calendarType == 'solar'
          ? (eventYear == 0 && _repeatYearly
                ? (_solarDate?.year ?? 0)
                : eventYear)
          : eventYear,
      'eventMonth': _eventMonth,
      'eventDay': _eventDay,
      'isLeapMonth': _isLeapMonth,
      'repeatYearly': _repeatYearly,
      'remark': _remarkController.text.trim(),
      'enabled': _enabled,
    };

    setState(() => _submitting = true);
    try {
      await _api.saveEvent(payload);
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('提示', widget.isEdit ? '重要日期已更新' : '重要日期已创建');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(widget.isEdit ? '编辑重要日期' : '新增重要日期')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
                  children: [
                    _buildBasicInfoCard(),
                    SizedBox(height: 16.h),
                    _buildAdvancedCard(),
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
              foregroundColor: AppThemeColors.textOnAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: _submitting
                ? const CircularProgressIndicator(
                    color: AppThemeColors.textOnAccent,
                  )
                : Text(widget.isEdit ? '保存修改' : '创建日期'),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
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
              Icon(
                Icons.cake_outlined,
                color: AppThemeColors.primary,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Text(
                '基础信息',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppThemeColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _textField(
            label: '标题',
            controller: _titleController,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入标题' : null,
          ),
          SizedBox(height: 14.h),
          Obx(() {
            final _ = _dropsController.dictVersion.value;
            return _dropdownField(
              label: '日期类型',
              value: _calendarType,
              items: _dropsController.calendarLabels,
              onChanged: (value) => setState(() => _calendarType = value),
            );
          }),
          SizedBox(height: 14.h),
          _calendarEditor(),
          SizedBox(height: 14.h),
          _textField(label: '备注', controller: _remarkController, maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard() {
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
              Icon(
                Icons.more_horiz_rounded,
                color: AppThemeColors.primary,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Text(
                '高级设置',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppThemeColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Obx(() {
            final _ = _dropsController.dictVersion.value;
            return _dropdownField(
              label: '类型（默认生日）',
              value: _eventType,
              items: _dropsController.eventTypeLabels,
              onChanged: (value) => setState(() => _eventType = value),
            );
          }),
          SizedBox(height: 14.h),
          Obx(() {
            final _ = _dropsController.dictVersion.value;
            return _dropdownField(
              label: '范围（默认家庭共享）',
              value: _scopeType,
              items: _dropsController.scopeLabels,
              onChanged: (value) => setState(() => _scopeType = value),
            );
          }),
          SizedBox(height: 14.h),
          SwitchListTile(
            value: _repeatYearly,
            onChanged: (value) => setState(() => _repeatYearly = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('按年循环（默认开启）'),
            activeTrackColor: AppThemeColors.primary,
          ),
          SizedBox(height: 14.h),
          SwitchListTile(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('启用提醒（默认开启）'),
            activeTrackColor: AppThemeColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _calendarEditor() {
    if (_calendarType == 'solar') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('公历日期'),
          SizedBox(height: 8.h),
          InkWell(
            onTap: _pickSolarDate,
            borderRadius: BorderRadius.circular(14.r),
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: AppThemeColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppThemeColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _solarDate == null ? '请选择日期' : _formatDate(_solarDate!),
                      style: const TextStyle(color: AppThemeColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.date_range_outlined),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _numberDropdown(
                label: '农历月份',
                value: _eventMonth,
                max: 12,
                onChanged: (value) => setState(() => _eventMonth = value),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _numberDropdown(
                label: '农历日期',
                value: _eventDay,
                max: 30,
                onChanged: (value) => setState(() => _eventDay = value),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        SwitchListTile(
          value: _isLeapMonth,
          onChanged: (value) => setState(() => _isLeapMonth = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('闰月'),
        ),
        SizedBox(height: 14.h),
        _textField(
          label: '年份（可选）',
          controller: _yearController,
          keyboardType: TextInputType.number,
          helperText: _repeatYearly ? '填写后可显示年龄/周年，留空则按每年循环处理' : '非循环时必须填写年份',
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    final effectiveValue = items.containsKey(value)
        ? value
        : (items.isNotEmpty ? items.keys.first : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          dropdownColor: AppThemeColors.surface,
          style: const TextStyle(color: AppThemeColors.textPrimary),
          decoration: _inputDecoration(),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(growable: false),
          onChanged: (next) => onChanged(next ?? value),
        ),
      ],
    );
  }

  Widget _numberDropdown({
    required String label,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        SizedBox(height: 8.h),
        DropdownButtonFormField<int>(
          initialValue: value,
          dropdownColor: AppThemeColors.surface,
          style: const TextStyle(color: AppThemeColors.textPrimary),
          decoration: _inputDecoration(),
          items: List.generate(
            max,
            (index) => DropdownMenuItem<int>(
              value: index + 1,
              child: Text('${index + 1}'),
            ),
          ),
          onChanged: (next) => onChanged(next ?? value),
        ),
      ],
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppThemeColors.textPrimary),
          decoration: _inputDecoration(helperText: helperText),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? helperText}) {
    return InputDecoration(
      helperText: helperText,
      helperStyle: TextStyle(
        color: AppThemeColors.textDisabled,
        fontSize: 11.sp,
      ),
      filled: true,
      fillColor: AppThemeColors.surfaceMuted,
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
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: AppThemeColors.textSecondary,
      ),
    );
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}
