# Changelog

## 1.1.4 — 2026-10-02

### Improved
- Reorganized the toolbar into Image, Slice, Paint and Compose tabs. Image tools, including Remove BG, now appear before slicing tools.
- Added scrolling to the right settings panel and organized settings into collapsible sections, with an accessible animation preview.
- Kept tool labels in English and synchronized related controls and preview updates.
- Optimized Remove BG with raw RGBA processing, squared color-distance comparisons and scanline filling.
- Reduced feathering memory usage and excluded hidden RGB values of transparent border pixels from background estimation.
- Split UI, canvas rendering, editing, history and text logic into focused components using composition.

### Fixed
- Undo/redo restores image and slice metadata without rewriting original source files.
- Exports use the current edited texture instead of reloading stale image data from disk.
- Corrected frame placement ordering and improved preview synchronization after image edits.
- Updated automatic tab selection to match the new toolbar order.

### Validation
- Added regression coverage for history, source-file preservation, exports, editing, previews and canvas operations.
- Added background-removal tests, including connectivity checks against a reference flood-fill implementation.

### Scope
- Packaged from commit `0b3d15e` (Update slicer_toolbar_builder.gd), with release metadata and documentation added.
- Background-thread processing, segmented large-sheet removal, progress and cancellation are not included in this release. Very large images can still block the editor during Remove BG.
