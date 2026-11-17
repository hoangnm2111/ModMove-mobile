# Design assets

- `fonts/Inter-Variable.ttf`: Inter from the Google Fonts repository, bundled for
  offline rendering. See `fonts/OFL.txt` for the SIL Open Font License.
- `icons/*.svg`: original 24-unit, 1.8-unit stroke icons implemented for ModMove.
- `documents/*.svg`: abstract demo documents without real identity data.
- `images/*.png`: generated production illustrations based on the supplied
  ModMove mockups. Prompts and provenance are in `docs/design/asset-prompts.json`.
- `images/mock-*.png`: generated demo cargo inspection and proof-of-delivery
  photos. They contain no real people, labels, addresses, or personal data.
- `illustrations/*.svg`: original vector empty, waiting, and success states for
  Iteration 2 driver flows.
- Iteration 2 raster prompts, icon inventory and dynamic-asset decisions are in
  `docs/design/iteration-2-asset-prompts.json`.

These are separate assets used by native Flutter controls. App screens are not
flattened images. The remote Customer and Driver flows use vehicle specifications
and fares from the API. Demo values exist only in the separate mock Driver mode.

With a configured key, the driver map is a native Google Maps view. Its top-down
vehicle marker is drawn once in `driver_map_marker.dart` and supplied to the SDK
as a bitmap; the geographic coverage and animated waves are native SDK circles.
Without a key, the temporary fallback draws the original illustrative map and
animated waves using Flutter Canvas; it is explicitly labelled as a mock map.

## Driver profile sample image

`images/demo-document.png` is a raster rendering of the repository's existing
`documents/identity.svg`, which is an abstract document labelled DEMO. The mock
onboarding picker uses it to exercise upload/retry without real personal papers.
It is not a photographed identity document.

## Customer redesign V1

- `images/customer-email.png`, `customer-security.png` and
  `customer-notifications.png`: transparent decorative illustrations generated
  with the built-in image tool, matching the approved Customer designs.
- `icons/customer-{parcel,cargo,moving}.svg`: original two-color category icons.
- `mail`, `search`, `star`, `coupon`, `eye-off`, `logout`, `edit`, `trash`,
  `ruler`, `history`: new SVG controls extending the existing stroke icon set.
- The existing logo, delivery banner, vehicle cutouts and bundled Inter fonts
  are reused. Customer styles are scoped separately from Driver density.
- Prompts and the full asset inventory are in
  `docs/design/customer-asset-prompts.json`.

Customer screens never use generated shipment evidence, sample QR codes or a
raster map. Those areas render API data, real uploads and native Google Maps.
