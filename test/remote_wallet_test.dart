import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/wallet/data/remote_wallet_repository.dart';
import 'package:modmove_mobile/features/wallet/presentation/wallet_cubit.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'creating a top-up never credits the balance; only subsequent server read changes it',
    () async {
      var deposit = 250000, posts = 0;
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            expect(jsonDecode(r.body), {'amount': 50000, 'platform': 'App'});
            return jsonResponse({
              'transactionId': 1,
              'amount': 50000,
              'checkoutUrl': 'https://pay.payos.vn/example',
              'expiresAt': '2026-11-08T20:00:00Z',
              'qrCode': 'example',
            });
          }
          return jsonResponse({...driverStatus(), 'depositBalance': deposit});
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final cubit = WalletCubit(RemoteWalletRepository(api));
      addTearDown(cubit.close);
      await cubit.refresh();
      await cubit.topUp(49000);
      expect(posts, 0);
      expect(cubit.state.error, contains('50.000'));
      await cubit.topUp(50000);
      expect(cubit.state.balance!.deposit, 250000);
      deposit = 300000;
      await cubit.refresh();
      expect(cubit.state.balance!.deposit, 300000);
      expect(posts, 1);
    },
  );
}
