import 'customer_models.dart';

class CustomerPlace {
  const CustomerPlace(this.address, this.position);
  final String address;
  final GeoPosition position;
}

abstract interface class CustomerPlaces {
  Future<List<CustomerPlace>> search(String query);
  Future<CustomerPlace> reverse(GeoPosition position);
  Future<GeoPosition> locate();
}
