import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class DarkMetric extends StatelessWidget {
  const DarkMetric({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.white.withValues(alpha: .58),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
