import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  BookingCubit(this.repository) : super(const BookingState());
  final CustomerRepository repository;
  int _revision = 0;
  Future<void> initialize() async {
    if (state.busy || state.needsOrderCheck) return;
    emit(BookingState(draft: state.draft, busy: true));
    try {
      final c = await repository.catalog();
      if (!isClosed) emit(BookingState(draft: state.draft, catalog: c));
    } catch (e) {
      if (!isClosed) {
        emit(BookingState(draft: state.draft, error: customerError(e)));
      }
    }
  }

  void edit(BookingDraft draft) {
    if (state.busy ||
        state.uploading ||
        state.created != null ||
        state.needsOrderCheck) {
      return;
    }
    final old = state.draft;
    final priceChanged =
        old.pickup != draft.pickup ||
        old.dropoff != draft.dropoff ||
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
    emit(
      BookingState(
        draft: state.draft,
        catalog: state.catalog,
        fare: state.fare,
        uploading: true,
      ),
    );
    try {
      final url = await repository.upload(name, bytes);
      if (!isClosed) {
        emit(
          BookingState(
            draft: state.draft.copyWith(photos: [...state.draft.photos, url]),
            catalog: state.catalog,
            fare: state.fare,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) error(customerError(e));
    }
  }

  Future<void> estimate() async {
    if (state.busy || state.uploading || state.needsOrderCheck) return;
    final invalid = state.draft.validate();
    if (invalid != null) return error(invalid);
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

  Future<void> submit() async {
    if (state.busy ||
        state.uploading ||
        state.created != null ||
        state.needsOrderCheck) {
      return;
    }
    final invalid = state.draft.validate(submit: true);
    if (invalid != null) return error(invalid);
    final fare = state.fare;
    if (fare == null) {
      return error('Vui lòng tính lại giá cước trước khi đặt đơn.');
    }
    emit(
      BookingState(
        draft: state.draft,
        catalog: state.catalog,
        fare: fare,
        busy: true,
      ),
    );
    try {
      final created = await repository.book(state.draft, fare);
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
                e is CustomerFailure && e.code == 'ORDER_RESULT_UNKNOWN',
          ),
        );
      }
    }
  }

  void confirmedNoOrderCreated() {
    if (!state.needsOrderCheck) return;
    emit(
      BookingState(
        draft: state.draft,
        catalog: state.catalog,
        fare: state.fare,
      ),
    );
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
  CustomerOrderCubit(this.repository, this.id, this.realtime)
    : super(const OrderState());
  final CustomerRepository repository;
  final CustomerRealtime realtime;
  final int id;
  Timer? _timer;
  StreamSubscription<CustomerRealtimeEvent>? _subscription;
  bool _refreshing = false, _trackingBusy = false;
  bool _closing = false;
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
        if (event.reconnected && state.tracking != null) {
          unawaited(loadTracking());
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
        final payment = state.payment;
        final keepQr =
            order.summary.needsPayment &&
            !order.paymentExpired &&
            payment != null &&
            payment.url == order.checkoutUrl;
        emit(
          OrderState(
            order: order,
            tracking: state.tracking,
            payment: keepQr ? payment : null,
            acting: state.acting,
            trackingError: state.trackingError,
          ),
        );
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
    if (isClosed || _closing || _trackingBusy) return;
    _trackingBusy = true;
    try {
      var tracking = await repository.tracking(id);
      final latest = state.tracking;
      if (latest?.at != null &&
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
      if (!isClosed) {
        emit(update(acting: state.acting, trackingError: customerError(e)));
      }
    } finally {
      _trackingBusy = false;
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
