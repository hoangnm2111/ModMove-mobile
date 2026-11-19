import 'customer_models.dart';

/// A typed address is resolved by the server when estimating the fare.
/// A selected search result or map pin also carries its exact coordinates.
class BookingAddress {
  const BookingAddress(this.address, {this.position});
  final String address;
  final GeoPosition? position;
}

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
