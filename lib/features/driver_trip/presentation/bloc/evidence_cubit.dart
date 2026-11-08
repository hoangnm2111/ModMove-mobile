import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/usecases/driver_trip_actions.dart';

class EvidenceItem {
  const EvidenceItem(
    this.photo, {
    this.uploaded,
    this.progress = 0,
    this.error,
    this.needsRetake = false,
  });
  final CargoPhoto photo;
  final UploadedEvidence? uploaded;
  final double progress;
  final String? error;
  final bool needsRetake;
}

class EvidenceState {
  EvidenceState({
    Map<CargoPhotoKind, EvidenceItem> items = const {},
    List<bool> checklist = const [false, false, false, false],
    this.note = '',
    this.cashCollected = false,
    this.busy = false,
    this.error,
  }) : items = Map.unmodifiable(items),
       checklist = List.unmodifiable(checklist);
  final Map<CargoPhotoKind, EvidenceItem> items;
  final List<bool> checklist;
  final String note;
  final bool cashCollected, busy;
  final String? error;
  int get uploadedCount =>
      items.values.where((item) => item.uploaded != null).length;
  bool get ready =>
      !busy && uploadedCount == 2 && checklist.every((item) => item);
  EvidenceState copyWith({
    Map<CargoPhotoKind, EvidenceItem>? items,
    List<bool>? checklist,
    String? note,
    bool? cashCollected,
    bool? busy,
    String? error,
  }) => EvidenceState(
    items: items ?? this.items,
    checklist: checklist ?? this.checklist,
    note: note ?? this.note,
    cashCollected: cashCollected ?? this.cashCollected,
    busy: busy ?? this.busy,
    error: error,
  );
}

class EvidenceCubit extends Cubit<EvidenceState> {
  EvidenceCubit(this.actions, this.photos) : super(EvidenceState()) {
    _tripId = actions.repository.current.trip?.job.id;
    _subscription = actions.repository.changes.listen(_session);
  }
  final DriverTripActions actions;
  final CargoPhotoRepository photos;
  late final StreamSubscription<DriverSession> _subscription;
  String? _tripId;
  EvidenceReview? _lastReview;
  int _epoch = 0;
  bool get _editable => actions.repository.current.trip?.editable ?? false;
  void _session(DriverSession session) {
    if (isClosed) return;
    final trip = session.trip;
    if (trip?.job.id != _tripId) {
      _tripId = trip?.job.id;
      _epoch++;
      emit(EvidenceState());
    }
    if (trip?.review == EvidenceReview.rejected &&
        _lastReview != EvidenceReview.rejected) {
      emit(
        state.copyWith(
          items: state.items.map(
            (kind, item) => MapEntry(
              kind,
              EvidenceItem(
                item.photo,
                needsRetake: true,
                error: 'Khách yêu cầu chụp lại ảnh.',
              ),
            ),
          ),
        ),
      );
    }
    _lastReview = trip?.review;
    if (trip != null && !trip.ongoing) {
      _epoch++;
      emit(state.copyWith(busy: false));
    }
  }

  void check(int index, bool value) {
    if (state.busy || !_editable) return;
    final list = state.checklist.toList();
    list[index] = value;
    emit(state.copyWith(checklist: list));
  }

  void setNote(String value) {
    if (!state.busy && _editable) emit(state.copyWith(note: value));
  }

  void setCashCollected(bool value) {
    if (!state.busy && _editable) emit(state.copyWith(cashCollected: value));
  }

  void remove(CargoPhotoKind kind) {
    if (state.busy || !_editable) return;
    emit(state.copyWith(items: {...state.items}..remove(kind)));
  }

  void _item(CargoPhotoKind kind, EvidenceItem item) {
    if (!isClosed) emit(state.copyWith(items: {...state.items, kind: item}));
  }

  Future<void> pick(CargoPhotoKind kind, CargoPhotoSource source) async {
    if (state.busy || !_editable) return;
    final epoch = _epoch;
    emit(state.copyWith(busy: true));
    try {
      final photo = await photos.pick(kind, source);
      if (photo == null || isClosed || epoch != _epoch || !_editable) return;
      if (state.items.entries.any(
        (e) => e.key != kind && listEquals(e.value.photo.bytes, photo.bytes),
      )) {
        throw const TripFailure(
          'Chọn hai ảnh khác nhau: toàn bộ hàng và hàng đã cố định.',
        );
      }
      _item(kind, EvidenceItem(photo));
      await _upload(kind, photo, epoch);
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        emit(
          state.copyWith(
            error: e is TripFailure
                ? e.message
                : 'Chưa mở được ảnh. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed && epoch == _epoch) {
        emit(state.copyWith(busy: false, error: state.error));
      }
    }
  }

  Future<void> _upload(CargoPhotoKind kind, CargoPhoto photo, int epoch) async {
    try {
      final result = await actions.repository.upload(photo, (progress) {
        if (!isClosed && epoch == _epoch) {
          _item(kind, EvidenceItem(photo, progress: progress));
        }
      });
      if (!isClosed && epoch == _epoch) {
        _item(kind, EvidenceItem(photo, uploaded: result, progress: 1));
      }
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        _item(
          kind,
          EvidenceItem(
            photo,
            error: e is TripFailure ? e.message : 'Chưa tải được ảnh. Thử lại.',
          ),
        );
      }
    }
  }

  Future<void> retry(CargoPhotoKind kind) async {
    final item = state.items[kind];
    if (state.busy || !_editable || item == null || item.needsRetake) return;
    emit(state.copyWith(busy: true));
    final epoch = _epoch;
    await _upload(kind, item.photo, epoch);
    if (!isClosed && epoch == _epoch) emit(state.copyWith(busy: false));
  }

  Future<void> submit() async {
    if (state.busy || !_editable) return;
    final epoch = _epoch;
    emit(state.copyWith(busy: true));
    try {
      await actions.submit(
        evidence: state.items.values
            .map((i) => i.uploaded)
            .whereType<UploadedEvidence>()
            .toList(),
        checklist: state.checklist,
        note: state.note,
        cashCollected: state.cashCollected,
      );
      if (!isClosed && epoch == _epoch) emit(state.copyWith(busy: false));
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        emit(
          state.copyWith(
            busy: false,
            error: e is TripFailure
                ? e.message
                : 'Chưa gửi được bằng chứng. Ảnh đã tải lên được giữ lại.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _epoch++;
    await _subscription.cancel();
    return super.close();
  }
}
