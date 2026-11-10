import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/network/api_client.dart';
import '../core/platform/secure_session_store.dart';
import '../core/theme/app_theme.dart';
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
import 'payment_return_cubit.dart';
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

class _RemoteAppState extends State<RemoteApp> {
  late final ApiClient _api;
  late final AuthCubit _auth;
  late final PaymentReturnCubit _paymentReturns;
  @override
  void initState() {
    super.initState();
    _api = ApiClient(store: const SecureSessionStore());
    _auth = AuthCubit(RemoteAuthRepository(_api))..restore();
    _paymentReturns = PaymentReturnCubit()..initialize();
  }

  @override
  void dispose() {
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
    ],
    child: BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => state.stage == AuthStage.signedIn
          ? _DriverSessionApp(
              key: ValueKey(_api.session!.userId),
              api: _api,
              logout: _auth.logout,
            )
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
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
  final _navigator = GlobalKey<NavigatorState>();

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
  Widget build(BuildContext context) => BlocListener<PaymentReturnCubit, bool>(
    listener: (_, pending) {
      if (pending) _openReturnedWallet();
    },
    child: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            _driver != null) {
          if (context.read<PaymentReturnCubit>().state) _openReturnedWallet();
          return ModMoveApp(
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
