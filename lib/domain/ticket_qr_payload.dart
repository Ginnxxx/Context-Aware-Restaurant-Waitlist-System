import 'dart:convert';

class TicketQrPayload {
  const TicketQrPayload({
    required this.ticketId,
    required this.venueId,
    required this.nonce,
  });

  static const prefix = 'queueless:v1:';

  final String ticketId;
  final String venueId;
  final String nonce;

  String encode() =>
      '$prefix${base64Url.encode(utf8.encode(jsonEncode({'ticket_id': ticketId, 'venue_id': venueId, 'nonce': nonce})))}';

  factory TicketQrPayload.decode(String encoded) {
    if (!encoded.startsWith(prefix)) {
      throw const FormatException('This is not a QueueLess QR ticket.');
    }
    final value = encoded.substring(prefix.length);
    final normalized = base64Url.normalize(value);
    final map =
        jsonDecode(utf8.decode(base64Url.decode(normalized)))
            as Map<String, dynamic>;
    return TicketQrPayload(
      ticketId: map['ticket_id'] as String,
      venueId: map['venue_id'] as String,
      nonce: map['nonce'] as String,
    );
  }
}
