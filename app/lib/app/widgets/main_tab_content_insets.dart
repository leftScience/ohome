import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 首页 / 主 tab 页共用的底部悬浮栏尺寸，避免各页面重复写死间距。
class MainTabContentInsets {
  const MainTabContentInsets._();

  static const double tabBarHeight = 60;
  static const double floatingBottomSpacing = 14;
  static const double historyBannerGap = 10;
  static const double historyBannerHeight = 58;
  static const double _contentGap = 10;

  /// 历史记录条悬浮时，推荐列表需要额外留出的底部滚动空间。
  static double get historyBannerOverlap =>
      historyBannerGap + historyBannerHeight.h + _contentGap.h;

  /// 主 tab 内容需要预留的底部高度。
  ///
  /// [withHistoryBanner] 为 true 时额外预留首页历史记录卡片的高度。
  static double bottom(BuildContext context, {bool withHistoryBanner = false}) {
    // Scaffold 的 bottomNavigationBar 会移除 body 的 padding，
    // 因此这里读取未被移除的 viewPadding 来获取系统底部安全区。
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final navBottom = safeBottom > floatingBottomSpacing
        ? safeBottom
        : floatingBottomSpacing;
    final bannerHeight = withHistoryBanner
        ? historyBannerGap + historyBannerHeight.h
        : 0.0;
    return navBottom + tabBarHeight + bannerHeight + _contentGap.h;
  }
}
