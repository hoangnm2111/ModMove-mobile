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

The app defaults to the real local backend at `http://10.0.2.2:5133` on Android Emulator. Start the backend, then run `flutter run` from this repository. See [backend API setup and sequential driver testing](docs/backend-api.md) for all 11 Driver tasks and the remaining Cloudinary/PayOS verification.

The UI fixture commands below describe the earlier demo. Add `--dart-define=USE_MOCK_API=true` when reviewing those mock screens; `SCREEN` does not bypass authentication in real API mode.

Driver onboarding, profile, dispatch, pickup, POD, trip earnings, wallet and
revenue screens use Flutter Material, BLoC/Cubit and feature-first Clean Architecture.

```sh
flutter pub get
flutter run
```

See the [UI review guide](docs/mobile-ui-review.md) for the seven screen entry
points, validation commands, APK location and current mock-data boundaries.
See [architecture](docs/architecture.md) for source organization and dependency
direction. Review screenshots are generated locally and excluded from Git.

## Driver flow (FE-43, FE-27, FE-19 to FE-23, FE-25, FE-26, FE-28, FE-29)

Online/offline, device GPS, 30-second offers, job details/atomic acceptance,
pickup, evidence review, POD, cash collection, trip history/earnings, wallet
top-up/withdrawal and Day/Week/Month revenue use real backend contracts.
To run on an Android emulator:

```sh
flutter run
```

Follow **Đăng ký tài xế (FE-43) → Gửi hồ sơ xét duyệt → Hồ sơ tài xế (FE-27)**.
An Admin approves the application. Return to the profile, select
**Vào trang chủ tài xế (FE-19)** and go online. **Tài khoản** returns to the
profile, **Đơn hàng** opens trip history, and **Ví** opens balances, transactions,
withdrawals and revenue. Pending/rejected profiles cannot go online.
Pickup photos require customer approval; Delivered remains distinct from the
Completed settlement. The separate `SCREEN=driver-home` shortcut only seeds a
demo driver when `USE_MOCK_API=true`.

Configure the Android key once using [Google Maps setup and sequential UI tests](docs/google-maps-android.md).
Maps use the native Google Maps SDK, with pan/pinch/rotate, zoom/recenter controls
and an animated 5 km dispatch area while searching. `android/secrets.properties`
stays ignored. No extra `GOOGLE_MAPS_ENABLED` flag is needed.
Until a key is configured, the app automatically uses the labelled original mock
map with pan/zoom and animated search waves. Run `flutter run` now to test the
driver UI; after key/Billing setup, rebuild to switch to Google Maps.

Read [the real API walkthrough](docs/backend-api.md) for sequential testing.
Cloudinary/PayOS credentials were unavailable during local verification, so
real uploads/payments and a full new trip through settlement remain to be tested.
Routing opens Google Maps externally; GPS currently runs in the foreground.
The older [pickup walkthrough](docs/driver-pickup-mock.md) applies only to the
explicit mock mode. Screenshots stay ignored.

## Driver profile mock API

With `USE_MOCK_API=true`, driver onboarding supports an interactive demo: register, upload
documents, submit, simulate a rejection, replace rejected documents, resubmit,
approve and toggle availability. The demo persists the mock profile and
version history locally. A separate **Mô phỏng** screen controls review outcomes
and one-shot API failures; the driver screens expose loading, retry and draft save.

Read [the Vietnamese walkthrough](docs/driver-profile-mock.md) for demo steps,
the proposed mock HTTP contract and the exact source call order for submission.
Presentation uses BLoC/Cubit, and the original profile mock API and persisted data
remain compatible. Real wallet and earnings screens are available in the default
API mode; the legacy demo is retained for isolated onboarding/pickup review.
