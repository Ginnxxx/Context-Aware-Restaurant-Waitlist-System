import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../shared/brand_widgets.dart';

class NoActiveTicketScreen extends StatelessWidget {
  const NoActiveTicketScreen({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const BrandMark(),
                const SizedBox(height: 52),
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 48,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'No active queue yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Join from Home and your live position, travel guidance and arrival pass will appear here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Browse venue'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
