import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/network/api_client.dart';
import '../core/platform/file_draft_store.dart';
import '../features/account/data/remote_account_security_repository.dart';
import '../features/account/presentation/account_security_cubit.dart';
import '../features/account/presentation/account_security_screen.dart';
import '../core/platform/secure_session_store.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/customer_theme.dart';
import '../features/auth/data/remote_auth_repository.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/onboarding/data/repositories/remote_driver_repository.dart';
import '../features/onboarding/data/repositories/device_photo_repository.dart';
import '../features/onboarding/domain/entities/driver_application.dart';
import '../features/onboarding/domain/usecases/driver_usecases.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/driver_trip/data/repositories/device_driver_location.dart';
import '../features/driver_trip/data/repositories/remote_driver_trip_repository.dart';
import '../features/driver_trip/data/services/driver_tracking_connection.dart';
import 'app.dart';
import 'customer_app.dart';
import 'payment_return_cubit.dart';
import '../features/notifications/data/firebase_push_device.dart';
import '../features/notifications/data/remote_push_token_repository.dart';
import '../features/notifications/presentation/push_cubit.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/incidents/data/remote_driver_incident_repository.dart';
import '../features/wallet/data/remote_wallet_repository.dart';
import '../features/wallet/presentation/wallet_cubit.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../features/earnings/data/remote_earnings_repository.dart';
import '../features/earnings/presentation/revenue_cubit.dart';
import '../features/earnings/presentation/revenue_screen.dart';

class RemoteApp extends StatefulWidget {
  const RemoteApp({super.key});
  @override
  State<RemoteApp> createState() => _RemoteAppState();
}

class _RemoteAppState extends State<RemoteApp> with WidgetsBindingObserver {
  late final ApiClient _api;
  late final AuthCubit _auth;
  late final PaymentReturnCubit _paymentReturns;
  late final PushCubit _push;
  late final StreamSubscription<AuthState> _authChanges;
  AuthStage _lastAuthStage = AuthStage.restoring;
  @override
  void initState() {
    super.initState();
    _api = ApiClient(store: const SecureSessionStore());
    _push = PushCubit(FirebasePushDevice(), RemotePushTokenRepository(_api));
    _auth = AuthCubit(RemoteAuthRepository(_api, detachPush: _push.detach));
    _authChanges = _auth.stream.listen((state) {
      if (_lastAuthStage == state.stage) return;
      _lastAuthStage = state.stage;
      if (state.stage == AuthStage.signedIn) {
        unawaited(_push.attach(_api.session!.userId));
      } else if (state.stage == AuthStage.login) {
        unawaited(_push.detach());
      }
    });
    unawaited(_initialize());
    _paymentReturns = PaymentReturnCubit()..initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initialize() async {
    await _push.initialize();
    if (mounted) await _auth.restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_push.synchronize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authChanges.cancel());
    unawaited(_push.close());
    unawaited(_auth.close());
    unawaited(_paymentReturns.close());
    unawaited(_api.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: _auth),
      BlocProvider.value(value: _paymentReturns),
      BlocProvider.value(value: _push),
    ],
    child: BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) =>
          state.stage == AuthStage.guest ||
              (state.stage == AuthStage.signedIn &&
                  _api.session?.role == 'Customer')
          ? CustomerApp(
              key: ValueKey(_api.session?.userId ?? 'guest'),
              api: _api,
              guest: state.stage == AuthStage.guest,
            )
          : state.stage == AuthStage.signedIn
          ? _DriverSessionApp(
              key: ValueKey(_api.session!.userId),
              api: _api,
              logout: _auth.logout,
            )
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildCustomerTheme(),
              home: const AuthScreen(),
            ),
    ),
  );
}

class _DriverSessionApp extends StatefulWidget {
  const _DriverSessionApp({super.key, required this.api, required this.logout});
  final ApiClient api;
  final VoidCallback logout;
  @override
  State<_DriverSessionApp> createState() => _DriverSessionAppState();
}

class _DriverSessionAppState extends State<_DriverSessionApp> {
  late final _drafts = FileDraftStore(
    widget.api.baseUrl,
    widget.api.session!.userId,
  );
  final _navigator = GlobalKey<NavigatorState>();
  bool _openingNotification = false;

