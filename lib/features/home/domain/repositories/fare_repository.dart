import '../entities/public_fare.dart';

abstract interface class FareRepository {
  List<PublicFare> getPublicFares();
}
