# SpriteForge architecture

The editor plugin loads `slicer_ui.tscn`. Existing UI and canvas callbacks remain
available as facades, preserving signal connections and editor integration.
Collaborators are composed with their host rather than chained through inheritance.

| Component | Responsibility |
| --- | --- |
| `slicer_ui.gd` | Coordinate tool selection, loading, slicing, export and selection properties |
| `slicer_toolbar_builder.gd` | Construct toolbar controls and connect callbacks |
| `slicer_sidebar_builder.gd` | Construct properties, export settings and the scrollable preview panel |
| `slicer_image_controller.gd` | Execute pixel edits, publish textures and save edited copies |
| `slicer_history_controller.gd` | Capture and restore complete image and slice snapshots |
| `slicer_history.gd` | Maintain undo/redo stacks (Memento caretaker) |
| `slicer_text_controller.gd` | Load fonts and render text using temporary viewports |
| `slicer_canvas.gd` | Own canvas state and route mouse/keyboard input |
| `slicer_canvas_renderer.gd` | Draw sprites, selection overlays, checkerboards and frame gizmos |
| `slicer_canvas_actions.gd` | Manipulate slices and generate magic-wand previews |
| `background_removal.gd` | Estimate border colors and remove connected background using scanline filling |

Builders bind controls to host callbacks once during construction. Controllers
access the host through a dynamic reference to avoid circular GDScript preloads.
They do not duplicate editor state. Canvas rendering remains inside the host's
`_draw` callback, as required by Godot's drawing API.

Brush operations reuse an existing ImageTexture when size and format match;
other edits publish a fresh texture. Undo snapshots remain separate image copies.
History restoration updates memory without rewriting original source files.

## Validation

Copy the addon into a Godot project, then run:

```sh
godot --headless --path /path/to/project --script res://addons/sprite_forge/tests/regression.gd
```

The test creates its fixtures in `user://spriteforge-tests`. It covers complete
undo/redo, source-file preservation, exports, preview synchronization, sidebar
scroll mode, slice duplication/merging/deletion, resizing, flipping, frame
geometry, wand previews and brush texture reuse. Treat any engine script error
as failure even if the final assertion summary says PASS. Rendering and text
capture were also checked with the Compatibility renderer in the test project.

Background removal has a separate test suite:

```sh
godot --headless --path /path/to/project --script res://addons/sprite_forge/tests/background_removal.gd
```

The algorithm classifies raw RGBA pixels using squared weighted color distance,
then queues horizontal spans instead of individual pixels. Feather distances use
one byte per pixel and are seeded only by newly removed opaque background.
Fully transparent border pixels do not contribute hidden RGB values to color
estimation. Removal remains based on border colors and connectivity: foreground
touching the border or matching the inferred background can still be removed.
