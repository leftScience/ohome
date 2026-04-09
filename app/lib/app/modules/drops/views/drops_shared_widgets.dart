import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/drops_event_model.dart';
import '../../../data/models/drops_item_model.dart';
import '../../../theme/app_theme.dart';
import '../controllers/drops_controller.dart';
import '../controllers/drops_events_controller.dart';
import '../controllers/drops_items_controller.dart';
import '../drops_catalog.dart';

String formatDropsDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

class DropsItemsPanel extends StatelessWidget {
  const DropsItemsPanel({
    super.key,
    required this.controller,
    required this.filterPadding,
    required this.listPadding,
    this.emptyText = '暂无物资记录',
  });

  final DropsItemsController controller;
  final EdgeInsetsGeometry filterPadding;
  final EdgeInsetsGeometry listPadding;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: filterPadding,
          child: _DropsItemsFilterCard(controller: controller),
        ),
        Expanded(
          child: Obx(() {
            final dropsController = Get.find<DropsController>();
            final _ = dropsController.dictVersion.value;
            if (controller.loading.value && controller.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => controller.loadItems(refresh: true),
                child: ListView(
                  padding: listPadding,
                  children: [
                    SizedBox(height: 120.h),
                    _EmptyState(
                      icon: Icons.inventory_2_outlined,
                      text: emptyText,
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => controller.loadItems(refresh: true),
              child: ListView.separated(
                controller: controller.scrollController,
                padding: listPadding,
                itemCount:
                    controller.items.length +
                    (controller.hasMore.value ? 1 : 0),
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (_, index) {
                  if (index >= controller.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = controller.items[index];
                  return DropsItemCard(
                    item: item,
                    onTap: () => controller.openDetail(item),
                    onDelete: () => controller.deleteItem(item),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class DropsEventsPanel extends StatelessWidget {
  const DropsEventsPanel({
    super.key,
    required this.controller,
    required this.filterPadding,
    required this.listPadding,
    this.emptyText = '暂无重要日期',
  });

  final DropsEventsController controller;
  final EdgeInsetsGeometry filterPadding;
  final EdgeInsetsGeometry listPadding;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: filterPadding,
          child: _DropsEventsFilterCard(controller: controller),
        ),
        Expanded(
          child: Obx(() {
            final dropsController = Get.find<DropsController>();
            final _ = dropsController.dictVersion.value;
            if (controller.loading.value && controller.events.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.events.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => controller.loadEvents(refresh: true),
                child: ListView(
                  padding: listPadding,
                  children: [
                    SizedBox(height: 120.h),
                    _EmptyState(
                      icon: Icons.event_note_outlined,
                      text: emptyText,
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => controller.loadEvents(refresh: true),
              child: ListView.separated(
                controller: controller.scrollController,
                padding: listPadding,
                itemCount:
                    controller.events.length +
                    (controller.hasMore.value ? 1 : 0),
                separatorBuilder: (_, _) => SizedBox(height: 14.h),
                itemBuilder: (_, index) {
                  if (index >= controller.events.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final event = controller.events[index];
                  return DropsEventCard(
                    event: event,
                    onDelete: () => controller.deleteEvent(event),
                    onEdit: () => controller.openEdit(event),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class DropsItemCard extends StatelessWidget {
  const DropsItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
  });

  final DropsItemModel item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dropsController = Get.find<DropsController>();
    final color = dropsCategoryColors[item.category] ?? AppThemeColors.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76.w,
                height: 76.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.r),
                  image: item.coverUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(item.coverUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: item.coverUrl.isEmpty
                    ? Icon(
                        Icons.photo_camera_back_outlined,
                        size: 28.w,
                        color: Colors.white24,
                      )
                    : null,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _DropsTag(
                          label: dropsController.categoryLabel(item.category),
                          color: color,
                        ),
                        _DropsTag(
                          label: dropsController.scopeLabel(item.scopeType),
                          color: AppThemeColors.primary,
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14.w,
                          color: Colors.white54,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            item.location.isEmpty ? '未填写位置' : item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 14.w,
                          color: Colors.white54,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            item.expireAt == null
                                ? '未设置截止日期'
                                : '截止日期 ${formatDropsDate(item.expireAt!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null) ...[
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.white54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
   ),
  ),
 );
}
}

class DropsEventCard extends StatelessWidget {
  const DropsEventCard({
    super.key,
    required this.event,
    this.onDelete,
    this.onEdit,
  });

  final DropsEventModel event;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final dropsController = Get.find<DropsController>();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppThemeColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.cake_outlined,
                  color: AppThemeColors.primary,
                  size: 24.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.white54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _DropsTag(
                label: dropsController.eventTypeLabel(event.eventType),
                color: AppThemeColors.primary,
              ),
              _DropsTag(
                label: dropsController.calendarLabel(event.calendarType),
                color: AppThemeColors.primary,
              ),
              _DropsTag(
                label: dropsController.scopeLabel(event.scopeType),
                color: AppThemeColors.primary,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 16.w,
                color: Colors.white54,
              ),
              SizedBox(width: 6.w),
              Text(
                event.nextOccurAt == null
                    ? '下一次：未计算'
                    : '下一次：${formatDropsDate(event.nextOccurAt!)}',
                style: TextStyle(fontSize: 13.sp, color: Colors.white70),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes_outlined, size: 16.w, color: Colors.white54),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  event.remark.isEmpty
                      ? (event.enabled ? '已启用提醒' : '已关闭提醒')
                      : event.remark,
                  style: TextStyle(fontSize: 13.sp, color: Colors.white54),
                ),
              ),
            ],
          ),
          if (onEdit != null) ...[
            SizedBox(height: 16.h),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('编辑'),
                onPressed: onEdit,
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

class _DropsItemsFilterCard extends StatelessWidget {
  const _DropsItemsFilterCard({required this.controller});

  final DropsItemsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: TextField(
              controller: controller.keywordController,
              onSubmitted: (_) => controller.search(),
              decoration: _searchDecoration('搜索名称、位置、备注'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropsEventsFilterCard extends StatelessWidget {
  const _DropsEventsFilterCard({required this.controller});

  final DropsEventsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: TextField(
              controller: controller.keywordController,
              onSubmitted: (_) => controller.search(),
              decoration: _searchDecoration('搜索标题或备注'),
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _searchDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: Colors.white54, fontSize: 14.5.sp, letterSpacing: 0.3),
    prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 22.w),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24.r),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24.r),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24.r),
      borderSide: BorderSide(
        color: const Color(0xFF2B78FF).withValues(alpha: 0.5),
        width: 1.2,
      ),
    ),
  );
}

class _DropsTag extends StatelessWidget {
  const _DropsTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 108.w,
            height: 108.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, size: 56.w, color: Colors.white24),
          ),
          SizedBox(height: 18.h),
          Text(
            text,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
