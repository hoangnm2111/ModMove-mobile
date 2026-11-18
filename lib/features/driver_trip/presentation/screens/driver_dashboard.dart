import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/job_offer_bloc.dart';
import '../widgets/job_alert_sheet.dart';
import 'driver_home_screen.dart';
import 'driver_simulation_sheet.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});
  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _showing = false;
  Future<void> _showOffer() async {
    if (_showing || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _showing = true;
    final details = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const JobAlertSheet(),
    );
    _showing = false;
    if (details == true && mounted) {
      Navigator.pushNamed(context, '/job-details');
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<JobOfferBloc, JobOfferState>(
        listenWhen: (previous, next) =>
            next.offer != null &&
            next.status == OfferStatus.available &&
            (previous.offer?.job.id != next.offer!.job.id ||
                previous.status == OfferStatus.idle),
        listener: (_, _) => _showOffer(),
        child: DriverHomeScreen(
          onActiveTrip: () => Navigator.pushNamed(context, '/active-trip'),
          onSimulation: tripSimulationAction(context),
          onJob: (job) {
            final bloc = context.read<JobOfferBloc>();
            if (bloc.state.offer?.job.id == job.id) {
              _showOffer();
            } else {
              bloc.add(OfferOpened(job.id));
            }
          },
        ),
      );
}
