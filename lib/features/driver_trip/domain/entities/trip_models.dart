import 'dart:math' as math;
import 'dart:typed_data';

enum TripStage { accepted, arrived, pickedUp, inTransit, cancelled }

enum EvidenceReview { none, pending, approved, rejected }

enum CargoPhotoKind { overall, secured }

enum CargoPhotoSource { camera, gallery, sample }

enum PaymentMethod { payos, cashSender, cashReceiver }

/// Loại sự cố tài xế được báo (BE: VehicleBreakdown | DamagedCargo | Accident | Other).
enum IncidentType {
  vehicleBreakdown('VehicleBreakdown', 'Xe hỏng / chết máy'),
  damagedCargo('DamagedCargo', 'Hàng hư hỏng'),
  accident('Accident', 'Tai nạn'),
  other('Other', 'Sự cố khác');

  const IncidentType(this.apiValue, this.label);
  final String apiValue, label;
}

class TripFailure implements Exception {
  const TripFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Trạng thái sự cố (BE: IncidentResolutionStatus) kèm nhãn tiếng Việt dùng chung web và app.
enum IncidentStatus {
  open('Đang chờ xử lý'),
  inProgress('Điều phối viên đang xử lý'),
  resolved('Đã xử lý'),
  cancelled('Báo cáo đã bị hủy');

  const IncidentStatus(this.label);
  final String label;

  static IncidentStatus parse(Object? value) => switch ('$value') {
    'InProgress' => inProgress,
    'Resolved' => resolved,
    'Cancelled' => cancelled,
    _ => open,
  };
}

/// Sự cố trên chuyến (BE: DriverIncidentResponse / `incidents[]` của chi tiết chuyến).
/// `reportedByYou = false` là sự cố do khách báo: mô tả chỉ là câu chung, không có ảnh.
class TripIncident {
  const TripIncident({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.type,
    required this.description,
    required this.reportedByYou,
    required this.status,
    required this.createdAt,
    this.photoUrls = const [],
    this.decision,
    this.note,
    this.resolvedAt,
    this.latitude,
    this.longitude,
    this.orderStatus,
  });
  final int id, orderId;
  final String orderCode, description;
  final IncidentType type;
  final List<String> photoUrls;
  final bool reportedByYou;
  final IncidentStatus status;

  /// ContinueTrip | ReassignDriver | CancelOrder (chỉ có khi Đã xử lý).
  final String? decision, note, orderStatus;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final double? latitude, longitude;

  bool get isOpen => status == IncidentStatus.open || status == IncidentStatus.inProgress;

  /// Luật: sự cố do chính tài xế báo còn mở thì chuyến tạm dừng. Sự cố do khách báo không chặn.
  bool get blocksTrip => reportedByYou && isOpen;

  static const decisionLabels = {
    'ContinueTrip': 'Tiếp tục chuyến',
    'ReassignDriver': 'Đổi tài xế',
    'CancelOrder': 'Hủy đơn',
  };
  String? get decisionLabel => decision == null ? null : (decisionLabels[decision] ?? decision);

  TripIncident copyWith({IncidentStatus? status, String? decision, String? note, DateTime? resolvedAt}) => TripIncident(
    id: id,
    orderId: orderId,
    orderCode: orderCode,
    type: type,
    description: description,
    reportedByYou: reportedByYou,
    status: status ?? this.status,
    createdAt: createdAt,
    photoUrls: photoUrls,
    decision: decision ?? this.decision,
    note: note ?? this.note,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    latitude: latitude,
    longitude: longitude,
    orderStatus: orderStatus,
  );

  factory TripIncident.fromJson(Map<String, dynamic> j, {int? orderId, String? orderCode}) {
    double? number(Object? v) => v is num ? v.toDouble() : null;
    return TripIncident(
      id: (j['id'] as num).toInt(),
      orderId: ((j['orderId'] ?? orderId) as num?)?.toInt() ?? 0,
      orderCode: (j['orderCode'] as String?) ?? orderCode ?? '',
      type: IncidentType.values.firstWhere((t) => t.apiValue == j['incidentType'], orElse: () => IncidentType.other),
      description: (j['description'] as String?) ?? '',
      photoUrls: ((j['photoUrls'] as List?) ?? const []).cast<String>(),
      reportedByYou: j['reportedByYou'] == true,
      status: IncidentStatus.parse(j['resolutionStatus']),
      decision: j['resolutionDecision'] as String?,
      note: j['resolutionNote'] as String?,
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal() ?? DateTime.now(),
      resolvedAt: DateTime.tryParse('${j['resolvedAt'] ?? ''}')?.toLocal(),
      latitude: number(j['latitude']),
      longitude: number(j['longitude']),
      orderStatus: j['orderStatus'] as String?,
    );
  }
}

/// Nội dung tài xế gửi khi báo sự cố. Ảnh được tải lên khi gửi (JPG/PNG ≤ 5 MB, tối đa 5 ảnh).
class IncidentDraft {
  const IncidentDraft({
    required this.type,
    required this.description,
    this.photos = const [],
    this.latitude,
    this.longitude,
  });
  final IncidentType type;
  final String description;
  final List<CargoPhoto> photos;

