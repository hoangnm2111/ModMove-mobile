# Customer mobile — real API integration

The default entry point uses the deployed backend at `https://modmove-103-178-235-191.sslip.io` on Android Emulator and physical devices. Customer has no mock repository, fallback fare, fake location or simulated payment completion. Login reads the role in the server response and opens either Customer or the existing Driver flow.

```powershell
flutter pub get
flutter run
```

For a local backend on Android Emulator, use `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5133`.
The base URL must not include `/api`. Do not add `USE_MOCK_API=true` when testing these features.
Stop and relaunch after changing `API_BASE_URL`. Sessions are scoped to the server URL;
sign in with a VPS account, or register a new one, when switching from the local database.

Connection check on 17 November 2026: the deployed `/health` returned `Healthy`, and
`/api/public/VehicleTypes` returned HTTP 200 with four vehicle types over HTTPS.
These public checks do not verify authenticated booking, uploads, payments or tracking.

## Implemented screens and contracts

Local update, 19 November 2026: booking inputs, uploaded cargo URLs and a cargo photo awaiting upload now survive navigation/process restarts in app-private files scoped to the server and account. A pending photo can be retried or discarded; submission waits until it is resolved. Regular drafts and orphaned trip photos expire after seven days; unresolved booking keys remain until reconciled. A restored regular draft needs a new quote. The map picker keeps coordinates; fare estimation must acknowledge them. The current backend does not acknowledge map pins; this remains a contract limitation to report, not an implemented backend fix. All earlier backend edits and migrations have been withdrawn to honor the mobile-only scope. The deployed service has not been changed. Home/order/incident/refund lists now refresh every 15 seconds, on foreground pushes and on resume.

| Ticket | Where to test | Backend API |
| --- | --- | --- |
| FE-02 | Register → Customer or Driver → email OTP | POST public/auth/register or register-driver, verify-email, otp/resend |
| FE-03 | Sign in; restore session; log out | POST public/auth/login, refresh; POST account/logout |
| FE-04 | Forgot password → email OTP → new password; Account → Change password | POST public/auth/forgot-password, reset-password; POST account/Password |
| FE-05 | Account → personal information / delete account | GET/PUT account/Profile; DELETE customer/Account |
| FE-06 | Home, active orders, history and search | GET customer/orders with view, search and pagination |
| FE-07 | Book → addresses / receiver; order → cancel | Native Google Maps picker + Android geocoder; POST customer/orders; GET public/Lookups/cancellation-reasons; POST orders/{id}/cancel |
| FE-08 | Book → cargo type, quantity, total weight, largest-item dimensions, 1–5 photos | GET public/Lookups/cargo-types; POST customer/Uploads |
| FE-09 | Book → suitable vehicle, loading service, quote | GET public/VehicleTypes; POST public/FareEstimate |
| FE-10 | Book → PayOS/Cash, cash payer, coupon, policies, commitment | GET customer/Coupons, public/Policies; POST customer/orders with expectedTotalFee |
| FE-17 | Order → PayOS QR/link, expiry, regenerate, check payment, receipt | POST customer/orders/{id}/payment with platform App; GET customer/orders/{id} |
| FE-11 | Pending order → matching progress/countdown | GET customer/orders/{id}; deadline derives from creation for Cash or payment.paidAt for PayOS |
| FE-12 | Order → pickup photos → approve / request new photos | POST customer/orders/{id}/pickup-evidence |
| FE-13 | Order → interactive map, last GPS, ETA, progress | GET customer/orders/{id}/tracking; SignalR /hubs/tracking → JoinOrder, LocationUpdated, OrderStatusChanged |
| FE-16 | Delivered order → confirm receipt | POST customer/orders/{id}/confirm-receipt |
| FE-18 | Completed order → rating; Account → My ratings | GET/POST customer/Ratings |
| FE-14 | Active order → report incident, photos, optional current GPS | POST customer/Incidents and customer/Uploads |
| FE-15 | Account/order → Incidents → request refund; Account → Refunds → details, reply, payout account | GET customer/Incidents; GET customer/Refunds and /{id}; POST Refunds/incidents, /{id}/reply; PUT /{id}/payout-account; GET public/Lookups/banks |
| FE-44 | Delivered order → complaint; Refund details → withdraw request | GET public/Lookups/complaint-reasons; POST customer/Refunds/complaints and /{id}/withdraw |

All paths above are prefixed with `/api/` except the SignalR hub.
Push-token registration uses the existing account FCM API. Customer notification types open Customer order, incident or refund screens and reload owned records.

## Backend rules reflected in the app

