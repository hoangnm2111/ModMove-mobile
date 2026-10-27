# ModMove mobile: implementation against the reference images

## Scope and source

Reproduce the seven app screens in `source/output/mobile-design-v1/` as working
Flutter widgets on Android. The presentation-board background, exterior headings,
phone silhouettes and shadows are not app content. Reference viewport: 390 × 844
logical pixels, with native Android safe areas and scrollable content on smaller
devices. Preserve large-text accessibility rather than scaling an entire screen
as a bitmap.

User-confirmed branch: `feature/tunm`. User-confirmed ticket IDs: `FE-01`, `FE-43`, `FE-27`.
Commit each verified implementation slice separately. Do not push to `main`.
Integration into `develop` requires Mobile CI and one peer approval.

## Visual analysis

| Element | Implementation decision |
| --- | --- |
| Typography | Bundle Inter with regular, medium, semibold, bold and extra-bold weights; tight headings and Vietnamese diacritics. AI images have no recoverable font metadata, so Inter is a deliberate visual match. |
| Brand | Orange wordmark, primary actions and selected navigation. Primary orange #D94B18, near-white surfaces, peach highlights. |
| Text | Near-black #151B24, secondary slate #606875, subdued labels #858C99. |
| Shape | Thin #E6E8EC borders, 8–12 dp card corners, 48 dp primary actions. |
| Layout | 12–16 dp page margins, compact cards, clear dividers; fixed bottom navigation/actions and vertically scrollable content. |
| Icons | Original 24-unit SVG stroke icons, consistent rounded joins; orange selected variants, explicit state icons and text. |
| Illustrations | Peach delivery hero, isolated pickup, van, orange truck, white truck. Generate from the reference image with imagegen. |
| Document previews | Abstract demo document illustrations; never display real identity data. Preview photos selected by the user. |
| Status | Green approved, amber pending, red correction required. Pending cannot edit or go online; rejected can replace rejected items only. |

## Commit-sized milestones

1. `[FE-01] chore: initialize Flutter Android app and design foundations`
   - Preserve existing README/CI and local-agent ignores.
   - Scaffold Android, bundle font/license, theme, shared components, SVG icons,
     image assets, source prompts, and this plan.
   - Verify dependencies, static analysis and shell rendering.
2. `[FE-01] feat: reproduce guest home and public fare screens`
   - Home hero, service cards, price preview, driver registration entry, navigation.
   - Public fare screen, vehicle tabs, specifications and illustrative pricing.
   - Verify navigation and render both screens against the reference.
3. `[FE-43] feat: implement driver verification screens`
   - Personal/vehicle steps, image picker and previews, 5 MB JPG/PNG validation,
     required-field feedback, upload slots, submission through a mock repository.
   - Verify form retention, invalid inputs, file checks and pending transition.
4. `[FE-27] feat: reproduce driver profile and approval states`
   - Personal/vehicle tabs, approved/pending/rejected UI, online gating,
     item-specific correction and locked accepted documents.
   - Verify state gates, resubmission and all three visual variants.
5. `[FE-01] test: verify mobile layouts and refine reference fidelity`
   - Capture all seven screens at the reference viewport; compare visually.
   - Check compact screens, text scaling and Android compilation.
   - Record commands, limitations and review screenshots; deliver a debug APK if
     the installed Android toolchain supports the build.

## Implementation boundaries

Use Flutter Material components as the UI kit, customized to the reference.
Use Provider / ChangeNotifier and a repository interface for onboarding state.
Backend APIs are not part of this UI task. Demo fixtures must be isolated and
clearly described in the project run instructions. Authentication, real pricing,
real document review, booking, wallet and payment integrations are future work;
do not pretend local state is server verification. Keep implementation controls
out of product screens; expose reference states through test/run configuration.

## Review criteria

- All seven screens exist and use actual text, controls and separate assets.
- Match reference copy, hierarchy, asset placement, color, card geometry, icons,
  selected navigation and status treatment.
- Forms, tabs, document preview, image selection and relevant state transitions
  work; smaller heights scroll without overflow.
- Native OS chrome varies by Android device. Raster AI text/illustrations are
  not mathematically reproducible; document remaining visible differences rather
  than claiming a 100% pixel match without evidence.
- Run the checks relevant to each milestone before its commit. Keep agent files
  ignored, generated build files out of Git, and source assets/licenses tracked.

## Sources

- Inter: https://rsms.me/inter/ and its SIL Open Font License.
- Flutter bundled fonts: https://docs.flutter.dev/cookbook/design/fonts
- Provider: https://pub.dev/packages/provider
- Flutter SVG: https://pub.dev/packages/flutter_svg
- Image picker: https://pub.dev/packages/image_picker
