import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../shared/brand_widgets.dart';

class CustomerPageHeader extends StatelessWidget {
  const CustomerPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const BrandMark(),
      const SizedBox(height: 32),
      Text(
        eyebrow,
        style: const TextStyle(
          color: AppColors.coral,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 7),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 7),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
