import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'driver_trip_scope.dart';
import '../features/incidents/domain/driver_incident_repository.dart';
import '../features/incidents/presentation/incident_list_screen.dart';
import '../features/incidents/presentation/incident_detail_screen.dart';
import '../features/incidents/presentation/incident_report_screen.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/driver_trip/presentation/screens/driver_dashboard.dart';
import '../features/driver_trip/presentation/screens/job_details_screen.dart';
import '../features/driver_trip/presentation/screens/active_trip_screen.dart';
import '../features/driver_trip/presentation/screens/trip_history_screen.dart';
import '../features/driver_trip/presentation/screens/trip_earnings_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_widgets.dart';
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
    this.onLogout,
    this.walletBuilder,
    this.revenueBuilder,
    this.incidentRepository,
  });
  final String screen;
  final DriverController? driverController;
  final MockDriverApi? mockApi;
  final DriverTripRepository? tripRepository;
  final CargoPhotoRepository? cargoPhotos;
  final VoidCallback? onLogout;
  final WidgetBuilder? walletBuilder;
  final WidgetBuilder? revenueBuilder;
  final DriverIncidentRepository? incidentRepository;

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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              HomeController(const GetPublicFares(DemoFareRepository())),
        ),
        BlocProvider(create: (_) => driverController ?? _createDriver()),
      ],
      child: DriverTripScope(
        repository: tripRepository,
        cargoPhotos: cargoPhotos,
        incidents: incidentRepository,
        child: MaterialApp(
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
                : _home(context),
          ),
          onGenerateRoute: (settings) {
            if (incidentRepository != null) {
              final incidentPage = switch (settings.name) {
                '/incidents' => IncidentListScreen(
                  orderId: settings.arguments as String?,
                ),
                '/incident-detail' => IncidentDetailScreen(
                  id: settings.arguments as String,
                ),
                '/incident-report' => IncidentReportScreen(
                  orderId: settings.arguments as String,
                ),
                _ => null,
              };
              if (incidentPage != null) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => incidentPage,
                );
              }
            }
            if (settings.name == '/revenue' && revenueBuilder != null) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: revenueBuilder!,
              );
            }
            if (settings.name == '/trips') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const TripHistoryScreen(),
              );
            }
            if (settings.name == '/trip-earnings') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    TripEarningsScreen(id: settings.arguments as String),
              );
            }
            if (settings.name == '/wallet' && walletBuilder != null) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: walletBuilder!,
              );
            }
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
                builder: _home,
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

  Widget _home(BuildContext context) => context.read<DriverController>().remote
      ? _profile(context)
      : HomeScreen(
          onRegister: () => Navigator.pushNamed(
            context,
            context.read<DriverController>().status == ApprovalStatus.draft
                ? '/verification'
                : '/profile',
          ),
          onAccount: () => Navigator.pushNamed(context, '/profile'),
        );

  Widget _profile(BuildContext context) => DriverProfileScreen(
    onIncidents: incidentRepository == null
        ? null
        : () => Navigator.pushNamed(context, '/incidents'),
    onLogout: onLogout,
    onWallet: walletBuilder == null
        ? null
        : () => Navigator.pushNamed(context, '/wallet'),
    onDemo: () => Navigator.pushNamed(context, '/driver-demo'),
    onHistory: () => Navigator.pushNamed(context, '/driver-history'),
    onOrders: () {
      if (context.read<DriverController>().remote &&
          context.read<DriverController>().canGoOnline) {
        Navigator.pushNamed(context, '/trips');
        return;
      }
      final trip = context.read<DriverTripRepository>().current.trip;
      if (trip?.ongoing ?? false) {
        Navigator.pushNamed(context, '/active-trip');
      } else if (context.read<DriverController>().canGoOnline) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/driver-home',
          (_) => false,
        );
      } else {
        showInfoSheet(
          context,
          'Chưa thể nhận đơn',
          'Hoàn thiện hồ sơ tài xế và chờ xét duyệt. Sau khi hồ sơ được duyệt '
              'và tài khoản hoạt động, bạn có thể vào trang chủ tài xế để nhận đơn.',
        );
      }
    },
    onHome: () => Navigator.pushNamedAndRemoveUntil(
      context,
      context.read<DriverController>().canGoOnline ? '/driver-home' : '/home',
      (_) => false,
    ),
    onUpdate: (step) =>
        Navigator.pushNamed(context, '/verification', arguments: step),
  );
}
