import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/usecases/driver_trip_actions.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/driver_home_bloc.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/screens/driver_home_screen.dart';

class LocationUiTrips extends MockDriverTripRepository
    implements DriverLocationRecovery {
  LocationUiTrips(this.issue) : super(delay: Duration.zero, autoOffer: false);
  DriverLocationIssue? issue;
  final recovery = Completer<void>();
  int attempts = 0;
  @override
  Future<void> refresh() async {}
  @override
  DriverSession get current => DriverSession(
    online: true,
    gpsEnabled: issue == null,
    locationFailure: issue == null
        ? null
        : DriverLocationFailure(issue!, 'Vị trí cần được thiết lập.'),
  );
  @override
  Future<void> recoverLocation() async {
    attempts++;
    await recovery.future;
    issue = null;
    await refresh();
  }
}

void main() {
  for (final entry in {
    DriverLocationIssue.permissionDenied: 'Cấp quyền vị trí',
    DriverLocationIssue.permissionBlocked: 'Mở cài đặt ứng dụng',
    DriverLocationIssue.serviceDisabled: 'Bật vị trí thiết bị',
  }.entries) {
    testWidgets('home recovers ${entry.key.name} using the matching action', (
      tester,
    ) async {
      final repo = LocationUiTrips(entry.key);
      final bloc = DriverHomeBloc(DriverTripActions(repo));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: BlocProvider.value(
            value: bloc,
            child: const DriverHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trực tuyến · Chờ vị trí'), findsOneWidget);
      await tester.tap(find.text(entry.value));
      await tester.pump();
      expect(repo.attempts, 1);
      expect(find.text(entry.value), findsNothing);
      repo.recovery.complete();
      await tester.pumpAndSettle();
      expect(find.text('Vị trí cần được thiết lập.'), findsNothing);
      expect(find.text('Bạn đang trực tuyến'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await bloc.close();
        await repo.close();
      });
    });
  }
}