- Registration is verified by email OTP before login. Login lockout (five wrong passwords, ten minutes) is enforced by the server; the client does not invent a lockout timer or bypass it.
- Password reset uses emailed OTP. The existing authenticated change-password endpoint requires the current password, not OTP. Successful password change signs the app out because the backend revokes all refresh sessions.
- A submitted order cannot be edited with the current backend. Edit the booking form before submission; afterwards cancel and book again while Pending/Accepted.
- Cargo quantity must be positive; total weight must be positive and at most 100,000 kg; dimensions are whole centimetres from 1 to 2,000. Vehicle fit allows rotation of the largest item and checks the total weight.
- Uploads are JPG/PNG, at most 5 MB; the order requires 1–5 returned photo URLs. Failed uploads do not discard existing photos or inputs.
- Changing any pricing input invalidates the quote. `FARE_CHANGED` requires a new server quote. Repeated submit taps are serialized.
- The current backend does not provide booking recovery by request key. The app requires an explicit order-list check after an uncertain result and does not automatically replay the POST. An optional mobile adapter is gated by `supportsBookingRecovery: true`; it must not be treated as an available API or authorization to add backend code. No backend migration accompanies this mobile work.
- PayOS orders must be paid before driver matching. A deep-link return only triggers an authenticated refresh; it never marks an order Paid. Expired or superseded QR codes are removed. Cash requires Sender/Receiver; PayOS sends no cash payer.
- Matching lasts up to ten minutes. The countdown is displayed only when a server-derived start timestamp is available. Reaching zero does not cancel locally.
- Pickup approval is only available for PickedUp with Pending proof and no pending driver incident. A rejection requires a specific reason.
- Location events update driver coordinates and preserve a recent ETA. Tracking/ETA retries every ten seconds while the order remains active, including after the first request fails; concurrent reads are coalesced. ETA expires after one minute without a fresh route response. GPS older than five minutes is labelled stale. No routing request is sent for each GPS event, and no road polyline is invented.
- Customer incidents can be reported during Arrived, PickedUp or InTransit. Incident refunds require a paid PayOS order.
- Complaints are allowed only while Delivered, within 24 hours, before completion. Confirming receipt completes the trip; the app explains the consequence before confirmation. The server also rejects confirmation while a complaint is open.
- Ratings are once per completed trip within 24 hours, immutable after submission.
- Refund amounts must be whole VND, greater than zero and at most the order total; the backend additionally enforces the remaining order-wide refundable amount. A bank account is required. Suggested PayOS accounts are confirmed using `useSuggested`; masked account numbers are never sent back.
- Only Requested complaints/incident refunds can be withdrawn. Cancellation refunds cannot be withdrawn. Processed/Rejected/Withdrawn refunds cannot have their payout account changed.

## Sequential UI walkthrough

1. Start the existing backend, then run the app. Choose **Register → Customer**, verify the emailed code and sign in. A pre-existing Customer account can also sign in directly.
2. On Home, choose **Book delivery**. Enter full pickup/dropoff addresses, or use map/address search and confirm a result. Enter recipient name and phone.
3. Select cargo type; enter quantity, total weight and largest-item dimensions. Capture or select 1–5 photos and wait for each upload.
4. Select a vehicle that fits, choose loading service, and request a quote. Continue to payment; choose Cash and its payer or PayOS. Select a coupon, recalculate the price, read policies and tick the goods commitment.
5. Submit once. For PayOS, create the payment QR/link, pay through PayOS, return and refresh until the backend confirms Paid. Never use the return URL as payment proof.
6. Follow matching and driver progress in the order. With a separate Driver session, accept, arrive and upload pickup photos. Customer reviews them; rejection preserves the order and asks the driver to replace the evidence.
7. Follow the latest GPS. After the Driver submits delivery proof, either confirm receipt or create a complaint before the 24-hour deadline. After completion, rate the trip once.
8. For incidents, use an Arrived/PickedUp/InTransit order, upload evidence and optionally attach current GPS. Follow responses through **Account → Incidents**.
9. For a paid PayOS incident, request a refund and enter a real payout account. In **Account → Complaints & refunds**, inspect status, reply to information requests, change an eligible payout account or withdraw a Requested complaint/refund.
10. Verify profile editing and password change with a test account. Account deletion is deliberately confirmed and should only be tested with an account intended for deletion.

## Local verification and limitations — 2026-11-16

Backend source was inspected read-only. No backend source or configuration was edited.

Mobile validation completed:
- `flutter analyze --no-fatal-infos`: no issues.
- `flutter test --coverage`: all 225 tests passed, including booking, API request contracts, pickup approval, refund eligibility, stale GPS, payment refresh and disposal during a pending real-time connection.
- `flutter build apk --debug`: successful; APK at `build/app/outputs/flutter-apk/app-debug.apk`.
- Customer home, orders, tracking, account and refund screens were opened on an Android emulator using the real local API.

