import '../entities/public_fare.dart';
import '../repositories/fare_repository.dart';

class GetPublicFares {
  const GetPublicFares(this.repository);
  final FareRepository repository;
  List<PublicFare> call() => repository.getPublicFares();
}
