import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/data/demo_queue_repository.dart';
import 'package:queueless/domain/queue_ticket.dart';

void main() {
  test('demo repository joins and cancels a customer ticket', () async {
    final repository = DemoQueueRepository();
    final ticket = await repository.joinQueue(guestName: 'Ari', partySize: 3);

    expect(ticket.guestName, 'Ari');
    expect(ticket.partySize, 3);
    expect(ticket.status, TicketStatus.waiting);

    await repository.cancelMyTicket(ticket.id);
    expect(await repository.watchMyActiveTicket().first, isNull);
  });

  test('ticket maps database no_show status and table label correctly', () {
    final ticket = QueueTicket.fromMap({
      'id': 'ticket-id',
      'guest_name': 'Mina',
      'party_size': 2,
      'queue_position': 0,
      'estimated_wait_minutes': 0,
      'status': 'no_show',
      'joined_at': '2026-08-10T10:00:00Z',
      'table_label': 'Booth 2',
      'departure_reason': 'geofence_exit',
      'delay_minutes': 5,
    });

    expect(ticket.status, TicketStatus.noShow);
    expect(ticket.tableLabel, 'Booth 2');
    expect(ticket.departureReason, 'geofence_exit');
    expect(ticket.delayMinutes, 5);
    expect(ticket.hasDelay, isTrue);
  });

  test('customer can report delay and request grace extensions', () async {
    final repository = DemoQueueRepository();
    final ticket = await repository.joinQueue(guestName: 'Zoe', partySize: 4);

    expect(ticket.delayMinutes, 0);
    expect(ticket.hasDelay, isFalse);

    final delayed = await repository.reportTicketDelay(ticket.id, additionalMinutes: 5);
    expect(delayed.delayMinutes, 5);
    expect(delayed.hasDelay, isTrue);

    final secondDelay = await repository.reportTicketDelay(ticket.id, additionalMinutes: 5);
    expect(secondDelay.delayMinutes, 10);

    // Max 10 minutes clamp
    final maxDelay = await repository.reportTicketDelay(ticket.id, additionalMinutes: 5);
    expect(maxDelay.delayMinutes, 10);
  });

  test('staff can assign a table and seat an arrived party', () async {
    final repository = DemoQueueRepository();
    final tickets = await repository.watchVenueTickets().first;
    final called = tickets.firstWhere(
      (ticket) => ticket.status == TicketStatus.called,
    );

    await repository.transitionTicket(called.id, TicketStatus.arrived);
    await repository.transitionTicket(
      called.id,
      TicketStatus.seated,
      tableLabel: 'Table 4',
    );

    final updated = await repository.watchVenueTickets().first;
    final seatedTicket = updated.firstWhere((ticket) => ticket.id == called.id);
    expect(seatedTicket.status, TicketStatus.seated);
    expect(seatedTicket.tableLabel, 'Table 4');

    await repository.releaseSeatedTicket(called.id);
    final released = await repository.watchVenueTickets().first;
    expect(
      released.firstWhere((ticket) => ticket.id == called.id).departedAt,
      isNotNull,
    );
  });

  test('seated customer is auto-departed on geofence exit event', () async {
    final repository = DemoQueueRepository();
    final joined = await repository.joinQueue(guestName: 'Koji', partySize: 2);

    await repository.transitionTicket(joined.id, TicketStatus.called);
    await repository.transitionTicket(joined.id, TicketStatus.arrived);
    await repository.transitionTicket(
      joined.id,
      TicketStatus.seated,
      tableLabel: 'Patio 1',
    );

    // Verify active seated ticket
    final activeTicket = await repository.getMyActiveTicket();
    expect(activeTicket, isNotNull);
    expect(activeTicket!.status, TicketStatus.seated);
    expect(activeTicket.tableLabel, 'Patio 1');

    // Simulate geofence exit trigger (MUC implicit departure sensing)
    await repository.recordContextEvent(
      ticketId: joined.id,
      eventType: 'outer_geofence_exited',
      distanceBand: 'far',
    );

    // Active ticket cleared and moved to history as auto-departed
    final clearedActive = await repository.getMyActiveTicket();
    expect(clearedActive, isNull);

    final history = await repository.getMyTicketHistory();
    expect(history.first.id, joined.id);
    expect(history.first.isAutoDeparted, isTrue);
    expect(history.first.tableLabel, 'Patio 1');
  });

  test('staff can manually call and check in a waiting party', () async {
    final repository = DemoQueueRepository();
    final ticket = await repository.joinQueue(guestName: 'Leo', partySize: 2);
    expect(ticket.status, TicketStatus.waiting);

    // Staff manually calls party from waiting state
    await repository.transitionTicket(ticket.id, TicketStatus.called);
    final calledTicket = (await repository.watchVenueTickets().first)
        .firstWhere((t) => t.id == ticket.id);
    expect(calledTicket.status, TicketStatus.called);
    expect(calledTicket.calledAt, isNotNull);

    // Staff manually checks in called party
    await repository.transitionTicket(ticket.id, TicketStatus.arrived);
    final arrivedTicket = (await repository.watchVenueTickets().first)
        .firstWhere((t) => t.id == ticket.id);
    expect(arrivedTicket.status, TicketStatus.arrived);

    // Staff seats the checked-in party
    await repository.transitionTicket(
      ticket.id,
      TicketStatus.seated,
      tableLabel: 'Table 7',
    );
    final seatedTicket = (await repository.watchVenueTickets().first)
        .firstWhere((t) => t.id == ticket.id);
    expect(seatedTicket.status, TicketStatus.seated);
    expect(seatedTicket.tableLabel, 'Table 7');
  });

  test('staff can directly check in an approaching walk-in party', () async {
    final repository = DemoQueueRepository();
    final ticket = await repository.joinQueue(guestName: 'Chloe', partySize: 4);
    
    // Party transitions to approaching
    await repository.recordContextEvent(
      ticketId: ticket.id,
      eventType: 'outer_geofence_entered',
      distanceBand: 'approaching',
    );

    // Staff checks them in directly without waiting for automated call
    await repository.transitionTicket(ticket.id, TicketStatus.arrived);
    final arrivedTicket = (await repository.watchVenueTickets().first)
        .firstWhere((t) => t.id == ticket.id);
    expect(arrivedTicket.status, TicketStatus.arrived);
  });

  test('smart capacity calling respects available seats and table-fit', () async {
    final repository = DemoQueueRepository();

    // Clear initial demo tickets to control exact venue capacity
    final initialTickets = await repository.watchVenueTickets().first;
    for (final t in initialTickets) {
      await repository.transitionTicket(t.id, TicketStatus.cancelled);
    }

    // Fill up capacity almost completely (seat 38 of 40 seats)
    final bigParty = await repository.joinQueue(guestName: 'Large Group', partySize: 38);
    await repository.transitionTicket(bigParty.id, TicketStatus.called);
    await repository.transitionTicket(bigParty.id, TicketStatus.arrived);
    await repository.transitionTicket(bigParty.id, TicketStatus.seated, tableLabel: 'Hall A');

    // Only 2 seats available (40 - 38 = 2)
    // Add a party of 4 (doesn't fit) and then a party of 2 (fits)
    final partyOf4 = await repository.joinQueue(guestName: 'Party of 4', partySize: 4);
    final partyOf2 = await repository.joinQueue(guestName: 'Party of 2', partySize: 2);

    // Calling next should smart-fit and call the party of 2 because party of 4 does not fit in 2 seats
    await repository.callNextParty();

    final tickets = await repository.watchVenueTickets().first;
    final calledParty2 = tickets.firstWhere((t) => t.id == partyOf2.id);
    final waitingParty4 = tickets.firstWhere((t) => t.id == partyOf4.id);

    expect(calledParty2.status, TicketStatus.called);
    expect(waitingParty4.status, TicketStatus.waiting);

    // Now available seats = 40 - (38 seated + 2 called) = 0
    // Trying to call next without force should throw capacity error
    expect(
      () => repository.callNextParty(),
      throwsA(isA<StateError>()),
    );

    // With force override, staff can still call
    await repository.callNextParty(force: true);
    final forcedTickets = await repository.watchVenueTickets().first;
    expect(
      forcedTickets.firstWhere((t) => t.id == partyOf4.id).status,
      TicketStatus.called,
    );
  });
}
