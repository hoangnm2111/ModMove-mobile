import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'features/onboarding/data/services/mock_driver_api.dart';
import 'features/onboarding/data/services/profile_mock_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  const screen = String.fromEnvironment('SCREEN', defaultValue: 'home');
  // Reference fixtures remain isolated; the ordinary app restores its mock data.
  if (screen != 'home' && screen != 'driver-onboarding') {
    runApp(const ModMoveApp());
    return;
  }
  try {
    final directory = await getApplicationSupportDirectory();
    final store = FileProfileMockStore(
      File('${directory.path}/driver-profile-mock-v1.json'),
    );
    final api = MockDriverApi(store: store, restored: await store.read());
    runApp(ModMoveApp(mockApi: api));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chưa mở được dữ liệu mô phỏng đã lưu. Dữ liệu cũ được giữ nguyên.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: main, child: const Text('Thử lại')),
                  TextButton(
                    onPressed: () => runApp(const ModMoveApp()),
                    child: const Text('Mở phiên tạm, không lưu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
