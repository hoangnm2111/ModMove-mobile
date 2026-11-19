import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/result_page.dart';
import '../../driver_trip/domain/entities/trip_models.dart';
import '../../driver_trip/domain/repositories/driver_trip_repository.dart';
import '../../driver_trip/domain/usecases/validate_cargo_photo.dart';
import '../domain/driver_incident_repository.dart';

String incidentError(Object e) => e is IncidentFailure
    ? e.message
    : e is TripFailure
    ? e.message
    : 'Chưa xử lý được sự cố. Vui lòng thử lại.';

class IncidentListState {
  const IncidentListState({
    this.data,
    this.status,
    this.busy = false,
    this.error,
  });
  final ResultPage<DriverIncident>? data;
  final String? status, error;
  final bool busy;
}

class IncidentListCubit extends Cubit<IncidentListState> {
  IncidentListCubit(this.repository, {this.orderId})
    : super(const IncidentListState());
  final DriverIncidentRepository repository;
  final String? orderId;
  int _generation = 0;
  Future<void> filter(String? status) => _load(status);
  Future<void> refresh() => _load(state.status);
  Future<void> more() => _load(state.status, more: true);
  Future<void> _load(String? status, {bool more = false}) async {
    if (isClosed || more && (state.busy || state.data?.hasNext != true)) return;
    final generation = ++_generation;
    final previous = status == state.status ? state.data : null;
    emit(IncidentListState(data: previous, status: status, busy: true));
    try {
      final page = await repository.list(
        page: more ? previous!.page + 1 : 1,
        status: status,
        orderId: orderId,
      );
      if (isClosed || generation != _generation) return;
      final items = more ? [...previous!.items, ...page.items] : page.items;
      final unique = {for (final item in items) item.id: item};
      emit(
        IncidentListState(
          status: status,
          data: ResultPage(
            unique.values.toList(),
            page.page,
            page.total,
            page.hasNext,
          ),
        ),
      );
    } catch (e) {
      if (!isClosed && generation == _generation) {
        emit(
          IncidentListState(
            data: previous,
            status: status,
            error: incidentError(e),
          ),
        );
      }
    }
  }
}

class IncidentDetailState {
  const IncidentDetailState({this.item, this.busy = false, this.error});
  final DriverIncident? item;
  final bool busy;
  final String? error;
}

class IncidentDetailCubit extends Cubit<IncidentDetailState> {
  IncidentDetailCubit(this.repository, this.id)
    : super(const IncidentDetailState());
  final DriverIncidentRepository repository;
  final String id;
  Future<void> refresh() async {
    if (isClosed || state.busy) return;
    emit(IncidentDetailState(item: state.item, busy: true));
    try {
      final item = await repository.detail(id);
      if (!isClosed) emit(IncidentDetailState(item: item));
    } catch (e) {
      if (!isClosed) {
        emit(
          IncidentDetailState(
            item: e is IncidentFailure && [403, 404].contains(e.status)
                ? null
                : state.item,
            error: incidentError(e),
          ),
        );
      }
    }
  }
}

class IncidentAttachment {
  const IncidentAttachment(this.photo, {this.url, this.error});
  final CargoPhoto photo;
  final String? url, error;
}

class IncidentReportState {
  const IncidentReportState({
    this.type = IncidentType.vehicleBreakdown,
    this.description = '',
    this.photos = const [],
    this.busy = false,
    this.uncertain = false,
    this.canReport = true,
    this.error,
    this.createdId,
  });
  final IncidentType type;
  final String description;
  final List<IncidentAttachment> photos;
  final bool busy, uncertain, canReport;
  final String? error, createdId;
  bool get locked => busy || uncertain || createdId != null;
  bool get ready =>
      !locked &&
      canReport &&
      description.trim().isNotEmpty &&
      description.trim().length <= 1000 &&
      photos.every((e) => e.url != null);
  IncidentReportState copy({
    IncidentType? type,
    String? description,
    List<IncidentAttachment>? photos,
    bool? busy,
    bool? uncertain,
    bool? canReport,
    String? error,
    String? createdId,
  }) => IncidentReportState(
    type: type ?? this.type,
    description: description ?? this.description,
    photos: photos ?? this.photos,
    busy: busy ?? this.busy,
    uncertain: uncertain ?? this.uncertain,
    canReport: canReport ?? this.canReport,
    error: error,
    createdId: createdId ?? this.createdId,
  );
}

