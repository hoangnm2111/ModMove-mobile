abstract final class DriverMatchingPolicy {
  /// Used by both mock matching and the geographic coverage shown on the map.
  // shortcut: hardcoded 5 km; server MATCHING_RADIUS_KM is admin-only to read, upgrade when the driver home loads matching config from the API
  static const searchRadiusMeters = 5000.0;
}
