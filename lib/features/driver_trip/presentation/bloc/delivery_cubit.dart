import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/domain/draft_store.dart';
import '../../domain/entities/photo_draft.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/repositories/trip_history_repository.dart';

class DeliveryState {
  const DeliveryState({
    this.photo,
    this.uploaded,
    this.cash = false,
    this.busy = false,
    this.arrivalSent = false,
    this.error,
  });
  final CargoPhoto? photo;
  final UploadedEvidence? uploaded;
  final bool cash, busy, arrivalSent;
  final String? error;
  DeliveryState copyWith({
    CargoPhoto? photo,
    UploadedEvidence? uploaded,
    bool clearUpload = false,
    bool? cash,
    bool? busy,
    bool? arrivalSent,
    String? error,
  }) => DeliveryState(
    photo: photo ?? this.photo,
    uploaded: clearUpload ? null : uploaded ?? this.uploaded,
    cash: cash ?? this.cash,
    busy: busy ?? this.busy,
    arrivalSent: arrivalSent ?? this.arrivalSent,
    error: error,
  );
}

class DeliveryCubit extends Cubit<DeliveryState> {
  DeliveryCubit(this.trips, this.delivery, this.photos, {this.drafts})
    : super(DeliveryState(busy: drafts != null)) {
    _orderId = trips.current.trip?.job.id;
    _assignedAt = trips.current.trip?.assignedAt;
    _subscription = trips.changes.listen((session) {
      if (!_sameTrip) {
        _epoch++;
        final id = _orderId;
        if (id != null) {
          unawaited(drafts?.remove('delivery_$id').catchError((Object _) {}));
        }
        if (!isClosed) emit(const DeliveryState());
      }
    });
    if (drafts != null) unawaited(_restore());
  }
  final DriverTripRepository trips;
  final DriverDeliveryRepository delivery;
  final CargoPhotoRepository photos;
  final DraftStore? drafts;
  late final String? _orderId;
  late final DateTime? _assignedAt;
  late final StreamSubscription<DriverSession> _subscription;
  int _epoch = 0;
  bool _restoring = false;
  Timer? _saveTimer;
  bool get _sameTrip =>
      trips.current.trip?.job.id == _orderId &&
      trips.current.trip?.stage == TripStage.inTransit &&
      trips.current.trip?.assignedAt == _assignedAt;
  Future<void> _persist() async {
    if (drafts == null || _orderId == null || _restoring) return;
    if (!_sameTrip) return drafts!.remove('delivery_$_orderId');
    await drafts!.write('delivery_$_orderId', {
      if (state.photo != null)
        'photo': photoDraft(state.photo!, state.uploaded),
      'cash': state.cash,
      'arrival': state.arrivalSent,
      'assignment': _assignedAt?.toIso8601String(),
    });
  }

  Future<void> _restore() async {
    final epoch = _epoch;
    _restoring = true;
    try {
      final saved = await drafts!.read('delivery_$_orderId');
      if (isClosed || epoch != _epoch || !_sameTrip) return;
      if (saved != null &&
          saved['assignment'] != _assignedAt?.toIso8601String()) {
        await drafts!.remove('delivery_$_orderId');
        if (!isClosed && epoch == _epoch) emit(const DeliveryState());
        return;
      }
      final j = saved?['photo'] == null
          ? null
          : Map<String, dynamic>.from(saved!['photo'] as Map);
      emit(
        DeliveryState(
          photo: j == null ? null : readPhotoDraft(j),
          uploaded: j == null ? null : readUploadDraft(j),
          cash: saved?['cash'] == true,
          arrivalSent: saved?['arrival'] == true,
        ),
      );
    } catch (_) {
      if (!isClosed && epoch == _epoch) {
        emit(
          const DeliveryState(
            error: 'Chưa khôi phục được ảnh giao hàng. Vui lòng chụp lại.',
          ),
        );
      }
    } finally {
      _restoring = false;
    }
  }

  @override
  void onChange(Change<DeliveryState> change) {
    super.onChange(change);
    if (drafts == null || _restoring) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(
        _persist().catchError((Object _) {
          const message =
              'Không lưu được ảnh trên thiết bị. Kiểm tra dung lượng trống.';
          if (!isClosed && state.error != message) {
            emit(state.copyWith(error: message));
          }
        }),
      );
    });
  }

  void confirmCash(bool value) {
    if (!state.busy) emit(state.copyWith(cash: value));
  }

  Future<void> pick(CargoPhotoSource source) => _run(() async {
    final epoch = _epoch;
    final photo = await photos.pick(CargoPhotoKind.overall, source);
    if (photo == null || isClosed || epoch != _epoch || !_sameTrip) return;
    emit(state.copyWith(photo: photo, clearUpload: true));
    await _persist();
    final uploaded = await trips.upload(photo, (_) {});
    if (!isClosed && epoch == _epoch && _sameTrip) {
      emit(state.copyWith(uploaded: uploaded));
    }
  });
  Future<void> retryUpload() => _run(() async {
    final epoch = _epoch;
    final photo = state.photo;
    if (photo == null) return;
    final uploaded = await trips.upload(photo, (_) {});
    if (!isClosed && epoch == _epoch && _sameTrip) {
      emit(state.copyWith(uploaded: uploaded));
    }
  });
  Future<void> arrive() => _run(() async {
    await delivery.arriveDropoff();
    if (!isClosed) emit(state.copyWith(arrivalSent: true));
  });
  Future<void> submit() => _run(() async {
    if (state.uploaded == null) {
      throw const TripFailure('Chụp và tải ảnh giao hàng trước.');
    }
    await delivery.deliver(
      photoUrl: state.uploaded!.reference,
      cashCollected: state.cash,
    );
  });
  Future<void> _run(Future<void> Function() action) async {
    if (state.busy || !_sameTrip || trips.current.trip?.onHold == true) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: e is TripFailure
                ? e.message
                : 'Chưa xử lý được yêu cầu. Hãy thử lại.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _saveTimer?.cancel();
    await _persist().catchError((Object _) {});
    _epoch++;
    await _subscription.cancel();
    return super.close();
  }
}
