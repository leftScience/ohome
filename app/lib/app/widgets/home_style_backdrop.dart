import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeStyleBackdrop extends StatelessWidget {
  const HomeStyleBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF0B0D14)),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 400.h,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0D14),
                      const Color(0xFF15182A).withValues(alpha: 0.44),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -56.h,
              right: -28.w,
              child: _BackdropGlow(
                size: 248.w,
                color: const Color(0xFF6F42F5).withValues(alpha: 0.14),
                innerAlpha: 0.025,
                stop: 0.36,
              ),
            ),
            Positioned(
              top: 132.h,
              left: -72.w,
              child: _BackdropGlow(
                size: 208.w,
                color: const Color(0xFF3E7BFA).withValues(alpha: 0.1),
                innerAlpha: 0.018,
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
              Colors.transparent,
            ],
            stops: [0.0, stop, 1.0],
          ),
        ),
      ),
    );
  }
}
