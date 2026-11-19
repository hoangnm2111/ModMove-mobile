import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/draft_store.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';

String customerError(Object error) => error is CustomerFailure
    ? error.message
    : 'Chưa xử lý được yêu cầu. Vui lòng thử lại.';

class ResourceState<T> {
  const ResourceState({this.data, this.busy = false, this.error});
  final T? data;
  final bool busy;
  final String? error;
}

class ResourceCubit<T> extends Cubit<ResourceState<T>> {
  ResourceCubit(this.loader) : super(ResourceState<T>());
  final Future<T> Function() loader;
  Future<void> load() async {
    if (isClosed || state.busy) return;
    emit(ResourceState(data: state.data, busy: true));
    try {
      final result = await loader();
      if (!isClosed) emit(ResourceState(data: result));
    } catch (e) {
      if (!isClosed) {
        emit(ResourceState(data: state.data, error: customerError(e)));
      }
    }
  }
}

class ActionState {
  const ActionState({this.busy = false, this.error, this.done = false});
  final bool busy, done;
  final String? error;
}

class ActionCubit extends Cubit<ActionState> {
  ActionCubit() : super(const ActionState());
  Future<bool> run(Future<void> Function() action) async {
    if (isClosed || state.busy) return false;
    emit(const ActionState(busy: true));
    try {
      await action();
      if (!isClosed) emit(const ActionState(done: true));
      return true;
    } catch (e) {
      if (!isClosed) emit(ActionState(error: customerError(e)));
      return false;
    }
  }

  void error(String message) {
    if (!isClosed && !state.busy) emit(ActionState(error: message));
  }
}

class ListState<T> {
  const ListState({
    this.items = const [],
    this.busy = false,
    this.error,
    this.page = 0,
    this.hasNext = false,
  });
  final List<T> items;
  final bool busy, hasNext;
  final String? error;
  final int page;
}

class PagedCubit<T> extends Cubit<ListState<T>> {
  PagedCubit(this.loader) : super(ListState<T>());
  Future<PageResult<T>> Function(int) loader;
  int _version = 0;
  Future<void> load({bool more = false}) async {
    if (isClosed) return;
    if (more && (state.busy || !state.hasNext)) return;
    final version = ++_version, page = more ? state.page + 1 : 1;
    final previous = more ? state.items : <T>[];
    emit(
      ListState(
        items: more ? previous : state.items,
        busy: true,
        page: state.page,
        hasNext: state.hasNext,
      ),
    );
    try {
      final result = await loader(page);
      if (!isClosed && version == _version) {
        emit(
          ListState(
            items: [...previous, ...result.items],
            page: result.page,
            hasNext: result.hasNext,
          ),
        );
      }
    } catch (e) {
      if (!isClosed && version == _version) {
        emit(
          ListState(
            items: state.items,
            page: state.page,
            hasNext: state.hasNext,
            error: customerError(e),
          ),
        );
      }
    }
  }
}

