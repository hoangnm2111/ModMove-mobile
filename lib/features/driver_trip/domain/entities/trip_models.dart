import 'dart:math' as math;
import 'dart:typed_data';

enum TripStage {
  accepted,
  arrived,
  pickedUp,
  inTransit,
  delivered,
  completed,
  cancelled,
}

enum EvidenceReview { none, pending, approved, rejected }

enum CargoPhotoKind { overall, secured }

enum CargoPhotoSource { camera, gallery, sample }

enum PaymentMethod { payos, cashSender, cashReceiver }

class TripFailure implements Exception {
  const TripFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  double distanceTo(GeoPoint other) {
    const radians = math.pi / 180;
    final a =
        math.pow(math.sin((other.latitude - latitude) * radians / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(other.latitude * radians) *
            math.pow(math.sin((other.longitude - longitude) * radians / 2), 2);
    return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class GpsFix {
  const GpsFix(this.point, this.at);
  final GeoPoint point;
  final DateTime at;
  bool freshAt(DateTime now) =>
      now.difference(at) <= const Duration(seconds: 30);
}

class DriverAccess {
  const DriverAccess({required this.approved, required this.active});
  final bool approved, active;
  bool get eligible => approved && active;
}

class DeliveryJob {
  const DeliveryJob({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.pickupPoint,
    required this.dropoffPoint,
    required this.createdAt,
    this.distanceKm = 8.4,
    this.minutes = 35,
    this.boxes = 8,
    this.weightKg = 250,
    this.fare = 240000,
    this.commission = 24000,
    this.payment = PaymentMethod.payos,
    this.paid = true,
    this.fragile = true,
    this.vehicle = 'Xe tải 1 tấn',
    this.customerName = 'Anh Hùng',
    this.customerPhone = '0900000321',
    this.detailsAvailable = true,
    this.orderCode = '',
    this.cargoDescription = '',
    this.notes = '',
    this.photoUrls = const [],
    this.loadingService = false,
    this.receiverName = '',
    this.receiverPhone = '',
    this.distanceFee = 0,
    this.serviceFee = 0,
    this.discount = 0,
    this.commissionRate = 0,
    this.handoverPoint,
    this.fareBreakdownAvailable = false,
  });
  final String id, pickup, dropoff, vehicle, customerName, customerPhone;
  final GeoPoint pickupPoint, dropoffPoint;
  final DateTime createdAt;
  final double distanceKm;
  final int minutes, boxes, weightKg, fare, commission;
  final PaymentMethod payment;
  final bool paid, fragile;
  final bool detailsAvailable;
  final String orderCode, cargoDescription, notes;
  final List<String> photoUrls;
  final bool loadingService;
  final String receiverName, receiverPhone;
  final int distanceFee, serviceFee, discount;
  final double commissionRate;
  final GeoPoint? handoverPoint;
  final bool fareBreakdownAvailable;
  GeoPoint get collectionPoint => handoverPoint ?? pickupPoint;
  String get displayCode => orderCode.isEmpty ? id : orderCode;
  int get net => fare - commission;
  bool get cash => payment != PaymentMethod.payos;
  bool expiredAt(DateTime now) =>
      !now.isBefore(createdAt.add(const Duration(minutes: 10)));
}

class JobOffer {
  const JobOffer(this.job, this.deadline);
  final DeliveryJob job;
  final DateTime deadline;
  int remainingAt(DateTime now) =>
      (deadline.difference(now).inMilliseconds / 1000).ceil().clamp(0, 30);
}

class CargoPhoto {
  CargoPhoto({required this.kind, required this.name, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final CargoPhotoKind kind;
  final String name;
  final Uint8List bytes;
}

class UploadedEvidence {
  const UploadedEvidence(this.kind, this.reference);
  final CargoPhotoKind kind;
  final String reference;
}

class ActiveTrip {
  ActiveTrip({
    required this.job,
    this.stage = TripStage.accepted,
    this.review = EvidenceReview.none,
    this.attempts = 0,
    this.reason,
    this.arrivedAt,
    this.submittedAt,
    this.cashCollected = false,
    this.note = '',
    this.deliveryPhotoUrl,
    this.deliveredAt,
    this.completedAt,
    this.incidents = const [],
    List<UploadedEvidence> evidence = const [],
  }) : evidence = List.unmodifiable(evidence);
  final DeliveryJob job;
  final TripStage stage;
  final EvidenceReview review;
  final int attempts;
  final String? reason;
  final String note;
  final DateTime? arrivedAt, submittedAt;
  final bool cashCollected;
  final List<UploadedEvidence> evidence;
  final String? deliveryPhotoUrl;
  final DateTime? deliveredAt, completedAt;
  final List<TripIncident> incidents;
  bool get editable =>
      (stage == TripStage.arrived ||
          stage == TripStage.pickedUp && review == EvidenceReview.rejected) &&
      attempts < 5;
  bool get ongoing => ![
    TripStage.cancelled,
    TripStage.delivered,
    TripStage.completed,
  ].contains(stage);
  ActiveTrip copyWith({
    TripStage? stage,
    EvidenceReview? review,
    int? attempts,
    String? reason,
    DateTime? arrivedAt,
    DateTime? submittedAt,
    bool? cashCollected,
    String? note,
    List<UploadedEvidence>? evidence,
    String? deliveryPhotoUrl,
    DateTime? deliveredAt,
    DateTime? completedAt,
  }) => ActiveTrip(
    job: job,
    stage: stage ?? this.stage,
    review: review ?? this.review,
    attempts: attempts ?? this.attempts,
    reason: reason,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    submittedAt: submittedAt ?? this.submittedAt,
    cashCollected: cashCollected ?? this.cashCollected,
    note: note ?? this.note,
    evidence: evidence ?? this.evidence,
    deliveryPhotoUrl: deliveryPhotoUrl ?? this.deliveryPhotoUrl,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    completedAt: completedAt ?? this.completedAt,
    incidents: incidents,
  );
}

class TripIncident {
  const TripIncident(this.id, this.description, this.status, this.resolution);
  final String id, description, status;
  final String? resolution;
}

class ShiftSummary {
  const ShiftSummary({
    this.completed = 0,
    this.income = 0,
    this.acceptanceRate = 0,
    this.available = true,
  });
  final int completed, income, acceptanceRate;
  final bool available;
}

class DriverSession {
  DriverSession({
    this.online = false,
    this.gpsEnabled = true,
    this.mapAvailable = true,
    this.fix,
    this.offer,
    this.trip,
    this.deposit = 0,
    this.earnings = 0,
    this.shift = const ShiftSummary(),
    this.pings = 0,
    List<DeliveryJob> jobs = const [],
    this.notice,
  }) : jobs = List.unmodifiable(jobs);
  final bool online, gpsEnabled, mapAvailable;
  final GpsFix? fix;
  final JobOffer? offer;
  final ActiveTrip? trip;
  final int deposit, earnings, pings;
  final ShiftSummary shift;
  final List<DeliveryJob> jobs;
  final String? notice;
}
