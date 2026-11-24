import 'dart:async';
import '../../domain/entities/trip_models.dart';
import '../../domain/entities/driver_matching_policy.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/usecases/validate_cargo_photo.dart';

/// In-process mock server. Validations run again after latency, immediately
/// before each mutation, to model atomic server-side transitions.
class MockDriverTripRepository implements DriverTripRepository, TripSimulator {
  MockDriverTripRepository({
    this._access = const DriverAccess(approved: true, active: true),
    this.delay = const Duration(milliseconds: 350),
    DateTime Function()? clock,
    this.autoOffer = true,
    this.availabilityGateway,
    bool initialOnline = false,
  }) : _clock = clock ?? DateTime.now {
    _seed();
    if (initialOnline && _access.eligible) {
      _online = true;
      _startGps();
    }
  }
  final Duration delay;
  final DateTime Function() _clock;
  final bool autoOffer;
  final Future<bool> Function(bool)? availabilityGateway;
  final _updates = StreamController<DriverSession>.broadcast();
  final _ignored = <String>{};
  final _taken = <String>{};
  final _deadlines = <String, DateTime>{};
  final _uploads = <String, (String, CargoPhotoKind)>{};
  final List<DeliveryJob> _jobs = [];
  DriverAccess _access;
  bool _online = false, _gps = true, _map = true, _foreground = true;
  bool _failRequest = false, _failUpload = false, _closed = false;
  int _deposit = 350000, _pings = 0, _generation = 0, _uploadId = 0;
  GpsFix? _fix;
  JobOffer? _offer;
  ActiveTrip? _trip;
  IncidentOutcome? _outcome;
  int _incidentSeq = 0;
  String? _notice;
  Timer? _gpsTimer, _offerTimer;
  GeoPoint _point = const GeoPoint(10.7240, 106.7057);
  @override
  DateTime get now => _clock();
  @override
  Stream<DriverSession> get changes => _updates.stream;
  bool get _hasTrip => _trip?.ongoing ?? false;
  bool _eligible(DeliveryJob job) =>
      _online &&
      _access.eligible &&
      !_hasTrip &&
      _gps &&
      (_fix?.freshAt(now) ?? false) &&
      !_taken.contains(job.id) &&
      !_ignored.contains(job.id) &&
      (!_deadlines.containsKey(job.id) || now.isBefore(_deadlines[job.id]!)) &&
      !job.expiredAt(now) &&
      _fix!.point.distanceTo(job.pickupPoint) <=
          DriverMatchingPolicy.mockSearchRadiusMeters &&
      job.weightKg <= 1000 &&
      job.vehicle == 'Xe tải 1 tấn' &&
      _deposit >= 200000 &&
      (job.cash ? _deposit >= job.commission : job.paid);
  @override
  DriverSession get current {
    final jobs = _jobs.where(_eligible).toList()
      ..sort(
        (a, b) => _point
            .distanceTo(a.pickupPoint)
            .compareTo(_point.distanceTo(b.pickupPoint)),
      );
    return DriverSession(
      online: _online,
      gpsEnabled: _gps,
      mapAvailable: _map,
      fix: _fix,
      offer: _offer,
      trip: _trip,
      deposit: _deposit,
      earnings: 1280000,
      shift: const ShiftSummary(
        completed: 3,
        income: 486000,
        acceptanceRate: 92,
      ),
      pings: _pings,
      jobs: jobs,
      notice: _notice,
      incidentOutcome: _outcome,
    );
  }

  void _publish() {
    if (!_closed) _updates.add(current);
  }

  void _seed() {
    _jobs.clear();
    _jobs.addAll([
      DeliveryJob(
        id: 'MM271026014${_generation == 0 ? '' : '-$_generation'}',
        pickup: '12 Nguyễn Văn Linh, Quận 7',
        dropoff: '85 Điện Biên Phủ, Bình Thạnh',
        pickupPoint: const GeoPoint(10.7348, 106.7057),
        dropoffPoint: const GeoPoint(10.8015, 106.7105),
        createdAt: now,
      ),
      DeliveryJob(
        id: 'MM271026015-$_generation',
        pickup: '25 Nguyễn Thị Thập, Quận 7',
        dropoff: '45 Võ Văn Kiệt, Quận 1',
        pickupPoint: const GeoPoint(10.7445, 106.7140),
        dropoffPoint: const GeoPoint(10.7653, 106.6997),
        createdAt: now,
        payment: PaymentMethod.cashSender,
        fare: 320000,
        commission: 32000,
      ),
    ]);
  }

