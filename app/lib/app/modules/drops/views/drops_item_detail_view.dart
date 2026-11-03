import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/api/drops.dart';
import '../../../data/models/drops_item_model.dart';
import '../../../theme/app_theme.dart';
import '../controllers/drops_controller.dart';
import 'drops_item_form_view.dart';

class DropsItemDetailView extends StatefulWidget {
  const DropsItemDetailView({super.key, required this.itemId});

  final int itemId;

  @override
  State<DropsItemDetailView> createState() => _DropsItemDetailViewState();
}

class _DropsItemDetailViewState extends State<DropsItemDetailView> {
  final _api = Get.find<DropsApi>();
  DropsItemModel? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Get.find<DropsController>().ensureDictsLoaded();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await _api.getItemDetail(widget.itemId);
      if (!mounted) return;
      setState(() => _item = detail);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit() async {
    final changed = await Get.to<bool>(
      () => DropsItemFormView(initialItemId: widget.itemId),
    );
    if (changed == true) {
      await _load();
      Get.find<DropsController>().refreshOverview();
      if (mounted) setState(() {});
    }
  }

  Future<void> _delete() async {
    final item = _item;
    if (item == null) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除 ${item.name} 后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.deleteItem(widget.itemId);
    if (!mounted) return;
    Get.back(result: true);
    Get.snackbar('提示', '物资已删除');
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final dropsController = Get.find<DropsController>();
    return Scaffold(
      backgroundColor: AppThemeColors.pageBackground,
      appBar: AppBar(
        title: const Text('物资详情'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : item == null
          ? const Center(
              child: Text(
                '物资不存在',
                style: TextStyle(color: AppThemeColors.textMuted),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Image Section ──
                  SizedBox(
                    height: 320.h,
                    child: Stack(
                      children: [
                        PageView(
                          children: item.photos.isEmpty
                              ? [
                                  Container(
                                    color: AppThemeColors.surfaceSunken,
                                    child: Center(
                                      child: Icon(
                                        Icons.photo_camera_back_outlined,
                                        size: 64.w,
                                        color: AppThemeColors.textDisabled,
                                      ),
                                    ),
                                  ),
                                ]
                              : item.photos
                                    .map(
                                      (photo) => Image.network(
                                        photo.resolvedUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    )
                                    .toList(growable: false),
                        ),
                        // Dark Gradient Overlay for readability
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 120.h,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppThemeColors.pageBackground,
                                  AppThemeColors.pageBackground.withValues(
                                    alpha: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Title & Highlights Card ──
                  Transform.translate(
                    offset: Offset(0, -30.h),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: AppThemeColors.surface,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: AppThemeColors.border),
                          boxShadow: AppThemeColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppThemeColors.textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: [
                                _Tag(
                                  label: dropsController.categoryLabel(
                                    item.category,
                                  ),
                                ),
                                _Tag(
                                  label: dropsController.scopeLabel(
                                    item.scopeType,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Details Section ──
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeColors.surface,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: AppThemeColors.border),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            Icons.location_on_outlined,
                            '存放位置',
                            item.location.isEmpty ? '未填写' : item.location,
                          ),
                          _infoRow(
                            Icons.event_outlined,
                            '截止日期',
                            item.expireAt == null
                                ? '未设置'
                                : _formatDate(item.expireAt!),
                          ),
                          _infoRow(
                            Icons.notifications_active_outlined,
                            '提醒状态',
                            item.enabled ? '已启用' : '已关闭',
                          ),
                          _infoRow(
                            Icons.photo_library_outlined,
                            '照片数量',
                            '${item.photoCount} 张',
                          ),
                          if (item.remark.isNotEmpty)
                            _infoRow(
                              Icons.notes_outlined,
                              '备注',
                              item.remark,
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: AppThemeColors.divider)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.w, color: AppThemeColors.textMuted),
          SizedBox(width: 12.w),
          SizedBox(
            width: 72.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppThemeColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppThemeColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = AppThemeColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.sp, color: effectiveColor),
      ),
    );
  }
}
