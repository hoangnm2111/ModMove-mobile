import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/config/platform_config.dart';
import 'package:modmove_mobile/core/config/platform_config_cubit.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/network/api_exception.dart';
import 'package:modmove_mobile/core/notifications/notice_catalog.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:modmove_mobile/features/customer/data/booking_draft_store.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/domain/order_rules.dart';
import 'package:modmove_mobile/features/customer/presentation/booking/booking_cubit.dart';
import 'package:modmove_mobile/features/customer/presentation/booking/booking_screen.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/driver_matching_policy.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/active_trip_bloc.dart';

import 'customer/fixtures.dart';

/// Phản hồi mẫu của GET /public/Config. Các số KHÔNG trùng giá trị từng bị gõ cứng trong app (200.000, 5 km, 24 giờ…).
Map<String, Object?> _config() => {
  'loadingFee': 250000.0,
  'requiredDeposit': 300000.0,
  'matchingRadiusKm': 7.0,
  'rules': {
    'maxCargoPhotos': 4,
    'maxPhotoSizeMb': 3,
    'maxOrderNoteLength': 300,
    'minPickupPhotos': 3,
    'maxPickupSubmissions': 4,
    'maxEvidencePhotos': 2,
    'matchingTimeoutMinutes': 15,
    'unpaidPaymentMinutes': 45,
    'payOsCodeMinutes': 12,
    'complaintWindowHours': 48,
    'ratingWindowHours': 36,
    'autoCompleteHours': 72,
    'arrivalRadiusMeters': 300,
    'passwordMinLength': 10,
    'passwordMaxLength': 30,
    'otpLifetimeMinutes': 3,
    'maxFailedLogins': 4,
    'loginLockMinutes': 20,
  },
};

