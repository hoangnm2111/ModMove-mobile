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
flattened images. All displayed vehicle specifications and fares are demo data.

## Driver profile sample image

`images/demo-document.png` is a raster rendering of the repository's existing
`documents/identity.svg`, which is an abstract document labelled DEMO. The mock
onboarding picker uses it to exercise upload/retry without real personal papers.
It is not a photographed identity document.
