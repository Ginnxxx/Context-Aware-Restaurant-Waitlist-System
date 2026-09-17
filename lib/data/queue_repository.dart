import '../domain/queue_ticket.dart';
import '../domain/ticket_qr_payload.dart';
import '../domain/venue_context.dart';

abstract interface class QueueRepository {
  bool get isDemo;

  bool get isStaffSignedIn;

  Future<void> ensureCustomerSession();

  Future<void> signInStaff({required String email, required String password});

  Future<void> signOut();

  Stream<QueueTicket?> watchMyActiveTicket({String? venueId});

  Future<QueueTicket?> getMyActiveTicket({String? venueId});

  Future<List<QueueTicket>> getMyTicketHistory();

  Stream<List<QueueTicket>> watchVenueTickets({String? venueId});

  Future<int> getVenueWaitingCount({String? venueId});

  Future<VenueContext> getVenueContext({String? venueId});

  Future<List<VenueContext>> getAllVenues();

  Stream<List<VenueContext>> watchVenues();

  Future<VenueContext> createVenue({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    int averageTurnoverMinutes = 5,
    int outerGeofenceMeters = 800,
    int arrivalGeofenceMeters = 100,
    int seatCapacity = 40,
  });

  Future<void> recordContextEvent({
    required String ticketId,
    required String eventType,
    required String distanceBand,
  });

  Future<TicketQrPayload> getTicketQrPayload(String ticketId);

  Future<void> registerDeviceInstallation({
    required String platform,
    required String fcmToken,
  });

  Future<QueueTicket> verifyTicketQr(String encodedPayload);

  Future<QueueTicket> joinQueue({
    required String guestName,
    required int partySize,
    String? venueId,
  });

  Future<void> cancelMyTicket(String ticketId);

  Future<void> callNextParty({String? venueId, bool force = false});

  Future<void> transitionTicket(
    String ticketId,
    TicketStatus status, {
    String? tableLabel,
  });

  Future<void> releaseSeatedTicket(String ticketId);

  Future<void> autoReleaseMyTicket(String ticketId, {String? reason});

  Future<QueueTicket> reportTicketDelay(
    String ticketId, {
    int additionalMinutes = 5,
  });

  Future<void> setQueueOpen(bool open, {String? venueId});

  Future<VenueContext> updateVenueSettings({
    String? venueId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required int averageTurnoverMinutes,
    required int outerGeofenceMeters,
    required int arrivalGeofenceMeters,
    required int seatCapacity,
  });
}
