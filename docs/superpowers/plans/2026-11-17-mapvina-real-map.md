# Plan: thay bản đồ mô phỏng bằng bản đồ thật MapVina

## Hiện trạng

- Chỉ có **một** widget bản đồ: `DriverMap` ([driver_map.dart](../../../lib/features/driver_trip/presentation/widgets/driver_map.dart)),
  dùng ở `driver_home_screen.dart:141` (vùng nhận đơn) và `pickup_navigation_screen.dart:31` (đường tới điểm lấy).
  App khách hàng không có bản đồ.
- `DriverMap` dùng `google_maps_flutter`, nhưng chỉ khi manifest có `com.google.android.geo.API_KEY`
  (kiểm qua MethodChannel `vn.modmove/maps_configuration` trong `MainActivity.kt`). Chưa có key Google
  → rơi về `MockDriverMap` (vẽ tay bằng `CustomPaint`). Đó là "map mockup" đang thấy.
- Đường tới điểm lấy là **đường thẳng nét đứt** giữa 2 điểm, không phải lộ trình thật.
- Backend đã dùng MapVina (geocode + route khi báo giá). Gợi ý địa chỉ ở app/web dùng Photon (OSM).

## Kết quả kiểm tra MapVina (đã gọi thử với `public_key`)

| Nhu cầu | MapVina | Ghi chú |
|---|---|---|
| Hiển thị map | Style vector `https://maps.mapvina.com/styles/v2/streets.json?key=KEY` | Đã tải được: JSON `"version":8`, `sources` vector, `sprite`, `glyphs` → **đúng chuẩn MapLibre style spec**. Không có SDK Flutter riêng → dùng package `maplibre_gl`. |
| Lộ trình | `GET https://maps.mapvina.com/route/v2/directions/json?origin=lat,lng&destination=lat,lng&mode=truck&key=KEY` | Đã gọi thử: trả `status:"OK"`, `routes[0].legs[0].distance.value` (m), `duration.value` (s), `overview_polyline.points` (chuỗi), `copyrights:"TrackAsia data"`. Polyline kiểu Google, **độ chính xác 1e6** (thấy `svt\`A…` ứng với lat 10.760896) → phải giải mã với precision 6. |
| Geocode/Autocomplete | Có (`api/v2/place/autocomplete`, `textsearch`, `geocode`) | **Ngoài phạm vi** plan này: autocomplete không trả toạ độ, backend vẫn tự geocode; giữ Photon. |
| Key | Lấy ở `account.mapvina.com`, truyền bằng query `key=` | Docs không nói có giới hạn key theo package/SHA-1. `public_key` chỉ để test. MapView được ghi là miễn phí. |

## SDK mobile của MapVina (đã kiểm tra github.com/mapvina, 17/11/2026)

- Có SDK Flutter chính thức: **`mapvina_gl` 1.0.1** trên pub.dev (repo `mapvina/flutter-mapvina-gl`), là bản fork của
  `maplibre_gl`, nên API gần như y hệt (`MapVinaMap`, `MapVinaMapController`, `addSymbol/addLine/addFill`, `CameraUpdate`).
  Phần Android dùng `io.github.mapvina:android-sdk-opengl:1.0.0` (có trên Maven Central), cần Kotlin ≥ 2.1, minSdk 21.
- Plugin gọi `MapVina.getInstance(context)` mà không truyền key; key nằm trong URL style (`?key=`). Cả `key=public`
  và `key=public_key` đều trả 200.
