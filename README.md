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

Read [the pickup walkthrough](docs/driver-pickup-mock.md) for demo scenarios,
architecture, tests and optional Google Maps setup. The trip API, GPS, routing and
uploads are mocked; the session resets on app restart. Screenshots stay ignored.

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
