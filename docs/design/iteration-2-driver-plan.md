# Iteration 2: Driver trip and earnings plan

## Scope and constraints

This plan covers tickets `FE-19`, `FE-20`, `FE-21`, `FE-22`, `FE-23`,
`FE-25`, `FE-26`, `FE-28`, and `FE-29` from the driver application backlog.
The source of truth is `../Report-3_Software Requirement Specification_v2.docx`.

Implementation starts only after the five design boards in
`../output/mobile-design-v2/` are reviewed. The Flutter UI must follow those
boards and the existing ModMove visual system: Inter, orange `#D94B18`, ink
`#151B24`, white surfaces, thin gray borders, rounded cards, green success,
amber pending, and red blocking states.

State management is **BLoC/Cubit** with `flutter_bloc`. New code must not use
`ChangeNotifier` or `Provider`. Before adding Iteration 2 screens, migrate the
existing Home and Onboarding presentation state to Cubits and replace the app
composition with `MultiBlocProvider`. Remove the `provider` dependency after
parity tests pass so the app has one state-management approach.

The backend API is unavailable. All behavior is implemented behind domain
repository interfaces using deterministic mock adapters. UI widgets and BLoCs
must not import mock classes directly. Replacing mock adapters with remote
adapters later must not change the presentation or domain API.

Review screenshots remain ignored and are never committed. Generated design
boards live outside the Git repository; prompt specifications are trackable.

## Design boards

| Board | Tickets | Screens and states |
| --- | --- | --- |
| `04-driver-dispatch.png` | FE-19, FE-20, FE-21 | Driver Home online state, 30-second job offer overlay, pre-acceptance job details |
| `05-pickup-and-inspection.png` | FE-22, FE-23 | Turn-by-turn pickup navigation, arrival within 500 m, cargo checklist and at least two evidence photos, waiting for customer approval |
| `06-pod-and-trip-earnings.png` | FE-25, FE-26 | Drop-off/POD photo, COD collection confirmation, delivered success and immutable fare/commission/net breakdown |
| `07-driver-wallet.png` | FE-28 | Deposit/earnings wallet, PayOS top-up QR/session result and withdrawal request/receipt |
| `08-revenue-summary.png` | FE-29 | Day/Week/Month revenue chart, aggregate cards, completed-trip list and one trip breakdown |

The boards show representative success paths. Flutter implementation must also
cover loading, empty, offline, expired, stale-location, upload failure,
first-accept-lost, insufficient-deposit, and pending-withdrawal states.

## Architecture

```text
features/
  driver_home/
  job_matching/
  active_trip/
  driver_wallet/
  driver_revenue/
    domain/
      entities/
      repositories/
      usecases/
    data/
      models/
      repositories/mock_*.dart
      services/mock_*.dart
    presentation/
      bloc/
      screens/
      widgets/
```

Dependency direction remains `presentation -> domain <- data`. The composition
root in `lib/app/` selects mock adapters and injects use cases into BLoCs.

Planned BLoCs:

- `DriverHomeBloc`: approval/duty state, GPS permission, live location stream,
  shift KPIs, active-order shortcut and wallet summary.
- `JobOfferBloc`: eligible job stream, 30-second countdown, decline/expire and
  atomic accept result. It prevents a second accept while one is in progress.
- `ActiveTripBloc`: accepted -> arrived -> picked up -> waiting approval ->
  in transit -> delivered -> completed state machine, route/ETA and arrival
  radius checks.
- `EvidenceBloc`: local camera/gallery items, validation, upload progress,
  retry, minimum two pickup images, one POD image and retained failed uploads.
- `WalletBloc`: balances, ledger, PayOS top-up session, 10-minute expiry,
  withdrawal validation and pending receipt.
- `RevenueBloc`: Day/Week/Month period, totals and per-trip breakdown.

## Mock API contract

Mock adapters simulate realistic async behavior and errors, not hard-coded UI
state:

- `TripRepository`: nearby jobs, job details, atomic first-accept-wins,
  arrival validation, status transitions and immutable settlement.
