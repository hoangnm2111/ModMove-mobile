# Mobile architecture

The Flutter Android app uses feature-first Clean Architecture and BLoC/Cubit.
Shared Material widgets are customized with the ModMove Inter/orange design
system. Dependency direction is `presentation → domain ← data`; composition
and route wiring belong to `lib/app/`.

```text
lib/
  main.dart                         Startup; real API is the default
  app/                              Auth/session composition and routes
  core/
    network/                        HTTP, token refresh, API errors
    domain/                         Shared paged result
    formatting/                     Integer VND and Vietnam time
    theme/                          Colors, typography, Material component theme
    widgets/                        Cards, buttons, navigation
  features/
    auth/                           Driver registration, OTP, encrypted session
    home/                           Public home and fare information
    onboarding/                     FE-43 and FE-27
    driver_trip/                    FE-19..23, FE-25 and FE-26
    wallet/                         FE-28
    earnings/                       FE-29
    incidents/                      FE-32: report, history, dispatcher response
      domain/                       Pure Dart entities and repository contracts
      data/                         Remote implementations / DTO mapping
      presentation/                 Cubits, screens and feature widgets
```

Domain does not import Flutter, plugins, transport or data classes. Widgets do
not construct API repositories. Financial and trip mutations use domain
contracts; server values determine balances, settlement and allowed transitions.
Fixtures belong to explicit mock adapters or tests.

## Composition and session

`RemoteApp` owns the authenticated session. `ApiClient` shares the access token,
serializes refresh-token rotation and converts backend errors into user-facing
messages. `SecureSessionStore` encrypts tokens and account/server-specific local
drafts. Signing out disposes the driver's repositories, streams and timers.
`RemoteDriverRepository` reads the real profile, onboarding status and vehicle
catalog. Existing onboarding controllers are Cubits despite their file names.

`DriverTripScope` provides the trip, photo and contact contracts together with
`DriverHomeBloc`, `JobOfferBloc`, `ActiveTripBloc` and `EvidenceCubit`.
The remote trip repository also implements `TripHistoryRepository` and
`DriverDeliveryRepository`. Route-scoped `DeliveryCubit`,
`TripHistoryCubit` and `TripDetailCubit` share that same authoritative trip
repository. Wallet and revenue routes inject `RemoteWalletRepository` /
`WalletCubit` and `RemoteEarningsRepository` / `RevenueCubit`.

Incidents injects `RemoteDriverIncidentRepository` with the same authenticated
API client. Route-scoped `IncidentReportCubit`, `IncidentListCubit` and
`IncidentDetailCubit` handle uploads, paginated filters, resolution updates
and reconciliation after uncertain submissions. Reports bind to a specific
active order and never switch silently when the assigned trip changes.
See [the Incidents walkthrough](driver-incidents.md).

## Trip consistency

The trip repository polls status/nearby orders and receives SignalR notifications.
On refresh it fetches full assigned-trip details, including customer contacts,
pickup review, POD, incidents and replacement handover points. A fresh install
can restore an existing trip without a local cache.

Offer countdowns use an absolute deadline, at most 30 seconds and no later than
the server matching expiry. Polling never extends a displayed offer. Before and
after a mutation the repository reads server state. If an acceptance/transition
response is lost, it reconciles using GET instead of replaying a POST. A delivered
receipt remains available while awaiting customer confirmation; only Completed
contributes to revenue.

Photo selection is a platform adapter. Evidence upload uses multipart
`/api/driver/uploads`; Cloudinary credentials remain on the backend. Pickup
needs 2–5 distinct uploaded URLs; POD needs one. The API is responsible for URL
ownership, valid transitions, cash rules and pickup resubmission limits.

## Wallet and revenue

Wallet state holds the server balance, ledger, withdrawal history and current
PayOS session. Opening checkout does not credit money. Confirmation requires the
matching top-up transaction to become Completed on the server. Withdrawal checks
re-read the balance immediately before submitting; lost responses trigger reads,
not automatic financial retries.

Revenue ranges are Vietnam calendar dates, with Monday-based weeks. The server
provides totals and the previous-period comparison. Every page of completed
orders is loaded before chart aggregation; the UI reveals rows in smaller
batches. A generation guard prevents a slow prior filter response replacing the
currently selected period.

## Maps and location

`DriverMap` uses native Google Maps when an Android Maps key is configured.
Without it, the requested temporary `MockDriverMap` displays an explicitly
labelled illustrated map, pan/zoom and animated coverage waves. Rendering uses
the shared search radius; animation respects lifecycle and reduced motion.
See [Google Maps setup](google-maps-android.md).

Location sent to the API always comes from the device in real mode, including
when the map is illustrative. SignalR sends location about every 5 seconds while
foreground, with REST fallback. Turn-by-turn routing opens Google Maps externally.
Background location and an in-app Directions route are not implemented here.

## Push notifications

`notifications/domain` defines device/token contracts and validates notification
destinations. Firebase and HTTP adapters live in `data`; `PushCubit` owns permission,
registration, token refresh, retries and pending taps. The composition root waits
for authentication and driver loading before opening routes. Foreground messages
use an Android notification channel; background messages use FCM display. Logout
drains registration and clears this device's token. See [Firebase setup and tests](firebase-push.md).

## Optional legacy demo and validation

`USE_MOCK_API=true` explicitly selects the previous onboarding/pickup demo.
Only that mode exposes simulated approvals, evidence decisions and sample media;
an API error never activates it. See [profile demo](driver-profile-mock.md) and
[pickup demo](driver-pickup-mock.md) for historical fixture scenarios.

See [the real API walkthrough](backend-api.md) for all 11 Driver tasks, sequential
testing, live verification and external-service limitations. Unit/widget tests
cover repository contracts, timing, race handling, financial state and responsive
layouts. Review screenshots and agent files remain ignored by Git.
