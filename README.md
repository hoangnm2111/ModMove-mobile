# đŸ“± ModMove - Mobile Application

[![Mobile CI Pipeline (Flutter / Android)](https://github.com/hoangnm2111/ModMove-mobile/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/hoangnm2111/ModMove-mobile/actions/workflows/mobile-ci.yml)

Cross-platform mobile application built with **Flutter (Android)** supporting two primary user roles:
1. **Customer**: Shipment booking, cargo photo capture, instant fare quote, live driver GPS tracking, VietQR PayOS payment, trip rating.
2. **Driver**: Online/offline toggle, 30s countdown trip offer acceptance, turn-by-turn route navigation, cargo pickup verification, Proof of Delivery (POD) photo upload, wallet and earnings management.

---

## đŸ› ï¸ Technology Stack
- **Framework:** Flutter 3.x / Dart (Target: Android SDK 34+)
- **State Management:** BLoC / Provider pattern
- **Real-Time GPS Streaming:** WebSocket / SignalR client (5-10s ping interval)
- **Mapping & Routing:** Google Maps Flutter SDK + Directions API polyline
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Media Upload:** Cloudinary SDK (Direct authenticated cargo & POD uploads)

---

## đŸŒ¿ Contribution Guidelines
- Create feature branches: eature/<your-name>
- Commit messages: [TICKET-ID] <type>: <description>
- All Pull Requests to develop must pass the Mobile CI pipeline and receive 1 peer approval.