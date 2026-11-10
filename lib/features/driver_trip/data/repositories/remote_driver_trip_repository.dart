import 'dart:async';
import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/domain/result_page.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_location_gateway.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/repositories/trip_history_repository.dart';
import '../../domain/usecases/validate_cargo_photo.dart';
import '../models/driver_trip_dto.dart';
import '../services/driver_tracking_connection.dart';

class RemoteDriverTripRepository
    implements
        DriverTripRepository,
        DriverDeliveryRepository,
        TripHistoryRepository {
  RemoteDriverTripRepository(
    this.api,
    this.location,
    this.tracking, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _tripKey = 'active-order:${api.baseUrl}:${api.session!.userId}' {
    _updates = tracking.updates.listen((_) => _tick());
  }
  final ApiClient api;
  final DriverLocationGateway location;
  final DriverTrackingConnection tracking;
  final DateTime Function() _clock;
  final _changes = StreamController<DriverSession>.broadcast();
  late final StreamSubscription<void> _updates;
  Timer? _timer;
  Future<void>? _refreshing;
  bool _foreground = true, _closed = false, _ticking = false, _mutating = false;
  DriverSession _current = DriverSession();
  Map<String, dynamic>? _accepted;
  final Map<String, DateTime> _deadlines = {};
  final Set<String> _dismissed = {};
  DriverAccess _access = const DriverAccess(approved: true, active: true);
  final String _tripKey;
  @override
  DriverSession get current => _current;
  @override
  DateTime get now => _clock();
  @override
  Stream<DriverSession> get changes => _changes.stream;
  void _emit(DriverSession value) {
    if (!_closed) {
      _current = value;
      _changes.add(value);
    }
  }

  DriverSession _copy({
    bool? online,
    bool? gpsEnabled,
    GpsFix? fix,
    JobOffer? offer,
    bool clearOffer = false,
    ActiveTrip? trip,
    bool clearTrip = false,
    List<DeliveryJob>? jobs,
    int? deposit,
    int? earnings,
    int? pings,
    ShiftSummary? shift,
    String? notice,
  }) => DriverSession(
    online: online ?? current.online,
    gpsEnabled: gpsEnabled ?? current.gpsEnabled,
    fix: fix ?? current.fix,
    offer: clearOffer ? null : offer ?? current.offer,
    trip: clearTrip ? null : trip ?? current.trip,
    jobs: jobs ?? current.jobs,
    deposit: deposit ?? current.deposit,
    earnings: earnings ?? current.earnings,
    pings: pings ?? current.pings,
    shift: shift ?? current.shift,
    notice: notice,
  );

  Future<void> initialize() async {
    final cache = await api.store.read(_tripKey);
    if (cache != null) _accepted = jsonDecode(cache) as Map<String, dynamic>;
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiFailure catch (e) {
      throw TripFailure(e.message);
    }
  }

  Future<void> _tick() async {
    if (_closed || !_foreground || _ticking || _mutating) return;
    _ticking = true;
    try {
      await refresh();
    } catch (e) {
      _emit(
        _copy(
          jobs: [],
          gpsEnabled: false,
          clearOffer: true,
          notice: e.toString(),
        ),
      );
    } finally {
      _ticking = false;
    }
  }

  @override
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() => _guard(() async {
    if (_closed) return;
    final status = await api.request('GET', '/api/driver/status') as Map;
    if (_closed) return;
    final activeId = status['activeOrderId']?.toString();
    ActiveTrip? trip;
    if (activeId != null) {
      trip = await detail(activeId);
    } else if (current.trip != null) {
      // Delivered trips leave /active; retain their server-confirmed receipt until
      // another trip starts. A reassignment may remove read access to the old trip.
      try {
        trip = DriverTripDto.parse(
          await api.request('GET', '/api/driver/trips/${current.trip!.job.id}')
              as Map,
        );
      } on ApiFailure catch (e) {
        if (![403, 404, 422].contains(e.status)) rethrow;
      }
    } else if (_accepted != null) {
      _accepted = null;
      await api.store.delete(_tripKey);
    }
    _emit(
      _copy(
        online: status['isOnline'] == true,
        trip: trip,
        clearTrip: trip == null,
        deposit: (status['depositBalance'] as num).round(),
        earnings: (status['earningsBalance'] as num).round(),
      ),
    );
    if (_foreground && (current.online || (trip?.ongoing ?? false))) {
      try {
        final fix = await location.current();
        if (!_foreground || _closed) return;
        await tracking.send(fix);
        _emit(_copy(fix: fix, gpsEnabled: true, pings: current.pings + 1));
      } on TripFailure catch (e) {
        _emit(
          _copy(
            gpsEnabled: false,
            jobs: [],
            clearOffer: true,
            notice: e.message,
          ),
        );
        return;
      }
    }
    if (!current.online ||
        (trip?.ongoing ?? false) ||
        !_access.eligible ||
        !_foreground) {
      _emit(_copy(jobs: [], clearOffer: true));
      return;
    }
    final rows =
        await api.request('GET', '/api/driver/matching/orders') as List;
    final jobs = rows
        .map((e) => _job(Map<String, dynamic>.from(e as Map)))
        .toList();
    _dismissed.removeWhere((id) => !jobs.any((job) => job.id == id));
    _deadlines.removeWhere((id, _) => !jobs.any((job) => job.id == id));
    _rows = {
      for (final row in rows)
        '${row['orderId']}': Map<String, dynamic>.from(row as Map),
    };
    var offer = current.offer;
    if (offer != null &&
        (offer.remainingAt(now) == 0 ||
            !jobs.any((j) => j.id == offer!.job.id))) {
      _dismissed.add(offer.job.id);
      offer = null;
    }
    final next = jobs.where((j) => !_dismissed.contains(j.id)).firstOrNull;
    offer ??= next == null
        ? null
        : JobOffer(
            next,
            _deadlines.putIfAbsent(
              next.id,
              () => now.add(const Duration(seconds: 30)),
            ),
          );
    _emit(_copy(jobs: jobs, offer: offer, clearOffer: offer == null));
  });
  Map<String, Map<String, dynamic>> _rows = {};
  DeliveryJob _job(Map<String, dynamic> row) => DeliveryJob(
    orderCode: '${row['orderCode'] ?? ''}',
    cargoDescription:
        '${row['cargoTypeName'] ?? row['cargoType']} · ${row['cargoLengthCm']} × ${row['cargoWidthCm']} × ${row['cargoHeightCm']} cm',
    notes: '${row['specialNotes'] ?? ''}',
    photoUrls: List<String>.unmodifiable(
      (row['cargoPhotoUrls'] as List? ?? []).cast<String>(),
    ),
    loadingService: row['hasLoadingService'] == true,
    id: '${row['orderId']}',
    pickup: row['pickupAddress'] as String,
    dropoff: row['dropoffAddress'] as String,
    pickupPoint: GeoPoint(
      (row['pickupLatitude'] as num).toDouble(),
      (row['pickupLongitude'] as num).toDouble(),
    ),
    dropoffPoint: GeoPoint(
      (row['dropoffLatitude'] as num).toDouble(),
      (row['dropoffLongitude'] as num).toDouble(),
    ),
    createdAt: DateTime.parse(row['createdAt'] as String),
    distanceKm: (row['estimatedDistanceKm'] as num).toDouble(),
    minutes: (row['estimatedDurationMin'] as num).toInt(),
    boxes: (row['cargoQuantity'] as num).toInt(),
    weightKg: (row['cargoWeightKg'] as num).round(),
    fare: (row['totalFee'] as num).round(),
    commission: (row['commissionAmount'] as num).round(),
    payment: row['paymentMethod'] == 'PayOS'
        ? PaymentMethod.payos
        : row['payerRole'] == 'Receiver'
        ? PaymentMethod.cashReceiver
        : PaymentMethod.cashSender,
    customerName: '',
    customerPhone: '',
    vehicle: 'Xe đã đăng ký',
    fragile: row['cargoType'] == 'Fragile',
  );

  @override
  Future<void> setOnline(bool online) => _guard(() async {
    if (_mutating) throw const TripFailure('Đang xử lý yêu cầu.');
    _mutating = true;
    try {
      if (_refreshing != null) await _refreshing;
      GpsFix? fix;
      if (online) fix = await location.current(requestPermission: true);
      await api.request(
        'PATCH',
        '/api/driver/online-status',
        body: {'isOnline': online},
      );
      _emit(_copy(online: online, jobs: [], clearOffer: true));
      if (fix != null && _foreground) await tracking.send(fix);
      if (!online && current.trip == null) await tracking.pause();
      await refresh();
    } finally {
      _mutating = false;
    }
  });
  @override
  void updateAccess(DriverAccess access) {
    _access = access;
  }

  @override
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      _tick();
    } else {
      unawaited(tracking.pause());
    }
  }

  @override
  Future<void> openOffer(String jobId) async {
    final job = current.jobs.where((j) => j.id == jobId).firstOrNull;
    if (job == null) {
      throw const TripFailure('Đơn không còn trong danh sách. Hãy tải lại.');
    }
    final deadline = _deadlines.putIfAbsent(
      jobId,
      () => now.add(const Duration(seconds: 30)),
    );
    if (!now.isBefore(deadline)) {
      throw const TripFailure('Đã hết thời gian xem lời mời này. Chờ đơn mới.');
    }
    _emit(_copy(offer: JobOffer(job, deadline)));
  }

  @override
  Future<void> declineOffer() async {
    if (current.offer != null) _dismissed.add(current.offer!.job.id);
    _emit(_copy(clearOffer: true));
  }

  @override
  Future<void> acceptOffer(String jobId) => _guard(() async {
    if (_mutating) throw const TripFailure('Đang xử lý yêu cầu.');
    final offer = current.offer;
    if (offer == null || offer.job.id != jobId || offer.remainingAt(now) <= 0) {
      throw const TripFailure('Lời mời đã hết hạn.');
    }
    _mutating = true;
    try {
      if (_refreshing != null) await _refreshing;
      if (current.offer?.job.id != jobId || offer.remainingAt(now) <= 0) {
        throw const TripFailure('Đơn không còn khả dụng.');
      }
      // Save recoverable details BEFORE sending, but trust them only if status confirms this order.
      final row = _rows[jobId];
      if (row == null) throw const TripFailure('Vui lòng tải lại đơn hàng.');
      _accepted = row;
      await api.store.write(_tripKey, jsonEncode(row));
      await api.request('POST', '/api/driver/matching/orders/$jobId/accept');
      _emit(
        _copy(
          trip: ActiveTrip(job: offer.job),
          clearOffer: true,
          jobs: [],
        ),
      );
      // Reload assigned contacts, proof and stage; offers deliberately omit contacts.
      try {
        await refresh();
      } on TripFailure {
        _emit(_copy(notice: 'Đã nhận đơn. Đang tải lại chi tiết chuyến.'));
      }
    } on ApiFailure catch (e) {
      _dismissed.add(jobId);
      _emit(
        _copy(
          clearOffer: true,
          jobs: [],
          notice: e.status == 409 ? 'Đơn đã được tài xế khác nhận.' : e.message,
        ),
      );
      // A lost response may follow a successful server write. Reconcile without resending POST.
      try {
        await refresh();
      } catch (_) {
        /* next refresh retries only reads */
      }
      if (current.trip?.job.id != jobId) {
        throw TripFailure(current.notice ?? e.message);
      }
    } finally {
      _mutating = false;
    }
  });
  @override
  Future<void> arrive() => _mutateTrip((trip) async {
    final fix = await location.current(requestPermission: true);
    if (!fix.freshAt(now) ||
        fix.point.distanceTo(trip.job.collectionPoint) > 500) {
      throw const TripFailure(
        'Chỉ xác nhận khi cách điểm lấy hoặc bàn giao không quá 500 m.',
      );
    }
    await tracking.send(fix);
    await api.request('POST', '/api/driver/trips/${trip.job.id}/arrive');
  }, confirmed: (trip) => trip.stage != TripStage.accepted);
  @override
  Future<UploadedEvidence> upload(
    CargoPhoto photo,
    void Function(double) progress,
  ) => _guard(() async {
    const ValidateCargoPhoto()(photo);
    progress(0);
    final data =
        await api.upload('/api/driver/uploads', photo.name, photo.bytes) as Map;
    progress(1);
    return UploadedEvidence(photo.kind, data['url'] as String);
  });
  @override
  Future<void> submitInspection({
    required List<UploadedEvidence> evidence,
    required List<bool> checklist,
    required String note,
    required bool cashCollected,
  }) => _mutateTrip(
    (trip) async {
      if (!trip.editable ||
          evidence.length < 2 ||
          evidence.length > 5 ||
          evidence.map((e) => e.reference).toSet().length != evidence.length) {
        throw const TripFailure(
          'Cần 2–5 ảnh khác nhau và chuyến đang cho phép kiểm hàng.',
        );
      }
      if (trip.job.payment == PaymentMethod.cashSender && !trip.cashCollected) {
        if (!cashCollected)
          throw const TripFailure(
            'Xác nhận đã thu tiền từ người gửi trước khi gửi ảnh.',
          );
        await api.request(
          'POST',
          '/api/driver/trips/${trip.job.id}/collect-cash',
        );
      }
      await api.request(
        'POST',
        '/api/driver/trips/${trip.job.id}/pickup',
        body: {'photoUrls': evidence.map((e) => e.reference).toList()},
      );
    },
    confirmed: (trip) =>
        trip.stage == TripStage.inTransit ||
        trip.stage == TripStage.pickedUp &&
            trip.review == EvidenceReview.pending,
  );

  @override
  Future<void> arriveDropoff() => _mutateTrip((trip) async {
    await api.request(
      'POST',
      '/api/driver/trips/${trip.job.id}/arrive-dropoff',
    );
  });

  @override
  Future<void> deliver({
    required String photoUrl,
    required bool cashCollected,
  }) => _mutateTrip(
    (trip) async {
      if (trip.stage != TripStage.inTransit || photoUrl.isEmpty) {
        throw const TripFailure('Cần ảnh giao hàng và chuyến đang giao.');
      }
      if (trip.job.cash &&
          !trip.cashCollected &&
          !cashCollected &&
          trip.job.fare > 0) {
        throw const TripFailure(
          'Xác nhận đã thu tiền trước khi hoàn tất giao hàng.',
        );
      }
      await api.request(
        'POST',
        '/api/driver/trips/${trip.job.id}/deliver',
        body: {'deliveryPhotoUrl': photoUrl, 'cashCollected': cashCollected},
      );
    },
    confirmed: (trip) =>
        [TripStage.delivered, TripStage.completed].contains(trip.stage),
  );

  Future<void> _mutateTrip(
    Future<void> Function(ActiveTrip) action, {
    bool Function(ActiveTrip)? confirmed,
  }) => _guard(() async {
    if (_mutating) throw const TripFailure('Đang xử lý yêu cầu.');
    _mutating = true;
    try {
      if (_refreshing != null) await _refreshing;
      final id = current.trip?.job.id;
      if (id == null) throw const TripFailure('Chưa có chuyến đang thực hiện.');
      final before = await detail(id);
      _emit(_copy(trip: before));
      if (confirmed?.call(before) == true) return;
      try {
        await action(before);
      } on ApiFailure {
        // A POST may have committed before the response was lost. Never replay it.
        try {
          final after = await detail(id);
          _emit(_copy(trip: after));
          if (confirmed?.call(after) == true) return;
        } catch (_) {
          /* keep the last known state and let the user refresh */
        }
        rethrow;
      }
      try {
        _emit(_copy(trip: await detail(id)));
      } on TripFailure {
        _emit(
          _copy(
            notice:
                'Yêu cầu đã được server nhận. Hãy tải lại trạng thái chuyến.',
          ),
        );
        throw const TripFailure(
          'Đã gửi yêu cầu. Chưa tải lại được kết quả; hãy làm mới trước khi thao tác tiếp.',
        );
      }
    } finally {
      _mutating = false;
    }
  });

  @override
  Future<ActiveTrip> detail(String id) => _guard(
    () async => DriverTripDto.parse(
      await api.request('GET', '/api/driver/trips/$id') as Map,
    ),
  );

  @override
  Future<ResultPage<TripSummary>> history({
    int page = 1,
    String view = 'All',
  }) => _guard(() async {
    final data =
        await api.request(
              'GET',
              '/api/driver/trips?page=$page&pageSize=20&view=${Uri.encodeQueryComponent(view)}',
            )
            as Map;
    return ResultPage(
      [
        for (final row in data['items'] as List)
          TripSummary(
            id: '${row['id']}',
            code: '${row['orderCode']}',
            status: '${row['orderStatus']}',
            pickup: '${row['pickupAddress']}',
            dropoff: '${row['dropoffAddress']}',
            fare: (row['totalFee'] as num).round(),
            earning: (row['driverEarning'] as num).round(),
            createdAt: DateTime.parse('${row['createdAt']}'),
          ),
      ],
      (data['pageNumber'] as num).toInt(),
      (data['totalCount'] as num).toInt(),
      data['hasNextPage'] == true,
    );
  });
  @override
  Future<String> reportIncident(String message) => _guard(() async {
    final trip = current.trip;
    if (trip == null || !trip.ongoing)
      throw const TripFailure('Chỉ báo sự cố khi đang có chuyến.');
    final result =
        await api.request(
              'POST',
              '/api/driver/incidents',
              body: {
                'orderId': int.parse(trip.job.id),
                'incidentType': 'Other',
                'description': message.trim(),
                if (current.fix?.freshAt(now) == true) ...{
                  'latitude': current.fix!.point.latitude,
                  'longitude': current.fix!.point.longitude,
                },
              },
            )
            as Map;
    return '${result['incidentId']}';
  });
  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    await _updates.cancel();
    await tracking.close();
    await _changes.close();
  }
}
