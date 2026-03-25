import 'dart:math' as math;

import 'package:flutter/material.dart';

class BinaryPatternBackground extends StatelessWidget {
  final Color dotColor;
  final double spacing;
  final double dotRadius;
  final double opacity;

  const BinaryPatternBackground({
    super.key,
    required this.dotColor,
    this.spacing = 24,
    this.dotRadius = 1,
    this.opacity = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _BinaryPatternPainter(
            dotColor: dotColor,
            spacing: spacing,
            dotRadius: dotRadius,
          ),
        ),
      ),
    );
  }
}

class _BinaryPatternPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  const _BinaryPatternPainter({
    required this.dotColor,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;

    for (var y = 2.0; y < size.height; y += spacing) {
      for (var x = 2.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BinaryPatternPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius;
  }
}

class DashedBorderContainer extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color? backgroundColor;
  final double borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final EdgeInsetsGeometry padding;

  const DashedBorderContainer({
    super.key,
    required this.child,
    required this.borderColor,
    this.backgroundColor,
    this.borderRadius = 12,
    this.strokeWidth = 2,
    this.dashLength = 10,
    this.dashGap = 6,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: borderColor,
        radius: borderRadius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        dashGap: dashGap,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashLength, metric.length - distance);
        final segment = metric.extractPath(distance, distance + len);
        canvas.drawPath(segment, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap;
  }
}
