import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double maxY;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i].clamp(0, maxY);
          final ratio = maxY == 0 ? 0.0 : (v / maxY);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 120 * ratio,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(labels[i], style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
