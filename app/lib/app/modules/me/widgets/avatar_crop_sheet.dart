import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';

class AvatarCropSheet extends StatefulWidget {
  const AvatarCropSheet({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  static Future<Uint8List?> show({required Uint8List imageBytes}) {
    return Get.bottomSheet<Uint8List>(
      AvatarCropSheet(imageBytes: imageBytes),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<AvatarCropSheet> createState() => _AvatarCropSheetState();
}

class _AvatarCropSheetState extends State<AvatarCropSheet> {
  final CropController _cropController = CropController();

  CropStatus _status = CropStatus.nothing;
  bool _cropping = false;

  bool get _canSubmit => _status == CropStatus.ready && !_cropping;

  void _submit() {
    if (!_canSubmit) return;

    setState(() {
      _cropping = true;
    });
    _cropController.cropCircle();
  }

  void _handleCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        if (!mounted) return;
        Get.back<Uint8List>(result: croppedImage);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _cropping = false;
        });
        Get.snackbar('提示', '头像裁剪失败：$cause');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      height: math.min(screenHeight * 0.84, 760.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h + bottomInset),
          child: Column(
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '裁剪头像',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          '拖动或缩放图片，让头像落在圆形区域内。',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _cropping ? null : () => Get.back<void>(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 22.w,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090909),
                    borderRadius: BorderRadius.circular(26.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Crop(
                    controller: _cropController,
                    image: widget.imageBytes,
                    withCircleUi: true,
                    interactive: true,
                    fixCropRect: true,
                    radius: 28.r,
                    baseColor: const Color(0xFF090909),
                    maskColor: Colors.black.withValues(alpha: 0.72),
                    filterQuality: FilterQuality.high,
                    willUpdateScale: (newScale) => newScale < 5,
                    progressIndicator: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    onStatusChanged: (status) {
                      if (!mounted) return;
                      setState(() {
                        _status = status;
                        if (status != CropStatus.cropping) {
                          _cropping = false;
                        }
                      });
                    },
                    onCropped: _handleCropped,
                    cornerDotBuilder: (size, edgeAlignment) =>
                        const SizedBox.shrink(),
                    initialRectBuilder: InitialRectBuilder.withBuilder(
                      (viewportRect, imageRect) {
                        final padding = 28.w;
                        final side =
                            math.min(viewportRect.width, viewportRect.height) -
                            padding * 2;
                        final left =
                            viewportRect.left + (viewportRect.width - side) / 2;
                        final top =
                            viewportRect.top +
                            (viewportRect.height - side) / 2;
                        return Rect.fromLTWH(left, top, side, side);
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cropping ? null : () => Get.back<void>(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(50.h),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
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
                    child: FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(50.h),
                        backgroundColor: AppThemeColors.primary,
                        disabledBackgroundColor: AppThemeColors.primary
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: _cropping
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              '确认上传',
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
    );
  }
}
