# MapVina on Android

Customer tracking, address selection and Driver maps now use MapVina Streets
Raster v2 through `flutter_map`. Search, reverse geocoding and driving routes use
MapVina REST v2. Google Maps SDK, its Android key and Android Geocoder are removed.

## Build configuration

Set the following in the ignored `android/secrets.properties` file:

```properties
MAPVINA_API_KEY=YOUR_MAPVINA_MOBILE_API_KEY
```

An environment variable of the same name overrides the file. Alternatively use
`--dart-define=MAPVINA_API_KEY=...` (prefer an ignored define file to avoid putting
credentials in shell history). Rebuild the APK; hot reload does not update Android
manifest metadata. Do not commit keys or print keyed request URLs.

Use a key intended for mobile distribution, with provider-supported restrictions
and quota controls. A key bundled in an APK is extractable; server credentials
belong on the backend. The public `public_key` is only for explicit development
testing, is labelled in the map footer, and is never selected automatically.

The separate backend `MapVina:ApiKey` still controls authoritative distance and
fare calculations. Displayed route distances never override server fares.

## Behavior and verification

- Pan/pinch, zoom, recenter, MapVina/OSM attribution, GPS markers and the Driver
  5 km dispatch circle remain available. GPS movement updates markers without
  snapping a map that the user has panned. Driver recenter opens street-level
  zoom 16 instead of fitting the entire dispatch circle again.
- Raster XYZ data ends at level 16. With 512px tiles and zoom offset -1, both
  the layer's native zoom and camera maximum must be 17. Higher camera levels
  would only magnify existing pixels. The final native level is now requested.
- While detail tiles are downloading, tiles from other zoom levels are hidden
  instead of magnified. A loading indicator stays visible until the image body
  finishes downloading. This also covers rapid repeated zoom presses, partial
  response failures and cancellations. Zoom controls disable at their limits.
- Driver Home puts availability and its switch in the app bar. The map height
  scales to 38% of the screen, between 280 and 360 logical pixels, replacing
  the previous 220-pixel map and separate availability card.
- Search results retain coordinates. Reverse lookup labels a pin but preserves
  its exact coordinates. Changing an address invalidates old selections.
- Manual address entry remains available when Maps, geocoding or GPS fail;
  the backend resolves that address at fare estimation. A backend that has not
  deployed coordinate support cannot safely accept exact map pins. This is a
  backend contract limitation to report to its owner, not permission to modify
  or deploy backend code. The earlier backend experiments were withdrawn.
- Driver navigation opens an in-app road route and instruction list. Use
  **Cập nhật tuyến** to recalculate from current GPS. Voice guidance and automatic
  rerouting are not included. Arrival/delivery checks still use authoritative
  trip state and device GPS, independently of map display.
- HTTP errors and provider quota errors remain recoverable. Provider request
  URLs, keys and error bodies are not displayed to the user.
- Driver Home distinguishes permission denied, permission blocked in settings,
  disabled device location and a missing GPS fix. Recovery prompts only on a
  button tap, opens the relevant settings when needed, and rechecks on resume.
  It does not toggle server availability to obtain permission. Tracking network
  failures are not labelled as missing location permission.
- The foreground GPS stream uses Android LocationManager consistently with
  one-shot fixes. Transient acquisition errors keep the existing subscription;
  permission/service errors release it. Polling does not restart a healthy stream.

## Android emulator

Allow ModMove location access **while using the app** in Android settings and
enable device Location. The default emulator point in California produced
MapVina HTTP 404 tiles; the same configured key returned PNG tiles for TP.HCM.
Set a Vietnamese test position in **Extended controls → Location → Set location**
or, with one emulator at the shown device ID:

```powershell
adb -s emulator-5554 emu geo fix 106.7009 10.7769
```

The command uses **longitude, then latitude**. Wait for the next location update
and tap the map's recenter control. This changes the emulator's simulated GPS;
the app does not substitute fake coordinates for a real device location.

Tile 404 messages now describe missing data in the viewed area; 401/403, 429
and connectivity failures have separate messages. Cancelling offscreen tile
requests during a pan/zoom does not display a connection error.

On 2026-11-19, the updated running emulator displayed street-level and final
native-level tiles at the test location. After restarting the mobile session,
the previously repeated five-second foreground-service start/stop cycle stopped.

The configured mobile key was checked on 2026-11-19: style JSON, 512×512 raster
tile, search, reverse and directions all returned HTTP 200; REST results were OK.
That is provider connectivity evidence, not a completed delivery or payment test.

Validation: 290 Flutter tests passed with coverage and `flutter analyze --no-fatal-infos`
reported no issues. The latest `flutter build apk --debug --target-platform android-x64`
succeeded and was installed on the Android emulator, preserving app data. The
universal debug APK packaging attempt ran out of local disk space; the latest APK
is for the x64 emulator. The merged Android manifest
contains the configured MapVina key and no Google Maps key. Tests include
`mapvina_client_test.dart`, `driver_mapvina_test.dart`, `customer_place_test.dart`,
`mapvina_tile_client_test.dart`, `mapvina_zoom_loading_test.dart`,
`device_driver_location_test.dart`, and
`driver_location_ui_test.dart`. A four-minute emulator observation after the fix
recorded one foreground location start and zero stops.
Map gestures and real tiles on a physical phone still require installing the APK.

## Provider contracts

- [MapVina styles](https://docs.mapvina.com/guides/): Streets Raster v2 style
  references the provider's tile JSON. Its XYZ tiles are 512 pixels, native
  max zoom 16, rendered with `tileDimension: 512`, `zoomOffset: -1`,
  `maxNativeZoom: 17`, and camera `maxZoom: 17`.
- [Search v2](https://docs.mapvina.com/api-integration/search/v2/)
- [Reverse v2](https://docs.mapvina.com/api-integration/reverse-geocoding/v2/)
- [Directions v2](https://docs.mapvina.com/api-integration/directions/v2/)
- [Flutter Map raster layer](https://docs.fleaflet.dev/layers/raster-tile-layer)

The renderer is provider independent; all map imagery and geographic API data
in the live app come from MapVina. No Google Maps tiles or geocoding APIs are used.
