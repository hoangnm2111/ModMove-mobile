import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../features/home/data/repositories/demo_fare_repository.dart';
import '../features/home/domain/usecases/get_public_fares.dart';
import '../features/home/presentation/controllers/home_controller.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/pricing_screen.dart';
import '../features/home/presentation/models/vehicle_option.dart';
import '../features/onboarding/data/repositories/demo_driver_repository.dart';
import '../features/onboarding/data/repositories/device_photo_repository.dart';
import '../features/onboarding/domain/usecases/driver_usecases.dart';
import '../features/onboarding/domain/entities/driver_application.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/onboarding/presentation/screens/verification_screen.dart';
import '../features/onboarding/presentation/screens/driver_profile_screen.dart';

class ModMoveApp extends StatelessWidget {
  const ModMoveApp({
    super.key,
    this.screen = const String.fromEnvironment('SCREEN', defaultValue: 'home'),
    this.driverController,
  });
  final String screen;
  final DriverController? driverController;

  DriverController _createDriver() {
    final repository = DemoDriverRepository(
      status: switch (screen) {
        'profile-approved' => ApprovalStatus.approved,
        'profile-pending' => ApprovalStatus.pending,
        'profile-rejected' => ApprovalStatus.rejected,
        _ => ApprovalStatus.draft,
      },
      completeDraft: screen == 'verification-vehicle',
    );
    return DriverController(
      loadApplication: GetDriverApplication(repository),
      submitApplication: SubmitDriverApplication(repository),
      pickPhoto: PickDocumentPhoto(DevicePhotoRepository()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              HomeController(const GetPublicFares(DemoFareRepository())),
        ),
        ChangeNotifierProvider(
          create: (_) => driverController ?? _createDriver(),
        ),
      ],
      child: MaterialApp(
        title: 'ModMove',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => screen == 'pricing'
              ? const PricingScreen()
              : screen.startsWith('verification')
              ? VerificationScreen(
                  initialStep: screen == 'verification-vehicle' ? 1 : 0,
                  onSubmitted: () =>
                      Navigator.pushReplacementNamed(context, '/profile'),
                )
              : screen.startsWith('profile')
              ? _profile(context)
              : _home(context),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/verification') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => VerificationScreen(
                initialStep: settings.arguments as int? ?? 0,
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
            return MaterialPageRoute<void>(settings: settings, builder: _home);
          }
          if (settings.name == '/pricing') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => PricingScreen(
                initialVehicle:
                    settings.arguments as VehicleOption? ?? VehicleOption.truck,
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _home(BuildContext context) => HomeScreen(
    onRegister: () => Navigator.pushNamed(
      context,
      context.read<DriverController>().status == ApprovalStatus.draft
          ? '/verification'
          : '/profile',
    ),
    onAccount: () => Navigator.pushNamed(context, '/profile'),
  );

  Widget _profile(BuildContext context) => DriverProfileScreen(
    onHome: () =>
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
    onUpdate: (step) =>
        Navigator.pushNamed(context, '/verification', arguments: step),
  );
}
