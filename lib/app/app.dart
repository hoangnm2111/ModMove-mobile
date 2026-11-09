import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';
import '../core/session/session_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/customer/data/customer_api.dart';
import '../features/customer/presentation/customer_shell.dart';
import 'driver_trip_scope.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/driver_trip/presentation/screens/driver_dashboard.dart';
import '../features/driver_trip/presentation/screens/job_details_screen.dart';
import '../features/driver_trip/presentation/screens/active_trip_screen.dart';
import '../core/theme/app_theme.dart';
import '../features/home/data/repositories/demo_fare_repository.dart';
import '../features/home/domain/usecases/get_public_fares.dart';
import '../features/home/presentation/controllers/home_controller.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/pricing_screen.dart';
import '../features/home/presentation/models/vehicle_option.dart';
import '../features/onboarding/data/repositories/demo_driver_repository.dart';
import '../features/onboarding/data/repositories/api_driver_repository.dart';
import '../features/onboarding/data/repositories/demo_photo_repository.dart';
import '../features/onboarding/data/services/mock_driver_api.dart';
import '../features/onboarding/data/repositories/device_photo_repository.dart';
import '../features/onboarding/domain/usecases/driver_usecases.dart';
import '../features/onboarding/domain/entities/driver_application.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/onboarding/presentation/screens/verification_screen.dart';
import '../features/onboarding/presentation/screens/driver_profile_screen.dart';
import '../features/onboarding/presentation/screens/driver_demo_screen.dart';
import '../features/onboarding/presentation/screens/driver_history_screen.dart';

class ModMoveApp extends StatelessWidget {
  const ModMoveApp({
    super.key,
    this.screen = const String.fromEnvironment('SCREEN', defaultValue: 'home'),
    this.driverController,
    this.mockApi,
    this.tripRepository,
    this.cargoPhotos,
    this.sessions,
    this.httpClient,
  });
  final String screen;
  final DriverController? driverController;
  final MockDriverApi? mockApi;
  final DriverTripRepository? tripRepository;
  final CargoPhotoRepository? cargoPhotos;

  /// Phiên đăng nhập (main.dart mở từ file; test dùng bộ nhớ).
  final SessionStore? sessions;

  /// Cho test chèn MockClient.
  final http.Client? httpClient;

  /// Điều hướng gốc – dùng khi phiên hết hạn để quay về trang chủ.
  static final navigatorKey = GlobalKey<NavigatorState>();

