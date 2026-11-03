import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PlaylistLoadingView extends StatefulWidget {
  const PlaylistLoadingView({
    super.key,
    required this.message,
    this.icon,
    this.accentColor = const Color(0xFF2563FF),
    this.textColor = AppThemeColors.textSecondary,
  });

  final String message;
  final IconData? icon;
  final Color accentColor;
  final Color textColor;

  @override
  State<PlaylistLoadingView> createState() => _PlaylistLoadingViewState();
}

class _PlaylistLoadingViewState extends State<PlaylistLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final rotation = _controller.value * math.pi * 2;
          final glowOpacity = (0.1 + (math.sin(rotation) + 1) * 0.04)
              .clamp(0.0, 1.0)
              .toDouble();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: glowOpacity),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const CustomPaint(
                      size: Size.square(92),
                      painter: _SpinnerTrackPainter(),
                    ),
                    Transform.rotate(
                      angle: rotation,
                      child: CustomPaint(
                        size: const Size.square(92),
                        painter: _SpinnerGradientPainter(accentColor: accent),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppThemeColors.surface,
                        border: Border.all(color: AppThemeColors.border),
                      ),
                    ),
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        size: 20,
                        color: widget.accentColor,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: widget.textColor,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpinnerTrackPainter extends CustomPainter {
  const _SpinnerTrackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.1;
    final radius = (size.width - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppThemeColors.borderStrong;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpinnerGradientPainter extends CustomPainter {
  const _SpinnerGradientPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.1;
    final radius = (size.width - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: [
          AppThemeColors.borderStrong,
          AppThemeColors.borderStrong,
          accentColor.withValues(alpha: 0.96),
          accentColor,
          AppThemeColors.borderStrong,
        ],
        stops: const [0.0, 0.36, 0.58, 0.8, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerGradientPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
