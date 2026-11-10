import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/driver_notification.dart';
import '../domain/push_repository.dart';

class PushState {
  const PushState({
    this.permission = PushPermission.unavailable,
    this.registered = false,
    this.busy = false,
    this.error,
    this.pending,
  });
  final PushPermission permission;
  final bool registered, busy;
  final String? error;
  final DriverNotification? pending;
}

class PushCubit extends Cubit<PushState> {
  PushCubit(this.device, this.repository) : super(const PushState());
  final PushDevice device;
  final PushTokenRepository repository;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _seen = <String>{};
  String? _user, _token;
  int _generation = 0;
  bool _ready = false;
  Future<void>? _sync;
  Future<void> _cleanup = Future.value();
  Timer? _retry;

  void _state({
    PushPermission? permission,
    bool? registered,
    bool busy = false,
    String? error,
    DriverNotification? pending,
    bool clearPending = false,
  }) {
    if (!isClosed) {
      emit(
        PushState(
          permission: permission ?? state.permission,
          registered: registered ?? state.registered,
          busy: busy,
          error: error,
          pending: clearPending ? null : pending ?? state.pending,
        ),
      );
    }
  }

  Future<void> initialize() async {
    try {
      _ready = await device.initialize();
      if (!_ready) return;
      _subscriptions.add(
        device.tokenChanges.listen((_) {
          if (_user != null) unawaited(synchronize(force: true));
        }, onError: (Object _) {}),
      );
      _subscriptions.add(
        device.messages.listen((message) async {
          if (_user == null || state.permission != PushPermission.allowed) {
            return;
          }
          if (message.id != null && !_seen.add('show:${message.id}')) return;
          if (_seen.length > 200) _seen.clear();
          try {
            await device.show(message);
          } catch (_) {
            /* OS may disable alerts. */
          }
        }),
      );
      _subscriptions.add(device.opened.listen(_open));
      final initial = await device.initialMessage();
      if (initial != null && initial.route != null) {
        if (initial.id != null) _seen.add('open:${initial.id}');
        _state(pending: initial);
      }
    } catch (_) {
      _state(error: 'Chưa khởi tạo được thông báo. Hãy mở lại ứng dụng.');
    }
  }

  void _open(DriverNotification message) {
    if (_user == null || message.route == null) return;
    if (message.id != null && !_seen.add('open:${message.id}')) return;
    _state(pending: message);
  }

  void consume() => _state(clearPending: true);

  Future<void> attach(String userId) async {
    if (_user == userId) return;
    final cleanup = _user == null ? _cleanup : detach();
    final generation = ++_generation;
    await cleanup;
    if (isClosed || generation != _generation) return;
    _user = userId;
    _state(registered: false);
    _retry?.cancel();
    _retry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.registered) unawaited(synchronize());
    });
    await synchronize(request: true, force: true);
  }

  Future<void> synchronize({bool request = false, bool force = false}) async {
    if (!_ready || _user == null || isClosed) return;
    final running = _sync;
    if (running != null) {
      await running;
      // A token refresh arriving during registration must not be lost.
      if (force) return synchronize(force: true);
      return;
    }
    final generation = _generation;
    bool current() => !isClosed && generation == _generation && _user != null;
    Future<void> perform() async {
      _state(busy: true);
      try {
        final permission = await device.permission(request: request);
        if (!current()) return;
        if (permission != PushPermission.allowed) {
          _state(permission: permission, registered: false);
          return;
        }
        _state(permission: permission, busy: true);
        final token = await device.token();
        if (!current()) return;
        if (token == null || token.isEmpty) throw StateError('Token not ready');
        if (!state.registered || token != _token || force) {
          // Remember attempted registrations too: an interrupted HTTP response
          // may still have saved this token on the backend before logout.
          _token = token;
          await repository.register(token);
        }
        if (current()) _state(permission: permission, registered: true);
      } catch (_) {
        if (current()) {
          _state(
            registered: false,
            error: 'Chưa kết nối được thông báo. App sẽ tự thử lại.',
          );
        }
      }
    }

    final work = perform();
    _sync = work;
    try {
      await work;
    } finally {
      if (identical(_sync, work)) _sync = null;
    }
  }

  /// Drain registration before logout so an in-flight PUT cannot reattach the
  /// token after the backend has cleared it. Return only this device's token.
  Future<String?> detach() async {
    _user = null;
    _generation++;
    _retry?.cancel();
    _state(registered: false, clearPending: true);
    final running = _sync;
    final previous = _cleanup;
    String? oldToken;
    final cleanup = () async {
      await previous;
      await running;
      oldToken = _token;
      _token = null;
      _seen.clear();
      try {
        await device.clear();
      } catch (_) {
        /* Offline logout still works. */
      }
    }();
    _cleanup = cleanup;
    await cleanup;
    return oldToken;
  }

  Future<void> openSettings() async {
    try {
      await device.openSettings();
    } catch (_) {
      _state(error: 'Mở Cài đặt Android → Ứng dụng → ModMove → Thông báo.');
    }
  }

  @override
  Future<void> close() async {
    _generation++;
    _user = null;
    _retry?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await device.close();
    return super.close();
  }
}
