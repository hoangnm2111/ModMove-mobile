# Iteration 2: Driver implementation and design

## Status — 2026-11-10

The mobile UI and remote adapters now cover FE-19, FE-20, FE-21, FE-22, FE-23,
FE-25, FE-26, FE-28 and FE-29, connected to the existing FE-43/FE-27 onboarding
flow. Backend source was read to establish contracts; this work changes only
mobile. New commits remain local until publishing is explicitly authorized.

Read [the API and sequential test guide](../backend-api.md) for the current
implementation, verified live reads/native screens and Cloudinary/PayOS limits.
The original mock-first plan has been superseded by the user's requirement to use
real APIs. The previous onboarding/pickup demo is still explicitly selectable;
real-mode failures never fall back to fabricated success.

## Design references

The existing boards in the workspace `output/mobile-design-v2/` remain the
visual references. They use Inter, orange `#D94B18`, ink `#151B24`, white
surfaces, thin gray borders, rounded cards, green success and amber pending.
Flutter Material is the UI kit, with the existing SVG icons/illustrations.

| Board | Tickets | Screens |
| --- | --- | --- |
| `04-driver-dispatch.png` | FE-19, FE-20, FE-21 | Online home, countdown offer, job details |
| `05-pickup-and-inspection.png` | FE-22, FE-23 | Pickup, cargo photos, customer review |
| `06-pod-and-trip-earnings.png` | FE-25, FE-26 | POD, cash confirmation, delivery receipt, fare breakdown |
| `07-driver-wallet.png` | FE-28 | Deposit/earnings balances, PayOS session, withdrawals |
| `08-revenue-summary.png` | FE-29 | Day/Week/Month chart, totals and completed trips |

Boards illustrate example amounts/states. The implemented copy, amounts and
enabled actions follow the backend contract, including separate Delivered and
Completed states. Loading, empty, expiry, stale GPS, lost acceptance, failed
upload and pending withdrawal states supplement the reference screens.
Screenshots remain ignored; design boards stay outside the repository.

## Architecture and work slices

Use feature-first Clean Architecture with BLoC/Cubit throughout:

| Slice | Responsibilities |
| --- | --- |
| FE-27 | Server profile, actual vehicle dimensions, review refresh and statistics |
| FE-19 / FE-20 / FE-21 | Device GPS, shift totals, detailed offers, absolute deadline, first-accept-wins |
| FE-22 / FE-23 | Restore server trip, handover-aware arrival, 2–5 photos, cash sender, customer approval |
| FE-25 | DeliveryCubit, receiver contact, arrival notification, POD upload/retry, cash gate and Delivered receipt |
| FE-26 | TripHistoryCubit/TripDetailCubit, filters/pagination, immutable server fare/commission/net |
| FE-28 | WalletCubit, balances/ledger, bank account, pending withdrawal and PayOS QR/session |
| FE-29 | RevenueCubit, Vietnam date ranges, all-page chart aggregation and previous-period comparison |

`features/driver_trip` owns the shared trip lifecycle. `features/wallet` and
`features/earnings` own financial screens. Domain contains pure Dart contracts;
data implements them with HTTP/platform adapters; `lib/app/` composes routes
and shared dependencies. See [architecture](../architecture.md).

## Behavior and acceptance

- Only server-eligible approved drivers can go online/receive jobs; server
  matching applies vehicle, distance, active-trip and deposit rules.
- Countdown is at most 30 seconds and capped by the server matching expiry.
  Repeated polling does not extend the deadline.
- GPS sends about every 5 seconds in foreground. Arrival requires a fresh fix
  within 500 m of pickup or the replacement driver's handover point.
- Pickup needs 2–5 uploaded, distinct photos; rejected evidence can be resubmitted
  within the server allowance. Only the customer approves pickup.
- Delivery requires POD and any outstanding cash confirmation. Delivered is a
  receipt; Completed is settlement. The app never credits money optimistically.
- Fare, commission, net, deposit minimum and withdrawal allowance come from the
  server. VND domain values are integers.
- Top-up is at least 50,000 VND; the PayOS session expires after 10 minutes.
  Confirmation requires the matching server transaction, not a checkout return.
- Withdrawal is positive, within the server allowance, uses a saved bank account
  and permits one pending request. Lost responses are reconciled with reads.
- Revenue uses Vietnam calendar days, Monday-based weeks and completed orders.
  All response pages contribute to charts, and stale filter responses are ignored.
- Screens scroll at 320×640 and 130% text scale; reviewed reference size is 390×844.
- Timers/subscriptions are disposed; mock controls and sample media are absent
  from the real API flow.

## Validation and delivery

Repository/BLoC/widget tests cover HTTP contracts, authorization, race handling,
countdown, upload/COD gating, withdrawals, top-up reconciliation, pagination,
Vietnam dates and responsive layouts. Native Android review uses the running
local API and seed driver accounts. External upload/payment services require
credentials before full end-to-end validation.

Format changed Dart files, run `flutter analyze --no-fatal-infos`,
`flutter test --coverage` and `flutter build apk --debug`.
Commit completed slices as `[FE-XX] feat: ...` on `feature/tunm`.
No push is authorized for this batch. A future PR to develop still requires
Mobile CI and a peer approval.
