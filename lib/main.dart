import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/app_theme.dart';
import 'design/app_widgets.dart';
import 'features/home/home_screen.dart';
import 'features/home/pricing_screen.dart';
import 'features/home/vehicle_option.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ModMoveApp());
}

class ModMoveApp extends StatelessWidget {
  const ModMoveApp({
    super.key,
    this.screen = const String.fromEnvironment('SCREEN', defaultValue: 'home'),
  });
  final String screen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
