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
- **Mapping & Routing:** MapVina raster tiles, search/reverse and Directions v2; Flutter Map renderer
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

Customer accounts now open a separate BLoC application using the real backend: booking,
payment, order tracking, pickup review, receipt confirmation, ratings, incidents and refunds.
Registration lets the user choose Customer or Driver. See the [Customer API walkthrough](docs/customer-api.md)
for all 18 tasks, backend rules and the live verification limits (MapVina, Cloudinary and Google Maps configuration).

The app defaults to the deployed backend at `https://modmove-103-178-235-191.sslip.io` for both Customer and Driver. Run `flutter run` from this repository on an emulator or a physical Android device with internet access. REST requests, uploads, FCM token registration and SignalR tracking use the same API base URL. See [backend API setup and sequential driver testing](docs/backend-api.md) for all 11 Driver tasks and the remaining Cloudinary/PayOS verification.

To use a local backend on Android Emulator instead, run `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5133`. The base URL must not include `/api`. Stop and relaunch the app after changing this build-time setting. Sessions and driver drafts are stored separately for each server; sign in with an account registered on the VPS when using the default URL. Local demo accounts are not automatically transferred to the VPS.

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

Configure `MAPVINA_API_KEY` using [MapVina setup and verification](docs/mapvina.md).
Customer and Driver maps use MapVina data with pan/pinch, zoom/recenter controls
and an animated 5 km driver dispatch area. `android/secrets.properties` stays
ignored. Rebuild the APK after changing the key. Live mode never substitutes a
mock map for missing configuration; manual addresses remain available.

Read [the real API walkthrough](docs/backend-api.md) for sequential testing.
Cloudinary/PayOS credentials were unavailable during local verification, so
real uploads/payments and a full new trip through settlement remain to be tested.
Routing opens the in-app MapVina route and step list. Android uses a location foreground service
while online/on a trip to keep GPS updates running when switching apps. Real-device
background/lock-screen and force-stop recovery checks are still required.
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