class IncidentReportCubit extends Cubit<IncidentReportState> {
  IncidentReportCubit(this.repository, this.trips, this.picker, this.orderId)
    : super(
        IncidentReportState(
          canReport:
              trips.current.trip?.job.id == orderId &&
              trips.current.trip?.ongoing == true,
        ),
      ) {
    _subscription = trips.changes.listen((s) {
      if (!isClosed) {
        emit(
          state.copy(
            canReport: s.trip?.job.id == orderId && s.trip?.ongoing == true,
            error: state.error,
          ),
        );
      }
    });
  }
  final DriverIncidentRepository repository;
  final DriverTripRepository trips;
  final CargoPhotoRepository picker;
  final String orderId;
  late final StreamSubscription<DriverSession> _subscription;
  IncidentReport? _attempt;
  int _baseline = 0;
  void selectType(IncidentType type) {
    if (!state.locked) emit(state.copy(type: type));
  }

  void describe(String value) {
    if (!state.locked) emit(state.copy(description: value));
  }

  void remove(int index) {
    if (!state.locked) {
      emit(state.copy(photos: [...state.photos]..removeAt(index)));
    }
  }

  Future<void> add(CargoPhotoSource source) async {
    if (state.locked ||
        state.photos.length >= 5 ||
        source == CargoPhotoSource.sample) {
      return;
    }
    emit(state.copy(busy: true));
    try {
      final photo = await picker.pick(CargoPhotoKind.overall, source);
      if (photo != null && !isClosed) {
        const ValidateCargoPhoto()(photo);
        if (state.photos.any((e) => listEquals(e.photo.bytes, photo.bytes))) {
          throw const IncidentFailure('Ảnh này đã được thêm.');
        }
        emit(state.copy(photos: [...state.photos, IncidentAttachment(photo)]));
        await _upload(state.photos.length - 1);
      }
    } catch (e) {
      if (!isClosed) emit(state.copy(error: incidentError(e)));
    } finally {
      if (!isClosed) emit(state.copy(busy: false, error: state.error));
    }
  }

  Future<void> retry(int index) async {
    if (state.locked) return;
    emit(state.copy(busy: true));
    await _upload(index);
    if (!isClosed) emit(state.copy(busy: false, error: state.error));
  }

  Future<void> _upload(int index) async {
    final photo = state.photos[index].photo;
    try {
      final url = await repository.upload(photo);
      if (!isClosed) {
        emit(
          state.copy(
            photos: [...state.photos]
              ..[index] = IncidentAttachment(photo, url: url),
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copy(
            photos: [...state.photos]
              ..[index] = IncidentAttachment(photo, error: incidentError(e)),
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (!state.ready || isClosed) return;
    emit(state.copy(busy: true));
    var posted = false;
    try {
      // A baseline distinguishes a lost response from an older identical report.
      final existing = await repository.list(orderId: orderId);
      _baseline = existing.items.fold(
        0,
        (n, item) => (int.tryParse(item.id) ?? 0) > n ? int.parse(item.id) : n,
      );
      if (isClosed) return;
      if (!state.canReport) {
        throw const IncidentFailure(
          'Chuyến đã thay đổi. Không thể gửi báo cáo cho chuyến này.',
        );
      }
      final fix = trips.current.fix;
      final report = IncidentReport(
        orderId: orderId,
        type: state.type,
        description: state.description.trim(),
        photos: state.photos.map((e) => e.url!).toList(),
        location: fix?.freshAt(trips.now) == true ? fix!.point : null,
      );
      report.validate();
      _attempt = report;
      posted = true;
      final id = await repository.report(report);
      if (!isClosed) emit(state.copy(busy: false, createdId: id));
    } catch (e) {
      if (isClosed) return;
      final uncertain = posted && (e is! IncidentFailure || e.uncertain);
      emit(
        state.copy(
          busy: false,
          uncertain: uncertain,
          error: uncertain
              ? 'Yêu cầu có thể đã được gửi. Kiểm tra kết quả trước khi tạo báo cáo khác.'
              : incidentError(e),
        ),
      );
      if (uncertain) await reconcile();
    }
  }

  Future<void> reconcile() async {
    if (isClosed || state.busy || !state.uncertain || _attempt == null) return;
    emit(state.copy(busy: true, error: state.error));
    try {
      final page = await repository.list(orderId: orderId);
      final match = page.items
          .where(
            (item) =>
                (int.tryParse(item.id) ?? 0) > _baseline &&
                _attempt!.matches(item),
          )
          .firstOrNull;
      if (!isClosed) {
        emit(
          state.copy(
            busy: false,
            uncertain: match == null,
            createdId: match?.id,
            error: match == null
                ? 'Chưa xác nhận được kết quả. Kiểm tra lại hoặc mở danh sách sự cố của chuyến.'
                : null,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) emit(state.copy(busy: false, error: incidentError(e)));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
