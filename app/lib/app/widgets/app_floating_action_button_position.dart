import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppFloatingActionButtonPosition {
  const AppFloatingActionButtonPosition._();

  static const FloatingActionButtonLocation scaffoldLocation =
      _AppFloatingActionButtonLocation();

  static double get rightMargin => 20.w;

  static double get bottomSpacing => 68.h;

  static double bottomOffset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + bottomSpacing;
  }
}

class AppFloatingActionButtonAnchor extends StatelessWidget {
  const AppFloatingActionButtonAnchor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppFloatingActionButtonPosition.rightMargin,
      bottom: AppFloatingActionButtonPosition.bottomOffset(context),
      child: child,
    );
  }
}

class _AppFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _AppFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final contentBottom =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.minInsets.bottom;
    final x =
        scaffoldGeometry.scaffoldSize.width -
        fabSize.width -
        AppFloatingActionButtonPosition.rightMargin;
    final y =
        contentBottom -
        fabSize.height -
        AppFloatingActionButtonPosition.bottomSpacing;
    return Offset(x, y);
  }
}
