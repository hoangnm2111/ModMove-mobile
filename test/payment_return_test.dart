import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/payment_return_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vn.modmove/payment_return');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Future<void> send(Object? value) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('paymentReturn', value),
      ),
      (_) {},
    );
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'cold payment return remains pending until authenticated navigation consumes it',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => 'modmove://orders/success?status=PAID&amount=999999',
      );
      final cubit = PaymentReturnCubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state, true);
      cubit.consume();
      expect(cubit.state, false);
    },
  );
  test(
    'warm success and cancellation only request wallet refresh/navigation',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final cubit = PaymentReturnCubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      for (final path in ['success', 'cancel']) {
        await send('modmove://orders/$path?status=PAID&orderCode=42');
        expect(cubit.state, true);
        cubit.consume();
        expect(cubit.state, false);
      }
    },
  );
  test('unknown and malformed return URLs cannot request navigation', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final cubit = PaymentReturnCubit();
    addTearDown(cubit.close);
    await cubit.initialize();
    for (final value in <Object?>[
      null,
      123,
      'not a uri',
      'https://orders/success',
      'modmove://attacker/success',
      'modmove://orders/withdraw',
      'modmove://user@orders/success',
      'modmove://orders:443/success',
    ]) {
      await send(value);
      expect(cubit.state, false);
    }
  });
  test('missing native bridge does not prevent ordinary app startup', () async {
    final cubit = PaymentReturnCubit();
    addTearDown(cubit.close);
    await cubit.initialize();
    expect(cubit.state, false);
  });
}
