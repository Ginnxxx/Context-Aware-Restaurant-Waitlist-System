import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';

class TableAssignmentDialog extends StatefulWidget {
  const TableAssignmentDialog({super.key, required this.ticket});

  final QueueTicket ticket;

  static Future<String?> show(
    BuildContext context, {
    required QueueTicket ticket,
  }) => showDialog<String>(
    context: context,
    builder: (context) => TableAssignmentDialog(ticket: ticket),
  );

  @override
  State<TableAssignmentDialog> createState() => _TableAssignmentDialogState();
}

class _TableAssignmentDialogState extends State<TableAssignmentDialog> {
  final TextEditingController _customController = TextEditingController();
  String _selectedTable = 'Table 1';
  bool _custom = false;

  static const List<String> _presets = [
    'Table 1',
    'Table 2',
    'Table 3',
    'Table 4',
    'Table 5',
    'Table 6',
    'Booth 1',
    'Booth 2',
    'Patio 1',
    'Patio 2',
    'Bar 1',
    'Bar 2',
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _confirm() {
    final table = _custom
        ? _customController.text.trim()
        : _selectedTable.trim();
    if (table.isEmpty) return;
    Navigator.pop(context, table);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.table_restaurant_outlined, color: AppColors.forest),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Table'),
              Text(
                '${widget.ticket.guestName} • ${widget.ticket.partySize} guests',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select an available table or booth for this party:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  label: Text(preset),
                  selected: !_custom && _selectedTable == preset,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTable = preset;
                        _custom = false;
                      });
                    }
                  },
                ),
              ChoiceChip(
                label: const Text('Custom…'),
                selected: _custom,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _custom = true);
                  }
                },
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _customController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Custom Table / Area name',
                hintText: 'e.g. VIP Room, High Top 3',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.sensors_rounded, color: AppColors.forest, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Autonomous departure tracking will automatically activate for this table.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _confirm,
        style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
        child: const Text('Confirm & Seat Party'),
      ),
    ],
  );
}
