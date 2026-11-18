# 📱 ModMove - Mobile Application

[![Mobile CI Pipeline (Flutter / Android)](https://github.com/hoangnm2111/ModMove-mobile/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/hoangnm2111/ModMove-mobile/actions/workflows/mobile-ci.yml)

Cross-platform mobile application built with **Flutter (Android)** supporting two primary user roles for the **ModMove On-Demand Moving and Delivery Application** (Capstone Project SEP490 - Team G121):

1. **Customer**: Shipment booking, cargo photo capture, instant fare estimation, live driver GPS tracking, VietQR PayOS payment, and trip ratings.
2. **Driver**: Online/offline toggle, 30s countdown trip offer acceptance, turn-by-turn route navigation, cargo pickup verification, Proof of Delivery (POD) photo upload, wallet, and earnings management.

---

## 🛠️ Technology Stack
- **Framework:** Flutter 3.x / Dart (Target: Android SDK 34+)
- **State Management:** BLoC / Cubit
- **Real-Time GPS Streaming:** WebSocket / SignalR client (5-10s ping interval)
- **Mapping & Routing:** Google Maps Flutter SDK + Directions API polyline
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Media Upload:** Cloudinary SDK (Direct authenticated cargo & POD uploads)

---

## 🌿 GitFlow & Contribution Rules
- `main`: Production-ready branch. Direct push is prohibited.
- `develop`: Primary integration branch.
- `feature/<name>`: Individual feature branch (e.g., `feature/tunm`).
- `release/<version>`: Stabilization branch before release into `main`.
- **Commit Convention:** `[TICKET-ID] <type>: <short description>`
  - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
  - Example: `[FE-03] feat: integrate Google Maps route polyline in booking screen`
- **Quality Gates:** All Pull Requests to `develop` must pass the Mobile CI pipeline and receive at least 1 peer approval.

## Run and review the mobile UI

The Home, public fare, driver verification and profile screens are implemented
using Flutter Material, BLoC and feature-first Clean Architecture.

```sh
flutter pub get
flutter run
```

See the [UI review guide](docs/mobile-ui-review.md) for the seven screen entry
points, validation commands, APK location and current mock-data boundaries.
See [architecture](docs/architecture.md) for source organization and dependency
direction. Review screenshots are generated locally and excluded from Git.

## Driver pickup (FE-19 to FE-23)

Online/offline, mock GPS, 30-second job offers, job details/atomic acceptance,
pickup navigation, cargo evidence uploads and customer approval are implemented
with BLoC/Cubit. To test the connected driver flow on an Android emulator, run:

```sh
flutter run
```

Follow **Đăng ký tài xế (FE-43) → Gửi hồ sơ xét duyệt → Hồ sơ tài xế (FE-27)**.
Use **Mô phỏng** to simulate approval, return to the profile, then select
**Vào trang chủ tài xế (FE-19)** and go online. **Tài khoản** returns to the same
profile; its **Đơn hàng** tab opens the active trip. Pending/rejected profiles
cannot go online. The separate `--dart-define=SCREEN=driver-home` shortcut seeds
an approved demo driver and skips onboarding; it is only for isolated trip tests.

Configure the Android key once using [Google Maps setup and sequential UI tests](docs/google-maps-android.md).
Maps use the native Google Maps SDK, with pan/pinch/rotate, zoom/recenter controls
and an animated 5 km dispatch area while searching. `android/secrets.properties`
stays ignored. No extra `GOOGLE_MAPS_ENABLED` flag is needed.
Until a key is configured, the app automatically uses the labelled original mock
map with pan/zoom and animated search waves. Run `flutter run` now to test the
full driver flow; after key/Billing setup, rebuild to switch to Google Maps.

Read [the pickup walkthrough](docs/driver-pickup-mock.md) for demo scenarios,
architecture and tests. The trip API, GPS, routing and
uploads are mocked; the session resets on app restart. Screenshots stay ignored.

## Driver GPS (backend thật)

- Online: foreground service của `geolocator` giữ GPS khi app ra nền; có thông báo thường trực
  "ModMove đang chia sẻ vị trí khi bạn Online". Offline thì tắt thông báo và dừng gửi.
  Manifest khai báo `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`;
  không xin `ACCESS_BACKGROUND_LOCATION`.
- **B18: chỉ phát hành APK.** Muốn lên Google Play phải khai báo loại foreground service `location`
  và nộp video minh họa trong Play Console.
- Máy ảo: đặt vị trí bằng Extended Controls → Location. Không có `DRIVER_FAKE_LAT/LNG` hay menu mô phỏng GPS;
  `USE_MOCK_DRIVER` vẫn dùng được (không gọi backend). Chi tiết: [docs/driver-pickup-mock.md](docs/driver-pickup-mock.md).

## Driver profile mock API

Driver onboarding now supports a complete interactive demo: register, upload
documents, submit, simulate a rejection, replace rejected documents, resubmit,
approve and toggle availability. The normal app persists the mock profile and
version history locally. A separate **Mô phỏng** screen controls review outcomes
and one-shot API failures; the driver screens expose loading, retry and draft save.

Read [the Vietnamese walkthrough](docs/driver-profile-mock.md) for demo steps,
the proposed mock HTTP contract and the exact source call order for submission.
Presentation uses BLoC/Cubit, and the original profile mock API and persisted data
remain compatible. The pickup flow is documented separately above; wallet and
earnings operations remain planned.
