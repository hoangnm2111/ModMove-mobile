import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/session/session_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/customer/data/customer_api.dart';
import '../features/customer/presentation/customer_shell.dart';
import 'driver_trip_scope.dart';
import 'push_host.dart';
import 'realtime_host.dart';
import '../core/notifications/app_notice.dart';
import '../core/notifications/notice_catalog.dart';
import '../core/notifications/notification_cubit.dart';
import '../core/notifications/realtime_source.dart';
import '../core/widgets/notice_banner.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/customer/presentation/order_detail/order_detail_screen.dart';
import '../features/notifications/data/firebase_push_device.dart';
import '../features/notifications/data/remote_push_token_repository.dart';
import '../features/notifications/domain/push_repository.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/notifications/presentation/push_cubit.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/driver_trip/presentation/screens/driver_dashboard.dart';
import '../features/driver_trip/presentation/screens/job_details_screen.dart';
import '../features/driver_trip/presentation/screens/active_trip_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_widgets.dart';
import '../features/home/data/repositories/demo_fare_repository.dart';
import '../features/home/domain/usecases/get_public_fares.dart';
import '../features/home/presentation/controllers/home_controller.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/pricing_screen.dart';
import '../features/home/presentation/models/vehicle_option.dart';
import '../features/driver_account/driver_incidents_screen.dart';
import '../features/driver_account/driver_ratings_screen.dart';
import '../features/driver_account/driver_trips_screen.dart';
import '../features/driver_account/driver_wallet_screen.dart';
import '../features/driver_trip/data/driver_api.dart';
import '../features/onboarding/data/repositories/backend_driver_repository.dart';
import '../features/onboarding/data/repositories/demo_driver_repository.dart';
import '../features/onboarding/data/repositories/api_driver_repository.dart';
import '../features/onboarding/data/repositories/demo_photo_repository.dart';
import '../features/onboarding/data/services/mock_driver_api.dart';
import '../features/onboarding/data/repositories/device_photo_repository.dart';
import '../features/onboarding/domain/usecases/driver_usecases.dart';
import '../features/onboarding/domain/entities/driver_application.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/onboarding/presentation/screens/verification_screen.dart';
import '../features/onboarding/presentation/screens/driver_profile_screen.dart';
import '../features/onboarding/presentation/screens/driver_demo_screen.dart';
import '../features/onboarding/presentation/screens/driver_history_screen.dart';

class ModMoveApp extends StatelessWidget {
  const ModMoveApp({
    super.key,
    this.screen = const String.fromEnvironment('SCREEN', defaultValue: 'home'),
    this.driverController,
    this.mockApi,
    this.tripRepository,
    this.cargoPhotos,
    this.sessions,
    this.httpClient,
    this.pushDevice,
    this.realtimeSource,
  });
  final String screen;
  final DriverController? driverController;
  final MockDriverApi? mockApi;
  final DriverTripRepository? tripRepository;
  final CargoPhotoRepository? cargoPhotos;

  /// Phiên đăng nhập (main.dart mở từ file; test dùng bộ nhớ).
  final SessionStore? sessions;

  /// Cho test chèn MockClient.
  final http.Client? httpClient;

  /// Thiết bị thông báo đẩy; mặc định là Firebase (tự tắt khi thiếu cấu hình hoặc không phải Android).
  final PushDevice? pushDevice;

  /// Nguồn thông báo thời gian thực (SignalR); test chèn nguồn giả. Mặc định: SignalR thật (tắt khi chạy `flutter test`).
  final RealtimeSource? realtimeSource;

  /// Mã đơn của màn chi tiết đang mở (OrderDetailScreen đặt/xoá): chạm thông báo của đúng đơn đó thì không đẩy màn trùng.

  /// Điều hướng gốc – dùng khi phiên hết hạn để quay về trang chủ.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Chạy luồng tài xế trên BE thật. Các màn mẫu (`SCREEN=...`), `USE_MOCK_DRIVER=true`
  /// và các bản test tự chèn mock/controller thì giữ dữ liệu mô phỏng.
  bool get _useBackend =>
      !AppConfig.useMockDriver &&
      screen == 'home' &&
      mockApi == null &&
      driverController == null &&
      tripRepository == null;

