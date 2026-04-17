import 'package:flutter/material.dart';
import '../core/utils/helpers.dart';

class CrowdIndicator extends StatelessWidget {
  final CrowdLevel level;
  final String? customLabel;

  const CrowdIndicator({
    super.key,
    required this.level,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = Helpers.getCrowdColor(level);
    final label = customLabel ?? 'Crowd Level: ${Helpers.getCrowdLabel(level)}';
    final percentage = Helpers.getCrowdPercentage(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: const Color(0xFFE0E4EA),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
