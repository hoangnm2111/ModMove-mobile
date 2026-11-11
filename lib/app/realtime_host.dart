import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/notifications/realtime_source.dart';
import '../core/session/session_store.dart';
import '../features/auth/presentation/auth_cubit.dart';

/// Đăng nhập (hoặc khôi phục phiên) → mở SignalR; đăng xuất / hết phiên → ngắt và xoá hộp thông báo,
/// để tài khoản đăng nhập sau không thấy thông báo cũ.
class RealtimeHost extends StatefulWidget {
  const RealtimeHost({super.key, required this.child});
  final Widget child;
  @override
  State<RealtimeHost> createState() => _RealtimeHostState();
}

class _RealtimeHostState extends State<RealtimeHost> {
  late final RealtimeBridge _bridge;
  StreamSubscription<Session?>? _subscription;
  int? _userId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>();
    _bridge = context.read<RealtimeBridge>();
    _subscription = auth.stream.listen(_onSession);
    _onSession(auth.state);
  }

  void _onSession(Session? session) {
    if (session?.userId == _userId) return;
    final previous = _userId;
    _userId = session?.userId;
    if (session == null) {
      unawaited(_bridge.stop());
    } else {
      // Đổi tài khoản (không qua đăng xuất): ngắt kết nối cũ, xoá hộp thông báo rồi kết nối lại bằng token mới.
      unawaited(() async {
        if (previous != null) await _bridge.stop();
        await _bridge.start();
      }());
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_bridge.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
