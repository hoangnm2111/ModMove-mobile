import 'dart:async';
import 'dart:collection';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/usecases/validate_cargo_photo.dart';
import '../driver_api.dart';
import '../driver_location_source.dart';

/// Chuyến đi của tài xế chạy trên BE thật (api/driver/*), dữ liệu lấy từ DB.
///
/// Không có push: khi tài xế đăng nhập, repository đồng bộ định kỳ
/// ([AppConfig.driverPollInterval]) — gửi GPS, lấy đơn lân cận (Matching), lấy chuyến đang chạy
/// (Trips/active). Mọi quy tắc nghiệp vụ (bán kính, loại xe, ví cọc, GPS ≥ 5 phút, tranh đơn…)
/// do BE kiểm tra; app chỉ hiển thị lại lỗi của BE bằng tiếng Việt.
class ApiDriverTripRepository implements DriverTripRepository, TripSimulator {
  ApiDriverTripRepository({
    required this.api,
    DriverLocationSource? location,
    this._access = const DriverAccess(approved: false, active: true),
    this.availabilityGateway,
    this.pollInterval = AppConfig.driverPollInterval,
    this.offerWindow = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _location = location ?? const DeviceLocationSource(),
       _clock = clock ?? DateTime.now;

  final DriverApi api;
  final DriverLocationSource _location;
  final Future<bool> Function(bool)? availabilityGateway;
  final Duration pollInterval;

  /// Thời gian tài xế cân nhắc một đơn sau khi mở (giao diện đếm ngược 30 giây).
  final Duration offerWindow;
  final DateTime Function() _clock;

  final _updates = StreamController<DriverSession>.broadcast();
  final _ignored = <String>{};
  final _deadlines = <String, DateTime>{};
  final _jobCache = <String, DeliveryJob>{};

  /// Chuyến đã báo "đã đến điểm giao" (BE không lưu bước này).
  final _dropoffNotified = <String>{};

  DriverAccess _access;
  bool _signedIn = false, _gps = true, _foreground = true, _closed = false;
  bool __online = false;
  Future<void>? _running;
  int _deposit = 0, _earnings = 0, _pings = 0, _required = 200000, _missing = 0;
  ShiftSummary _shift = const ShiftSummary();
  GpsFix? _fix;
  JobOffer? _offer;
  ActiveTrip? _trip;
  IncidentOutcome? _outcome;
  List<DeliveryJob> _jobs = const [];
  String? _notice, _vehicleName;
  Timer? _timer;
  DateTime? _shiftAt;

  /// Luồng GPS đang nghe và hàng đợi gửi (cũ trước). Hàng đợi chỉ nằm trong bộ nhớ: tắt app là mất.
  StreamSubscription<GpsSample>? _watch;
  final _queue = Queue<GpsSample>();
  static const _maxQueued = 120, _maxAge = Duration(minutes: 10);

  /// BE ghi log GPS tối đa 1 điểm mỗi 60 giây mỗi đơn và điểm cũ không đổi vị trí cuối (B21):
  /// gửi bù dày hơn chỉ tốn request.
  static const _logGap = Duration(seconds: 60);

  /// Online ⇔ đang nghe GPS (và có thông báo của foreground service); mọi chỗ đổi trạng thái đều qua setter này.
  bool get _online => __online;
  set _online(bool value) {
    __online = value;
    _syncWatch();
  }

  @override
  DateTime get now => _clock();
  @override
  Stream<DriverSession> get changes => _updates.stream;
  bool get _hasTrip => _trip?.ongoing ?? false;

  @override
  DriverSession get current => DriverSession(
    online: _online,
    gpsEnabled: _gps,
    fix: _fix,
    offer: _offer,
    trip: _trip,
    deposit: _deposit,
    earnings: _earnings,
    shift: _shift,
    requiredDeposit: _required,
    missingDeposit: _missing,
    incidentOutcome: _outcome,
    pings: _pings,
    jobs: _hasTrip
        ? const []
        : _jobs.where((j) => !_ignored.contains(j.id)).toList(),
    notice: _notice,
  );

  void _publish() {
    if (!_closed && !_updates.isClosed) _updates.add(current);
  }

  /* ------------------------------------------------------------ vòng đời */

  /// Gọi khi đăng nhập/đăng xuất. Chỉ tài khoản Driver mới được đồng bộ.
  void onSessionChanged({required bool isDriver}) {
    if (isDriver == _signedIn) return;
    _signedIn = isDriver;
    if (isDriver) {
      _startTimer();
      unawaited(_sync());
    } else {
      _timer?.cancel();
      _timer = null;
      _reset();
      _publish();
    }
  }

  void _reset() {
    _online = false;
    _fix = null;
    _offer = null;
    _trip = null;
    _outcome = null;
    _jobs = const [];
    _deposit = _earnings = _pings = _missing = 0;
    _required = 200000;
    _shift = const ShiftSummary();
    _notice = null;
    _vehicleName = null;
    _shiftAt = null;
    _ignored.clear();
    _deadlines.clear();
    _jobCache.clear();
    _dropoffNotified.clear();
    _access = const DriverAccess(approved: false, active: true);
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_signedIn || _closed || !(_foreground || _online)) return;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_sync()));
  }

  /// Online thì vẫn đồng bộ khi ra nền (foreground service giữ tiến trình); Offline ra nền thì dừng hẳn.
  @override
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      _startTimer();
      if (_signedIn) unawaited(_sync());
    } else if (!_online) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _syncWatch() {
    if (_signedIn && __online && !_closed) {
      // Lỗi luồng (tắt GPS, mất quyền): mỗi vòng đồng bộ thử nghe lại.
      _watch ??= _location.watch().listen(_onSample, onError: (_) => _onWatchError());
      return;
    }
    _watch?.cancel();
    _watch = null;
    _queue.clear();
    if (!_foreground) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onSample(GpsSample sample) {
    _gps = true;
    _fix = GpsFix(sample.point, sample.at);
    _queue.addLast(sample);
    while (_queue.length > _maxQueued) {
      _queue.removeFirst();
    }
    _publish();
  }

  void _onWatchError() {
    _watch?.cancel();
    _watch = null;
    _gps = false;
    _fix = null;
    _publish();
  }

  @override
  void updateAccess(DriverAccess access) {
    _access = access;
    if (!access.eligible && _online) {
      _online = false;
      _offer = null;
      _jobs = const [];
      _notice = 'Hồ sơ chưa được duyệt hoặc tài khoản đang bị khóa.';
    }
    _publish();
  }

  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    _syncWatch();
    await _updates.close();
  }

  /* ------------------------------------------------------------ đồng bộ */

  /// Một vòng đồng bộ với BE. [strict] = ném lỗi để giao diện hiển thị (kéo để tải lại).
  /// Vòng đang chạy thì vòng định kỳ dùng lại kết quả của nó; vòng strict chờ xong rồi chạy lại.
  Future<void> _sync({bool strict = false}) {
    if (!_signedIn || _closed) return Future.value();
    final running = _running;
    if (running != null && !strict) return running;
    final next = (running ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => _syncOnce(strict: strict));
    _running = next;
    return next.whenComplete(() {
      if (identical(_running, next)) _running = null;
    });
  }

  Future<void> _syncOnce({required bool strict}) async {
    if (!_signedIn || _closed) return;
    try {
      final status = await api.status();
      _applyStatus(status);

      if (_online) {
        try {
          await _pushLocation();
        } catch (error) {
          // Gửi GPS lỗi (mạng, 5xx) không làm hỏng cả vòng: điểm còn trong hàng đợi, vòng sau gửi bù.
          if (error is ApiException && error.code == 'ACCOUNT_INACTIVE') rethrow;
        }
      }
      await _loadTrip(
        _trip?.job.id ?? (status['activeOrderId'] as num?)?.toInt().toString(),
      );
      if (_online && !_hasTrip) {
        await _loadJobs();
      } else {
        _jobs = const [];
        if (_offer != null && !_hasTrip) _offer = null;
      }
      await _loadShift();
      _publish();
    } catch (error) {
      if (error is ApiException && error.code == 'ACCOUNT_INACTIVE') {
        _access = const DriverAccess(approved: false, active: false);
        _online = false;
        _notice = error.message;
        _publish();
      }
      if (strict) throw _failure(error);
    }
  }

  void _applyStatus(Map<String, dynamic> j) {
    _deposit = _money(j['depositBalance']);
    _earnings = _money(j['earningsBalance']);
    _access = DriverAccess(
      approved: j['approvalStatus'] == 'Approved',
      active: true,
    );
    _online = j['isOnline'] == true && _access.eligible;
  }

  /// Gửi hàng đợi theo thứ tự cũ trước. Lỗi mạng/5xx: dừng và giữ lại (ném lên để vòng sau gửi bù);
  /// 400/422: bỏ điểm đó. 422 MOCK_LOCATION (B20): tắt Online.
  Future<void> _pushLocation() async {
    final cutoff = now.subtract(_maxAge);
    _queue.removeWhere((s) => s.at.isBefore(cutoff));
    _thinBacklog();
    // Chỉ gửi các điểm có sẵn lúc bắt đầu: điểm đến trong lúc gửi chờ vòng sau, để mạng chậm
    // không giữ vòng đồng bộ mãi ở đây (không tải được chuyến và đơn).
    for (var left = _queue.length; left > 0 && _queue.isNotEmpty; left--) {
      final sample = _queue.first;
      try {
        await api.sendLocation(
          sample.point.latitude,
          sample.point.longitude,
          accuracy: sample.accuracy,
          isMocked: sample.isMocked,
          recordedAt: sample.at,
        );
        _pings++;
      } on ApiException catch (error) {
        if (error.code == 'ACCOUNT_INACTIVE' || (error.status != 400 && error.status != 422)) rethrow;
        if (error.code == 'MOCK_LOCATION') {
          await _blockMockLocation();
        } else if (error.status == 400 && identical(sample, _queue.last)) {
          await _sendWithServerTime(sample);
        }
      }
      if (_queue.isNotEmpty && identical(_queue.first, sample)) _queue.removeFirst();
    }
  }

  /// Sau khi mất mạng: giữ 1 điểm mỗi [_logGap] và điểm mới nhất, theo thứ tự cũ trước.
  void _thinBacklog() {
    if (_queue.length < 3) return;
    final newest = _queue.last;
    final kept = <GpsSample>[];
    for (final sample in _queue) {
      if (kept.isEmpty || identical(sample, newest) || !sample.at.isBefore(kept.last.at.add(_logGap))) kept.add(sample);
    }
    _queue
      ..clear()
      ..addAll(kept);
  }

  /// BE trả 400 khi `recordedAt` lệch giờ server (đồng hồ máy chạy nhanh quá 30 giây): gửi lại điểm mới nhất
  /// không kèm `recordedAt` để BE dùng giờ của nó, nếu không tài xế bị coi là mất GPS mà không biết vì sao.
  Future<void> _sendWithServerTime(GpsSample sample) async {
    try {
      await api.sendLocation(sample.point.latitude, sample.point.longitude, accuracy: sample.accuracy, isMocked: sample.isMocked);
      _pings++;
    } on ApiException catch (error) {
      if (error.code == 'ACCOUNT_INACTIVE') rethrow;
      // Lỗi khác: bỏ điểm này, điểm tiếp theo đến sau 5 giây.
    }
  }

  Future<void> _blockMockLocation() async {
    _notice = 'Tắt ứng dụng giả lập vị trí để nhận đơn';
    _offer = null;
    _jobs = const [];
    _online = false;
    try {
      // BE vẫn ghi Online: báo Offline để vòng sau không bật lại (đang có chuyến thì BE từ chối, bỏ qua).
      final gateway = availabilityGateway;
      if (gateway != null) {
        await gateway(false);
      } else {
        await api.setOnline(false);
      }
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    final orders = await api.matchingOrders();
    _jobs = [for (final o in orders) _jobFromMatching(o)];
    for (final job in _jobs) {
      _jobCache[job.id] = job;
    }
    final offer = _offer;
    if (offer != null && offer.remainingAt(now) == 0) _offer = null;
  }

  Future<void> _loadTrip(String? knownId) async {
    final active = await api.activeTrip();
    final previous = _trip;
    if (active != null) {
      final next = _tripFrom(active);
      if (previous != null && previous.job.id == next.job.id) {
        _detectIncidentChange(previous, next);
      }
      _trip = next;
      _offer = null;
      return;
    }
    if (previous == null) return;
    // Chuyến đã hủy được giữ lại để màn hình báo cho tài xế; đã biết kết quả thì không hỏi lại BE mỗi vòng.
    if (!previous.ongoing) return;
    // Chuyến vừa biến mất khỏi "active": hủy, hoàn tất, đổi tài xế hoặc hủy do sự cố.
    final hadIncident = previous.incidents.any((i) => i.isOpen);
    if (hadIncident) {
      final outcome = await _outcomeFor(previous);
      if (outcome != null) {
        _outcome = outcome;
        _trip = null;
        _notice = outcome.title;
        return;
      }
    }
    try {
      final detail = await api.trip(previous.job.id);
      final status = detail['orderStatus'] as String?;
      if (status == 'Cancelled') {
        _trip = _tripFrom(detail);
        // Người hủy có thể là khách, điều phối viên hoặc hệ thống: không gán cho khách.
        _notice = 'Chuyến #${previous.job.label} đã bị hủy.';
      } else {
        _trip = null;
        _notice = 'Chuyến #${previous.job.label} đã kết thúc.';
      }
    } catch (_) {
      _trip = null;
    }
  }

  /// So sánh sự cố trước và sau lần tải: sự cố mở vừa được đóng thì báo kết quả cho tài xế.
  void _detectIncidentChange(ActiveTrip previous, ActiveTrip next) {
    for (final before in previous.incidents.where((i) => i.isOpen)) {
      final after = next.incidents.where((i) => i.id == before.id).firstOrNull;
      if (after == null || after.isOpen) continue;
      if (after.status == IncidentStatus.cancelled) {
        _outcome = IncidentOutcome(
          IncidentOutcomeKind.dismissed,
          orderCode: next.job.label,
          incidentId: after.id,
          note: after.note,
        );
      } else if (after.decision == 'ContinueTrip') {
        _outcome = IncidentOutcome(
          IncidentOutcomeKind.continueTrip,
          orderCode: next.job.label,
          incidentId: after.id,
          note: after.note,
        );
      }
    }
  }

  /// Đơn đã rời khỏi tôi sau khi sự cố đóng: đọc quyết định của điều phối viên từ api/driver/incidents.
  Future<IncidentOutcome?> _outcomeFor(ActiveTrip previous) async {
    try {
      final page = await api.incidents(
        orderId: int.tryParse(previous.job.id),
        pageSize: 10,
      );
      final items =
          ((page['items'] as List?) ?? const [])
              .map(
                (e) => TripIncident.fromJson(
                  (e as Map).cast<String, dynamic>(),
                  orderCode: previous.job.label,
                ),
              )
              .where(
                (i) =>
                    i.status == IncidentStatus.resolved && i.decision != null,
              )
              .toList()
            ..sort(
              (a, b) => (b.resolvedAt ?? b.createdAt).compareTo(
                a.resolvedAt ?? a.createdAt,
              ),
            );
      final latest = items.firstOrNull;
      if (latest == null) return null;
      final kind = switch (latest.decision) {
        'ReassignDriver' => IncidentOutcomeKind.reassignedAway,
        'CancelOrder' => IncidentOutcomeKind.orderCancelled,
        _ => null,
      };
      return kind == null
          ? null
          : IncidentOutcome(
              kind,
              orderCode: previous.job.label,
              incidentId: latest.id,
              note: latest.note,
            );
    } catch (_) {
      return null;
    }
  }

  @override
  void acknowledgeOutcome() {
    if (_outcome == null) return;
    _outcome = null;
    _publish();
  }

  Future<void> _loadShift() async {
    final last = _shiftAt;
    if (!_access.approved ||
        (last != null && now.difference(last) < const Duration(seconds: 30))) {
      return;
    }
    _shiftAt = now;
    try {
      final j = await api.todayEarnings();
      _shift = ShiftSummary(
        completed: (j['completedTrips'] as num?)?.toInt() ?? 0,
        income: _money(j['netEarnings']),
      );
      final wallet = await api.wallet();
      _required = _money(wallet['requiredDeposit']);
      _missing = _money(wallet['missingDepositAmount']);
    } catch (_) {
      /* Thống kê ca là phụ; giữ giá trị cũ. */
    }
  }

  @override
  Future<void> refresh() async {
    _shiftAt = null;
    await _sync(strict: true);
  }

  /* ------------------------------------------------------------ thao tác */

  TripFailure _failure(Object error) {
    if (error is TripFailure) return error;
    if (error is ApiException) {
      // Cùng mã lỗi, câu chữ riêng cho tài xế (khách có câu riêng ở ApiException).
      if (error.code == 'INCIDENT_PENDING') {
        return const TripFailure('Bạn đang có sự cố chờ điều phối viên xử lý.');
      }
      if (error.code == 'INCIDENT_NOT_ALLOWED') {
        return const TripFailure('Chỉ báo sự cố khi đơn đang chạy.');
      }
      return TripFailure(error.message);
    }
    return const TripFailure('Chưa thực hiện được. Vui lòng thử lại.');
  }

  /// Lỗi khi mở/nhận đơn: 409 ở đây luôn là "tài xế khác đã nhận trước" (không phải trùng dữ liệu chung).
  TripFailure _matchingFailure(Object error) {
    if (error is ApiException) {
      if (error.status == 409) {
        return const TripFailure('Đơn đã có tài xế khác nhận trước.');
      }
      if (error.code == 'ORDER_CANCELLED') {
        return const TripFailure('Khách đã hủy đơn này.');
      }
      if (error.code == 'BUSINESS_RULE') {
        return const TripFailure('Đơn không còn mở để nhận.');
      }
    }
    return _failure(error);
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      // BE từ chối vì chuyến đang có sự cố mở (dữ liệu trên máy đã cũ): tải lại để khớp rồi báo lỗi.
      if (error is ApiException && error.code == 'INCIDENT_PENDING') {
        try {
          await _reloadTrip();
        } catch (_) {
          /* giữ lỗi gốc */
        }
      }
      throw _failure(error);
    }
  }

  @override
  Future<void> setOnline(bool online) async {
    if (online && !_access.eligible) {
      throw const TripFailure(
        'Cần hồ sơ đã duyệt và tài khoản đang hoạt động.',
      );
    }
    if (!online && _hasTrip) {
      throw const TripFailure(
        'Bạn đang có chuyến. Hoàn tất chuyến trước khi tắt hoạt động.',
      );
    }
    if (online) {
      final sample = await _location.current();
      if (sample == null) {
        _gps = false;
        _publish();
        throw const TripFailure('Bật quyền vị trí trước khi nhận đơn.');
      }
      _onSample(sample);
    }
    await _call(() async {
      final gateway = availabilityGateway;
      if (gateway != null) {
        if (!await gateway(online)) {
          throw const TripFailure(
            'Chưa cập nhật được trạng thái hoạt động. Vui lòng thử lại.',
          );
        }
      } else {
        await api.setOnline(online);
      }
    });
    _online = online;
    _notice = null;
    if (online) {
      await _call(_pushLocation);
    } else {
      _offer = null;
      _jobs = const [];
    }
    _publish();
    if (online) unawaited(_sync());
  }

  @override
  Future<void> openOffer(String jobId) async {
    final existing = _offer;
    if (existing?.job.id == jobId && existing!.remainingAt(now) > 0) return;
    final Map<String, dynamic> detail;
    try {
      detail = await api.matchingOrder(jobId);
    } catch (error) {
      if (error is ApiException &&
          (error.status == 409 || error.status == 422)) {
        // Đơn đã có người nhận / bị hủy / hết hạn ghép: bỏ khỏi danh sách để không hiện lại.
        _ignored.add(jobId);
        _publish();
      }
      throw _matchingFailure(error);
    }
    if (detail['canAccept'] == false) {
      throw TripFailure(_reason(detail['ineligibleReason'] as String?));
    }
    final job = _jobFromMatching(detail, fallback: _jobCache[jobId]);
    _jobCache[jobId] = job;
    var deadline = now.add(offerWindow);
    final expires = DateTime.tryParse('${detail['matchingExpiresAt'] ?? ''}');
    if (expires != null && expires.isBefore(deadline)) deadline = expires;
    if (!deadline.isAfter(now)) {
      throw const TripFailure('Đơn đã hết thời gian ghép.');
    }
    _deadlines[jobId] = deadline;
    _offer = JobOffer(job, deadline);
    _publish();
  }

  @override
  Future<void> declineOffer() async {
    final id = _offer?.job.id;
    if (id != null) _ignored.add(id);
    _offer = null;
    _publish();
  }

  @override
  Future<void> acceptOffer(String jobId) async {
    final offer = _offer;
    if (offer?.job.id != jobId || offer!.remainingAt(now) == 0) {
      throw const TripFailure('Đã hết thời gian nhận chuyến.');
    }
    try {
      await api.acceptOrder(jobId);
    } catch (error) {
      if (error is ApiException &&
          (error.status == 409 || error.status == 422)) {
        // Đơn đã có người nhận / bị huỷ: bỏ khỏi danh sách để không hiện lại.
        _ignored.add(jobId);
        _jobs = _jobs.where((j) => j.id != jobId).toList();
        _publish();
      }
      throw _matchingFailure(error);
    }
    _offer = null;
    _jobs = const [];
    final active = await _call(api.activeTrip);
    _trip = active == null ? ActiveTrip(job: offer.job) : _tripFrom(active);
    _publish();
  }

  ActiveTrip _requireTrip() {
    if (!_access.eligible) {
      throw const TripFailure('Tài khoản không được phép thao tác.');
    }
    final trip = _trip;
    if (trip == null || !trip.ongoing) {
      throw const TripFailure('Chuyến đã hủy hoặc không còn hoạt động.');
    }
    return trip;
  }

  Future<void> _reloadTrip() async {
    final id = _trip?.job.id;
    if (id == null) return;
    final detail = await _call(() => api.trip(id));
    _trip = _tripFrom(detail);
    _publish();
  }

  @override
  Future<void> arrive() async {
    final trip = _requireTrip();
    if (trip.stage == TripStage.arrived) return;
    if (trip.stage != TripStage.accepted) {
      throw const TripFailure('Trạng thái chuyến đã thay đổi.');
    }
    await _call(() => api.arrive(trip.job.id));
    await _reloadTrip();
  }

  @override
  Future<UploadedEvidence> upload(
    CargoPhoto photo,
    void Function(double) progress,
  ) async {
    const ValidateCargoPhoto()(photo);
    final trip = _requireTrip();
    if (!trip.editable) {
      throw const TripFailure('Chưa thể thay đổi ảnh ở trạng thái này.');
    }
    progress(0.1);
    final url = await _call(() => api.upload(photo.name, photo.bytes));
    progress(1);
    return UploadedEvidence(photo.kind, url);
  }

  @override
  Future<void> submitInspection({
    required List<UploadedEvidence> evidence,
    required List<bool> checklist,
    required String note,
    required bool cashCollected,
  }) async {
    final trip = _requireTrip();
    if (!trip.editable) {
      throw const TripFailure('Không thể gửi ảnh ở trạng thái hiện tại.');
    }
    if (evidence.length < 2) {
      throw const TripFailure('Cần tải đủ 2 ảnh bằng chứng.');
    }
    if (note.length > 500) throw const TripFailure('Ghi chú tối đa 500 ký tự.');
    if (trip.job.payment == PaymentMethod.cashSender && !trip.job.paid) {
      if (!cashCollected) {
        throw const TripFailure(
          'Xác nhận đã thu tiền từ người gửi trước khi lấy hàng.',
        );
      }
      try {
        await api.collectCash(trip.job.id);
      } catch (error) {
        // Lần gửi trước đã ghi nhận thu tiền nhưng gửi ảnh lỗi: BE báo đã thu rồi thì gửi ảnh tiếp.
        if (error is! ApiException || error.code != 'ORDER_ALREADY_PAID') {
          await _call<void>(() => Future<void>.error(error));
        }
      }
    }
    await _call(
      () => api.pickup(trip.job.id, [for (final e in evidence) e.reference]),
    );
    await _reloadTrip();
  }

  @override
  Future<int> reportIncident(IncidentDraft draft) async {
    final trip = _requireTrip();
    final text = draft.description.trim();
    if (text.isEmpty) throw const TripFailure('Nhập mô tả sự cố.');
    if (text.length > 1000) {
      throw const TripFailure('Mô tả sự cố tối đa 1000 ký tự.');
    }
    if (draft.photos.length > 5) throw const TripFailure('Tối đa 5 ảnh.');
    final urls = <String>[];
    for (final photo in draft.photos) {
      const ValidateCargoPhoto()(photo);
      urls.add(await _call(() => api.upload(photo.name, photo.bytes)));
    }
    final id = await _call(
      () => api.reportIncident(
        orderId: trip.job.id,
        incidentType: draft.type.apiValue,
        description: text,
        photoUrls: urls,
        latitude: draft.latitude ?? _fix?.point.latitude,
        longitude: draft.longitude ?? _fix?.point.longitude,
      ),
    );
    _notice =
        'Đã gửi sự cố #$id. Chuyến tạm dừng cho tới khi điều phối viên xử lý.';
    await _reloadTrip();
    return id;
  }

  @override
  Future<void> arriveDropoff() async {
    final trip = _requireTrip();
    if (trip.stage != TripStage.inTransit) {
      throw const TripFailure('Chuyến chưa ở giai đoạn giao hàng.');
    }
    await _call(() => api.arriveDropoff(trip.job.id));
    // Màn hình hiện trạng thái "đã báo khách" từ cờ này, không cần thêm câu thông báo.
    _dropoffNotified.add(trip.job.id);
    _trip = trip.copyWith(dropoffNotified: true);
    _publish();
  }

  @override
  Future<void> collectCash() async {
    final trip = _requireTrip();
    if (!trip.job.cash) {
      throw const TripFailure('Đơn này đã thanh toán online.');
    }
    await _call(() => api.collectCash(trip.job.id));
    await _reloadTrip();
  }

  @override
  Future<void> deliver(CargoPhoto proof) async {
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
    final url = await _call(() => api.upload(proof.name, proof.bytes));
    await _call(() => api.deliver(trip.job.id, url));
    _trip = null;
    _dropoffNotified.remove(trip.job.id);
    _shiftAt = null;
    _notice = 'Đã giao hàng thành công chuyến #${trip.job.label}.';
    _publish();
    unawaited(_sync());
  }

  /* ------------------------------------------------------------ không có mô phỏng GPS (B20) */

  /// BE thật không có kịch bản mô phỏng; máy ảo test bằng Extended Controls → Location.
  @override
  Set<TripSimulation> get supported => const {};

  @override
  Future<void> simulate(TripSimulation action) async {
    throw const TripFailure('Kịch bản này chỉ có ở bản mô phỏng.');
  }

  /* ------------------------------------------------------------ ánh xạ JSON → model */

  static int _money(Object? v) =>
      v is num ? v.round() : int.tryParse('$v') ?? 0;
  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static String _reason(String? reason) => (reason == null || reason.isEmpty)
      ? 'Đơn không còn khả dụng hoặc bạn chưa đủ điều kiện.'
      : reason;

  static PaymentMethod _payment(Map<String, dynamic> j) {
    if (j['paymentMethod'] != 'Cash') return PaymentMethod.payos;
    return j['payerRole'] == 'Receiver'
        ? PaymentMethod.cashReceiver
        : PaymentMethod.cashSender;
  }

  /// Dòng của `Matching/orders` hoặc `Matching/orders/{id}` (chi tiết có thêm cước/hàng).
  DeliveryJob _jobFromMatching(
    Map<String, dynamic> j, {
    DeliveryJob? fallback,
  }) {
    final cargo = j['cargo'] is Map
        ? (j['cargo'] as Map).cast<String, dynamic>()
        : j;
    String pick(String a, String b) => (j[a] ?? j[b] ?? '') as String;
    return DeliveryJob(
      id: '${j['orderId'] ?? j['id'] ?? fallback?.id}',
      code: (j['orderCode'] as String?) ?? fallback?.code,
      pickup: pick('pickupAddress', 'pickup'),
      dropoff: pick('dropoffAddress', 'dropoff'),
      pickupPoint: GeoPoint(
        _num(j['pickupLatitude']),
        _num(j['pickupLongitude']),
      ),
      dropoffPoint: GeoPoint(
        _num(j['dropoffLatitude']),
        _num(j['dropoffLongitude']),
      ),
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal() ?? now,
      distanceKm: _num(j['estimatedDistanceKm']),
      minutes: _num(j['estimatedDurationMin']).round(),
      boxes: _num(cargo['cargoQuantity'] ?? cargo['quantity']).round(),
      weightKg: _num(cargo['cargoWeightKg'] ?? cargo['weightKg']).round(),
      fare: _money(j['totalFee']),
      commission: _money(j['commissionAmount']),
      payment: _payment(j),
      paid: j['paymentMethod'] != 'Cash',
      fragile: false,
      vehicle:
          (j['vehicleTypeName'] as String?) ??
          fallback?.vehicle ??
          _vehicleName ??
          '',
      customerName:
          (j['customerName'] as String?) ??
          fallback?.customerName ??
          'Khách hàng',
      customerPhone:
          (j['customerPhone'] as String?) ?? fallback?.customerPhone ?? '',
    );
  }

  /// Chi tiết chuyến `Trips/{id}` hoặc `Trips/active`.
  ActiveTrip _tripFrom(Map<String, dynamic> j) {
    final cargo =
        (j['cargo'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final proof = (j['proof'] as Map?)?.cast<String, dynamic>();
    final histories = ((j['statusHistories'] as List?) ?? const []).map(
      (e) => (e as Map).cast<String, dynamic>(),
    );
    DateTime? when(String status) {
      final times = histories
          .where((h) => h['toStatus'] == status)
          .map((h) => DateTime.tryParse('${h['changedAt']}')?.toLocal());
      return times.whereType<DateTime>().fold<DateTime?>(
        null,
        (a, b) => a == null || b.isAfter(a) ? b : a,
      );
    }

    final job = DeliveryJob(
      id: '${j['id']}',
      code: j['orderCode'] as String?,
      pickup: (j['pickupAddress'] ?? '') as String,
      dropoff: (j['dropoffAddress'] ?? '') as String,
      pickupPoint: GeoPoint(
        _num(j['pickupLatitude']),
        _num(j['pickupLongitude']),
      ),
      dropoffPoint: GeoPoint(
        _num(j['dropoffLatitude']),
        _num(j['dropoffLongitude']),
      ),
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal() ?? now,
      distanceKm: _num(j['estimatedDistanceKm']),
      minutes: _num(j['estimatedDurationMin']).round(),
      boxes: _num(cargo['quantity']).round(),
      weightKg: _num(cargo['weightKg']).round(),
      fare: _money(j['totalFee']),
      commission: _money(j['commissionAmount']),
      payment: _payment(j),
      paid: j['paymentStatus'] == 'Paid',
      fragile: false,
      vehicle: (j['vehicleTypeName'] as String?) ?? _vehicleName ?? '',
      customerName: (j['customerName'] as String?) ?? 'Khách hàng',
      customerPhone: (j['customerPhone'] as String?) ?? '',
    );

    final status = j['orderStatus'] as String?;
    final proofStatus = proof?['proofStatus'] as String?;
    final stage = switch (status) {
      'Arrived' => TripStage.arrived,
      'PickedUp' => TripStage.pickedUp,
      'InTransit' => TripStage.inTransit,
      'Cancelled' => TripStage.cancelled,
      _ => TripStage.accepted,
    };
    final review = switch (status) {
      'InTransit' => EvidenceReview.approved,
      'PickedUp' =>
        proofStatus == 'Rejected'
            ? EvidenceReview.rejected
            : EvidenceReview.pending,
      _ => EvidenceReview.none,
    };
    final urls = ((proof?['pickupPhotoUrls'] as List?) ?? const [])
        .cast<String>();
    return ActiveTrip(
      job: job,
      stage: stage,
      review: review,
      attempts: (proof?['pickupSubmissionCount'] as num?)?.toInt() ?? 0,
      reason: review == EvidenceReview.rejected
          ? (proof?['rejectionReason'] as String?)
          : null,
      arrivedAt: when('Arrived'),
      submittedAt: when('PickedUp'),
      cashCollected: job.paid && job.cash,
      dropoffNotified:
          stage == TripStage.inTransit && _dropoffNotified.contains(job.id),
      incidents: [
        for (final e in ((j['incidents'] as List?) ?? const []))
          TripIncident.fromJson(
            (e as Map).cast<String, dynamic>(),
            orderId: (j['id'] as num?)?.toInt(),
            orderCode: j['orderCode'] as String?,
          ),
      ],
      evidence: [
        for (var i = 0; i < urls.length; i++)
          UploadedEvidence(
            i.isEven ? CargoPhotoKind.overall : CargoPhotoKind.secured,
            urls[i],
          ),
      ],
    );
  }
}