  void _openNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          _driver == null ||
          _navigator.currentState == null ||
          _openingNotification) {
        return;
      }
      final push = context.read<PushCubit>();
      final message = push.state.pending;
      if (message == null) return;
      push.consume();
      _openingNotification = true;
      try {
        var route = message.route;
        if (route == '/job-details') {
          await _trips!.openOffer(message.orderId!);
        } else if (route == '/active-trip') {
          await _trips!.refresh();
          if (_trips!.current.trip?.ongoing != true ||
              _trips!.current.trip?.job.id != message.orderId) {
            route = '/trips';
          }
        } else if (route == '/profile') {
          await _driver!.refresh();
        }
        if (!mounted || route == null) return;
        _navigator.currentState!.pushNamedAndRemoveUntil(
          route,
          (route) => route.isFirst,
          arguments: message.argument,
        );
      } catch (_) {
        if (mounted && _navigator.currentContext != null) {
          ScaffoldMessenger.of(_navigator.currentContext!).showSnackBar(
            const SnackBar(
              content: Text(
                'Chưa mở được thông báo. Hãy làm mới danh sách; đơn có thể đã hết hạn.',
              ),
            ),
          );
        }
      } finally {
        _openingNotification = false;
        if (mounted && push.state.pending != null) _openNotification();
      }
    });
  }

  void _openReturnedWallet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _driver == null || _navigator.currentState == null) {
        return;
      }
      final returns = context.read<PaymentReturnCubit>();
      if (!returns.state) return;
      returns.consume();
      _navigator.currentState!.pushNamedAndRemoveUntil(
        '/wallet',
        (route) => route.isFirst,
      );
    });
  }

  DriverController? _driver;
  RemoteDriverTripRepository? _trips;
  late Future<void> _loading;
  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<void> _load() async {
    final profile = RemoteDriverRepository(widget.api);
    await profile.initialize();
    final trips = RemoteDriverTripRepository(
      widget.api,
      DeviceDriverLocation(),
      SignalRDriverTracking(widget.api),
    );
    try {
      await trips.initialize();
    } catch (_) {
      await trips.close();
      rethrow;
    }
    if (!mounted) {
      await trips.close();
      return;
    }
    _trips = trips;
    _driver = DriverController(
      loadApplication: GetDriverApplication(profile),
      submitApplication: SubmitDriverApplication(
        profile,
        validation: RemoteDriverRepository.validation,
        requireUploadedDocuments: true,
      ),
      pickPhoto: PickDocumentPhoto(DevicePhotoRepository()),
      profile: ManageDriverProfile(profile),
      validation: RemoteDriverRepository.validation,
      vehicleTypes: profile.vehicleTypes
          .map((e) => e['name'] as String)
          .toList(),
    );
  }

  @override
  void dispose() {
    if (_trips != null) unawaited(_trips!.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<PushCubit, PushState>(
        listenWhen: (before, after) =>
            !identical(before.pending, after.pending),
        listener: (_, state) {
          if (state.pending != null) _openNotification();
        },
      ),
      BlocListener<PaymentReturnCubit, bool>(
        listener: (_, pending) {
          if (pending) _openReturnedWallet();
        },
      ),
    ],
    child: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            _driver != null) {
          if (context.read<PaymentReturnCubit>().state) _openReturnedWallet();
          if (context.read<PushCubit>().state.pending != null) {
            _openNotification();
          }
          return ModMoveApp(
            drafts: _drafts,
            accountSecurityBuilder: (_) => BlocProvider(
              create: (_) => AccountSecurityCubit(
                RemoteAccountSecurityRepository(widget.api),
              ),
              child: const AccountSecurityScreen(),
            ),
            notificationSettingsBuilder: (_) =>
                const NotificationSettingsScreen(),
            navigatorKey: _navigator,
            driverController: _driver,
            tripRepository: _trips,
            incidentRepository: RemoteDriverIncidentRepository(widget.api),
            onLogout: widget.logout,
            walletBuilder: (_) => BlocProvider(
              create: (_) => WalletCubit(RemoteWalletRepository(widget.api)),
              child: const WalletScreen(),
            ),
            revenueBuilder: (_) => BlocProvider(
              create: (_) => RevenueCubit(RemoteEarningsRepository(widget.api)),
              child: const RevenueScreen(),
            ),
            screen: _driver!.status == ApprovalStatus.approved
                ? 'driver-home'
                : _driver!.status == ApprovalStatus.draft
                ? 'driver-onboarding'
                : 'profile-pending',
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: snapshot.hasError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              snapshot.error is ApplicationFailure
                                  ? (snapshot.error as ApplicationFailure)
                                        .message
                                  : '${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  setState(() => _loading = _load()),
                              child: const Text('Thử lại'),
                            ),
                            TextButton(
                              onPressed: widget.logout,
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