  Future<void> _request() async {
    await Future<void>.delayed(delay);
    if (_closed) throw const TripFailure('Phiên làm việc đã đóng.');
    if (_failRequest) {
      _failRequest = false;
      throw const TripFailure('Kết nối gián đoạn. Vui lòng thử lại.');
    }
  }

  @override
  Future<void> refresh() async {
    await _request();
    _publish();
  }

  @override
  void updateAccess(DriverAccess access) {
    _access = access;
    if (!access.eligible) {
      _online = false;
      _offer = null;
      _notice = 'Hồ sơ chưa được duyệt hoặc tài khoản đang bị khóa.';
      _stopGps();
    }
    _publish();
  }

  @override
  Future<void> setOnline(bool online) async {
    await _request();
    if (online && !_access.eligible) {
      throw const TripFailure(
        'Cần hồ sơ đã duyệt và tài khoản đang hoạt động.',
      );
    }
    if (online && !_gps) {
      throw const TripFailure('Bật quyền vị trí trước khi nhận đơn.');
    }
    if (!online && _hasTrip) {
      throw const TripFailure(
        'Bạn đang có chuyến. Hoàn tất chuyến trước khi tắt hoạt động.',
      );
    }
    if (availabilityGateway != null && !await availabilityGateway!(online)) {
      throw const TripFailure(
        'Chưa cập nhật được trạng thái hoạt động. Vui lòng thử lại.',
      );
    }
    _online = online;
    _notice = null;
    if (online) {
      _startGps();
      if (autoOffer) _scheduleOffer();
    } else {
      _stopGps();
      _offerTimer?.cancel();
      _offer = null;
    }
    _publish();
  }

  void _scheduleOffer() {
    _offerTimer?.cancel();
    _offerTimer = Timer(const Duration(seconds: 6), () {
      if (current.jobs.isNotEmpty && _offer == null && _foreground) {
        _offer = _makeOffer(current.jobs.first);
        _publish();
      }
    });
  }

  void _ping() {
    if (!_online || !_gps || !_foreground || _closed) return;
    _fix = GpsFix(_point, now);
    _pings++;
    if (_offer != null && _offer!.remainingAt(now) == 0) {
      _ignored.add(_offer!.job.id);
      _offer = null;
    }
    _publish();
  }

