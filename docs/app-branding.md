# ModMove app icon

The user selected the orange icon containing a white delivery truck, parcel and
integrated M on 2026-11-11. The clean source PNG is
`assets/images/modmove-app-icon.png`; it contains no Canvas badge. Authentication
and session-loading screens render this original through `AppLogo`.

Android uses `@mipmap/ic_launcher` for both standard and round launcher icons.
Legacy icons are exported for mdpi through xxxhdpi. Adaptive icons separate the
orange background from a white-tinted alpha mask and include a monochrome layer
for themed icons. The 6% foreground inset preserves the full truck and wheels
under Android launcher masks. Native startup themes also use the new icon.

To reproduce the committed Android resources from the source files:

```sh
flutter pub get
dart run tool/generate_app_icons.dart
```

The wrapper runs `flutter_launcher_icons` with `flutter_launcher_icons.yaml`,
then keeps the adaptive foreground's white tint. The mask source is intentionally
black; Android uses its alpha and tints it white. Running the package directly
without the wrapper would reset that tint reference.

The source icon and transparent mask were prepared with the built-in imagegen
tool. The mask prompt requested an exact black silhouette of the chosen white
truck, preserving the M, window, wheel centers and parcel seam as transparent
cutouts, without redesigning its geometry. Failed draft exports are not used.

Reinstall/relaunch the app after changing native resources; hot reload does not
refresh the launcher icon. Review screenshots stay in ignored `.codex/` folders.

Validation on 2026-11-11: analyzer clean, all 181 existing tests passed and debug
APK built. Installed on the separate Android API 36 `ModMoveReview` emulator;
checked the masked icon in App info and the native startup screen. The M, cab and
both wheels remained visible. Backend source was not modified.
