import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class HowTile extends StatelessWidget {
  const HowTile({
    super.key,
    required this.number,
    required this.icon,
    required this.label,
  });

  final String number;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 130,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.coral,
            ),
          ),
          const Spacer(),
          Icon(icon, color: AppColors.forest),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
