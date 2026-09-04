import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/ticket_qr_payload.dart';

class QrPassDialog extends StatelessWidget {
  const QrPassDialog({super.key, required this.payload});

  final TicketQrPayload payload;

  static Future<void> show(
    BuildContext context, {
    required TicketQrPayload payload,
  }) => showDialog<void>(
    context: context,
    builder: (context) => QrPassDialog(payload: payload),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your arrival pass'),
    // Give the QR widget a concrete box. qr_flutter uses a
    // LayoutBuilder internally, which cannot be measured by the
    // intrinsic-width pass that AlertDialog performs on unconstrained
    // children.
    content: SizedBox(
      width: 260,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: payload.encode(),
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask staff to scan this code when your table is called.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
