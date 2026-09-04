import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../shared/brand_widgets.dart';

class PreferenceTile extends StatelessWidget {
  const PreferenceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    leading: SoftIcon(
      icon,
      color: AppColors.forest,
      background: AppColors.mint,
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle),
    trailing: TextButton(onPressed: onTap, child: Text(status)),
  );
}
