import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/network/api_client.dart';
import '../core/session/session_store.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/driver_trip/data/driver_api.dart';
import '../features/driver_trip/data/repositories/api_driver_trip_repository.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import '../features/driver_trip/domain/entities/trip_models.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/driver_trip/domain/usecases/driver_trip_actions.dart';
import '../features/driver_trip/presentation/bloc/driver_home_bloc.dart';
import '../features/driver_trip/presentation/bloc/job_offer_bloc.dart';
import '../features/driver_trip/presentation/bloc/active_trip_bloc.dart';
import '../features/driver_trip/data/repositories/platform_trip_contact_repository.dart';
import '../features/driver_trip/data/repositories/device_cargo_photo_repository.dart';
import '../features/driver_trip/presentation/bloc/evidence_cubit.dart';
import '../core/notifications/notification_cubit.dart';
import '../features/driver_trip/presentation/trip_notices.dart';
import '../features/onboarding/presentation/controllers/profile_notices.dart';

class DriverTripScope extends StatefulWidget {
  const DriverTripScope({
    super.key,
    required this.child,
    this.repository,
    this.cargoPhotos,
    this.useBackend = false,
    this.navigatorKey,
  });
  final Widget child;
  final DriverTripRepository? repository;

  /// `true`: chuyến đi chạy trên BE thật (api/driver/*) thay vì dữ liệu mô phỏng.
  final bool useBackend;

  /// Điều hướng gốc của app: dùng để hiện hộp thoại kết quả xử lý sự cố ở bất kỳ màn hình nào.
  final GlobalKey<NavigatorState>? navigatorKey;
  final CargoPhotoRepository? cargoPhotos;
  @override
  State<DriverTripScope> createState() => _DriverTripScopeState();
}

