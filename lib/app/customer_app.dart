import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/network/api_client.dart';
import '../core/theme/customer_theme.dart';
import '../features/customer/domain/customer_models.dart';
import '../features/customer/domain/customer_repository.dart';
import '../features/customer/domain/customer_places.dart';
import '../features/customer/data/remote_customer_repository.dart';
import '../features/customer/data/customer_realtime.dart';
import '../features/customer/data/mapvina_customer_places.dart';
import '../features/customer/presentation/customer_cubits.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/customer/presentation/customer_booking_screen.dart';
import '../features/customer/presentation/customer_order_screen.dart';
import '../features/customer/presentation/customer_support_screen.dart';
import '../features/customer/presentation/customer_refund_screen.dart';
import '../features/customer/presentation/customer_rating_screen.dart';
import '../features/notifications/presentation/push_cubit.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import 'payment_return_cubit.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key, required this.api, this.guest = false});
  final ApiClient api;
  final bool guest;
  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  final navigator = GlobalKey<NavigatorState>();
  late final CustomerRepository repo = RemoteCustomerRepository(widget.api);
  int? paymentOrder;
  bool opening = false;
  void handlePending() {
    if (widget.guest || opening) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || navigator.currentState == null || opening) return;
      opening = true;
      final returns = context.read<PaymentReturnCubit>();
      final push = context.read<PushCubit>();
      if (returns.state) {
        returns.consume();
        if (paymentOrder != null) {
          navigator.currentState!.pushNamedAndRemoveUntil(
            '/order',
            (r) => r.isFirst,
            arguments: paymentOrder,
          );
        } else {
          navigator.currentState!.pushNamedAndRemoveUntil(
            '/orders',
            (r) => r.isFirst,
          );
        }
      }
      final notification = push.state.pending;
      if (notification != null) {
        push.consume();
        final refund = int.tryParse(notification.refundId ?? '');
        final order = int.tryParse(notification.orderId ?? '');
        final route = notification.customerRoute;
        if (route != null) {
          navigator.currentState!.pushNamedAndRemoveUntil(
            route,
            (r) => r.isFirst,
            arguments: route == '/refund' ? refund : order,
          );
        }
      }
      opening = false;
    });
  }

  @override
  void initState() {
    super.initState();
    handlePending();
  }

  Route<void> route(RouteSettings settings) {
    Widget screen;
    final id = settings.arguments is int ? settings.arguments as int : null;
    switch (settings.name) {
      case '/':
        screen = CustomerHomeScreen(guest: widget.guest);
      case '/orders':
        screen = Scaffold(
          appBar: AppBar(title: const Text('Đơn hàng')),
          body: const CustomerOrdersScreen(),
        );
      case '/booking':
        screen = BlocProvider(
          create: (_) => BookingCubit(
            repo,
            initial: settings.arguments is BookingDraft
                ? settings.arguments as BookingDraft
                : null,
          )..initialize(),
          child: CustomerBookingScreen(
            onCreated: (id) {
              paymentOrder = id;
              navigator.currentState!.pushReplacementNamed(
                '/order',
                arguments: id,
              );
            },
          ),
        );
      case '/order' when id != null && id > 0:
        paymentOrder = id;
        screen = BlocProvider(
          create: (_) =>
              CustomerOrderCubit(repo, id, SignalRCustomerRealtime(widget.api))
                ..initialize(),
          child: const CustomerOrderScreen(),
        );
      case '/report' when id != null && id > 0:
        screen = CustomerSupportForm(
          kind: CustomerSupportKind.incident,
          orderId: id,
        );
      case '/complaint' when settings.arguments is OrderDetail:
        screen = CustomerSupportForm(
          kind: CustomerSupportKind.complaint,
          orderId: (settings.arguments as OrderDetail).summary.id,
        );
      case '/incident-refund' when settings.arguments is Incident:
        final incident = settings.arguments as Incident;
        screen = CustomerSupportForm(
          kind: CustomerSupportKind.refund,
          orderId: incident.orderId,
          incidentId: incident.id,
        );
      case '/incidents':
        screen = CustomerSupportList(refunds: false, orderId: id);
      case '/refunds':
        screen = const CustomerSupportList(refunds: true);
      case '/refund' when id != null && id > 0:
        screen = CustomerRefundScreen(id: id);
      case '/ratings':
        screen = const CustomerRatingsScreen();
      case '/rate' when id != null && id > 0:
        screen = CustomerRateScreen(orderId: id);
      case '/notifications':
        screen = const NotificationSettingsScreen(customer: true);
      default:
        screen = Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Không tìm thấy trang.')),
        );
    }
    if (widget.guest && settings.name != '/') {
      screen = const CustomerHomeScreen(guest: true);
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => screen);
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CustomerRepository>.value(value: repo),
      RepositoryProvider<CustomerPlaces>(
        create: (_) => MapVinaCustomerPlaces(),
        dispose: (places) => (places as MapVinaCustomerPlaces).close(),
      ),
    ],
    child: MultiBlocListener(
      listeners: [
        BlocListener<PushCubit, PushState>(
          listenWhen: (a, b) => !identical(a.pending, b.pending),
          listener: (_, s) {
            if (s.pending != null) handlePending();
          },
        ),
        BlocListener<PaymentReturnCubit, bool>(
          listener: (_, s) {
            if (s) handlePending();
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildCustomerTheme(),
        navigatorKey: navigator,
        onGenerateRoute: route,
      ),
    ),
  );
}
