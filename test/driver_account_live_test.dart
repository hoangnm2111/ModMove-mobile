// Kiểm tra trực tiếp ví / chuyến / đánh giá với BE đang chạy (chỉ đọc). Mặc định bị bỏ qua:
//   flutter test --dart-define=LIVE_API=http://localhost:5133/api test/driver_account_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/driver_account/driver_account_models.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_api.dart';

const _live = String.fromEnvironment('LIVE_API');

Future<DriverApi> _login(String email) async {
  final sessions = MemorySessionStore();
  final api = ApiClient(sessions: sessions, baseUrl: _live);
  await sessions.save(await AuthApi(api).login(email, 'ModMove@123'));
  return DriverApi(api);
}

void main() {
  setUpAll(() => HttpOverrides.global = null);

  test('ví, giao dịch, rút tiền, thu nhập của driver2 parse đúng', () async {
    final api = await _login('driver2@modmove.local');
    final wallet = DriverWallet.fromJson(await api.wallet());
    final tx = PageOf.fromJson(await api.walletTransactions(), WalletTx.fromJson);
    final earnings = EarningsSummary.fromJson(await api.earnings('Month'));
    // ignore: avoid_print
    print('WALLET ${wallet.status} deposit=${wallet.deposit} bank=${wallet.bank?.bankName} cod=${wallet.canReceiveOrders} '
        'tx=${tx.items.map((t) => '${t.label}:${t.amount}').join(',')} month=${earnings.completedTrips}/${earnings.net}');
    expect(wallet.deposit, greaterThan(0));
    expect(tx.items, isNotEmpty);
  }, skip: _live.isEmpty ? 'cần --dart-define=LIVE_API' : false);

  test('chuyến + đánh giá của driver1 parse đúng', () async {
    final api = await _login('driver@modmove.local');
    final trips = PageOf.fromJson(await api.trips(view: 'History'), DriverTripSummary.fromJson);
    final ratings = RatingsSummary.fromJson(await api.ratings());
    // ignore: avoid_print
    print('TRIPS ${trips.items.map((t) => '${t.code}:${t.statusLabel}:${t.earning}').join(', ')} hasNext=${trips.hasNext} '
        'RATINGS avg=${ratings.average} total=${ratings.total} dist=${ratings.distribution}');
    expect(trips.items, isNotEmpty);
    expect(ratings.total, greaterThan(0));
  }, skip: _live.isEmpty ? 'cần --dart-define=LIVE_API' : false);
}
