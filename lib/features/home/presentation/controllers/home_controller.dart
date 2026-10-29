import 'package:flutter/foundation.dart';
import '../../domain/entities/public_fare.dart';
import '../../domain/usecases/get_public_fares.dart';

class HomeController extends ChangeNotifier {
  HomeController(GetPublicFares getPublicFares)
    : fares = List.unmodifiable(getPublicFares());
  final List<PublicFare> fares;
  PublicFare fareFor(VehicleType type) =>
      fares.singleWhere((fare) => fare.type == type);
}
