import 'package:flutter/material.dart';

import '../../data/queue_repository.dart';
import '../../domain/queue_ticket.dart';
import '../widgets/customer_message_card.dart';
import '../widgets/customer_page_header.dart';
import '../widgets/history_ticket_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});

  final QueueRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<QueueTicket> history = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final value = await widget.repository.getMyTicketHistory();
      if (mounted) setState(() => history = value);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
          children: [
            const CustomerPageHeader(
              eyebrow: 'YOUR VISITS',
              title: 'Queue history',
              subtitle: 'Completed, cancelled and missed queue entries.',
            ),
            const SizedBox(height: 24),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              CustomerMessageCard(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load history',
                message: error!,
                actionLabel: 'Try again',
                onAction: load,
              )
            else if (history.isEmpty)
              const CustomerMessageCard(
                icon: Icons.history_toggle_off_rounded,
                title: 'No past visits',
                message:
                    'Once a queue visit is completed or cancelled, it will be kept here.',
              )
            else
              for (final ticket in history) ...[
                HistoryTicketCard(ticket: ticket),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    ),
  );
}
