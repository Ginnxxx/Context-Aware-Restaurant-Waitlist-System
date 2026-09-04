import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class GuestDot extends StatelessWidget {
  const GuestDot({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 13,
    backgroundColor: color,
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: AppColors.ink,
      ),
    ),
  );
}
