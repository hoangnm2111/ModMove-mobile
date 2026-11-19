import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/draft_store.dart';
import '../../domain/entities/photo_draft.dart';
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
  EvidenceCubit(this.actions, this.photos, {this.drafts})
    : super(EvidenceState(busy: drafts != null)) {
    _tripId = actions.repository.current.trip?.job.id;
    _attempts = actions.repository.current.trip?.attempts;
    _assignedAt = actions.repository.current.trip?.assignedAt;
    _lastReview = actions.repository.current.trip?.review;
    _subscription = actions.repository.changes.listen(_session);
    if (drafts != null) unawaited(_restore());
  }
  final DriverTripActions actions;
  final CargoPhotoRepository photos;
  final DraftStore? drafts;
  int? _attempts;
  DateTime? _assignedAt;
  Timer? _saveTimer;
  bool _restoring = false;
  bool get _draftAllowed {
    final trip = actions.repository.current.trip;
    return trip != null &&
        (trip.stage == TripStage.arrived ||
            trip.stage == TripStage.pickedUp &&
                trip.review == EvidenceReview.rejected);
  }

  Future<void> _persist() async {
    final id = _tripId;
    if (drafts == null || id == null || _restoring) return;
    if (!_draftAllowed) return drafts!.remove('pickup_$id');
    await drafts!.write('pickup_$id', {
      'attempts': _attempts,
      'review': actions.repository.current.trip!.review.name,
      'assignment': _assignedAt?.toIso8601String(),
      'items': state.items.values
          .map(
            (i) => {
              ...photoDraft(i.photo, i.uploaded),
              'retake': i.needsRetake,
            },
          )
          .toList(),
      'checklist': state.checklist,
      'note': state.note,
      'cash': state.cashCollected,
    });
  }

  Future<void> _restore() async {
    final id = _tripId, epoch = _epoch;
    if (id == null || drafts == null) {
      if (!isClosed) emit(EvidenceState());
      return;
    }
    _restoring = true;
    try {
      final saved = await drafts!.read('pickup_$id');
      if (isClosed || epoch != _epoch) return;
      final trip = actions.repository.current.trip;
      if (_draftAllowed &&
          saved != null &&
          saved['attempts'] == trip?.attempts &&
          saved['review'] == trip?.review.name &&
          saved['assignment'] == trip?.assignedAt?.toIso8601String()) {
        final items = <CargoPhotoKind, EvidenceItem>{};
        for (final raw in saved['items'] as List) {
          final j = Map<String, dynamic>.from(raw as Map);
          final photo = readPhotoDraft(j);
          final retake = j['retake'] == true;
          items[photo.kind] = EvidenceItem(
            photo,
            uploaded: retake ? null : readUploadDraft(j),
            needsRetake: retake,
          );
        }
        emit(
          EvidenceState(
            items: items,
            checklist: List<bool>.from(saved['checklist'] as List),
            note: saved['note'] as String,
            cashCollected: saved['cash'] == true,
          ),
        );
      } else {
        await drafts!.remove('pickup_$id');
        if (!isClosed && epoch == _epoch) emit(EvidenceState());
      }
    } catch (_) {
      if (!isClosed && epoch == _epoch) {
        emit(
          EvidenceState(
            error: 'Chưa khôi phục được ảnh đã lưu. Vui lòng chụp lại.',
          ),
        );
      }
    } finally {
      _restoring = false;
    }
  }

  @override
  void onChange(Change<EvidenceState> change) {
    super.onChange(change);
    if (drafts == null || _restoring) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(
        _persist().catchError((Object _) {
          const message =
              'Không lưu được bản nháp ảnh trên máy. Kiểm tra dung lượng trống.';
          if (!isClosed && state.error != message) {
            emit(state.copyWith(error: message));
          }
        }),
      );
    });
  }

  late final StreamSubscription<DriverSession> _subscription;
  String? _tripId;
  EvidenceReview? _lastReview;
  int _epoch = 0;
  bool get _editable => actions.repository.current.trip?.editable ?? false;
  void _session(DriverSession session) {
    if (isClosed) return;
    final trip = session.trip;
    if (trip?.job.id != _tripId || trip?.assignedAt != _assignedAt) {
      final previous = _tripId;
      if (previous != null) {
        unawaited(drafts?.remove('pickup_$previous').catchError((Object _) {}));
      }
      _tripId = trip?.job.id;
      _attempts = trip?.attempts;
      _assignedAt = trip?.assignedAt;
      _epoch++;
      emit(EvidenceState());
    }
    if (trip?.attempts != _attempts) {
      _attempts = trip?.attempts;
      _epoch++;
      // Keep previews while waiting; a rejection below invalidates their URLs.
      // The previous attempt is removed from disk as soon as it is submitted.
      final id = _tripId;
      if (id != null) {
        unawaited(drafts?.remove('pickup_$id').catchError((Object _) {}));
      }
      emit(state.copyWith(busy: false));
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
      await _persist();
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
    _saveTimer?.cancel();
    await _persist().catchError((Object _) {});
    _epoch++;
    await _subscription.cancel();
    return super.close();
  }
}
