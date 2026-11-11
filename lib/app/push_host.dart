import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/session/session_store.dart';
import '../core/widgets/notice_banner.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/notifications/domain/push_message.dart';
import '../features/notifications/presentation/push_cubit.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import 'app.dart';

/// Nối thông báo đẩy (FCM) với phiên đăng nhập và điều hướng:
///  - đăng nhập / khôi phục phiên → xin quyền, lấy token, `PUT api/account/fcmtoken`;
///  - đăng xuất / hết phiên → huỷ token trên máy (AuthCubit.logout gửi kèm `fcmToken` cho BE);
///  - app quay lại màn hình → đồng bộ lại token;
///  - chạm thông báo (đang mở, chạy nền hoặc mở lạnh) → mở đúng màn hình theo vai trò.
class PushHost extends StatefulWidget {
  const PushHost({super.key, required this.child});
  final Widget child;
  @override
  State<PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<PushHost> with WidgetsBindingObserver {
  late final PushCubit _push;
  late final AuthCubit _auth;
  StreamSubscription<Session?>? _authSubscription;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _push = context.read<PushCubit>();
    _auth = context.read<AuthCubit>();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.stream.listen(_onSession);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await _push.initialize();
    if (mounted) _onSession(_auth.state);
  }

  void _onSession(Session? session) {
    if (session == null) {
      unawaited(_push.detach());
    } else {
      unawaited(_push.attach('${session.userId}'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_push.synchronize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  /// Chờ có điều hướng và phiên đăng nhập (mở lạnh từ thông báo) rồi mới mở màn hình.
  void _openPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = ModMoveApp.navigatorKey.currentState;
      final message = _push.state.pending;
      if (!mounted ||
          _opening ||
          message == null ||
          navigator == null ||
          _auth.state == null) {
        return;
      }
      _push.consume();
      _opening = true;
      try {
        await _route(navigator, message, _auth.state!.role);
      } catch (_) {
        final context = ModMoveApp.navigatorKey.currentContext;
        if (mounted && context != null && context.mounted) {
          showNotice(
            context,
            'Chưa mở được thông báo. Hãy mở mục liên quan để xem thông tin mới nhất.',
            error: true,
          );
        }
      } finally {
        _opening = false;
        if (mounted && _push.state.pending != null) _openPending();
      }
    });
  }

  /// Dữ liệu thông báo chỉ chọn màn hình; trạng thái thật luôn đọc lại từ API khi màn hình mở.
  Future<void> _route(
    NavigatorState navigator,
    PushMessage message,
    String role,
  ) async {
    String? route;
    Object? argument;
    if (role == 'Customer') {
      final id = int.tryParse(message.orderId ?? '');
      if (id == null) return;
      route = '/customer-order';
      argument = id;
    } else if (role == 'Driver') {
      final trips = context.read<DriverTripRepository>();
      switch (message.type) {
        case 'NEW_MATCHING_ORDER':
          final id = message.orderId;
          if (id == null) {
            route = '/driver-home';
          } else {
            await trips.openOffer(id);
            route = '/job-details';
          }
        case 'INCIDENT_REPORTED' ||
            'INCIDENT_IN_PROGRESS' ||
            'INCIDENT_DECIDED':
          // Tải lại chuyến để banner/kết quả cập nhật, rồi mở chi tiết sự cố (không có mã thì mở danh sách).
          await trips.refresh();
          final incidentId = int.tryParse(message.incidentId ?? '');
          route = incidentId == null ? '/driver-incidents' : '/driver-incident';
          argument = incidentId;
        case 'PICKUP_APPROVED' ||
            'PICKUP_REJECTED' ||
            'ORDER_STATUS_CHANGED':
          await trips.refresh();
          route = trips.current.trip?.ongoing == true
              ? '/active-trip'
              : '/driver-trips';
        case 'ORDER_CANCELLED' || 'ORDER_COMPLETED':
          route = '/driver-trips';
        case 'RATING_RECEIVED':
          route = '/driver-ratings';
        case 'WITHDRAWAL_DECIDED':
          route = '/driver-wallet';
        case 'DRIVER_APPLICATION_APPROVED' || 'DRIVER_APPLICATION_REJECTED':
          await context.read<DriverController>().syncAccount();
          route = '/profile';
      }
    }
    if (route == null || !mounted) return;
    navigator.pushNamedAndRemoveUntil(
      route,
      (r) => r.isFirst,
      arguments: argument,
    );
  }

  @override
  Widget build(BuildContext context) => BlocListener<PushCubit, PushState>(
    listenWhen: (before, after) =>
        !identical(before.pending, after.pending) && after.pending != null,
    listener: (_, _) => _openPending(),
    child: widget.child,
  );
}