  DriverController _createDriver() {
    final fixture = DemoDriverRepository(
      status: switch (screen) {
        'profile-approved' => ApprovalStatus.approved,
        'driver-home' => ApprovalStatus.approved,
        'profile-pending' => ApprovalStatus.pending,
        'profile-rejected' => ApprovalStatus.rejected,
        _ => ApprovalStatus.draft,
      },
      completeDraft: screen == 'verification-vehicle',
    );
    final api =
        mockApi ??
        MockDriverApi(
          initial: screen == 'home' || screen == 'driver-onboarding'
              ? MockDriverApi.freshApplication()
              : fixture.loadCachedApplication(),
        );
    final repository = ApiDriverRepository(
      client: api.client,
      cached: api.cachedApplication,
    );
    return DriverController(
      loadApplication: GetDriverApplication(repository),
      submitApplication: SubmitDriverApplication(
        repository,
        requireUploadedDocuments: true,
      ),
      pickPhoto: PickDocumentPhoto(
        DemoPhotoRepository(DevicePhotoRepository()),
      ),
      profile: ManageDriverProfile(repository),
      simulator: repository,
      onDispose: repository.close,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>(
          create: (_) => ApiClient(
            sessions: sessions ?? MemorySessionStore(),
            client: httpClient,
          ),
          dispose: (api) => api.close(),
        ),
        RepositoryProvider<AuthApi>(create: (c) => AuthApi(c.read<ApiClient>())),
        RepositoryProvider<CustomerApi>(
          create: (c) => CustomerApi(c.read<ApiClient>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (c) {
              final api = c.read<ApiClient>();
              final auth = AuthCubit(api: c.read<AuthApi>(), sessions: api.sessions);
              api.onSessionExpired = auth.expire;
              return auth;
            },
          ),
          BlocProvider(
            create: (_) =>
                HomeController(const GetPublicFares(DemoFareRepository())),
          ),
          BlocProvider(create: (_) => driverController ?? _createDriver()),
        ],
        child: _app(context),
      ),
    );
  }

  Widget _app(BuildContext context) {
    return BlocListener<AuthCubit, Session?>(
      listenWhen: (prev, next) => prev != null && next == null,
      // Đăng xuất / phiên hết hạn → đóng các màn đang mở, về trang gốc
      listener: (_, _) =>
          navigatorKey.currentState?.popUntil((route) => route.isFirst),
      child: DriverTripScope(
        repository: tripRepository,
        cargoPhotos: cargoPhotos,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'ModMove',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => screen == 'driver-home'
                ? const DriverDashboard()
                : screen == 'pricing'
                ? const PricingScreen()
                : screen.startsWith('verification') ||
                      screen == 'driver-onboarding'
                ? VerificationScreen(
                    initialStep: screen == 'verification-vehicle' ? 1 : 0,
                    onDemo: () => Navigator.pushNamed(context, '/driver-demo'),
                    onSubmitted: () =>
                        Navigator.pushReplacementNamed(context, '/profile'),
                  )
                : screen.startsWith('profile')
                ? _profile(context)
                : _gate(context),
          ),
          onGenerateRoute: (settings) {
            if (settings.name == '/active-trip') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const ActiveTripScreen(),
              );
            }
            if (settings.name == '/job-details') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (context) => JobDetailsScreen(
                  onAccepted: () =>
                      Navigator.pushReplacementNamed(context, '/active-trip'),
                ),
              );
            }
            if (settings.name == '/driver-home') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const DriverDashboard(),
              );
            }
            if (settings.name == '/driver-demo') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const DriverDemoScreen(),
              );
            }
            if (settings.name == '/driver-history') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const DriverHistoryScreen(),
              );
            }
            if (settings.name == '/verification') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (context) => VerificationScreen(
                  initialStep: settings.arguments as int? ?? 0,
                  onDemo: () => Navigator.pushNamed(context, '/driver-demo'),
                  onSubmitted: () =>
                      Navigator.pushReplacementNamed(context, '/profile'),
                ),
              );
            }
            if (settings.name == '/profile') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: _profile,
              );
            }
            if (settings.name == '/home') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: _gate,
              );
            }
            if (settings.name == '/pricing') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => PricingScreen(
                  initialVehicle:
                      settings.arguments as VehicleOption? ??
                      VehicleOption.truck,
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  /// Khách đã đăng nhập → app khách; còn lại → trang chủ công khai.
  Widget _gate(BuildContext context) => BlocBuilder<AuthCubit, Session?>(
    builder: (context, session) =>
        session?.isCustomer == true ? const CustomerShell() : _home(context),
  );

  /// Đăng nhập; tài xế vào luồng hồ sơ/nhận đơn hiện có, khách tự vào app khách.
  Future<Session?> _login(BuildContext context) async {
    final session = await Navigator.push<Session>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (session != null && session.isDriver && context.mounted) {
      Navigator.pushNamed(context, '/profile');
    }
    return session;
  }

  Widget _home(BuildContext context) => HomeScreen(
    onRegister: () => Navigator.pushNamed(
      context,
      context.read<DriverController>().status == ApprovalStatus.draft
          ? '/verification'
          : '/profile',
    ),
    onAccount: () => _login(context),
    onDeliver: () => _login(context),
  );

  Widget _profile(BuildContext context) => DriverProfileScreen(
    onDemo: () => Navigator.pushNamed(context, '/driver-demo'),
    onHistory: () => Navigator.pushNamed(context, '/driver-history'),
    onHome: () => Navigator.pushNamedAndRemoveUntil(
      context,
      context.read<DriverController>().canGoOnline ? '/driver-home' : '/home',
      (_) => false,
    ),
    onUpdate: (step) =>
        Navigator.pushNamed(context, '/verification', arguments: step),
  );
}