class _DriverTripScopeState extends State<DriverTripScope>
    with WidgetsBindingObserver {
  late final DriverTripRepository _repository;
  late final DriverHomeBloc _homeBloc;
  late final DriverController _driver;
  late final StreamSubscription<DriverPresentationState> _profileSubscription;
  StreamSubscription<Session?>? _authSubscription;
  StreamSubscription<DriverSession>? _outcomeSubscription;
  bool _showingOutcome = false;
  DriverSession? _previousSession;
  DriverPresentationState? _previousProfile;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final driver = context.read<DriverController>();
    _driver = driver;
    _repository =
        widget.repository ??
        (widget.useBackend
            ? ApiDriverTripRepository(
                api: DriverApi(context.read<ApiClient>()),
                access: DriverAccess(
                  approved: driver.canGoOnline,
                  active: driver.accountActive,
                ),
                availabilityGateway: driver.saveOnline,
              )
            : MockDriverTripRepository(
                access: DriverAccess(
                  approved: driver.canGoOnline,
                  active: driver.accountActive,
                ),
                availabilityGateway: driver.saveOnline,
                initialOnline: driver.online,
              ));
    _homeBloc = DriverHomeBloc(DriverTripActions(_repository));
    _outcomeSubscription = _repository.changes.listen((session) {
      _pushTripNotices(session);
      _onOutcome(session);
    });
    _previousSession = _repository.current;
    _previousProfile = driver.state;
    driver.availabilityDelegate = (value) async {
      final success = await _homeBloc.changeAvailability(value);
      if (!success) driver.reportAvailabilityError(_homeBloc.state.error);
      return success;
    };
    if (widget.useBackend) {
      // Tài xế đăng nhập → tải hồ sơ + bắt đầu đồng bộ với BE; đăng xuất → xoá sạch.
      final auth = context.read<AuthCubit>();
      _authSubscription = auth.stream.listen(_onSession);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSession(auth.state);
      });
    }
    _profileSubscription = driver.stream.listen((state) {
      _pushProfileNotices(state);
      final profile = state.application;
      if (profile != null) {
        _repository.updateAccess(
          DriverAccess(
            approved: profile.canGoOnline,
            active: profile.accountActive,
          ),
        );
      }
    });
  }

  NotificationCubit? get _notices {
    try {
      return context.read<NotificationCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Chạy dữ liệu mô phỏng: tự sinh thông báo từ thay đổi trạng thái. Chạy BE thật thì
  /// SignalR (RealtimeBridge) đã đẩy đúng các thông báo này nên bỏ qua để khỏi trùng.
  void _pushTripNotices(DriverSession session) {
    final previous = _previousSession;
    _previousSession = session;
    if (widget.useBackend || !mounted) return;
    final cubit = _notices;
    if (cubit == null) return;
    for (final notice in tripNotices(previous, session)) {
      cubit.push(notice);
    }
  }

  void _pushProfileNotices(DriverPresentationState state) {
    final previous = _previousProfile;
    _previousProfile = state;
    if (widget.useBackend || !mounted) return;
    final cubit = _notices;
    if (cubit == null) return;
    for (final notice in profileNotices(previous, state)) {
      cubit.push(notice);
    }
  }

  /// Điều phối viên xử lý xong sự cố: báo cho tài xế một lần; đơn đã rời khỏi tài xế thì về màn chính.
  Future<void> _onOutcome(DriverSession session) async {
    final outcome = session.incidentOutcome;
    final navigator = widget.navigatorKey?.currentState;
    final dialogContext = widget.navigatorKey?.currentContext;
    if (outcome == null || _showingOutcome || navigator == null || dialogContext == null) return;
    _showingOutcome = true;
    final message = outcome.message.isNotEmpty
        ? outcome.message
        : switch (outcome.kind) {
            IncidentOutcomeKind.continueTrip => 'Bạn có thể tiếp tục chuyến.',
            IncidentOutcomeKind.dismissed => 'Chuyến được tiếp tục bình thường.',
            IncidentOutcomeKind.reassignedAway => 'Đơn đã được điều phối viên giao cho tài xế khác.',
            IncidentOutcomeKind.orderCancelled => 'Điều phối viên đã hủy đơn.',
          };
    await showDialog<void>(
      context: dialogContext,
      builder: (_) => AlertDialog(
        title: Text(outcome.title),
        content: Text(message),
        actions: [
          FilledButton(
            key: const Key('incident-outcome-ok'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
    _repository.acknowledgeOutcome();
    _showingOutcome = false;
    if (outcome.kind == IncidentOutcomeKind.reassignedAway || outcome.kind == IncidentOutcomeKind.orderCancelled) {
      navigator.pushNamedAndRemoveUntil('/driver-home', (_) => false);
    }
  }

  bool _wasDriver = false;
  void _onSession(Session? session) {
    final isDriver = session?.isDriver == true;
    final repository = _repository;
    if (repository is ApiDriverTripRepository) {
      repository.onSessionChanged(isDriver: isDriver);
    }
    if (isDriver && !_wasDriver) {
      unawaited(_driver.syncAccount());
    } else if (!isDriver && _wasDriver) {
      _driver.clearAccount();
    }
    _wasDriver = isDriver;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive includes native camera/gallery overlays. Only pause GPS once
    // the app is actually backgrounded; resume never resets offer deadlines.
    if (state == AppLifecycleState.paused) _repository.setForeground(false);
    if (state == AppLifecycleState.resumed) _repository.setForeground(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driver.availabilityDelegate = null;
    unawaited(_homeBloc.close());
    unawaited(_profileSubscription.cancel());
    unawaited(_authSubscription?.cancel());
    unawaited(_outcomeSubscription?.cancel());
    if (widget.repository == null) {
      final repository = _repository;
      if (repository is MockDriverTripRepository) unawaited(repository.close());
      if (repository is ApiDriverTripRepository) unawaited(repository.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepositoryProvider<DriverTripRepository>.value(
        value: _repository,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => EvidenceCubit(
                DriverTripActions(_repository),
                widget.cargoPhotos ?? DeviceCargoPhotoRepository(),
              ),
            ),
            BlocProvider.value(value: _homeBloc),
            BlocProvider(
              create: (_) => JobOfferBloc(DriverTripActions(_repository)),
            ),
            BlocProvider(
              create: (_) => ActiveTripBloc(
                DriverTripActions(_repository),
                const PlatformTripContactRepository(),
              ),
            ),
          ],
          child: widget.child,
        ),
      );
}
