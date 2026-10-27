import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_widgets.dart';
import '../features/home/data/repositories/demo_fare_repository.dart';
import '../features/home/domain/usecases/get_public_fares.dart';
import '../features/home/presentation/controllers/home_controller.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/pricing_screen.dart';
import '../features/home/presentation/models/vehicle_option.dart';

class ModMoveApp extends StatelessWidget {
  const ModMoveApp({
    super.key,
    this.screen = const String.fromEnvironment('SCREEN', defaultValue: 'home'),
  });
  final String screen;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeController(const GetPublicFares(DemoFareRepository())),
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
              : HomeScreen(
                  onRegister: () => showInfoSheet(
                    context,
                    'Đăng ký tài xế',
                    'Chuẩn bị CCCD, giấy phép lái xe, đăng ký xe, đăng kiểm và ảnh phương tiện.',
                  ),
                  onAccount: () => showInfoSheet(
                    context,
                    'Tài khoản ModMove',
                    'Theo dõi hồ sơ tài xế và thông tin phương tiện của bạn.',
                  ),
                ),
        ),
        onGenerateRoute: (settings) {
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
}
