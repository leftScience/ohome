import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/api/drops.dart';
import '../../../data/models/drops_item_model.dart';
import '../../../theme/app_theme.dart';
import '../controllers/drops_controller.dart';

class DropsItemFormView extends StatefulWidget {
  const DropsItemFormView({super.key, this.initialItemId});

  final int? initialItemId;

  bool get isEdit => initialItemId != null;

  @override
  State<DropsItemFormView> createState() => _DropsItemFormViewState();
}

class _DropsItemFormViewState extends State<DropsItemFormView> {
  final _formKey = GlobalKey<FormState>();
  final _api = Get.find<DropsApi>();
  final _dropsController = Get.find<DropsController>();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _remarkController = TextEditingController();

  final List<XFile> _newPhotos = <XFile>[];
  final List<String> _locationSuggestions = <String>[];

  String _scopeType = 'shared';
  String _category = 'food';
  bool _enabled = true;
  DateTime? _expireAt;
  DropsItemModel? _item;
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dropsController.ensureDictsLoaded();
    _loadSuggestions();
    if (widget.isEdit) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final values = await _api.getLocationSuggestions();
    if (!mounted) return;
    setState(() {
      _locationSuggestions
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> _loadDetail() async {
    final id = widget.initialItemId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final detail = await _api.getItemDetail(id);
      if (!mounted) return;
      setState(() {
        _item = detail;
        _scopeType = detail.scopeType.isEmpty ? 'shared' : detail.scopeType;
        _category = detail.category.isEmpty ? 'food' : detail.category;
        _enabled = detail.enabled;
        _expireAt = detail.expireAt;
        _nameController.text = detail.name;
        _locationController.text = detail.location;
        _remarkController.text = detail.remark;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final totalPhotos = (_item?.photos.length ?? 0) + _newPhotos.length;
    if (totalPhotos >= 3) {
      Get.snackbar('提示', '最多上传 3 张照片');
      return;
    }
    final file = await _picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() {
      _newPhotos.add(file);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _expireAt ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 20),
    );
    if (result == null || !mounted) return;
    setState(() => _expireAt = result);
  }

  Future<void> _deleteExistingPhoto(int photoId) async {
    final item = _item;
    final itemId = item?.id;
    if (item == null || itemId == null) return;
    if ((item.photos.length + _newPhotos.length) <= 1) {
      Get.snackbar('提示', '至少保留一张照片');
      return;
    }
    await _api.deleteItemPhoto(itemId: itemId, photoId: photoId);
    await _loadDetail();
    Get.snackbar('提示', '照片已删除');
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!widget.isEdit && _newPhotos.isEmpty) {
      Get.snackbar('提示', '新增物资必须至少拍摄一张照片');
      return;
    }
    if (widget.isEdit &&
        ((_item?.photos.length ?? 0) + _newPhotos.length) <= 0) {
      Get.snackbar('提示', '编辑时至少保留一张照片');
      return;
    }

    final payload = <String, dynamic>{
      'scopeType': _scopeType,
      'category': _category,
      'name': _nameController.text.trim(),
      'location': _locationController.text.trim(),
      'expireAt': _expireAt == null ? '' : _formatDate(_expireAt!),
      'remark': _remarkController.text.trim(),
      'enabled': _enabled,
    };

    setState(() => _submitting = true);
    try {
      if (widget.isEdit) {
        final id = widget.initialItemId!;
        await _api.updateItem(id: id, fields: payload);
        if (_newPhotos.isNotEmpty) {
          await _api.addItemPhotos(id: id, photos: _newPhotos);
        }
      } else {
        await _api.createItem(fields: payload, photos: _newPhotos);
      }
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('提示', widget.isEdit ? '物资已更新' : '物资已创建');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(title: Text(widget.isEdit ? '编辑物资' : '新增物资')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 120.h),
                  children: [
                    _buildPhotoCard(),
                    SizedBox(height: 16.h),
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
                : Text(widget.isEdit ? '保存修改' : '创建物资'),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    final existingPhotos = _item?.photos ?? const [];
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
              Text(
                '物资照片',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppThemeColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(kIsWeb ? '上传图片' : '拍照'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '新增物资至少 1 张，最多 3 张；编辑时可追加或删除，但始终至少保留 1 张。',
            style: TextStyle(fontSize: 12.sp, color: AppThemeColors.textMuted),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              ...existingPhotos.map(
                (photo) => _PhotoTile(
                  image: Image.network(photo.resolvedUrl, fit: BoxFit.cover),
                  label: '已上传',
                  onDelete: photo.id == null
                      ? null
                      : () => _deleteExistingPhoto(photo.id!),
                ),
              ),
              ..._newPhotos.asMap().entries.map(
                (entry) => _PhotoTile(
                  image: _PickedPhotoPreview(file: entry.value),
                  label: '待上传',
                  onDelete: () {
                    setState(() {
                      _newPhotos.removeAt(entry.key);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
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
                Icons.edit_note_outlined,
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
            label: '名称',
            controller: _nameController,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入名称' : null,
          ),
          SizedBox(height: 14.h),
          _textField(
            label: '存放位置',
            controller: _locationController,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入存放位置' : null,
          ),
          if (_locationSuggestions.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _locationSuggestions
                  .map(
                    (item) => ActionChip(
                      label: Text(item),
                      onPressed: () => setState(() {
                        _locationController.text = item;
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          SizedBox(height: 14.h),
          _dateField(),
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
              label: '分类（默认食品）',
              value: _category,
              items: _dropsController.categoryLabels,
              onChanged: (value) => setState(() => _category = value),
            );
          }),
          SizedBox(height: 14.h),
          Obx(() {
            final _ = _dropsController.dictVersion.value;
            return _dropdownField(
              label: '可视范围（默认家庭共享）',
              value: _scopeType,
              items: _dropsController.scopeLabels,
              onChanged: (value) => setState(() => _scopeType = value),
            );
          }),
          SizedBox(height: 14.h),
          SwitchListTile(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('启用提醒（默认开启）'),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AppThemeColors.primary,
          ),
        ],
      ),
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

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('保质/截止日期'),
        SizedBox(height: 8.h),
        InkWell(
          onTap: _pickDate,
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
                    _expireAt == null ? '未设置日期' : _formatDate(_expireAt!),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppThemeColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _expireAt == null
                      ? null
                      : () => setState(() => _expireAt = null),
                  icon: const Icon(Icons.clear_rounded),
                ),
                const Icon(Icons.date_range_outlined),
              ],
            ),
          ),
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.label,
    required this.onDelete,
  });

  final Widget image;
  final String label;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 96.w,
          height: 96.w,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r)),
          child: image,
        ),
        Positioned(
          left: 6.w,
          bottom: 6.h,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppThemeColors.scrim,
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 9.sp, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          right: 4.w,
          top: 4.h,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: AppThemeColors.scrim,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickedPhotoPreview extends StatefulWidget {
  const _PickedPhotoPreview({required this.file});

  final XFile file;

  @override
  State<_PickedPhotoPreview> createState() => _PickedPhotoPreviewState();
}

class _PickedPhotoPreviewState extends State<_PickedPhotoPreview> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(covariant _PickedPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.file.name != widget.file.name) {
      _bytes = null;
      _error = null;
      _loadBytes();
    }
  }

  Future<void> _loadBytes() async {
    try {
      final bytes = await widget.file.readAsBytes();
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover);
    }

    if (_error != null) {
      return Container(
        color: AppThemeColors.surfaceSunken,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppThemeColors.textDisabled,
        ),
      );
    }

    return Container(
      color: AppThemeColors.surfaceSunken,
      alignment: Alignment.center,
      child: SizedBox(
        width: 20.w,
        height: 20.w,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
