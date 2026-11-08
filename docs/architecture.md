# Mobile architecture

The app uses feature-first Clean Architecture with BLoC/Cubit in the
presentation layer and customized Flutter Material components as its UI kit.

```text
lib/
  main.dart                     Android/system startup
  app/                          Composition root and routes
  core/
    theme/                      Shared colors and typography
    widgets/                    Shared visual components
  features/
    home/
    onboarding/
      domain/
        entities/               Pure Dart business values
        repositories/           Repository contracts
        usecases/               Validation and application operations
      data/
        repositories/           Demo or remote contract implementations
        services/               Platform/plugin adapters when needed
      presentation/
        controllers/            Observable UI state, injected use cases
        models/                 Display labels/formatting
        screens/                Flutter pages
        widgets/                Feature widgets
```

Dependency direction: presentation → domain ← data. `lib/app/` chooses concrete
repository implementations and injects use cases/controllers. Domain imports
neither Flutter, Provider, platform plugins nor data-layer classes. Widgets do
not instantiate repositories. Data fixtures stay outside presentation/domain.

Public fares use a demo repository. Driver profiles use `ApiDriverRepository`,
which maps domain entities to JSON and sends HTTP requests through an injected
`http.Client`. The app currently injects `MockClient` from `MockDriverApi`: an
in-process mock transport with latency, HTTP errors, serialized mutations,
idempotent submission and persistent version history. The proposed contract is
documented in [the profile walkthrough](driver-profile-mock.md).

`DriverProfileRepository` extends the basic fixture contract with asynchronous
load, draft save, upload, history and availability. `DriverReviewSimulator` is a
separate contract for demo controls, not production driver permissions. Domain
still imports neither Flutter nor transport/plugin APIs. `lib/app/` selects the
adapters; `main.dart` opens the local file store for normal runs.

Photo selection remains an injected adapter; the demo adds a labelled sample
image option. File validation and editing rules live in domain, and mock server
validation independently checks its authoritative version and document decisions.
This is not authentication, payment, Cloudinary or a real review backend.