  /// Không có GPS thì để trống: BE tự lấy vị trí cuối của tài xế.
  final double? latitude, longitude;
}

/// Kết quả xử lý sự cố cần báo cho tài xế (một lần): hiện hộp thoại rồi gọi `acknowledgeOutcome`.
enum IncidentOutcomeKind { continueTrip, dismissed, reassignedAway, orderCancelled }

class IncidentOutcome {
  const IncidentOutcome(this.kind, {required this.orderCode, this.incidentId, this.note});
  final IncidentOutcomeKind kind;
  final String orderCode;
  final int? incidentId;
  final String? note;

  /// Ghi chú huỷ đơn có dạng `... [Cargo: ReturnToPickup|Keep]`.
  String? get cargoHint {
    final match = RegExp(r'\[Cargo: (\w+)\]').firstMatch(note ?? '');
    return match?.group(1);
  }

  String get title => switch (kind) {
    IncidentOutcomeKind.continueTrip => 'Điều phối viên: tiếp tục chuyến',
    IncidentOutcomeKind.dismissed => 'Báo cáo sự cố đã bị hủy',
    IncidentOutcomeKind.reassignedAway => 'Đơn $orderCode đã chuyển cho tài xế khác',
    IncidentOutcomeKind.orderCancelled => 'Đơn $orderCode đã bị hủy do sự cố',
  };

  String get message {
    final clean = (note ?? '').replaceAll(RegExp(r'\s*\[Cargo: \w+\]'), '').trim();
    final hint = switch (cargoHint) {
      'ReturnToPickup' => 'Hãy đưa hàng về điểm lấy.',
      'Keep' => 'Bạn tiếp tục giữ hàng theo hướng dẫn của điều phối viên.',
      final other? => other,
      null => null,
    };
    return [if (clean.isNotEmpty) clean, ?hint].join('\n');
  }
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
    this.code,
  });
  final String id, pickup, dropoff, vehicle, customerName, customerPhone;

  /// Mã đơn hiển thị cho người dùng (BE: orderCode); [id] là khoá gọi API.
  final String? code;
  String get label => code ?? id;
  final GeoPoint pickupPoint, dropoffPoint;
  final DateTime createdAt;
  final double distanceKm;
  final int minutes, boxes, weightKg, fare, commission;
  final PaymentMethod payment;
  final bool paid, fragile;
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
    List<UploadedEvidence> evidence = const [],
    List<TripIncident> incidents = const [],
  }) : evidence = List.unmodifiable(evidence),
       incidents = List.unmodifiable(incidents);
  final DeliveryJob job;
  final TripStage stage;
  final EvidenceReview review;
  final int attempts;
  final String? reason;
  final String note;
  final DateTime? arrivedAt, submittedAt;
  final bool cashCollected;
  final List<UploadedEvidence> evidence;
  final List<TripIncident> incidents;

  /// Sự cố do tài xế báo còn mở: chuyến tạm dừng, khóa các bước của chuyến.
  TripIncident? get blockingIncident => incidents.where((i) => i.blocksTrip).firstOrNull;

  /// Sự cố do khách báo còn mở: chỉ nhắc, không khóa nút.
  TripIncident? get customerOpenIncident => incidents.where((i) => i.isOpen && !i.reportedByYou).firstOrNull;
  bool get editable =>
      (stage == TripStage.arrived ||
          stage == TripStage.pickedUp && review == EvidenceReview.rejected) &&
      attempts < 5;
  bool get ongoing => stage != TripStage.cancelled;
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
    List<TripIncident>? incidents,
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
    incidents: incidents ?? this.incidents,
  );
}

class ShiftSummary {
  const ShiftSummary({
    this.completed = 0,
    this.income = 0,
    this.acceptanceRate = 0,
  });
  final int completed, income, acceptanceRate;
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
    this.requiredDeposit = 200000,
    this.missingDeposit = 0,
    this.incidentOutcome,
  }) : jobs = List.unmodifiable(jobs);

  /// Kết quả xử lý sự cố chưa báo cho tài xế (null khi không có).
  final IncidentOutcome? incidentOutcome;

  /// Ký quỹ tối thiểu để nhận mọi đơn (BE: REQUIRED_DEPOSIT) và phần còn thiếu.
  final int requiredDeposit, missingDeposit;
  final bool online, gpsEnabled, mapAvailable;
  final GpsFix? fix;
  final JobOffer? offer;
  final ActiveTrip? trip;
  final int deposit, earnings, pings;
  final ShiftSummary shift;
  final List<DeliveryJob> jobs;
  final String? notice;
}
