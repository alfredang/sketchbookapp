# CLAUDE.md

Guidance for working in this repository.

## Project

**Sketchbook Studio** — a native iPhone & iPad sketching app (SwiftUI + PencilKit +
RealityKit). Live on the App Store (bundle `com.tertiaryinfotech.sketchbookapp`, team
`GU9WTSTX9M`).

## Structure

- `Sketchbook/App/` — app entry, orientation lock.
- `Sketchbook/Drawing/` — `CanvasView` (the `PKCanvasView` wrapper), symmetry, perspective
  guides, templates, flood fill, filters, layer compositor.
- `Sketchbook/Models/` — `SketchDocument` (multi-page, Codable + legacy migration), `Page`,
  `Layer`, `BrushType` (brush library → PencilKit ink types), `PencilGrade`, `Template`.
- `Sketchbook/Features/` — `Editor` (view + `EditorViewModel` + toolbar/side panels),
  `Gallery`, `Settings`, `About`.
- `Sketchbook/Store/` — `DocumentStore` (iCloud + local), sample art.
- `SketchbookUITests/` — XCUITest screenshots + drawing/multi-page validation.

## Build & release

- **XcodeGen project**: edit `project.yml`, then `xcodegen generate`. The version is
  `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`; `App/Info.plist` uses
  `$(…)` placeholders, so bump only `project.yml`.
- **Build number must strictly increase** on every App Store upload.
- App Store submission is driven via the App Store Connect API — see the
  `app-store-submission` / `ios-app-update` skills and the gitignored `.env`
  (`ASC_*` keys; the `.p8` lives outside the repo). Never commit `.env` or `*.p8`.
- Install on a device: `ios-install-device` skill (`xcrun devicectl`).

## Conventions

- Keep drawing input robust: a SwiftUI `.scaleEffect` over `PKCanvasView` breaks Pencil/
  touch input — use PencilKit's own `zoomScale` for canvas zoom. Never reassign
  `canvas.drawing` while a stroke is in progress (gate on `canvasViewDidBegin/EndUsingTool`),
  or the live stroke is cancelled.
- Commit drawing changes to the model synchronously on stroke end (not async), to avoid a
  re-render resetting the canvas to a stale value.

## Follow-ups / future work

See **[ROADMAP.md](ROADMAP.md)** for the tracked backlog. After **1.2** is approved on the
App Store, prioritise the **P0 multi-page content-loss bug** (drawings lost when navigating
between pages — pre-existing since 1.1). Planned features include **vector shapes** and
**color-filling vector shapes**. Update ROADMAP.md as items are completed or added.
