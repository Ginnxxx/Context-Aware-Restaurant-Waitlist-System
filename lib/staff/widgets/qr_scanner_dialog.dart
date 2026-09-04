import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';
import '../../data/queue_repository.dart';
import '../../domain/queue_ticket.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key, required this.repository});

  final QueueRepository repository;

  static Future<QueueTicket?> show(
    BuildContext context, {
    required QueueRepository repository,
  }) => showDialog<QueueTicket>(
    context: context,
    builder: (context) => QrScannerDialog(repository: repository),
  );

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_checking) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    await _controller.stop();
    try {
      final ticket = await widget.repository.verifyTicketQr(value);
      if (mounted) Navigator.pop(context, ticket);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = exception.toString();
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Scan arrival pass'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.coral, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  if (_checking)
                    const ColoredBox(
                      color: Color(0x99000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Place the customer’s QueueLess QR inside the frame.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _error == null ? AppColors.muted : AppColors.coral,
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
    ],
  );
}