- **Trạng thái do chính MapVina ghi nhận (04/10/2026): tích hợp Flutter "BLOCKED"** (issue #33 vẫn mở).
  - Lỗi Android: `url_launcher_android` dùng Kotlin DSL, không build được với toolchain cũ của app mẫu (AGP 8.9, Kotlin 1.9).
    App mình dùng AGP 9.0.1 + Kotlin 2.3.20 và đang build được với `url_launcher`, nên **nhiều khả năng không dính**.
    Tuy vậy MapVina chưa test runtime Flutter (NOT TESTED).
  - SDK Android native (`android-sdk` 1.0.2) thì PARTIAL PASS: chạy được trên emulator ở TP.HCM, hiện logo MapVina ở góc dưới bên trái.
    Lưu ý: GPS emulator mặc định ở Mỹ, nằm ngoài vùng dữ liệu, nên map trắng. Khi test phải dùng `DRIVER_FAKE_LAT/LNG`.
- Kết luận: dùng `mapvina_gl`, nhưng phải **làm spike build trước** (bước 0). Nếu build hoặc runtime lỗi thì chuyển sang `maplibre_gl`
  với cùng URL style: code gần như giữ nguyên, chỉ đổi import và tên class.

## Quyết định

1. Dùng `mapvina_gl` (dự phòng: `maplibre_gl`) + style MapVina. **Bỏ `google_maps_flutter`** và `MockDriverMap`:
   MapView MapVina miễn phí nên không cần nhánh dự phòng vẽ tay; lỗi tải map vẫn hiện `_UnavailableMap` có nút "Thử lại".
2. Key MapVina truyền bằng `--dart-define=MAPVINA_KEY=...` qua `AppConfig` (giống `API_BASE_URL`), mặc định `public_key`
   để chạy dev ngay. Bỏ MethodChannel `maps_configuration` và placeholder `MAPS_API_KEY` trong Gradle/manifest.
3. Lộ trình thật tới điểm lấy: gọi Directions MapVina **từ app** với `mode=truck`, vẽ polyline thật;
   lỗi/timeout → vẫn vẽ đường thẳng nét đứt như hiện tại (không chặn luồng chuyến).
   - Rủi ro: key nằm trong APK (giống mọi key bản đồ mobile). Nếu nhóm không chấp nhận → phương án B:
     thêm endpoint backend `GET /api/driver/route?from=&to=` dùng `IMapService.Route` sẵn có; app chỉ gọi BE. Cần chốt trước bước 4.
4. Giữ nguyên số km/phút hiển thị ở `pickup_navigation_screen` (đang tính từ GPS) trong plan này; có thể thay bằng
   `distance/duration` của Directions sau.

## Các bước

### 0. Spike build (khoảng 30 phút, làm trên nhánh nháp)
- Thêm `mapvina_gl: 1.0.1`, đặt một `MapVinaMap(styleString: …streets.json?key=public_key)` tạm vào `DriverMap`.
- `flutter build apk --debug`, sau đó `flutter run` với `DRIVER_FAKE_LAT=10.7769 DRIVER_FAKE_LNG=106.7009`.
- Đạt yêu cầu khi: build qua, tiles TP.HCM hiện, kéo/zoom được, thêm được một symbol và một line, không crash khi rời màn hình.
- Không đạt → thay bằng `maplibre_gl`, chạy lại các bước trên. Ghi kết quả vào plan này.

**Kết quả spike 17/11/2026** (nhánh `spike/mapvina-gl`, chưa commit; widget thử ở `widgets/mapvina_spike_map.dart`
được đặt vào chỗ của `MockDriverMap` trong `DriverMap`):

| Kiểm tra | Kết quả |
|---|---|
| `flutter pub add mapvina_gl:1.0.1` | PASS: resolve được cùng các dependency hiện có (thêm `mapvina_gl`, `_platform_interface`, `_web` 1.0.1) |
| `flutter analyze` | PASS: không có lỗi |
| API dùng được: `MapVinaMap`, `addFill` (vòng nhận đơn dạng polygon 64 điểm), `addLine`, `addCircle`, `animateCamera` | PASS ở mức biên dịch |
| `flutter test` | 215 pass, 3 fail, đều do spike gây ra: 2 test trong `driver_google_map_test.dart` tìm `MockDriverMap`, 1 test `complete pickup 320x640` báo `MissingPluginException` vì platform view |
| `flutter build apk --debug` | PASS: lỗi Kotlin DSL ở issue #33 **không** xảy ra với AGP 9.0.1 / Kotlin 2.3.20 |
| Chạy trên emulator Pixel 9 Pro (`SCREEN=driver-home`) | PASS sau khi sửa lỗi key (xem dưới): hiện tiles MapVina thật ở Q.7/Q.8, logo MapVina, vị trí xe, vòng nhận đơn đúng bán kính; kéo bản đồ được; chuyển màn hình rồi quay lại không crash |
| Màn "Đến điểm lấy hàng" (line tới điểm lấy) | CHƯA KIỂM TRA trên máy ảo |

**Lỗi chặn trong `mapvina_gl` 1.0.1 (đã tìm ra nguyên nhân):** app crash native ngay khi tải tiles với lỗi
`std::runtime_error: You must provide API key for tile sources`. Key nằm trong URL style **không** đủ.
Nguyên nhân: mỗi lần tạo bản đồ, `MapVinaMapController` gọi `MapVina.getInstance(context)`, và hàm này luôn đặt
`apiKey = null` rồi gọi `FileSource.setApiKey(null)`, nên key đặt từ trước (kể cả trong `MainActivity`) đều bị xoá.
Cách vòng qua đang dùng trong spike, đã chạy được:
1. `MainActivity` có thêm MethodChannel `vn.modmove/mapvina` → `setApiKey` gọi `MapVina.getInstance(ctx, key, WellKnownTileServer.MapVina)` + `MapVina.setApiKey(key)`;
   app module thêm `implementation("io.github.mapvina:android-sdk-opengl:1.0.2")` để gọi được lớp `MapVina`.
2. `MapVinaMap` mở bằng style rỗng `{"version":8,"sources":{},"layers":[]}`; ở `onStyleLoadedCallback` đầu tiên thì gọi
   `setApiKey`, sau đó `controller.setStyle(<URL MapVina>)`; chỉ vẽ annotation ở callback của style thật.
3. Giữ `controller` và cờ trong `State`, vì `DriverMap` rebuild khoảng 15 fps cho hiệu ứng sóng, và plugin luôn gọi callback của widget mới nhất.
Nên báo lỗi này lên `mapvina/flutter-mapvina-gl` (một dòng sửa trong `MapVinaUtils.getMapVina`); khi họ sửa xong thì bỏ bước 1–2.

Ghi chú rút ra từ spike:
- Máy dev đang dùng Flutter 3.44.1 / Dart 3.12.1, còn project yêu cầu `sdk: ^3.12.2`. Spike tạm hạ xuống `^3.12.1`
  (**không merge thay đổi này**); một số gói vì thế bị hạ phiên bản trong lock. Nên `flutter upgrade` máy này.
- `logoEnabled` mặc định là `false` → phải bật `logoEnabled: true` để hiện logo MapVina.
- Ở bước 1, key lấy từ `AppConfig.mapVinaKey` (dart-define) rồi truyền qua channel ở trên, không hard-code `public_key` trong Kotlin.
- Không có callback báo lỗi tải style. Muốn hiện `_UnavailableMap` thì phải tự hẹn giờ: nếu sau ~10 giây vẫn chưa có
  `onStyleLoadedCallback` thì coi như tải lỗi.
- Test: gán `MapVinaPlatform.createInstance` bằng một fake (giống `RecordingMapsPlatform` đang dùng cho Google) để widget test
  không cần platform view. Ở bước 4, viết helper này thay cho `recording_maps_platform.dart`.

### 1. Dependency & cấu hình
- `pubspec.yaml`: thêm `mapvina_gl` (hoặc `maplibre_gl` theo kết quả bước 0), xoá `google_maps_flutter`
  và dev dep `google_maps_flutter_platform_interface`. `flutter pub get`.
- `AppConfig`: thêm `mapVinaKey = String.fromEnvironment('MAPVINA_KEY', defaultValue: 'public_key')`
  và getter `mapVinaStyleUrl`.
- Xoá `lib/core/platform/maps_configuration.dart`, handler `maps_configuration` trong `MainActivity.kt`,
  `<meta-data com.google.android.geo.API_KEY>` trong `AndroidManifest.xml`, khối `MAPS_API_KEY` trong
  `android/app/build.gradle.kts` và `android/secrets.properties.example` (nếu chỉ chứa key này).

### 2. Viết lại `DriverMap` bằng `MapVinaMap` (giữ nguyên API widget; dưới đây ghi tên class kiểu MapLibre, bên mapvina_gl là `MapVinaMap`)
Constructor giữ nguyên (`route`, `available`, `searching`, `searchRadiusMeters`, `position`, `destination`) → 2 màn hình gọi không phải sửa.
- `MapLibreMap(styleString: AppConfig.mapVinaStyleUrl, initialCameraPosition: …, onMapCreated, onStyleLoadedCallback)`;
  giữ `EagerGestureRecognizer`, tắt nghiêng, nút phóng to/thu nhỏ/về vị trí tự vẽ như cũ.
- Marker tài xế: `addImage('truck', bytes)` từ asset đang dùng trong `driver_map_marker.dart` → `addSymbol`.
  Sửa `driver_map_marker.dart` trả `Uint8List` thay cho `BitmapDescriptor`.
- Điểm lấy hàng: symbol/circle màu xanh.
- Vùng nhận đơn: MapLibre không có circle theo mét → tạo polygon xấp xỉ (64 điểm) từ tâm + bán kính,
  `addFill` (cam alpha .07, viền .45). Sóng lan toả: cập nhật `updateFill` ~15 fps như logic `_animateCoverage` hiện có.
- Camera: `animateCamera(CameraUpdate.newLatLngBounds(...))` — giữ nguyên cách tính bounds hiện có.
- Cập nhật vị trí khi `didUpdateWidget` (position đổi) bằng `updateSymbol`, không dựng lại map.
- `onMapLoadError`/style lỗi → hiện `_UnavailableMap` + retry.
- Dòng chú thích dưới map: bỏ chữ "thử nghiệm / mô phỏng"; để attribution MapLibre bật (`attributionButtonPosition`)
  và không che nó.
- Xoá `mock_driver_map.dart`.

### 3. Lộ trình thật (chỉ khi `route && destination != null`)
- Tạo `lib/features/driver_trip/data/mapvina_directions.dart`: hàm `Future<List<GeoPoint>?> route(GeoPoint from, GeoPoint to)`
  dùng `http` sẵn có, timeout 8s, `status != "OK"` → `null`.
- Giải mã polyline precision 6: tự viết ~15 dòng (không thêm package).
- Trong `DriverMap`: gọi khi có destination lần đầu và khi tài xế lệch > ~150 m so với lần gọi trước (tránh gọi mỗi 5s poll).
  Có kết quả → `addLine` liền màu cam rộng 5; không có → đường thẳng nét đứt (`lineDasharray`).

### 4. Test
- Xoá `test/driver_google_map_test.dart`, `test/helpers/recording_maps_platform.dart`, mock channel
  `maps_configuration` trong `test/flutter_test_config.dart`.
- Thêm test thuần Dart:
  - giải mã polyline: chuỗi từ response thật đã kiểm (`svt\`Ak{bjS…`) → điểm đầu ≈ (10.760896, 106.679739);
  - polygon vòng tròn: mọi đỉnh cách tâm ≈ bán kính (sai số < 1%);
  - `MapVinaDirections` với `MockClient`: OK → có điểm; lỗi/timeout → `null`.
- Widget test: `DriverMap(available: false)` → hiện "Chưa tải được bản đồ" (MapLibre là platform view nên không test render map).
- `flutter analyze` + `flutter test`.

### 5. Chạy thật & tài liệu
- `flutter run` trên emulator/máy thật với `--dart-define=DRIVER_FAKE_LAT=10.7769 --dart-define=DRIVER_FAKE_LNG=106.7009`:
  kiểm tra màn chính (vòng nhận đơn đúng 1 tỉ lệ địa lý) và màn đến điểm lấy (đường bám theo phố).
- Thay `docs/google-maps-android.md` bằng `docs/mapvina-android.md`: cách lấy key ở account.mapvina.com,
  chạy với `--dart-define=MAPVINA_KEY=...`; cập nhật đoạn map trong `docs/architecture.md`.

## Cần chốt trước khi làm
- Đăng ký key MapVina thật cho nhóm (public_key có hạn mức thấp, chỉ test).
- Gọi Directions trực tiếp từ app (bước 3) hay qua backend (phương án B)?
- Điều khoản attribution/logo MapVina chưa thấy trong docs — hỏi MapVina hoặc giữ attribution mặc định của style.

## Đã thực hiện (17/11/2026)

- Chốt: gọi Directions **qua backend** (phương án B), giữ nguyên style gốc MapVina.
- Backend (`ModMove-backend`, nhánh `feature/hieu`, chưa commit): `RouteInfo` thêm `Polyline`, adapter MapVina đọc
  `overview_polyline`, endpoint mới `GET api/driver/route` (use case `GetDriverRoute`), test và dòng tài liệu API.
  Backend vẫn gọi `mode=driving` (cùng route với báo giá, dùng chung cache); không dùng `mode=truck` như plan ban đầu.
- App: viết lại `DriverMap` bằng `mapvina_gl`, bỏ `google_maps_flutter`, `MockDriverMap`, MethodChannel `maps_configuration`.
- **Sửa plan:** polyline của MapVina có **5** chữ số thập phân, không phải 6 (test đối chiếu với `end_location` trong response thật).
- LineOptions của `mapvina_gl` không có `lineDasharray`, nên đường thẳng dự phòng vẽ liền, mờ hơn đường thật.
- Chưa làm: test hình học vòng nhận đơn (hàm `_ring` là private), thay km/phút bằng số từ Directions.
