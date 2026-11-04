import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../controllers/search_controller.dart' as search_controller;

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const _searchPlaceholder = 'assets/images/douban_default.png';

  late final search_controller.SearchController controller =
      Get.find<search_controller.SearchController>();

  @override
  void initState() {
    super.initState();
    final initialKeyword = Get.arguments;
    if (initialKeyword is String && initialKeyword.trim().isNotEmpty) {
      controller.searchController.text = initialKeyword.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(controller.performSearch());
      });
    }
  }

  bool _isResultState() {
    return controller.keyword.value.trim().isNotEmpty;
  }

  void _handleBack() {
    if (_isResultState()) {
      FocusScope.of(context).unfocus();
      controller.resetToInitialState();
      return;
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canPop = !_isResultState();
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          FocusScope.of(context).unfocus();
          controller.resetToInitialState();
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeColors.pageBackground,
            elevation: 0,
            titleSpacing: 0,
            leadingWidth: 48,
            leading: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                color: AppThemeColors.textPrimary,
              ),
              onPressed: _handleBack,
            ),
            title: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                height: 45.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22.r),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      const Color(0xFF448AFF).withValues(alpha: 0.15),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(1.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppThemeColors.surface,
                    borderRadius: BorderRadius.circular(21.r),
                  ),
                  child: TextField(
                    controller: controller.searchController,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.2,
                      color: AppThemeColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索资源',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 0,
                      ),
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        height: 1.2,
                        color: AppThemeColors.textDisabled,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.search_rounded,
                          color: AppThemeColors.textMuted,
                        ),
                        onPressed: () => controller.performSearch(),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => controller.performSearch(),
                  ),
                ),
              ),
            ),
            actions: [
              Obx(() {
                final showCancel =
                    controller.searched.value && !controller.searching.value;
                if (!showCancel) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    controller.resetToInitialState();
                  },
                  child: const Text(
                    '取消',
                    style: TextStyle(color: AppThemeColors.textPrimary),
                  ),
                );
              }),
            ],
          ),
          backgroundColor: AppThemeColors.pageBackground,
          body: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: Obx(() {
              final showRecommend = controller.keyword.value.trim().isEmpty;
              if (showRecommend) {
                return const _InitialArea();
              }

              if (!controller.searched.value) return const SizedBox.shrink();
              if (controller.searching.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = controller.panResources;
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Text(
                      '暂无搜索结果',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final textParts = item.textParts;
                  final title = textParts.title;
                  final description = textParts.description;
                  final itemUrl = item.url.trim();
                  final isTransferring = controller.transferringUrls.contains(
                    itemUrl,
                  );
                  final sourceRaw = item.source.trim();
                  final sourceName = sourceRaw.startsWith('tg:')
                      ? sourceRaw.substring(3)
                      : sourceRaw;
                  final hasSource = sourceName.isNotEmpty;
                  final dateStr = item.dateCnYmd.isNotEmpty
                      ? item.dateCnYmd
                      : item.datetime.trim();
                  final hasDate = dateStr.isNotEmpty;
                  final images = item.images;
                  final previewImage = images.isNotEmpty
                      ? images.first.trim()
                      : '';
                  final hasPreviewImage = previewImage.isNotEmpty;

                  return Container(
                    decoration: BoxDecoration(
                      color: AppThemeColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppThemeColors.border,
                        width: 1,
                      ),
                      boxShadow: AppThemeColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: SizedBox(
                                  width: 84.w,
                                  height: 112.h,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          _searchPlaceholder,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (hasPreviewImage)
                                        Positioned.fill(
                                          child: Image.network(
                                            previewImage,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) {
                                                  return Image.asset(
                                                    _searchPlaceholder,
                                                    fit: BoxFit.cover,
                                                  );
                                                },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: 112.h),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (hasSource || hasDate)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (hasSource)
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 8.w,
                                                          vertical: 4.h,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppThemeColors
                                                          .accent
                                                          .withValues(
                                                            alpha: 0.10,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999.r,
                                                          ),
                                                      border: Border.all(
                                                        color: AppThemeColors
                                                            .accent
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                top: 1.h,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .rocket_launch_rounded,
                                                            size: 10.w,
                                                            color:
                                                                AppThemeColors
                                                                    .accent,
                                                          ),
                                                        ),
                                                        SizedBox(width: 4.w),
                                                        Flexible(
                                                          child: Text(
                                                            sourceName,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 10.sp,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  AppThemeColors
                                                                      .accent,
                                                              height: 1.25,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (hasDate) ...[
                                              if (hasSource)
                                                SizedBox(width: 8.w),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    size: 11.w,
                                                    color: AppThemeColors
                                                        .textDisabled,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      color: AppThemeColors
                                                          .textDisabled,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      if (hasSource || hasDate)
                                        SizedBox(height: 10.h),
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppThemeColors.textPrimary,
                                          height: 1.45,
                                        ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        SizedBox(height: 6.h),
                                        Text(
                                          description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: AppThemeColors.textSecondary,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 底部操作栏
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppThemeColors.divider,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 复制链接
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: itemUrl),
                                    );
                                    Get.snackbar('提示', '已复制链接');
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        AppThemeColors.textSecondary,
                                    minimumSize: Size(0, 58.h),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16.r),
                                      ),
                                    ),
                                  ),
                                  icon: Icon(Icons.copy_rounded, size: 16.w),
                                  label: Text(
                                    '复制链接',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              // 竖分割
                              Container(
                                width: 1,
                                height: 30.h,
                                color: AppThemeColors.border,
                              ),
                              // 转存按钮
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: isTransferring
                                      ? null
                                      : () => controller.transferQuark(item),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isTransferring
                                        ? AppThemeColors.textDisabled
                                        : AppThemeColors.accent,
                                    minimumSize: Size(0, 58.h),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        bottomRight: Radius.circular(16.r),
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    isTransferring
                                        ? Icons.more_horiz_rounded
                                        : Icons.cloud_download_rounded,
                                    size: 16.w,
                                  ),
                                  label: Text(
                                    isTransferring ? '提交中...' : '一键转存',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ),
      );
    });
  }
}

class _InitialArea extends GetView<search_controller.SearchController> {
  const _InitialArea();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.historyKeywords.isNotEmpty) {
        return const _SearchHistorySection();
      }
      return const SizedBox.shrink();
    });
  }
}

class _SearchHistorySection
    extends GetView<search_controller.SearchController> {
  const _SearchHistorySection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final keywords = controller.historyKeywords;
      if (keywords.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppThemeColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => controller.clearHistoryKeywords(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0),
                  minimumSize: Size(0, 28.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppThemeColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: keywords
                .map((item) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppThemeColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppThemeColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => controller.useHistoryKeyword(item),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 10.w,
                              right: 6.w,
                              top: 6.h,
                              bottom: 6.h,
                            ),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => controller.removeHistoryKeyword(item),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 2.w,
                              right: 8.w,
                              top: 6.h,
                              bottom: 6.h,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14.w,
                              color: AppThemeColors.textDisabled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      );
    });
  }
}
