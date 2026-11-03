import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

class HomeStyleBackdrop extends StatelessWidget {
  const HomeStyleBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppThemeColors.pageBackground,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 420.h,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFE9F1FE),
                      const Color(0xFFF4F6FB).withValues(alpha: 0.7),
                      const Color(0xFFF4F6FB).withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -56.h,
              right: -28.w,
              child: _BackdropGlow(
                size: 248.w,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                innerAlpha: 0.02,
                stop: 0.36,
              ),
            ),
            Positioned(
              top: 132.h,
              left: -72.w,
              child: _BackdropGlow(
                size: 208.w,
                color: const Color(0xFF3E7BFA).withValues(alpha: 0.08),
                innerAlpha: 0.015,
                stop: 0.46,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({
    required this.size,
    required this.color,
    required this.innerAlpha,
    required this.stop,
  });

  final double size;
  final Color color;
  final double innerAlpha;
  final double stop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: innerAlpha),
              color.withValues(alpha: 0),
            ],
            stops: [0.0, stop, 1.0],
          ),
        ),
      ),
    );
  }
}
