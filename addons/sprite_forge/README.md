# SpriteForge - Godot 4 Sprite Slicer & Background Remover

A powerful Unity-style sprite editor and slicing tool for Godot 4, featuring smart background removal (perfect for AI-generated or flat background art).

## Features
- **Smart Background Remover:** Perceptual color clustering (K-means) + BFS flood fill + smoothstep edge matting to clean up solid or gradient backgrounds.
- **Visual Slicing Editor:** Manual slice creation (Right-click drag), multi-selection box (Left-click drag), resize handles, and zoom support.
- **Multi-Slice Manipulation:** Select and move multiple slices together, or delete them all at once.
- **Grid Slicing:** Subdivide sheets into fixed cell grids with custom offset and separation, automatically discarding empty slices.
- **Positional Batch Renaming:** Spatially sort and rename multiple selected frames sequentially (row-by-row) with smart zero padding.
- **Animation Preview Player:** Preview animation frames in real-time inside the editor.
- **Flexible Export:** Extract slices instantly as individual PNGs, AtlasTextures, or directly as SpriteFrames resources.

## Installation
1. Copy the `addons/sprite_forge` folder to your Godot project's `res://addons/` directory.
2. Enable the plugin via **Project -> Project Settings -> Plugins**.
3. The **SpriteForge** panel will appear in your bottom editor panel.

## Usage Guide
1. **Browse:** Select the sprite sheet texture you want to edit.
2. **Remove BG (Optional):** If your texture has a flat/gradient background, adjust the tolerance and click **Remove BG**. This automatically saves a clean transparent copy as `*_nobg.png` and loads it into the canvas.
3. **Auto Slice / Grid Slice:** 
   - Click **Auto Slice** to detect and slice sprites automatically based on transparency.
   - Click **Grid Slice...** to slice by a regular grid with customizable cell dimensions, offset, padding, and an option to automatically discard empty cells.
4. **Fine-Tuning:**
   - **Right-Click Drag** anywhere on the canvas to draw a new custom slice.
   - **Left-Click Drag** over empty space to select multiple slices using a selection box.
   - **Ctrl/Shift + Left Click** to add/remove specific slices to the selection.
   - Drag selected slices to move them together.
   - Drag red corner handles to resize.
5. **Batch Renaming:** Select multiple slices and type a name in the "Selected Slice" edit field. Slices are automatically sorted in reading order (top-to-bottom, left-to-right) and renamed with smart padded suffixes (e.g., `run_01`, `run_02`).
6. **Animation Preview:** Select slices (or leave selection empty to cycle through all slices) and click **Play** in the "Animation Preview" panel to preview the animation in real-time. Tweak playback speed with the FPS spinbox.
7. **Delete Slices:** Press **Delete** (or Backspace on macOS) to remove selected slices, or click the **Delete Selected** button.
8. **Extract Slices:** Choose the desired formats (PNG, AtlasTexture, and/or SpriteFrames) from the sidebar checkboxes and click **Extract All**. Slices are extracted to a separate folder inside your assets.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