http.Response _ok(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void main() {
  tearDown(AppRules.reset);

  group('số liệu thật từ BE', () {
    test('chưa nhận được số liệu: tiền và bán kính là chưa biết, giới hạn dùng số dự phòng', () {
      expect(AppRules.config, isNull);
      expect(DriverMatchingPolicy.searchRadiusMeters, 0); // bản đồ không vẽ vùng phủ thay vì vẽ số tự đoán
      expect(OrderRules.maxCargoPhotos, PlatformRules.fallback.maxCargoPhotos);
      expect(ActiveTripState.arrivalRadiusM, 500);
    });

    test('đọc phản hồi của BE', () {
      final c = PlatformConfig.fromJson(_config());
      expect((c.loadingFee, c.requiredDeposit, c.matchingRadiusKm), (250000, 300000, 7));
      expect((c.rules.maxCargoPhotos, c.rules.complaintWindowHours, c.rules.arrivalRadiusMeters), (4, 48, 300));
    });

    test('thiếu trường quy tắc (BE cũ) thì dùng số dự phòng cho trường đó, không lỗi', () {
      final c = PlatformConfig.fromJson({
        'loadingFee': 1,
        'requiredDeposit': 2,
        'matchingRadiusKm': 3,
        'rules': {'maxCargoPhotos': 9},
      });
      expect((c.rules.maxCargoPhotos, c.rules.maxPhotoSizeMb), (9, PlatformRules.fallback.maxPhotoSizeMb));
    });

    test('mọi luật phía khách, tài xế đổi theo số của BE', () {
      AppRules.apply(PlatformConfig.fromJson(_config()));

      expect(OrderRules.maxCargoPhotos, 4);
      expect(OrderRules.maxEvidencePhotos, 2);
      expect(OrderRules.maxPhotoBytes, 3 * 1024 * 1024);
      expect(OrderRules.maxNote, 300);
      expect(OrderRules.complaintWindow, const Duration(hours: 48));
      expect(OrderRules.ratingWindow, const Duration(hours: 36));
      expect(OrderRules.autoCompleteAfter, const Duration(hours: 72));
      expect(OrderRules.unpaidCancelAfter, const Duration(minutes: 45));
      expect(InputRules.password('a' * 9), isFalse);
      expect(InputRules.password('a' * 10), isTrue);
      expect(InputRules.passwordHint, 'từ 10 đến 30 ký tự');
      expect(JobOffer.matchingWindow, const Duration(minutes: 15));
      expect(DriverMatchingPolicy.searchRadiusMeters, 7000);
      expect(ActiveTripState.arrivalRadiusM, 300);
    });

    test('câu báo lỗi có số lấy từ BE', () {
      AppRules.apply(PlatformConfig.fromJson(_config()));

      expect(knownErrorMessage('COMPLAINT_WINDOW_CLOSED'), contains('48 giờ'));
      expect(knownErrorMessage('RATING_WINDOW_CLOSED'), contains('36 giờ'));
      expect(knownErrorMessage('FILE_TOO_LARGE'), contains('3 MB'));
      expect(knownErrorMessage('TOO_MANY_PHOTOS'), contains('2 ảnh'));
      expect(knownErrorMessage('COLLECT_CASH_WRONG_LOCATION'), contains('300 m'));
      expect(knownErrorMessage('ORDER_CANCELLED'), errorMessages['ORDER_CANCELLED']); // câu không có số vẫn tra bảng
      expect(knownErrorMessage('MA_LA'), isNull);
    });

    test('thông báo "đơn đã giao" nêu đúng hạn khiếu nại của BE', () {
      expect(
        noticeFor('ORDER_DELIVERED', data: {'orderCode': 'MM1'}).body,
        contains('24 giờ'),
      ); // dự phòng khi chưa có số thật
      AppRules.apply(PlatformConfig.fromJson(_config()));

      expect(noticeFor('ORDER_DELIVERED', data: {'orderCode': 'MM1'}).body, contains('48 giờ'));
    });
  });

  group('PlatformConfigCubit', () {
    test('tải thành công thì cập nhật AppRules và trạng thái', () async {
      final cubit = PlatformConfigCubit(() async => PlatformConfig.fromJson(_config()));
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state?.loadingFee, 250000);
      expect(AppRules.config?.requiredDeposit, 300000);
    });

    test('lỗi mạng thì giữ null (không hiện số tự đoán) và thử lại được', () async {
      var calls = 0;
      final cubit = PlatformConfigCubit(() async {
        calls++;
        if (calls == 1) throw const ApiException('mất mạng');
        return PlatformConfig.fromJson(_config());
      });
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state, isNull);

      await cubit.ensureLoaded();
      expect(cubit.state?.loadingFee, 250000);
      await cubit.ensureLoaded(); // đã có thì không gọi lại
      expect(calls, 2);
    });
  });

  group('màn đặt xe: phí bốc xếp', () {
    const draft = BookingDraft(
      pickupAddress: '12 Nguyễn Huệ, Hà Nội',
      dropoffAddress: '45 Cầu Giấy, Hà Nội',
      cargoType: 'GOODS',
      weightKg: 10,
      lengthCm: 10,
      widthCm: 10,
      heightCm: 10,
    );

    Widget app(PlatformConfigCubit config) {
      final api = ApiClient(
        sessions: MemorySessionStore(null),
        baseUrl: 'http://api',
        client: MockClient((req) async {
          final p = req.url.path;
          if (p.endsWith('/public/VehicleTypes')) return _ok([]);
          if (p.endsWith('/public/Lookups/cargo-types')) {
            return _ok([
              {'code': 'GOODS', 'name': 'Hàng hoá', 'description': null},
            ]);
          }
          if (p.endsWith('/public/Config')) return _ok(_config());
          return _ok(paged([]));
        }),
      );
      return BlocProvider.value(
        value: config,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: api),
            RepositoryProvider(create: (_) => CustomerApi(api)),
            RepositoryProvider<BookingDraftStore>.value(value: MemoryBookingDraftStore()),
          ],
          child: BlocProvider(
            create: (_) => AuthCubit(api: AuthApi(api), sessions: api.sessions),
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const BookingScreen(initial: draft),
            ),
          ),
        ),
      );
    }

    Future<void> toPayment(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      tester.element(find.byType(Scaffold).first).read<BookingCubit>().goTo(3);
      await tester.pumpAndSettle();
    }

    testWidgets('có số thật của BE thì hiện phí bốc xếp', (tester) async {
      final known = PlatformConfigCubit(() async => PlatformConfig.fromJson(_config()));
      addTearDown(known.close);
      await known.load();

      await tester.pumpWidget(app(known));
      await toPayment(tester);

      expect(find.textContaining('Phí 250.000'), findsOneWidget);
    });

    testWidgets('chưa có số thật (mất mạng) thì không hiện số tiền nào', (tester) async {
      final unknown = PlatformConfigCubit(() async => throw const ApiException('mất mạng'));
      addTearDown(unknown.close);

      await tester.pumpWidget(app(unknown));
      await toPayment(tester);

      expect(find.textContaining('Phí '), findsNothing);
      expect(find.text('Khuân vác tại điểm lấy và điểm giao.'), findsOneWidget);
    });
  });
}
