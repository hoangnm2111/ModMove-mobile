# Mobile architecture

The app uses feature-first Clean Architecture with Provider/ChangeNotifier in the
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

Public fares and profile review currently use demo repositories. Real backend
integration replaces those adapters while preserving domain contracts and UI.
Photo selection is an injected adapter; file validation and approval/editing
rules belong to domain use cases. The demo is not an authentication, payment,
Cloudinary upload or server-side identity-review implementation.
