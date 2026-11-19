import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:modmove_mobile/features/wallet/domain/driver_wallet_repository.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/wallet/data/remote_wallet_repository.dart';
import 'package:modmove_mobile/features/wallet/presentation/wallet_cubit.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'top-up accepts 1 VND when funded, and requires the full current deposit deficit',
    () async {
      var deposit = 200000;
      final amounts = <int>[];
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.url.path == '/api/driver/wallet') {
            return jsonResponse(walletFixture(deposit: deposit));
          }
          final amount = (jsonDecode(r.body) as Map)['amount'] as int;
          amounts.add(amount);
          return jsonResponse({
            'transactionId': 1,
            'amount': amount,
            'checkoutUrl': 'https://pay.payos.vn/test',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'qrCode': 'test',
          });
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final c = WalletCubit(RemoteWalletRepository(api));
      addTearDown(c.close);
      await c.topUp(1);
      expect(c.state.payment?.amount, 1);
      deposit = -10000;
      await c.topUp(200000);
      expect(c.state.payment, isNull);
      expect(c.state.error, contains('210000'));
      expect(amounts, [1]);
      await c.topUp(210000);
      expect(amounts, [1, 210000]);
      expect(
        c.state.balance!.deposit,
        -10000,
      ); // A QR never credits the wallet.
    },
  );
  test(
    'PayOS service error keeps its support reference and removes the older QR',
    () async {
      var unavailable = false;
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((request) async {
          if (request.url.path == '/api/driver/wallet') {
            return jsonResponse(walletFixture());
          }
          expect(request.url.path, '/api/driver/wallet/topup');
          if (unavailable) {
            return jsonResponse({
              'code': 'SERVER_ERROR',
              'detail': 'An unexpected error occurred.',
              'traceId': '0HND123:00000001',
            }, 500);
          }
          return jsonResponse({
            'transactionId': 8,
            'amount': 100000,
            'checkoutUrl': 'https://pay.payos.vn/previous',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'qrCode': 'previous-qr',
          });
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final cubit = WalletCubit(RemoteWalletRepository(api));
      addTearDown(cubit.close);
      await cubit.topUp(100000);
      expect(cubit.state.payment, isNotNull);
      unavailable = true;
      await cubit.topUp(200000);
      expect(cubit.state.payment, isNull);
      expect(cubit.state.paymentConfirmed, false);
      expect(
        cubit.state.error,
        contains('Dịch vụ nạp tiền hiện không khả dụng'),
      );
      expect(cubit.state.errorReference, '0HND123:00000001');
    },
  );

  test(
    'PayOS validation failure is not mislabeled as a service outage',
    () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient(
          (_) async => jsonResponse({'code': 'VALIDATION'}, 400),
        ),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      await expectLater(
        RemoteWalletRepository(api).topUp(100000),
        throwsA(
          isA<WalletFailure>().having(
            (e) => e.message,
            'message',
            contains('Thông tin chưa hợp lệ'),
          ),
        ),
      );
    },
  );

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
          if (r.url.path.endsWith('/transactions') ||
              r.url.path.endsWith('/withdrawals')) {
            return jsonResponse(pageFixture([]));
          }
          return jsonResponse(walletFixture(deposit: deposit));
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final cubit = WalletCubit(RemoteWalletRepository(api));
      addTearDown(cubit.close);
      await cubit.refresh();
      await cubit.topUp(0);
      expect(posts, 0);
      expect(cubit.state.error, contains('lớn hơn 0'));
      await cubit.topUp(50000);
      expect(cubit.state.balance!.deposit, 250000);
      deposit = 300000;
      await cubit.refresh();
      expect(cubit.state.balance!.deposit, 300000);
      expect(posts, 1);
    },
  );
  test(
    'withdrawal rechecks debt and pending request, never duplicates a lost POST',
    () async {
      var pending = false, posts = 0, deposit = -20000, earnings = 120000;
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.url.path == '/api/driver/wallet') {
            return jsonResponse(
              walletFixture(
                deposit: deposit,
                earnings: earnings,
                pending: pending,
              ),
            );
          }
          if (r.method == 'POST') {
            posts++;
            expect(r.url.path, '/api/driver/wallet/withdrawals');
            expect(jsonDecode(r.body), {'amount': 10000});
            pending = true;
            deposit = 0;
            earnings = 90000;
            throw http.ClientException('lost response after server committed');
          }
          return jsonResponse(pageFixture([]));
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final cubit = WalletCubit(RemoteWalletRepository(api));
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state.balance!.withdrawable, 100000);
      await cubit.withdraw(110000);
      expect(posts, 0);
      await cubit.withdraw(10000);
      expect(posts, 1);
      expect(cubit.state.balance!.pendingWithdrawal, true);
      expect(cubit.state.balance!.earnings, 90000);
      await cubit.withdraw(10000);
      expect(posts, 1);
      expect(cubit.state.error, contains('chờ xử lý'));
    },
  );
  test(
    'withdrawal has no invented minimum; bank account uses validated backend fields',
    () async {
      final calls = <http.Request>[];
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          calls.add(r);
          if (r.method == 'PUT') return http.Response('', 204);
          return jsonResponse({
            'transactionId': 99,
            'amount': 1,
            'debtDeducted': 0,
          }, 201);
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final repo = RemoteWalletRepository(api);
      final receipt = await repo.withdraw(1);
      expect(receipt.amount, 1);
      await repo.saveBank(
        const DriverBankAccount(' Vietcombank ', '123456789', ' TAI XE TEST '),
      );
      expect(calls.last.url.path, '/api/driver/wallet/bank-account');
      expect(jsonDecode(calls.last.body), {
        'bankName': 'Vietcombank',
        'bankAccountNumber': '123456789',
        'bankAccountHolder': 'TAI XE TEST',
      });
      await expectLater(
        repo.saveBank(const DriverBankAccount('Bank', '123', 'Name')),
        throwsA(isA<WalletFailure>()),
      );
      expect(calls.length, 2);
    },
  );
  test(
    'PayOS success is recognized only for the matching confirmed transaction',
    () async {
      var completed = false;
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            return jsonResponse({
              'transactionId': 7,
              'amount': 50000,
              'checkoutUrl': 'https://pay.payos.vn/example',
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .toIso8601String(),
              'qrCode': 'actual-payload',
            });
          }
          if (r.url.path.endsWith('/transactions')) {
            return jsonResponse(
              pageFixture([
                {
                  'id': 7,
                  'transactionType': 'TopUpDeposit',
                  'amount': 50000,
                  'balanceAfter': 300000,
                  'transactionStatus': completed ? 'Completed' : 'Pending',
                  'createdAt': '2026-11-10T02:00:00Z',
                },
              ]),
            );
          }
          if (r.url.path.endsWith('/withdrawals')) {
            return jsonResponse(pageFixture([]));
          }
          return jsonResponse(walletFixture());
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final cubit = WalletCubit(RemoteWalletRepository(api));
      addTearDown(cubit.close);
      await cubit.refresh();
      await cubit.topUp(50000);
      await cubit.refresh();
      expect(cubit.state.payment!.qrCode, 'actual-payload');
      expect(cubit.state.paymentConfirmed, false);
      completed = true;
      await cubit.refresh();
      expect(cubit.state.paymentConfirmed, true);
    },
  );
}