  void _startGps() {
    _stopGps();
    _ping();
    if (_foreground) {
      _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _ping());
    }
  }

  void _stopGps() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  @override
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground && _online) {
      _startGps();
    } else {
      _stopGps();
    }
    _publish();
  }

  DeliveryJob _job(String id) =>
      _jobs.where((job) => job.id == id).firstOrNull ??
      (throw const TripFailure('Đơn không còn khả dụng.'));
  @override
  Future<void> openOffer(String jobId) async {
    await _request();
    if (_offer?.job.id == jobId) {
      if (_offer!.remainingAt(now) == 0) {
        throw const TripFailure('Đã hết thời gian nhận chuyến.');
      }
      return;
    }
    final job = _job(jobId);
    if (!_eligible(job)) {
      throw const TripFailure(
        'Đơn không còn khả dụng hoặc bạn chưa đủ điều kiện.',
      );
    }
    _offer = _makeOffer(job);
    _publish();
  }

  @override
  Future<void> declineOffer() async {
    final id = _offer?.job.id;
    await _request();
    if (id == _offer?.job.id) {
      if (id != null) _ignored.add(id);
      _offer = null;
      _publish();
    }
  }

  JobOffer _makeOffer(DeliveryJob job) => JobOffer(
    job,
    _deadlines.putIfAbsent(job.id, () => now.add(JobOffer.matchingWindow)),
  );

  @override
  Future<void> acceptOffer(String jobId) async {
    await _request();
    final job = _job(jobId);
    // There is deliberately no await between these checks and assignment.
    if (_taken.contains(jobId)) {
      throw const TripFailure(
        'Tài xế khác đã nhận đơn này. Hãy chọn đơn khác.',
      );
    }
    if (_offer?.job.id != jobId || _offer!.remainingAt(now) == 0) {
      throw const TripFailure('Đã hết thời gian nhận chuyến.');
    }
    if (!_eligible(job)) {
      throw const TripFailure('Bạn không còn đủ điều kiện nhận đơn này.');
    }
    _taken.add(jobId);
    _trip = ActiveTrip(job: job);
    _offer = null;
    _publish();
  }

  ActiveTrip _requireTrip() {
    if (!_access.eligible) {
      throw const TripFailure('Tài khoản không được phép thao tác.');
    }
    if (_trip == null || !_trip!.ongoing) {
      throw const TripFailure('Chuyến đã hủy hoặc không còn hoạt động.');
    }
    return _trip!;
  }

  @override
  Future<void> arrive() async {
    await _request();
    final trip = _requireTrip();
    if (trip.stage == TripStage.arrived) return;
    if (trip.stage != TripStage.accepted) {
      throw const TripFailure('Trạng thái chuyến đã thay đổi.');
    }
    if (!_gps || !(_fix?.freshAt(now) ?? false)) {
      throw const TripFailure('Chưa có vị trí mới. Hãy bật GPS và thử lại.');
    }
    if (_fix!.point.distanceTo(trip.job.pickupPoint) > 500) {
      throw const TripFailure('Bạn cần cách điểm lấy hàng không quá 500 m.');
    }
    _trip = trip.copyWith(stage: TripStage.arrived, arrivedAt: now);
    _publish();
  }

  @override
  Future<UploadedEvidence> upload(
    CargoPhoto photo,
    void Function(double) progress,
  ) async {
    const ValidateCargoPhoto()(photo);
    final tripId = _requireTrip().job.id;
    if (!_trip!.editable) {
      throw const TripFailure('Chưa thể thay đổi ảnh ở trạng thái này.');
    }
    if (photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
      throw const TripFailure('Ảnh JPG/PNG phải nhỏ hơn 5 MB.');
    }
    for (var step = 1; step <= 4; step++) {
      await Future<void>.delayed(delay);
      if (_closed) throw const TripFailure('Phiên làm việc đã đóng.');
      progress(step / 4);
    }
    if (_failUpload) {
      _failUpload = false;
      throw const TripFailure('Tải ảnh thất bại. Ảnh được giữ lại để thử lại.');
    }
    if (_requireTrip().job.id != tripId || !_trip!.editable) {
      throw const TripFailure('Trạng thái chuyến đã thay đổi.');
    }
    final ref = 'mock://pickup/$tripId/${++_uploadId}';
    _uploads[ref] = (tripId, photo.kind);
    return UploadedEvidence(photo.kind, ref);
  }

  @override
  Future<void> submitInspection({
    required List<UploadedEvidence> evidence,
    required List<bool> checklist,
    required String note,
    required bool cashCollected,
  }) async {
    await _request();
    final trip = _requireTrip();
    if (!trip.editable) {
      throw const TripFailure('Không thể gửi ảnh ở trạng thái hiện tại.');
    }
    if (checklist.length != 4 ||
        checklist.any((item) => !item) ||
        evidence.map((item) => item.kind).toSet().length < 2) {
      throw const TripFailure('Hoàn tất kiểm tra và tải đủ 2 ảnh bằng chứng.');
    }
    for (final photo in evidence) {
      if (_uploads[photo.reference] != (trip.job.id, photo.kind)) {
        throw const TripFailure('Ảnh chưa được tải lên cho chuyến này.');
      }
    }
    if (trip.review == EvidenceReview.rejected &&
        evidence.any(
          (photo) =>
              trip.evidence.any((old) => old.reference == photo.reference),
        )) {
      throw const TripFailure('Chụp và tải lại ảnh theo yêu cầu của khách.');
    }
    if (trip.job.payment == PaymentMethod.cashSender && !cashCollected) {
      throw const TripFailure(
        'Xác nhận đã thu tiền từ người gửi trước khi lấy hàng.',
      );
    }
    if (note.length > 500) throw const TripFailure('Ghi chú tối đa 500 ký tự.');
    _trip = trip.copyWith(
      stage: TripStage.pickedUp,
      review: EvidenceReview.pending,
      attempts: trip.attempts + 1,
      submittedAt: now,
      evidence: evidence,
      note: note.trim(),
      cashCollected: cashCollected,
    );
    _publish();
  }

  @override
  Future<int> reportIncident(IncidentDraft draft) async {
    await _request();
    final trip = _requireTrip();
    final text = draft.description.trim();
    if (text.isEmpty) throw const TripFailure('Nhập mô tả sự cố.');
    if (text.length > 1000) {
      throw const TripFailure('Mô tả sự cố tối đa 1000 ký tự.');
    }
    for (final photo in draft.photos) {
      const ValidateCargoPhoto()(photo);
    }
    final id = ++_incidentSeq;
    _trip = trip.copyWith(
      incidents: [
        ...trip.incidents,
        TripIncident(
          id: id,
          orderId: int.tryParse(trip.job.id) ?? 0,
          orderCode: trip.job.label,
          type: draft.type,
          description: text,
          reportedByYou: true,
          status: IncidentStatus.open,
          createdAt: now,
          photoUrls: [
            for (final p in draft.photos) 'mock://incident/${p.name}',
          ],
        ),
      ],
    );
    _notice =
        'Đã gửi sự cố #$id. Chuyến tạm dừng cho tới khi điều phối viên xử lý.';
    _publish();
    return id;
  }

  @override
  void acknowledgeOutcome() {
    if (_outcome == null) return;
    _outcome = null;
    _publish();
  }

  /// Sự cố mở đầu tiên của chuyến (ưu tiên sự cố của tài xế) để giả lập thao tác của điều phối viên.
  TripIncident _openIncident() {
    final trip = _requireTrip();
    final open = trip.incidents.where((i) => i.isOpen).toList()
      ..sort((a, b) => (b.reportedByYou ? 1 : 0) - (a.reportedByYou ? 1 : 0));
    if (open.isEmpty) throw const TripFailure('Chưa có sự cố nào đang mở.');
    return open.first;
  }

  void _replaceIncident(TripIncident updated) {
    final trip = _requireTrip();
    _trip = trip.copyWith(
      incidents: [
        for (final i in trip.incidents) i.id == updated.id ? updated : i,
      ],
    );
  }

  @override
  Future<void> arriveDropoff() async {
    await _request();
    if (_requireTrip().stage != TripStage.inTransit) {
      throw const TripFailure('Chuyến chưa ở giai đoạn giao hàng.');
    }
    _trip = _requireTrip().copyWith(dropoffNotified: true);
    _publish();
  }

  @override
  Future<void> collectCash() async {
    await _request();
    final trip = _requireTrip();
    _trip = trip.copyWith(cashCollected: true);
    _publish();
  }

  @override
  Future<void> deliver(CargoPhoto proof) async {
    await _request();
    const ValidateCargoPhoto()(proof);
    final trip = _requireTrip();
    if (trip.stage != TripStage.inTransit) {
      throw const TripFailure('Chuyến chưa ở giai đoạn giao hàng.');
    }
    if (trip.job.cash && !trip.cashCollected) {
      throw const TripFailure(
        'Xác nhận đã thu tiền mặt trước khi hoàn tất giao hàng.',
      );
    }
    _trip = null;
    _notice = 'Đã giao hàng thành công chuyến #${trip.job.label}.';
    _publish();
  }

  @override
  Set<TripSimulation> get supported => TripSimulation.values.toSet();

  @override
  Future<void> simulate(TripSimulation action) async {
    switch (action) {
      case TripSimulation.newOffer:
        if (_hasTrip) {
          throw const TripFailure('Đang có chuyến, không thể nhận thêm.');
        }
        _generation++;
        _seed();
        _ignored.clear();
        if (!_online) await setOnline(true);
        await openOffer(_jobs.first.id);
      case TripSimulation.acceptElsewhere:
        if (_offer != null) _taken.add(_offer!.job.id);
        _notice = 'Đơn vừa được tài xế khác nhận.';
      case TripSimulation.cancelOrder:
        if (_trip != null) _trip = _trip!.copyWith(stage: TripStage.cancelled);
        _offer = null;
        _notice = 'Khách hàng đã hủy chuyến.';
      case TripSimulation.gpsLost:
        _gps = false;
        _stopGps();
        _offer = null;
      case TripSimulation.gpsRestored:
        _gps = true;
        if (_online) _startGps();
      case TripSimulation.mapUnavailable:
        _map = false;
      case TripSimulation.mapRestored:
        _map = true;
      case TripSimulation.nearPickup:
        _point = _requireTrip().job.pickupPoint;
        _ping();
      case TripSimulation.nearDropoff:
        _point = _requireTrip().job.dropoffPoint;
        _ping();
      case TripSimulation.dispatcherStarts:
        _replaceIncident(
          _openIncident().copyWith(status: IncidentStatus.inProgress),
        );
      case TripSimulation.dispatcherContinues:
        final incident = _openIncident();
        _replaceIncident(
          incident.copyWith(
            status: IncidentStatus.resolved,
            decision: 'ContinueTrip',
            note: 'Đã kiểm tra, tiếp tục chuyến.',
            resolvedAt: now,
          ),
        );
        _outcome = IncidentOutcome(
          IncidentOutcomeKind.continueTrip,
          orderCode: incident.orderCode,
          incidentId: incident.id,
          note: 'Đã kiểm tra, tiếp tục chuyến.',
        );
      case TripSimulation.dispatcherDismisses:
        final incident = _openIncident();
        _replaceIncident(
          incident.copyWith(
            status: IncidentStatus.cancelled,
            note: 'Báo cáo không hợp lệ.',
            resolvedAt: now,
          ),
        );
        _outcome = IncidentOutcome(
          IncidentOutcomeKind.dismissed,
          orderCode: incident.orderCode,
          incidentId: incident.id,
          note: 'Báo cáo không hợp lệ.',
        );
      case TripSimulation.dispatcherReassigns:
        final incident = _openIncident();
        _outcome = IncidentOutcome(
          IncidentOutcomeKind.reassignedAway,
          orderCode: incident.orderCode,
          incidentId: incident.id,
          note: 'Xe hỏng, đơn chuyển sang tài xế gần nhất.',
        );
        _trip = null;
      case TripSimulation.dispatcherCancelsOrder:
        final incident = _openIncident();
        _outcome = IncidentOutcome(
          IncidentOutcomeKind.orderCancelled,
          orderCode: incident.orderCode,
          incidentId: incident.id,
          note: 'Hủy do sự cố nghiêm trọng. [Cargo: ReturnToPickup]',
        );
        _trip = null;
      case TripSimulation.customerReportsIncident:
        final trip = _requireTrip();
        _trip = trip.copyWith(
          incidents: [
            ...trip.incidents,
            TripIncident(
              id: ++_incidentSeq,
              orderId: int.tryParse(trip.job.id) ?? 0,
              orderCode: trip.job.label,
              type: IncidentType.other,
              description:
                  'Khách hàng báo cáo sự cố, Điều phối viên đang xử lý.',
              reportedByYou: false,
              status: IncidentStatus.open,
              createdAt: now,
            ),
          ],
        );
      case TripSimulation.advanceRoute:
        final target = _requireTrip().job.pickupPoint;
        final distance = _point.distanceTo(target);
        final fraction = distance <= 300 ? 1.0 : 300 / distance;
        _point = GeoPoint(
          _point.latitude + (target.latitude - _point.latitude) * fraction,
          _point.longitude + (target.longitude - _point.longitude) * fraction,
        );
        _ping();
      case TripSimulation.uploadFailure:
        _failUpload = true;
      case TripSimulation.requestFailure:
        _failRequest = true;
      case TripSimulation.customerApproves:
      case TripSimulation.customerRejects:
        final trip = _requireTrip();
        if (trip.review != EvidenceReview.pending) {
          throw const TripFailure('Chưa có ảnh đang chờ khách xác nhận.');
        }
        final approved = action == TripSimulation.customerApproves;
        _trip = trip.copyWith(
          review: approved ? EvidenceReview.approved : EvidenceReview.rejected,
          stage: approved ? TripStage.inTransit : TripStage.pickedUp,
          reason: approved
              ? null
              : 'Ảnh chưa rõ dây chằng. Vui lòng chụp lại hàng đã cố định.',
        );
      case TripSimulation.emptyJobs:
        _jobs.clear();
        _offer = null;
      case TripSimulation.lowDeposit:
        _deposit = 100000;
    }
    _publish();
  }

  Future<void> close() async {
    _closed = true;
    _stopGps();
    _offerTimer?.cancel();
    await _updates.close();
  }
}
