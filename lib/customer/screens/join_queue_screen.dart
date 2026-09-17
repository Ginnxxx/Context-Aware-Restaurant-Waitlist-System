import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/venue_context.dart';
import '../../shared/brand_widgets.dart';

class JoinQueueScreen extends StatelessWidget {
  const JoinQueueScreen({
    super.key,
    required this.partySize,
    required this.busy,
    required this.error,
    required this.demoMode,
    this.venue,
    required this.onNameChanged,
    required this.onPartyChanged,
    required this.onBack,
    required this.onJoin,
  });

  final int partySize;
  final bool busy;
  final String? error;
  final bool demoMode;
  final VenueContext? venue;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onPartyChanged;
  final VoidCallback onBack;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const BrandMark(),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let’s save\nyour place.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'A few details and you’re free to keep moving.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 30),
                const Text(
                  'YOUR NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  onChanged: onNameChanged,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Alex',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PARTY SIZE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: List.generate(6, (index) {
                      final value = index + 1;
                      final selected = value == partySize;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: () => onPartyChanged(value),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.forest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '$value',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? AppColors.white
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 26),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            SoftIcon(Icons.location_on_outlined),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Context-aware timing',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            StatusPill('ON'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We’ll use your location while you wait to recommend the best time to leave. You stay in control.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (demoMode) ...[
                  const StatusPill(
                    'DEMO DATA',
                    color: AppColors.amber,
                    icon: Icons.science_outlined,
                  ),
                  const SizedBox(height: 12),
                ],
                if (venue?.queueOpen == false) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.coral.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause_circle_outline_rounded,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The queue for ${venue?.name ?? 'this branch'} is currently paused by staff. New parties cannot join right now.',
                            style: const TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (error != null) ...[
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy || (venue?.queueOpen == false)
                        ? null
                        : onJoin,
                    style: (venue?.queueOpen == false)
                        ? FilledButton.styleFrom(
                            disabledBackgroundColor:
                                AppColors.coral.withValues(alpha: 0.2),
                            disabledForegroundColor: AppColors.coral,
                          )
                        : null,
                    child: Text(
                      busy
                          ? 'Joining…'
                          : (venue?.queueOpen == false)
                              ? 'Queue is paused'
                              : 'Confirm & join queue',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Current estimate: 24 minutes',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
