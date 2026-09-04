import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';

class TicketAction {
  const TicketAction({
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
  });

  final TicketStatus status;
  final String label;
  final IconData icon;
  final Color color;
}

List<TicketAction> actionsForStatus(TicketStatus status) => switch (status) {
  TicketStatus.waiting => const [
    TicketAction(
      status: TicketStatus.called,
      label: 'Call this party',
      icon: Icons.campaign_outlined,
      color: AppColors.forest,
    ),
    TicketAction(
      status: TicketStatus.arrived,
      label: 'Check in manually',
      icon: Icons.how_to_reg_rounded,
      color: AppColors.forest,
    ),
    TicketAction(
      status: TicketStatus.cancelled,
      label: 'Remove from queue',
      icon: Icons.close_rounded,
      color: AppColors.coral,
    ),
  ],
  TicketStatus.approaching => const [
    TicketAction(
      status: TicketStatus.called,
      label: 'Call this party',
      icon: Icons.campaign_outlined,
      color: AppColors.forest,
    ),
    TicketAction(
      status: TicketStatus.arrived,
      label: 'Check in manually',
      icon: Icons.how_to_reg_rounded,
      color: AppColors.forest,
    ),
    TicketAction(
      status: TicketStatus.cancelled,
      label: 'Remove from queue',
      icon: Icons.close_rounded,
      color: AppColors.coral,
    ),
  ],
  TicketStatus.called => const [
    TicketAction(
      status: TicketStatus.arrived,
      label: 'Check in manually',
      icon: Icons.how_to_reg_rounded,
      color: AppColors.forest,
    ),
    TicketAction(
      status: TicketStatus.noShow,
      label: 'Mark no-show',
      icon: Icons.person_off_outlined,
      color: AppColors.coral,
    ),
    TicketAction(
      status: TicketStatus.cancelled,
      label: 'Remove from queue',
      icon: Icons.close_rounded,
      color: AppColors.coral,
    ),
  ],
  TicketStatus.arrived => const [
    TicketAction(
      status: TicketStatus.seated,
      label: 'Mark seated',
      icon: Icons.table_restaurant_outlined,
      color: AppColors.forest,
    ),
    TicketAction(
      status: TicketStatus.cancelled,
      label: 'Cancel ticket',
      icon: Icons.close_rounded,
      color: AppColors.coral,
    ),
  ],
  _ => const [],
};
