import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'push_cubit.dart';

/// Refresh visible data on push/resume, with a polling fallback if push is unavailable.
class LiveRefresh extends StatefulWidget {
  const LiveRefresh({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;
  @override
  State<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends State<LiveRefresh> with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<void>? _events;
  bool _foreground = true, _busy = false, _visible = true;
  DateTime? _last;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_events == null) {
      try {
        _events = context.read<PushCubit>().updates.listen((_) => _refresh());
      } catch (_) {
        /* Fixtures and guest screens can run without push. */
      }
    }
  }

  Future<void> _refresh({bool manual = false}) async {
    if (!mounted ||
        _busy ||
        !_foreground ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    if (!manual &&
        _last != null &&
        DateTime.now().difference(_last!) < const Duration(seconds: 2)) {
      return;
    }
    _busy = true;
    _last = DateTime.now();
    try {
      await widget.onRefresh();
    } catch (_) {
      /* Feature cubits display their own retry/error state. */
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _last = null;
      unawaited(_refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.isCurrentOf(context) ?? true;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
    _visible = visible;
    return RefreshIndicator(
      onRefresh: () => _refresh(manual: true),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_events?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