Live local API verification:
- Customer login and role: HTTP 200.
- Vehicle types, cargo types, complaint/cancellation reasons, banks and policies: HTTP 200.
- Profile, order list and 14 order details, coupons, incidents, ratings, refund list and six refund details: HTTP 200.
- Tracking for demo order 12: HTTP 200 with actual last GPS; ETA is null and its position is stale.
- Authenticated SignalR handshake and JoinOrder(12): successful against the local backend; no driver GPS was fabricated for the check.
- Fare estimate with valid cargo and Ho Chi Minh City addresses: HTTP 500 `SERVER_ERROR`.
- Customer photo upload with a PNG under 5 MB: HTTP 500 `SERVER_ERROR`.
- The checked local backend appsettings files have no MapVina API key or Cloudinary API secret. Runtime configuration and provider errors need to be checked by the backend owner. No mock was substituted.
- This Android build has no Google Maps key. The app shows an explicit unavailable-map message and retains address entry/search. See [Google Maps configuration](google-maps-android.md) before testing native map gestures/pins with authorized Maps SDK billing.
- Consequently, successful live creation of a new order, payment of that new order, and its full delivery/refund cycle could not be verified in this session. These request contracts and state transitions have automated tests. Existing seed orders were read; their delivery, refund and payment states were not changed to manufacture a successful end-to-end test.
- OTP email delivery, actual financial transfers and a new Customer FCM delivery still require configured external services and a suitable test account/device. The app does not simulate those outcomes.

Review images from the running app with API data are outside Git in `../output/customer-api-review-2026-11-16/`.
No screenshots, credentials or local agent files belong in the commits.

## Customer audit — 2026-11-17

Rechecked all 18 requested functions against the current backend controllers, request validators and notification types. All 22 actions exposed by the seven Customer controllers have mobile repository calls and reachable UI flows. Shared authentication, account profile/password, FCM and public catalog APIs are also connected. No Customer mock implementation was added.

Corrections and missing details completed:
- FE-02 / FE-05 / FE-07: accept `+84` phone input but normalize it to `0xxxxxxxxx` for registration, profile and recipient API requests. The backend accepts only the domestic format.
- FE-04: validate new passwords consistently in the authenticated change-password form as well as registration/reset.
- FE-06: order history now filters by exact status, inclusive Vietnam calendar dates and recipient phone digits using the existing API query parameters; search and filters can be cleared.
- FE-07 / FE-08 / FE-09: enforce address/coupon lengths, finite weight and vehicle capacity; Android back navigates to the previous booking step without losing inputs. Rebooking a cancelled/completed order pre-fills addresses, recipient, cargo and uploaded photos while requiring a new vehicle selection, quote and consent. Retired cargo types require a replacement selection without clearing other fields.
- FE-12 / FE-17: show the pickup rejection reason, submission count, applied coupon and actual payment timestamp from order details.
- FE-13: clear old-driver GPS after reassignment or a server response with no driver location; discard in-flight responses from the previous assignment. A fresh SignalR location during the current request remains authoritative. Handover ETA is labelled as the transfer between drivers rather than the destination.
- FE-15 / FE-44: show refund decision/payout dates and provide a direct path from an order to complaints/refunds.

Re-test on the UI: sign up/edit profile with `+84`, filter History by Completed/Cancelled and recipient digits, open a cancelled order and select **Đặt lại với thông tin này**, use Android back between booking steps, and inspect a rejected pickup proof/refund timeline.

Validation after these changes: `flutter analyze --no-fatal-infos` passed, all **235 tests** passed with coverage, and `flutter build apk --debug` succeeded. The new tests include phone normalization, filter query parameters, rebooking, booking-step navigation, invalid vehicle capacity and driver reassignment/GPS races. These automated tests use isolated test fixtures; the app itself continues to use the real API.

Limits remain explicit:
- There is still no backend endpoint for editing an already submitted order. The supported workflow is cancellation followed by rebooking; the app does not pretend to edit the original order.
- Authenticated password change uses the current password because that is the backend contract; OTP is used for password reset.
- Google Maps needs the Android key. The tracking endpoint supplies GPS and ETA, not a road polyline; the app does not fabricate a route.
- On this audit date, `localhost:5133/health` and `/api/public/VehicleTypes` returned HTTP 200 with an HTML document, not ModMove health/catalog responses. No running `ModMove.WebApi` process was found. These responses are not successful live API checks.
- The checked local configuration still has no MapVina key, Cloudinary configuration or SMTP host. These are required for a Production startup; uploads, booking, emailed OTP and their full payment/delivery/refund cycle remain unverified against a live backend in this audit.
- The VPS deployment bundle is prepared separately under `../output/modmove-vps-2026-11-17/`, pinned to backend commit `20d13c53944c9c8977a0a7f810e34001ca77c7cf`. No backend source was edited. Deployment awaits VPS SSH access and provider configuration; no remote service or DNS/HTTPS endpoint has been provisioned yet.