  DriverController _createDriver(BuildContext context) {
    if (_useBackend) {
      final repository = BackendDriverRepository(
        api: DriverApi(context.read<ApiClient>()),
      );
      return DriverController(
        loadApplication: GetDriverApplication(repository),
        submitApplication: SubmitDriverApplication(
          repository,
          requireUploadedDocuments: true,
        ),
        pickPhoto: PickDocumentPhoto(
          DemoPhotoRepository(DevicePhotoRepository()),
        ),
        profile: ManageDriverProfile(repository),
      );
    }
    final fixture = DemoDriverRepository(
      status: switch (screen) {
        'profile-approved' => ApprovalStatus.approved,
        'driver-home' => ApprovalStatus.approved,
        'profile-pending' => ApprovalStatus.pending,
        'profile-rejected' => ApprovalStatus.rejected,
        _ => ApprovalStatus.draft,
      },
      completeDraft: screen == 'verification-vehicle',
    );
    final api =
        mockApi ??
        MockDriverApi(
          initial: screen == 'home' || screen == 'driver-onboarding'
              ? MockDriverApi.freshApplication()
              : fixture.loadCachedApplication(),
        );
    final repository = ApiDriverRepository(
      client: api.client,
      cached: api.cachedApplication,
    );
    return DriverController(
      loadApplication: GetDriverApplication(repository),
      submitApplication: SubmitDriverApplication(
        repository,
        requireUploadedDocuments: true,
      ),
      pickPhoto: PickDocumentPhoto(
        DemoPhotoRepository(DevicePhotoRepository()),
      ),
      profile: ManageDriverProfile(repository),
      simulator: repository,
      onDispose: repository.close,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>(
          create: (_) => ApiClient(
            sessions: sessions ?? MemorySessionStore(),
            client: httpClient,
          ),
          dispose: (api) => api.close(),
        ),
        RepositoryProvider<AuthApi>(
          create: (c) => AuthApi(c.read<ApiClient>()),
        ),
        RepositoryProvider<DriverApi>(
          create: (c) => DriverApi(c.read<ApiClient>()),
        ),
        RepositoryProvider<CustomerApi>(
          create: (c) => CustomerApi(c.read<ApiClient>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => NotificationCubit()),
          BlocProvider(
            create: (c) {
              final notices = c.read<NotificationCubit>();
              return PushCubit(
                pushDevice ?? FirebasePushDevice(),
                RemotePushTokenRepository(c.read<ApiClient>()),
                // App đang mở: hiện banner trong app thay cho thông báo hệ thống. SignalR gửi cùng nội dung,
                // NotificationCubit chống trùng theo (type, orderId) nên chỉ hiện một lần.
                onForeground: (message) {
                  if (!message.actionable) return false;
                  notices.push(
                    noticeFor(
                      message.type,
                      data: {
                        for (final e in message.data.entries)
                          e.key: '${e.value}',
                      },
                      title: message.title,
                      body: message.body,
                    ),
                  );
                  return true;
                },
              );
            },
          ),
          BlocProvider(
            create: (c) {
              final api = c.read<ApiClient>();
              final auth = AuthCubit(
                api: c.read<AuthApi>(),
                sessions: api.sessions,
                detachPush: c.read<PushCubit>().detach,
              );
              api.onSessionExpired = auth.expire;
              return auth;
            },
          ),
          BlocProvider(
            create: (_) =>
                HomeController(const GetPublicFares(DemoFareRepository())),
          ),
          BlocProvider(create: (c) => driverController ?? _createDriver(c)),
        ],
        child: RepositoryProvider<RealtimeSource>(
          create: (_) => realtimeSource ?? defaultRealtimeSource(AppConfig.apiBaseUrl),
          child: RepositoryProvider<RealtimeBridge>(
            create: (c) => RealtimeBridge(
              c.read<RealtimeSource>(),
              c.read<NotificationCubit>(),
              c.read<ApiClient>().sessions,
            ),
            child: RealtimeHost(child: _app(context)),
          ),
        ),
      ),
    );
  }

  Widget _app(BuildContext context) {
    return BlocListener<AuthCubit, Session?>(
      listenWhen: (prev, next) => prev != null && next == null,
      // Đăng xuất / phiên hết hạn → bỏ mọi màn đang mở và dựng lại trang chủ công khai.
      // Không dùng popUntil(isFirst): nhiều luồng tài xế đặt màn tài xế làm màn gốc
      // (pushNamedAndRemoveUntil('/driver-home', ...)), khi đó đăng xuất vẫn ở lại màn tài xế
      // và các API trả "phiên hết hạn". '/home' luôn đi qua _gate nên khách vãng lai thấy trang công khai.
      listener: (_, _) => navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home',
        (_) => false,
      ),
      child: DriverTripScope(
        useBackend: _useBackend,
        navigatorKey: navigatorKey,
        repository: tripRepository,
        cargoPhotos: cargoPhotos,
        child: PushHost(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'ModMove',
            debugShowCheckedModeBanner: false,
            builder: (context, child) => NoticeHost(
              onOpen: _openNotice,
              child: child ?? const SizedBox.shrink(),
            ),
            theme: buildAppTheme(),
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => screen == 'driver-home'
                  ? const DriverDashboard()
                  : screen == 'pricing'
                  ? const PricingScreen()
                  : screen.startsWith('verification') ||
                        screen == 'driver-onboarding'
                  ? VerificationScreen(
                      initialStep: screen == 'verification-vehicle' ? 1 : 0,
                      onDemo: () =>
                          Navigator.pushNamed(context, '/driver-demo'),
                      onSubmitted: () =>
                          Navigator.pushReplacementNamed(context, '/profile'),
                    )
                  : screen.startsWith('profile')
                  ? _profile(context)
                  : _gate(context),
            ),
            onGenerateRoute: (settings) {
              if (settings.name == '/active-trip') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const ActiveTripScreen(),
                );
              }
              if (settings.name == '/job-details') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (context) => JobDetailsScreen(
                    onAccepted: () =>
                        Navigator.pushReplacementNamed(context, '/active-trip'),
                  ),
                );
              }
              if (settings.name == '/driver-home') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverDashboard(),
                );
              }
              if (settings.name == '/inbox') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => NotificationsScreen(onOpen: _openNotice),
                );
              }
              if (settings.name == '/customer-order' &&
                  settings.arguments is int) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      OrderDetailScreen(orderId: settings.arguments! as int),
                );
              }
              if (settings.name == '/notifications') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const NotificationSettingsScreen(),
                );
              }
              if (settings.name == '/driver-incidents') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverIncidentsScreen(),
                );
              }
              if (settings.name == '/driver-incident' &&
                  settings.arguments is int) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => DriverIncidentDetailScreen(
                    id: settings.arguments! as int,
                  ),
                );
              }
              if (settings.name == '/driver-wallet') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverWalletScreen(),
                );
              }
              if (settings.name == '/driver-trips') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverTripsScreen(),
                );
              }
              if (settings.name == '/driver-ratings') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverRatingsScreen(),
                );
              }
              if (settings.name == '/driver-demo') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverDemoScreen(),
                );
              }
              if (settings.name == '/driver-history') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const DriverHistoryScreen(),
                );
              }
              if (settings.name == '/verification') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (context) => VerificationScreen(
                    initialStep: settings.arguments as int? ?? 0,
                    onDemo: () => Navigator.pushNamed(context, '/driver-demo'),
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
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: _gate,
                );
              }
              if (settings.name == '/pricing') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => PricingScreen(
                    initialVehicle:
                        settings.arguments as VehicleOption? ??
                        VehicleOption.truck,
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  /// Chạm banner hoặc một mục trong hộp thông báo: mở màn hình liên quan. Mã lạ hoặc thiếu `orderId` thì không làm gì.
  void _openNotice(AppNotice notice) {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) return;
    // ORDER_CANCELLED, ORDER_COMPLETED, INCIDENT_* tới cả khách và tài xế: tài xế không có màn chi tiết đơn
    // của khách (api/customer/* trả 403), nên mở màn của tài xế.
    if (context.read<AuthCubit>().state?.isDriver == true) {
      _openDriverNotice(navigator, context, notice);
      return;
    }
    switch (notice.target) {
      case NoticeTarget.order || NoticeTarget.refund:
        final id = notice.orderId;
        if (id == null) return;
        // Đang xem chi tiết của đúng đơn đó: màn tự tải lại khi có thông báo, không đẩy thêm màn trùng.
        if (openOrderId.value == id) return;
        navigator.pushNamed('/customer-order', arguments: id);
      case NoticeTarget.driverJob:
        navigator.pushNamedAndRemoveUntil('/driver-home', (_) => false);
      case NoticeTarget.driverTrip:
        navigator.pushNamed('/active-trip');
      case NoticeTarget.driverProfile:
        navigator.pushNamed('/profile');
      case NoticeTarget.none:
        break;
    }
  }

  void _openDriverNotice(
    NavigatorState navigator,
    BuildContext context,
    AppNotice notice,
  ) {
    final ongoing =
        context.read<DriverTripRepository>().current.trip?.ongoing ?? false;
    final incidentId = int.tryParse(notice.data['incidentId'] ?? '');
    switch (notice.type) {
      case 'NEW_MATCHING_ORDER':
        navigator.pushNamedAndRemoveUntil('/driver-home', (_) => false);
      case 'INCIDENT_REPORTED' || 'INCIDENT_IN_PROGRESS' || 'INCIDENT_DECIDED':
        if (incidentId == null) {
          navigator.pushNamed('/driver-incidents');
        } else {
          navigator.pushNamed('/driver-incident', arguments: incidentId);
        }
      case 'PICKUP_APPROVED' || 'PICKUP_REJECTED' || 'CASH_COLLECTED':
        navigator.pushNamed(ongoing ? '/active-trip' : '/driver-trips');
      case 'ORDER_CANCELLED' || 'ORDER_COMPLETED':
        navigator.pushNamed('/driver-trips');
      case 'RATING_RECEIVED':
        navigator.pushNamed('/driver-ratings');
      case 'WITHDRAWAL_DECIDED':
        navigator.pushNamed('/driver-wallet');
      case 'DRIVER_APPLICATION_APPROVED' ||
          'DRIVER_APPLICATION_REJECTED' ||
          'DRIVER_APPLICATION_SUBMITTED':
        navigator.pushNamed('/profile');
    }
  }

  /// Khách đã đăng nhập → app khách; tài xế đã đăng nhập → trang chủ tài xế (đã duyệt)
  /// hoặc hồ sơ tài xế; chưa đăng nhập → trang chủ công khai.
  /// (Trước đây tài xế rơi về trang công khai có nút "Đăng nhập" → trông như bị đăng xuất.)
  Widget _gate(BuildContext context) => BlocBuilder<AuthCubit, Session?>(
    builder: (context, session) {
      if (session?.isCustomer == true) return const CustomerShell();
      if (session?.isDriver == true && _useBackend) {
        return BlocBuilder<DriverController, DriverPresentationState>(
          builder: (context, _) =>
              context.read<DriverController>().canGoOnline
                  ? const DriverDashboard()
                  : _profile(context),
        );
      }
      return _home(context);
    },
  );

  /// Đăng nhập; tài xế vào luồng hồ sơ/nhận đơn hiện có, khách tự vào app khách.
  Future<Session?> _login(BuildContext context, {bool registerDriver = false}) async {
    final session = await Navigator.push<Session>(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(startAsDriver: registerDriver)),
    );
    if (session != null && session.isDriver && context.mounted) {
      Navigator.pushNamed(context, '/profile');
    }
    return session;
  }

  Widget _home(BuildContext context) => HomeScreen(
    onRegister: () async {
      // Nộp/xem hồ sơ cần tài khoản Driver trên BE: chưa đăng nhập thì đăng nhập trước.
      if (_useBackend && context.read<AuthCubit>().state?.isDriver != true) {
        await _login(context, registerDriver: context.read<AuthCubit>().state == null);
        return;
      }
      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        context.read<DriverController>().status == ApprovalStatus.draft
            ? '/verification'
            : '/profile',
      );
    },
    // Chế độ mô phỏng không có tài khoản BE: "Tài khoản" mở thẳng hồ sơ tài xế mô phỏng (như trước khi nối BE).
    onAccount: () => _useBackend
        ? _login(context)
        : Navigator.pushNamed(context, '/profile'),
    onDeliver: () => _login(context),
  );

  Widget _profile(BuildContext context) => DriverProfileScreen(
    onDemo: () => Navigator.pushNamed(context, '/driver-demo'),
    onHistory: () => Navigator.pushNamed(context, '/driver-history'),
    onWallet: _useBackend
        ? () => Navigator.pushNamed(context, '/driver-wallet')
        : null,
    onOrders: () {
      final trip = context.read<DriverTripRepository>().current.trip;
      if (trip?.ongoing ?? false) {
        Navigator.pushNamed(context, '/active-trip');
      } else if (context.read<DriverController>().canGoOnline) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/driver-home',
          (_) => false,
        );
      } else {
        showInfoSheet(
          context,
          'Chưa thể nhận đơn',
          'Hoàn thiện hồ sơ tài xế và chờ xét duyệt. Sau khi hồ sơ được duyệt '
              'và tài khoản hoạt động, bạn có thể vào trang chủ tài xế để nhận đơn.',
        );
      }
    },
    onHome: () => Navigator.pushNamedAndRemoveUntil(
      context,
      context.read<DriverController>().canGoOnline ? '/driver-home' : '/home',
      (_) => false,
    ),
    onUpdate: (step) =>
        Navigator.pushNamed(context, '/verification', arguments: step),
  );
}
