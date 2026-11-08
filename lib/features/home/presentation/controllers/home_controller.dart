import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/public_fare.dart';
import '../../domain/usecases/get_public_fares.dart';

class HomeController extends Cubit<List<PublicFare>> {
  HomeController(GetPublicFares getPublicFares)
    : super(List.unmodifiable(getPublicFares()));
  List<PublicFare> get fares => state;
  PublicFare fareFor(VehicleType type) =>
      fares.singleWhere((fare) => fare.type == type);
}
