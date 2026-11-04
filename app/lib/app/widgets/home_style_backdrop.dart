import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

/// 首页与主 Tab 共用的动态极光流体背景。
///
/// 通过慢速呼吸的渐变光球与微光网格，营造通透、灵动的现代媒体中心氛围。
/// 自动响应系统的无障碍「减少动态效果」设置。
class HomeStyleBackdrop extends StatefulWidget {
  const HomeStyleBackdrop({super.key});

  @override
  State<HomeStyleBackdrop> createState() => _HomeStyleBackdropState();
}

class _HomeStyleBackdropState extends State<HomeStyleBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations && _controller.isAnimating) {
      _controller.stop();
    } else if (!disableAnimations && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppThemeColors.pageBackground,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = Curves.easeInOutSine.transform(_controller.value);
                final wave = math.sin(_controller.value * math.pi);

                return Stack(
                  children: [
                    // 顶部天光渐变基底
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 440.h,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFE2EEFF),
                              const Color(0xFFEDE9FE).withValues(alpha: 0.72),
                              AppThemeColors.pageBackground.withValues(
                                alpha: 0,
                              ),
                            ],
                            stops: const [0.0, 0.48, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 右上角主极光球（紫罗兰 → 品牌蓝呼吸位移）
                    Positioned(
                      top: (-68 + 18 * t).h,
                      right: (-36 + 22 * (1 - t)).w,
                      child: _BackdropGlow(
                        size: (280 + 18 * wave).w,
                        color: Color.lerp(
                          const Color(0xFF7C4DFF),
                          const Color(0xFF4F46E5),
                          t,
                        )!.withValues(alpha: 0.14),
                        innerAlpha: 0.04,
                        stop: 0.42,
                      ),
                    ),
                    // 左上角辅极光球（天青蓝呼吸漂移）
                    Positioned(
                      top: (84 - 20 * t).h,
                      left: (-68 + 24 * t).w,
                      child: _BackdropGlow(
                        size: (240 + 16 * (1 - wave)).w,
                        color: Color.lerp(
                          const Color(0xFF186EEF),
                          const Color(0xFF06B6D4),
                          t,
                        )!.withValues(alpha: 0.12),
                        innerAlpha: 0.03,
                        stop: 0.48,
                      ),
                    ),
                    // 中部暖粉微光点缀，提升卡片透光层次
                    Positioned(
                      top: (186 + 14 * (1 - t)).h,
                      right: (42 + 28 * t).w,
                      child: _BackdropGlow(
                        size: 168.w,
                        color: const Color(
                          0xFFEC4899,
                        ).withValues(alpha: 0.055 + 0.02 * wave),
                        innerAlpha: 0.015,
                        stop: 0.45,
                      ),
                    ),
                    // 顶部科技感微光点阵
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 260.h,
                      child: CustomPaint(
                        painter: _SubtleDotMatrixPainter(
                          opacity: 0.045 + 0.015 * wave,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
    return Container(
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
    );
  }
}

class _SubtleDotMatrixPainter extends CustomPainter {
  const _SubtleDotMatrixPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 22.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (double y = 12; y < size.height; y += spacing) {
      final verticalFade = (1.0 - (y / size.height)).clamp(0.0, 1.0);
      final alpha = opacity * verticalFade * verticalFade;
      if (alpha <= 0.004) continue;
      paint.color = AppThemeColors.primary.withValues(alpha: alpha);
      for (double x = 14; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleDotMatrixPainter oldDelegate) {
    return (oldDelegate.opacity - opacity).abs() > 0.002;
  }
}
