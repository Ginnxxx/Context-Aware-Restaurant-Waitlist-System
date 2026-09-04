import 'package:flutter/material.dart';

import '../../shared/brand_widgets.dart';

class EmptyQueue extends StatelessWidget {
  const EmptyQueue({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAF7),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const SoftIcon(Icons.done_all_rounded, color: Color(0xFF267B67)),
        const SizedBox(height: 12),
        Text(
          'The live queue is clear',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'New parties will appear here automatically.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
