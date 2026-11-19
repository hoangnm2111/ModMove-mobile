import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';

class PlatformTripContactRepository implements TripContactRepository {
  const PlatformTripContactRepository();
  @override
  Future<bool> callCustomer(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone));
  @override
  Future<bool> openNavigation(GeoPoint destination) => launchUrl(
    Uri(
      scheme: 'geo',
      path: '${destination.latitude},${destination.longitude}',
      queryParameters: {
        'q': '${destination.latitude},${destination.longitude}',
      },
    ),
    mode: LaunchMode.externalApplication,
  );
}
