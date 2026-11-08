import 'package:flutter/material.dart';
import '../../../../core/widgets/app_widgets.dart';
import 'driver_home_screen.dart';
import 'driver_simulation_sheet.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});
  @override
  Widget build(BuildContext context) => DriverHomeScreen(
    onSimulation: () => showTripSimulation(context),
    onJob: (job) =>
        showInfoSheet(context, '#${job.id}', '${job.pickup}\n→ ${job.dropoff}'),
  );
}
