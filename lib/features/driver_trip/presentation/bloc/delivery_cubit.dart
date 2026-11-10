import 'package:flutter_bloc/flutter_bloc.dart';
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
  DeliveryCubit(this.trips, this.delivery, this.photos)
    : super(const DeliveryState());
  final DriverTripRepository trips;
  final DriverDeliveryRepository delivery;
  final CargoPhotoRepository photos;
  void confirmCash(bool value) {
    if (!state.busy) emit(state.copyWith(cash: value));
  }

  Future<void> pick(CargoPhotoSource source) => _run(() async {
    final photo = await photos.pick(CargoPhotoKind.overall, source);
    if (photo == null || isClosed) return;
    emit(state.copyWith(photo: photo, clearUpload: true));
    final uploaded = await trips.upload(photo, (_) {});
    if (!isClosed) emit(state.copyWith(uploaded: uploaded));
  });
  Future<void> retryUpload() => _run(() async {
    final photo = state.photo;
    if (photo == null) return;
    final uploaded = await trips.upload(photo, (_) {});
    if (!isClosed) emit(state.copyWith(uploaded: uploaded));
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
    if (state.busy) return;
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
}
