enum TicketStatus {
  waiting,
  called,
  approaching,
  arrived,
  seated,
  cancelled,
  noShow,
}

class QueueTicket {
  const QueueTicket({
    required this.id,
    required this.guestName,
    required this.partySize,
    required this.position,
    required this.estimatedWaitMinutes,
    required this.status,
    required this.joinedAt,
    this.venueId,
    this.calledAt,
    this.departedAt,
    this.tableLabel,
    this.departureReason,
    this.delayMinutes = 0,
  });

  final String id;
  final String? venueId;
  final String guestName;
  final int partySize;
  final int position;
  final int estimatedWaitMinutes;
  final TicketStatus status;
  final DateTime joinedAt;
  final DateTime? calledAt;
  final DateTime? departedAt;
  final String? tableLabel;
  final String? departureReason;
  final int delayMinutes;

  bool get isAutoDeparted =>
      departedAt != null && departureReason == 'geofence_exit';

  bool get hasDelay => delayMinutes > 0;

  factory QueueTicket.fromMap(
    Map<String, dynamic> map, {
    int? position,
    int? estimatedWaitMinutes,
  }) => QueueTicket(
    id: map['id'] as String,
    venueId: map['venue_id'] as String?,
    guestName: map['guest_name'] as String,
    partySize: (map['party_size'] as num).toInt(),
    position: position ?? (map['queue_position'] as num?)?.toInt() ?? 0,
    estimatedWaitMinutes:
        estimatedWaitMinutes ??
        (map['estimated_wait_minutes'] as num?)?.toInt() ??
        0,
    status: TicketStatus.values.firstWhere(
      (status) => status.databaseValue == map['status'],
    ),
    joinedAt: DateTime.parse(map['joined_at'] as String),
    calledAt: map['called_at'] == null
        ? null
        : DateTime.parse(map['called_at'] as String),
    departedAt: map['departed_at'] == null
        ? null
        : DateTime.parse(map['departed_at'] as String),
    tableLabel: map['table_label'] as String?,
    departureReason: map['departure_reason'] as String?,
    delayMinutes: (map['delay_minutes'] as num?)?.toInt() ?? 0,
  );

  QueueTicket copyWith({
    TicketStatus? status,
    int? position,
    int? estimatedWaitMinutes,
    DateTime? calledAt,
    DateTime? departedAt,
    String? tableLabel,
    String? departureReason,
    int? delayMinutes,
  }) => QueueTicket(
    id: id,
    venueId: venueId,
    guestName: guestName,
    partySize: partySize,
    position: position ?? this.position,
    estimatedWaitMinutes: estimatedWaitMinutes ?? this.estimatedWaitMinutes,
    status: status ?? this.status,
    joinedAt: joinedAt,
    calledAt: calledAt ?? this.calledAt,
    departedAt: departedAt ?? this.departedAt,
    tableLabel: tableLabel ?? this.tableLabel,
    departureReason: departureReason ?? this.departureReason,
    delayMinutes: delayMinutes ?? this.delayMinutes,
  );
}

extension TicketStatusLabel on TicketStatus {
  String get databaseValue => switch (this) {
    TicketStatus.noShow => 'no_show',
    _ => name,
  };

  String get label => switch (this) {
    TicketStatus.waiting => 'Waiting',
    TicketStatus.called => 'Table ready',
    TicketStatus.approaching => 'Approaching',
    TicketStatus.arrived => 'Arrived',
    TicketStatus.seated => 'Seated',
    TicketStatus.cancelled => 'Cancelled',
    TicketStatus.noShow => 'No-show',
  };
}
