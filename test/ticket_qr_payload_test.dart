import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/domain/ticket_qr_payload.dart';

void main() {
  test('QR payload round-trips ticket, venue, and nonce', () {
    const original = TicketQrPayload(
      ticketId: '11111111-1111-1111-1111-111111111111',
      venueId: '22222222-2222-2222-2222-222222222222',
      nonce: '33333333-3333-3333-3333-333333333333',
    );

    final decoded = TicketQrPayload.decode(original.encode());

    expect(decoded.ticketId, original.ticketId);
    expect(decoded.venueId, original.venueId);
    expect(decoded.nonce, original.nonce);
  });

  test('rejects non-QueueLess QR values', () {
    expect(
      () => TicketQrPayload.decode('https://example.com'),
      throwsFormatException,
    );
  });
}