- `LocationRepository`: permission state and a 5-second coordinate stream;
  stale after 30 seconds. A fake route supplies distance and ETA.
- `EvidenceRepository`: image validation and upload-progress stream, with a
  controllable failure followed by retry success.
- `WalletRepository`: separate security-deposit and earnings balances,
  transaction ledger, PayOS mock session and one pending withdrawal limit.
- `RevenueRepository`: aggregates completed ledger entries by Vietnam time
  for day, week, and month.

Required rules from the SRS:

- Only Approved, Active and Online drivers without an active order see jobs.
- A job offer expires after 30 seconds; only the first eligible accept succeeds
  (`GB-08`).
- GPS updates every 5 seconds during an active trip; location is stale after
  30 seconds.
- Arrival requires the driver to be within 500 m of the stop.
- Pickup needs at least two photos: overall cargo and cargo secured in vehicle.
- POD needs one delivery photo; COD at drop-off must be recorded first.
- Default commission is 10% and fixed for the accepted order.
- COD visibility requires deposit >= 200,000 VND and >= order commission.
- Deposit top-up is at least 50,000 VND; PayOS mock expires in 10 minutes.
- Withdrawal is greater than zero, no more than available earnings, uses a
  saved bank account, and permits only one Pending request.

## Commit-sized implementation order

1. `[FE-19] refactor: adopt Bloc state management foundation`
   - Add `flutter_bloc` and `equatable`.
   - Migrate existing Home/Onboarding controllers to Cubits and remove Provider.
   - Preserve all existing behavior and tests.
2. `[FE-19] feat: implement driver home and mock GPS stream`
   - Online/offline eligibility, location permission/stale states, map shell,
     shift KPIs, wallet shortcut and active-order state.
3. `[FE-20] feat: add countdown driver job alert`
   - New-job overlay, audio/haptic hook, deterministic 30-second timer,
     decline/expire behavior and lifecycle-safe cancellation.
4. `[FE-21] feat: implement job details and atomic acceptance`
   - Route/cargo/payment/earnings details, first-accept-wins mock transaction,
     unavailable and ineligible outcomes.
5. `[FE-22] feat: implement pickup navigation and arrival gate`
   - Mock route/ETA/location stream, map fallback, 500 m arrival validation and
     customer contact entry point.
6. `[FE-23] feat: implement cargo inspection evidence flow`
   - Checklist, two required images, mismatch note, upload retry and waiting for
     customer approval/rejection.
7. `[FE-25] feat: implement POD upload and trip completion`
   - Destination arrival, POD image, conditional COD confirmation, location gate
     and Delivered transition.
8. `[FE-26] feat: show immutable trip earnings settlement`
   - Gross fare, commission, net earning, payment method and completion receipt.
9. `[FE-28] feat: implement driver wallet actions with mock PayOS`
   - Balances/ledger, preset/custom top-up, QR session states, withdrawal form,
     bank account and pending receipt.
10. `[FE-29] feat: implement driver revenue summary`
    - Day/Week/Month tabs, totals, empty/error states and trip breakdown.
11. `[FE-29] test: verify driver trip and earnings flows`
    - BLoC transition tests, fake-clock countdown/expiry tests, repository rule
      tests, widget/navigation tests, seven Iteration 2 reference states,
      responsive layouts, analyzer and Android debug APK.

Each feature commit must pass formatting, analyzer and its focused tests before
the next slice. The final validation runs `flutter test --coverage` and
`flutter build apk --debug`. No push or merge to `develop` is included; CI and
one peer approval remain required.

## Acceptance criteria

- Visual hierarchy and copy match the approved design boards at 390 x 844.
- BLoCs expose explicit initial/loading/success/empty/error/blocked states.
- Timers and streams are cancelled on close; no duplicate subscriptions.
- Mock adapters are replaceable and contain every fixture/latency/failure flag.
- The order status machine rejects invalid transitions.
- Money uses integer VND values in domain code; no floating-point settlement.
- Buttons are disabled during mutations; retries do not duplicate acceptance,
  upload, top-up, withdrawal, or settlement.
- Compact screens scroll without overflow and important controls remain usable
  at 130% text scale.
