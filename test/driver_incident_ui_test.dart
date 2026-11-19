import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/usecases/driver_trip_actions.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/active_trip_bloc.dart';
import 'package:modmove_mobile/features/incidents/domain/driver_incident_repository.dart';
import 'package:modmove_mobile/features/incidents/presentation/incident_detail_screen.dart';
import 'package:modmove_mobile/features/incidents/presentation/incident_list_screen.dart';
import 'package:modmove_mobile/features/incidents/presentation/incident_report_screen.dart';
import 'support/incident_fixtures.dart';

Widget host(
  Widget page,
  IncidentTestRepository repo,
  IncidentTestTrips trips, {
  double scale = 1,
}) => MultiRepositoryProvider(
  providers: [
    RepositoryProvider<DriverIncidentRepository>.value(value: repo),
    RepositoryProvider<DriverTripRepository>.value(value: trips),
    RepositoryProvider<CargoPhotoRepository>(
      create: (_) => IncidentTestPicker(),
    ),
  ],
  child: BlocProvider(
    create: (_) =>
        ActiveTripBloc(DriverTripActions(trips), IncidentTestContact()),
    child: MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => switch (settings.name) {
          '/incident-report' => IncidentReportScreen(
            orderId: settings.arguments as String,
          ),
          '/incident-detail' => IncidentDetailScreen(
            id: settings.arguments as String,
          ),
          '/incidents' => IncidentListScreen(
            orderId: settings.arguments as String?,
          ),
          _ => const Scaffold(body: Text('Trip destination')),
        },
      ),
    ),
  ),
);

void main() {
  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    for (final screen in ['report', 'list', 'detail']) {
      testWidgets('incidents $screen fits $size and scrolls', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = IncidentTestRepository();
        final trips = IncidentTestTrips();
        final key = GlobalKey();
        final page = switch (screen) {
          'report' => const IncidentReportScreen(orderId: '42'),
          'list' => const IncidentListScreen(),
          _ => const IncidentDetailScreen(id: '6'),
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: host(page, repo, trips, scale: size.width == 320 ? 1.3 : 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 390) {
          await tester.runAsync(() async {
            final render =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('test/screenshots/incidents-$screen.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await trips.controller.close();
      });
    }
  }
  testWidgets(
    'report requires description then navigates to real returned receipt',
    (tester) async {
      final repo = IncidentTestRepository();
      final trips = IncidentTestTrips();
      await tester.pumpWidget(
        host(const IncidentReportScreen(orderId: '42'), repo, trips),
      );
      await tester.pumpAndSettle();
      PrimaryButton submit() => tester.widget<PrimaryButton>(
        find.byKey(const Key('submit-incident')),
      );
      expect(submit().onPressed, isNull);
      await tester.tap(find.text('Hư hỏng hàng'));
      await tester.enterText(
        find.byKey(const Key('incident-description')),
        'Kiện hàng bị móp, nhờ hỗ trợ.',
      );
      await tester.pump();
      expect(submit().onPressed, isNotNull);
      tester.testTextInput.hide();
      await tester.tap(find.byKey(const Key('submit-incident')));
      await tester.pumpAndSettle();
      expect(repo.reports.single.type, IncidentType.damagedCargo);
      expect(repo.reports.single.description, 'Kiện hàng bị móp, nhờ hỗ trợ.');
      expect(find.text('Chi tiết sự cố'), findsOneWidget);
      expect(find.text('Sự cố #7'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await trips.controller.close();
    },
  );
  testWidgets('description survives scrolling away and back', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final trips = IncidentTestTrips();
    await tester.pumpWidget(
      host(
        const IncidentReportScreen(orderId: '42'),
        IncidentTestRepository(),
        trips,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('incident-description')),
      'Xe gặp sự cố trên đường',
    );
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('incident-description')))
          .controller!
          .text,
      'Xe gặp sự cố trên đường',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await trips.controller.close();
  });
  testWidgets(
    'filter passes server status; refresh updates dispatcher decision',
    (tester) async {
      final repo = IncidentTestRepository();
      final trips = IncidentTestTrips();
      await tester.pumpWidget(host(const IncidentListScreen(), repo, trips));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang xử lý'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.status, 'InProgress');
      await tester.tap(find.text('Xe bị thủng lốp, cần hỗ trợ.'));
      await tester.pumpAndSettle();
      expect(find.text('Sự cố #6'), findsOneWidget);
      repo.items = [
        incident(
          status: 'Resolved',
          decision: 'ContinueTrip',
          note: 'Có thể tiếp tục chuyến sau khi thay lốp.',
        ),
      ];
      await tester.tap(find.byTooltip('Kiểm tra phản hồi'));
      await tester.pumpAndSettle();
      expect(find.text('Đã xử lý'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Tiếp tục chuyến đi'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tiếp tục chuyến đi'), findsOneWidget);
      expect(
        find.text('Có thể tiếp tục chuyến sau khi thay lốp.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await trips.controller.close();
    },
  );
}
