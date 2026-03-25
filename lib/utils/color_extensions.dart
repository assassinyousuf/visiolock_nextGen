import 'dart:ui';

extension ColorOpacityExtension on Color {
  /// Replacement for `withOpacity` (deprecated).
  ///
  /// Expects [opacity] in the 0..1 range.
  Color withOpacity01(double opacity) {
    final a = (opacity * 255).round().clamp(0, 255);
    return withAlpha(a);
  }
}