class BookingState {
  const BookingState({
    this.draft = const BookingDraft(),
    this.catalog,
    this.fare,
    this.busy = false,
    this.uploading = false,
    this.error,
    this.created,
    this.needsOrderCheck = false,
  });
  final BookingDraft draft;
  final BookingCatalog? catalog;
  final Fare? fare;
  final bool busy, uploading, needsOrderCheck;
  final String? error;
  final CreatedOrder? created;
}

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this.repository, {BookingDraft? initial, this.drafts})
    : _hasInitial = initial != null,
      super(BookingState(draft: initial ?? const BookingDraft()));
  final CustomerRepository repository;
  final DraftStore? drafts;
  final bool _hasInitial;
  bool _restored = false;
  static String _newKey() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Future<void> _persist(BookingState s) async {
    if (drafts == null) return;
    if (s.created != null) return drafts!.remove('booking');
    await drafts!.write('booking', {
      'draft': s.draft.toJson(),
      'pending': s.needsOrderCheck,
      if (s.needsOrderCheck && s.fare != null)
        'fare': {
          'distance': s.fare!.distance,
          'minutes': s.fare!.minutes,
          'distanceFee': s.fare!.distanceFee,
          'serviceFee': s.fare!.serviceFee,
          'discount': s.fare!.discount,
          'total': s.fare!.total,
          'recovery': s.fare!.supportsBookingRecovery,
        },
    });
  }

  @override
  void onChange(Change<BookingState> change) {
    super.onChange(change);
    if (_restored) {
      unawaited(_persist(change.nextState).catchError((Object _) {}));
    }
  }

  int _revision = 0;
  Future<void> initialize() async {
    if (isClosed ||
        state.busy ||
        (state.needsOrderCheck && state.catalog != null)) {
      return;
    }
    emit(
      BookingState(
        draft: state.draft,
        fare: state.fare,
        needsOrderCheck: state.needsOrderCheck,
        busy: true,
      ),
    );
    try {
      if (!_restored) {
        final saved = await drafts?.read('booking');
        if (isClosed) return;
        if (saved != null && (!_hasInitial || saved['pending'] == true)) {
          final j = saved['fare'] as Map?;
          emit(
            BookingState(
              draft: BookingDraft.fromJson(
                Map<String, dynamic>.from(saved['draft'] as Map),
              ),
              fare: j == null
                  ? null
                  : Fare(
                      (j['distance'] as num).toDouble(),
                      j['minutes'] as int,
                      (j['distanceFee'] as num).toDouble(),
                      (j['serviceFee'] as num).toDouble(),
                      (j['discount'] as num).toDouble(),
                      (j['total'] as num).toDouble(),
                      supportsBookingRecovery: j['recovery'] == true,
                    ),
              needsOrderCheck: saved['pending'] == true,
              busy: true,
            ),
          );
        }
        _restored = true;
      }
      final c = await repository.catalog();
      if (!isClosed) {
        final draft =
            state.needsOrderCheck ||
                c.cargoTypes.any((v) => v.code == state.draft.cargoType)
            ? state.draft
            : state.draft.copyWith(cargoType: '');
        emit(
          BookingState(
            draft: draft,
            catalog: c,
            fare: state.fare,
            needsOrderCheck: state.needsOrderCheck,
            error: state.needsOrderCheck
                ? 'Có yêu cầu đặt đơn chưa xác định kết quả. Kiểm tra trước khi tạo đơn khác.'
                : null,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          BookingState(
            draft: state.draft,
            fare: state.fare,
            needsOrderCheck: state.needsOrderCheck,
            error: customerError(e),
          ),
        );
      }
    }
  }

  void edit(BookingDraft draft) {
    if (isClosed ||
        state.busy ||
        state.uploading ||
        state.created != null ||
        state.needsOrderCheck) {
      return;
    }
    final old = state.draft;
    final priceChanged =
        old.pickup != draft.pickup ||
        old.dropoff != draft.dropoff ||
        old.pickupPoint != draft.pickupPoint ||
        old.dropoffPoint != draft.dropoffPoint ||
        old.weight != draft.weight ||
        old.length != draft.length ||
        old.width != draft.width ||
        old.height != draft.height ||
        old.vehicleId != draft.vehicleId ||
        old.loading != draft.loading ||
        old.coupon != draft.coupon;
    _revision++;
    emit(
      BookingState(
        draft: draft,
        catalog: state.catalog,
        fare: priceChanged ? null : state.fare,
      ),
    );
  }

  void error(String message) => emit(
    BookingState(
      draft: state.draft,
      catalog: state.catalog,
      fare: state.fare,
      error: message,
    ),
  );
  Future<void> upload(String name, Uint8List bytes) async {
    if (state.busy ||
        state.uploading ||
        state.needsOrderCheck ||
        state.draft.photos.length >= 5) {
      return;
    }
    if (bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024 ||
        !RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false).hasMatch(name)) {
      return error('Chọn ảnh JPG hoặc PNG hợp lệ, tối đa 5 MB.');
    }
    emit(
      BookingState(
        draft: state.draft.copyWith(
          pendingPhoto: PendingCargoPhoto(name, bytes),
        ),
        catalog: state.catalog,
        fare: state.fare,
        uploading: true,
      ),
    );
    try {
      await _persist(state);
      final url = await repository.upload(name, bytes);
      if (!isClosed) {
        emit(
          BookingState(
            draft: state.draft.copyWith(
              photos: [...state.draft.photos, url],
              clearPendingPhoto: true,
            ),
            catalog: state.catalog,
            fare: state.fare,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) error(customerError(e));
    }
  }

  Future<void> retryPhoto() async {
    final pending = state.draft.pendingPhoto;
    if (pending != null) await upload(pending.name, pending.bytes);
  }

  void discardPendingPhoto() =>
      edit(state.draft.copyWith(clearPendingPhoto: true));

  Future<void> estimate() async {
    if (state.busy || state.uploading || state.needsOrderCheck) return;
    final invalid = state.draft.validate();
    if (invalid != null) return error(invalid);
    final vehicles = state.catalog?.vehicles.where(
      (v) => v.id == state.draft.vehicleId,
    );
    if (vehicles == null ||
        vehicles.isEmpty ||
        !vehicles.first.fits(state.draft)) {
      return error(
        'Chọn lại loại xe phù hợp với tải trọng và kích thước hàng.',
      );
    }
    final revision = _revision;
    emit(BookingState(draft: state.draft, catalog: state.catalog, busy: true));
    try {
      final fare = await repository.estimate(state.draft);
      if (!isClosed && revision == _revision) {
        emit(
          BookingState(draft: state.draft, catalog: state.catalog, fare: fare),
        );
      }
    } catch (e) {
      if (!isClosed) error(customerError(e));
    }
  }

  Future<void> submit({bool retry = false}) async {
    if (state.busy ||
        state.uploading ||
        state.created != null ||
        (state.needsOrderCheck && !retry)) {
      return;
    }
    final invalid = state.draft.validate(submit: true);
    if (invalid != null) return error(invalid);
    final fare = state.fare;
    if (retry &&
        (!state.needsOrderCheck ||
            fare?.supportsBookingRecovery != true ||
            state.draft.requestKey == null)) {
      return;
    }
    if (fare == null) {
      return error('Vui lòng tính lại giá cước trước khi đặt đơn.');
    }
    emit(
      BookingState(
        draft: state.draft.copyWith(
          requestKey: state.draft.requestKey ?? _newKey(),
        ),
        catalog: state.catalog,
        fare: fare,
        busy: true,
        needsOrderCheck: true,
      ),
    );
    var sent = false;
    try {
      // Persist BEFORE the request: a process death can then retry the same key.
      await _persist(state);
      CreatedOrder? created;
      if (fare.supportsBookingRecovery &&
          repository is CustomerBookingRecovery) {
        created = await (repository as CustomerBookingRecovery).findBooking(
          state.draft.requestKey!,
        );
      }
      if (created == null) {
        sent = true;
        created = await repository.book(state.draft, fare);
      }
      if (!isClosed) {
        emit(
          BookingState(
            draft: state.draft,
            catalog: state.catalog,
            fare: fare,
            created: created,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          BookingState(
            draft: state.draft,
            catalog: state.catalog,
            fare: e is CustomerFailure && e.code == 'FARE_CHANGED'
                ? null
                : fare,
            error: customerError(e),
            needsOrderCheck:
                (retry &&
                    !(e is CustomerFailure && e.code == 'FARE_CHANGED')) ||
                (e is CustomerFailure && e.code == 'ORDER_RESULT_UNKNOWN') ||
                (sent && e is! CustomerFailure),
          ),
        );
      }
    }
  }

  void confirmedNoOrderCreated() {
    if (state.fare?.supportsBookingRecovery == true) return;
    if (!state.needsOrderCheck) return;
    emit(
      BookingState(
        draft: state.draft,
        catalog: state.catalog,
        fare: state.fare,
      ),
    );
  }

  Future<void> retryPending() => submit(retry: true);
  @override
  Future<void> close() async {
    if (_restored) await _persist(state).catchError((Object _) {});
    return super.close();
  }
}

class OrderState {
  const OrderState({
    this.order,
    this.tracking,
    this.payment,
    this.busy = false,
    this.acting = false,
    this.error,
    this.trackingError,
  });
  final OrderDetail? order;
  final TrackingSnapshot? tracking;
  final PaymentLink? payment;
  final bool busy, acting;
  final String? error, trackingError;
}

class CustomerOrderCubit extends Cubit<OrderState> {
  CustomerOrderCubit(
    this.repository,
    this.id,
    this.realtime, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const OrderState());
  final DateTime Function() _clock;
  final CustomerRepository repository;
  final CustomerRealtime realtime;
  final int id;
  Timer? _timer;
  StreamSubscription<CustomerRealtimeEvent>? _subscription;
  bool _refreshing = false, _trackingBusy = false;
  bool _trackingAgain = false;
  int _trackingGeneration = 0;
  bool _closing = false;
  DateTime? _trackingAttemptAt;
  Completer<void>? _refreshDone;
  OrderState update({
    OrderDetail? order,
    TrackingSnapshot? tracking,
    PaymentLink? payment,
    bool busy = false,
    bool acting = false,
    String? error,
    String? trackingError,
  }) => OrderState(
    order: order ?? state.order,
    tracking: tracking ?? state.tracking,
    payment: payment ?? state.payment,
    busy: busy,
    acting: acting,
    error: error,
    trackingError: trackingError ?? state.trackingError,
  );
  Future<void> initialize() async {
    await refresh();
    if (isClosed || _closing) return;
    _subscription = realtime.events.listen((event) {
      if (isClosed || _closing) return;
      if (event.position != null &&
          event.at != null &&
          state.tracking != null) {
        if (state.tracking!.at == null ||
            event.at!.isAfter(state.tracking!.at!)) {
          emit(
            update(
              tracking: state.tracking!.withLocation(
                event.position!,
                event.at!,
              ),
              acting: state.acting,
            ),
          );
        }
      } else {
        unawaited(refresh());
        if (event.reconnected) {
          _refreshTrackingIfDue();
        }
      }
    });
    try {
      await realtime.start(id);
    } catch (_) {
      /* REST status refresh remains available. */
    }
    if (isClosed || _closing) {
      await realtime.stop();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.order?.summary.terminal != true) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_refreshing || state.acting || isClosed || _closing) return;
    _refreshing = true;
    _refreshDone = Completer<void>();
    emit(update(busy: state.order == null));
    try {
      final order = await repository.order(id);
      if (!isClosed) {
        final previous = state.order;
        final trackingChanged =
            previous != null &&
            (previous.driverPhone != order.driverPhone ||
                previous.plate != order.plate ||
                previous.summary.status != order.summary.status);
        if (trackingChanged) {
          _trackingGeneration++;
          _trackingAttemptAt = null;
          if (_trackingBusy) _trackingAgain = true;
        }
        final payment = state.payment;
        final keepQr =
            order.summary.needsPayment &&
            !order.paymentExpired &&
            payment != null &&
            payment.url == order.checkoutUrl;
        emit(
          OrderState(
            order: order,
            tracking: trackingChanged ? null : state.tracking,
            payment: keepQr ? payment : null,
            acting: state.acting,
            trackingError: state.trackingError,
          ),
        );
        if (!order.summary.terminal) _refreshTrackingIfDue();
      }
    } catch (e) {
      if (!isClosed) {
        emit(update(error: customerError(e), acting: state.acting));
      }
    } finally {
      _refreshing = false;
      _refreshDone?.complete();
    }
  }

  Future<void> loadTracking() async {
    if (isClosed || _closing) return;
    if (_trackingBusy) {
      return _trackingDone?.future;
    }
    _trackingBusy = true;
    _trackingDone = Completer<void>();
    _trackingAttemptAt = _clock();
    final generation = _trackingGeneration;
    final before = state.tracking;
    try {
      var tracking = await repository.tracking(id);
      if (isClosed || _closing || generation != _trackingGeneration) return;
      final latest = state.tracking;
      if (!identical(latest, before) &&
          latest?.at != null &&
          latest?.driver != null &&
          (tracking.at == null || latest!.at!.isAfter(tracking.at!))) {
        tracking = tracking.withLocation(latest!.driver!, latest.at!);
      }
      if (!isClosed) {
        emit(
          OrderState(
            order: state.order,
            tracking: tracking,
            payment: state.payment,
            acting: state.acting,
          ),
        );
      }
    } catch (e) {
      if (!isClosed && !_closing && generation == _trackingGeneration) {
        emit(update(acting: state.acting, trackingError: customerError(e)));
      }
    } finally {
      _trackingBusy = false;
      _trackingDone?.complete();
      if (_trackingAgain) {
        _trackingAgain = false;
        if (!isClosed && !_closing && state.order?.summary.terminal != true) {
          unawaited(loadTracking());
        }
      }
    }
  }

  Completer<void>? _trackingDone;

  void _refreshTrackingIfDue() {
    if (isClosed || _closing || state.order?.summary.terminal == true) return;
    if (_trackingAttemptAt == null ||
        _clock().difference(_trackingAttemptAt!) >=
            const Duration(seconds: 10)) {
      unawaited(loadTracking());
    }
  }

  Future<bool> act(Future<void> Function() action) async {
    if (state.acting || isClosed || _closing) return false;
    emit(update(acting: true));
    if (_refreshing) await _refreshDone?.future;
    if (isClosed) return false;
    try {
      await action();
      if (isClosed) return true;
      emit(update());
      await refresh();
      return true;
    } catch (e) {
      if (!isClosed) emit(update(error: customerError(e)));
      return false;
    }
  }

  Future<void> createPayment() async {
    await act(() async {
      final payment = await repository.payment(id);
      if (!isClosed) emit(update(payment: payment, acting: true));
    });
  }

  @override
  Future<void> close() async {
    _closing = true;
    _timer?.cancel();
    await _subscription?.cancel();
    await realtime.stop();
    return super.close();
  }
}

class EvidenceState {
  const EvidenceState({this.photos = const [], this.busy = false, this.error});
  final List<String> photos;
  final bool busy;
  final String? error;
}

class CustomerEvidenceCubit extends Cubit<EvidenceState> {
  CustomerEvidenceCubit(this.repository) : super(const EvidenceState());
  final CustomerRepository repository;
  Future<void> add(String name, Uint8List bytes) async {
    if (isClosed || state.busy || state.photos.length >= 5) return;
    emit(EvidenceState(photos: state.photos, busy: true));
    try {
      final url = await repository.upload(name, bytes);
      if (!isClosed) emit(EvidenceState(photos: [...state.photos, url]));
    } catch (e) {
      if (!isClosed) {
        emit(EvidenceState(photos: state.photos, error: customerError(e)));
      }
    }
  }

  void remove(String url) {
    if (!state.busy) {
      emit(EvidenceState(photos: state.photos.where((p) => p != url).toList()));
    }
  }
}
