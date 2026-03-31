import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/models/todo_item_model.dart';
import '../controllers/home_controller.dart';

class HomeTodoPanel extends StatelessWidget {
  const HomeTodoPanel({super.key});

  static const Color _panelAccent = Color(0xFF6C63FF);
  static const Color _panelBackground = Color(0xFF13141F);
  static const Color _panelBackgroundSoft = Color(0xFF1A1C29);
  static const Color _panelBorder = Color(0xFF2E3045);
  static const Color _tileBackgroundSoft = Color(0xFF1F2131);
  static const Color _tilePendingStart = Color(0xFF33206B);
  static const Color _tilePendingMiddle = Color(0xFF272A42);
  static const Color _tilePendingEnd = Color(0xFF1C1E30);
  static const Color _textMuted = Color(0xFF8E919A);

  HomeController get controller => Get.find<HomeController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pendingItems = controller.pendingTodoItems;
      final completedItems = controller.completedTodoItems;
      final loading = controller.todoLoading.value;
      final submitting = controller.todoSubmitting.value;
      final reordering = controller.todoReordering.value;
      final expanded = controller.completedExpanded.value;

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF191A21),
              _panelBackground,
              const Color(0xFF111216),
            ],
          ),
          border: Border.all(color: _panelBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26.r),
          child: Stack(
            children: [
              Positioned(
                top: -28.h,
                left: 20.w,
                child: IgnorePointer(
                  child: Container(
                    width: 96.w,
                    height: 96.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _panelAccent.withValues(alpha: 0.13),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -24.h,
                right: -8.w,
                child: IgnorePointer(
                  child: Container(
                    width: 102.w,
                    height: 102.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(15.w, 10.h, 15.w, 15.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(submitting: submitting),
                    SizedBox(height: 12.h),
                    if (!controller.isLoggedIn)
                      _buildHintCard(
                        icon: Icons.lock_outline_rounded,
                        title: '登录后查看和管理待办',
                        subtitle: '右上角按钮会在登录后可用',
                      )
                    else if (loading && controller.todoItems.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: _panelAccent,
                            ),
                          ),
                        ),
                      )
                    else if (pendingItems.isEmpty && completedItems.isEmpty)
                      _buildHintCard(
                        icon: Icons.add_task_rounded,
                        title: '还没有待办事项',
                        subtitle: '点击右上角 + 新建任务',
                      )
                    else ...[
                      if (pendingItems.isNotEmpty)
                        _buildPendingList(
                          items: pendingItems,
                          reordering: reordering,
                        ),
                      if (pendingItems.isNotEmpty && completedItems.isNotEmpty)
                        SizedBox(height: 10.h),
                      if (completedItems.isNotEmpty)
                        _buildCompletedSection(
                          items: completedItems,
                          expanded: expanded,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader({required bool submitting}) {
    final canCreate = controller.isLoggedIn && !submitting;

    return Row(
      children: [
        Container(
          width: 5.w,
          height: 22.h,
          decoration: BoxDecoration(
            color: _panelAccent,
            borderRadius: BorderRadius.circular(999.r),
            boxShadow: [
              BoxShadow(
                color: _panelAccent.withValues(alpha: 0.24),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            '待办事项',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canCreate ? _showCreateDialog : null,
            borderRadius: BorderRadius.circular(16.r),
            child: Ink(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: canCreate ? 0.06 : 0.03),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: canCreate ? 0.06 : 0.03,
                  ),
                ),
              ),
              child: Center(
                child: submitting
                    ? SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: _panelAccent,
                        ),
                      )
                    : Icon(
                        Icons.add_rounded,
                        size: 19.w,
                        color: canCreate ? Colors.white70 : Colors.white24,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingList({
    required List<TodoItemModel> items,
    required bool reordering,
  }) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: controller.canReorderPendingTodos
          ? (oldIndex, newIndex) => controller.reorderPendingTodos(
              oldIndex: oldIndex,
              newIndex: newIndex,
            )
          : (_, _) {},
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final scale =
                1 + (0.015 * Curves.easeOut.transform(animation.value));
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.26),
                        blurRadius: 14,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: _panelAccent.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey<String>('todo_pending_${item.id ?? index}'),
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 8.h),
          child: _buildTodoTile(
            item,
            index: index,
            showDragHandle: true,
            reordering: reordering,
          ),
        );
      },
    );
  }

  Widget _buildCompletedSection({
    required List<TodoItemModel> items,
    required bool expanded,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: _panelBackgroundSoft.withValues(alpha: 0.72),
        border: Border.all(color: _panelBorder.withValues(alpha: 0.92)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: controller.toggleCompletedExpanded,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Row(
                children: [
                  Container(
                    width: 7.w,
                    height: 7.w,
                    decoration: BoxDecoration(
                      color: _panelAccent.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      '已完成 ${items.length} 项',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18.w,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == items.length - 1 ? 0 : 6.h,
                      ),
                      child: _buildTodoTile(items[i], showDragHandle: false),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodoTile(
    TodoItemModel item, {
    int? index,
    required bool showDragHandle,
    bool reordering = false,
  }) {
    final processing = controller.isProcessingTodo(item.id);
    final completed = item.completed;
    final tileColors = completed
        ? [
            _tileBackgroundSoft.withValues(alpha: 0.92),
            _panelBackgroundSoft.withValues(alpha: 0.9),
          ]
        : [_tilePendingStart, _tilePendingMiddle, _tilePendingEnd];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: processing ? null : () => _showActionSheet(item),
        borderRadius: BorderRadius.circular(20.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: 56.h),
          padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tileColors,
            ),
            border: Border.all(
              color: completed
                  ? _panelBorder.withValues(alpha: 0.96)
                  : _panelAccent.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: completed ? 0.12 : 0.18),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
              if (!completed)
                BoxShadow(
                  color: _panelAccent.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildToggleButton(item, processing),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  item.title.isEmpty ? '未命名待办' : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.2,
                    fontWeight: completed ? FontWeight.w600 : FontWeight.w700,
                    color: completed ? _textMuted : Colors.white,
                    decoration: completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: _textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              if (processing)
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _panelAccent,
                  ),
                )
              else
                _buildTrailingHandle(
                  item: item,
                  index: index,
                  showDragHandle: showDragHandle,
                  reordering: reordering,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(TodoItemModel item, bool processing) {
    final completed = item.completed;
    final borderColor = completed
        ? _panelAccent.withValues(alpha: 0.36)
        : _panelAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: processing ? null : () => controller.toggleTodoCompleted(item),
        borderRadius: BorderRadius.circular(999.r),
        child: Ink(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? _panelAccent.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: completed
                  ? borderColor
                  : borderColor.withValues(alpha: 0.88),
              width: 1.8,
            ),
          ),
          child: completed
              ? Icon(Icons.check_rounded, size: 13.w, color: _panelAccent)
              : null,
        ),
      ),
    );
  }

  Widget _buildTrailingHandle({
    required TodoItemModel item,
    required int? index,
    required bool showDragHandle,
    required bool reordering,
  }) {
    final dots = Opacity(
      opacity: showDragHandle && !reordering ? 1 : 0.68,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 1.h),
        child: _TodoGripDots(
          color: item.completed ? Colors.white24 : Colors.white30,
        ),
      ),
    );

    if (showDragHandle && index != null) {
      return ReorderableDelayedDragStartListener(
        index: index,
        enabled: !controller.isProcessingTodo(item.id) && !reordering,
        child: dots,
      );
    }

    return dots;
  }

  Widget _buildHintCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: _tileBackgroundSoft.withValues(alpha: 0.88),
        border: Border.all(color: _panelBorder.withValues(alpha: 0.92)),
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Icon(icon, color: Colors.white54, size: 16.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    height: 1.35,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final inputController = TextEditingController();
    try {
      final title = await Get.dialog<String>(
        AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFF1C1E25),
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(color: _panelBorder.withValues(alpha: 0.98)),
          ),
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
          contentPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
          actionsPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
          title: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: _panelAccent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: _panelAccent.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 19.w,
                  color: _panelAccent,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '新建待办',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '支持多行输入，保存时会自动整理成一条待办标题',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        height: 1.35,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '任务内容',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                  child: TextField(
                    controller: inputController,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 4,
                    maxLines: 8,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      height: 1.45,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: '例如：整理今日片单、更新分类标签、回复重要消息',
                      hintStyle: TextStyle(
                        color: Colors.white30,
                        fontSize: 12.sp,
                        height: 1.4,
                      ),
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            Obx(() {
              final submitting = controller.todoSubmitting.value;
              return FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _panelAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: submitting
                    ? null
                    : () => Get.back(result: inputController.text),
                child: submitting
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('添加任务'),
              );
            }),
          ],
        ),
      );
      if (title == null) return;
      await controller.addTodoItem(_normalizeTodoDraft(title));
    } finally {
      inputController.dispose();
    }
  }

  String _normalizeTodoDraft(String value) {
    return value
        .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  Future<void> _showActionSheet(TodoItemModel item) async {
    final action = await Get.bottomSheet<_TodoAction>(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border(
            top: BorderSide(color: _panelBorder.withValues(alpha: 0.98)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  item.title.isEmpty ? '未命名待办' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16.h),
                _buildSheetAction(
                  label: '编辑待办',
                  icon: Icons.edit_outlined,
                  onTap: () => Get.back(result: _TodoAction.edit),
                ),
                SizedBox(height: 10.h),
                _buildSheetAction(
                  label: '删除待办',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onTap: () => Get.back(result: _TodoAction.delete),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
    );

    if (action == null) return;
    await _handleTodoAction(item, action);
  }

  Widget _buildSheetAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final foreground = destructive ? const Color(0xFFFF8A80) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground.withValues(alpha: 0.92), size: 20.w),
              SizedBox(width: 12.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showTodoTitleDialog({
    required String title,
    required String hintText,
    required String confirmText,
    String initialValue = '',
  }) async {
    final textController = TextEditingController(text: initialValue);
    try {
      return await Get.dialog<String>(
        AlertDialog(
          backgroundColor: const Color(0xFF1C1E25),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(color: _panelBorder.withValues(alpha: 0.98)),
          ),
          titlePadding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 10.h),
          contentPadding: EdgeInsets.fromLTRB(22.w, 0, 22.w, 10.h),
          actionsPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Get.back(result: value),
            style: TextStyle(fontSize: 14.sp, color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 14.h,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.r),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.r),
                borderSide: BorderSide(
                  color: _panelAccent.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _panelAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Get.back(result: textController.text),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } finally {
      textController.dispose();
    }
  }

  Future<void> _handleTodoAction(TodoItemModel item, _TodoAction action) async {
    switch (action) {
      case _TodoAction.edit:
        await _showEditDialog(item);
        return;
      case _TodoAction.delete:
        await _confirmDelete(item);
        return;
    }
  }

  Future<void> _showEditDialog(TodoItemModel item) async {
    final result = await _showTodoTitleDialog(
      title: '编辑待办',
      hintText: '请输入待办标题',
      confirmText: '保存',
      initialValue: item.title,
    );
    if (result == null) return;
    await controller.updateTodoTitle(item: item, title: result);
  }

  Future<void> _confirmDelete(TodoItemModel item) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF1C1E25),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: _panelBorder.withValues(alpha: 0.98)),
        ),
        title: Text(
          '删除待办',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          item.title.isEmpty ? '确定删除这条待办吗？' : '确定删除「${item.title}」吗？',
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.45,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteTodoItem(item);
  }
}

class _TodoGripDots extends StatelessWidget {
  const _TodoGripDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12.w,
      height: 14.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_buildDotRow(), _buildDotRow(), _buildDotRow()],
      ),
    );
  }

  Widget _buildDotRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_buildDot(), _buildDot()],
    );
  }

  Widget _buildDot() {
    return Container(
      width: 2.5.w,
      height: 2.5.w,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

enum _TodoAction { edit, delete }
