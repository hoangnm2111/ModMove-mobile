# 📱 ModMove - Mobile Application

[![Mobile CI Pipeline (Flutter / Android)](https://github.com/hoangnm2111/ModMove-mobile/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/hoangnm2111/ModMove-mobile/actions/workflows/mobile-ci.yml)

Cross-platform mobile application built with **Flutter (Android)** supporting two primary user roles for the **ModMove On-Demand Moving and Delivery Application** (Capstone Project SEP490 - Team G121):

1. **Customer**: Shipment booking, cargo photo capture, instant fare estimation, live driver GPS tracking, VietQR PayOS payment, and trip ratings.
2. **Driver**: Online/offline toggle, 30s countdown trip offer acceptance, turn-by-turn route navigation, cargo pickup verification, Proof of Delivery (POD) photo upload, wallet, and earnings management.

---

## 🛠️ Technology Stack
- **Framework:** Flutter 3.x / Dart (Target: Android SDK 34+)
- **State Management:** BLoC / Provider pattern
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
using Flutter Material, Provider and feature-first Clean Architecture.

```sh
flutter pub get
flutter run
```

See the [UI review guide](docs/mobile-ui-review.md) for the seven screen entry
points, validation commands, APK location and current mock-data boundaries.
See [architecture](docs/architecture.md) for source organization and dependency
direction. Review screenshots are generated locally and excluded from Git.
