import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A callback only requests opening the authenticated wallet. Neither the path
/// nor query parameters are evidence that money was received.
class PaymentReturnCubit extends Cubit<bool> {
  PaymentReturnCubit({
    this.channel = const MethodChannel('vn.modmove/payment_return'),
  }) : super(false);
  final MethodChannel channel;

  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'paymentReturn') _receive(call.arguments);
    });
    try {
      _receive(await channel.invokeMethod<String>('initialReturn'));
    } on MissingPluginException {
      // Unsupported platforms have no Android payment-return bridge.
    } on PlatformException {
      // Wallet refresh and manual return remain available.
    }
  }

  void _receive(Object? value) {
    if (isClosed || value is! String) return;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == 'modmove' &&
        uri.host == 'orders' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        ['/success', '/cancel'].contains(uri.path)) {
      emit(true);
    }
  }

  void consume() {
    if (!isClosed) emit(false);
  }

  @override
  Future<void> close() {
    channel.setMethodCallHandler(null);
    return super.close();
  }
}
