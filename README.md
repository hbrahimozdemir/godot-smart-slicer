# SpriteForge - Godot 4 Sprite Slicer & Background Remover

A powerful Unity-style sprite editor and slicing tool for Godot 4, featuring smart background removal (perfect for AI-generated or flat background art).

## Features
- **Smart Background Remover:** Perceptual color clustering (K-means) + BFS flood fill + smoothstep edge matting to clean up solid or gradient backgrounds.
- **Visual Slicing Editor:** Manual slice creation (Right-click drag), multi-selection box (Left-click drag), resize handles, and zoom support.
- **Multi-Slice Manipulation:** Select and move multiple slices together, or delete them all at once.
- **Flexible Export:** Extract slices instantly as individual PNGs or AtlasTextures.

## Installation
1. Copy the `addons/sprite_forge` folder to your Godot project's `res://addons/` directory.
2. Enable the plugin via **Project -> Project Settings -> Plugins**.
3. The **SpriteForge** panel will appear in your bottom editor panel.

## Usage Guide
1. **Browse:** Select the sprite sheet texture you want to edit.
2. **Remove BG (Optional):** If your texture has a flat/gradient background, adjust the tolerance and click **Remove BG**. This automatically saves a clean transparent copy as `*_nobg.png` and loads it into the canvas.
3. **Auto Slice:** Click to detect and slice sprites automatically.
4. **Fine-Tuning:**
   - **Right-Click Drag** anywhere on the canvas to draw a new custom slice.
   - **Left-Click Drag** over empty space to select multiple slices using a selection box.
   - **Ctrl/Shift + Left Click** to add/remove specific slices to the selection.
   - Drag selected slices to move them together.
   - Drag red corner handles to resize.
5. **Delete Slices:** Press **Delete** (or Backspace on macOS) to remove selected slices, or click the **Delete Selected** button.
6. **Extract Slices:** Choose either `PNG` or `AtlasTexture` from the dropdown and click **Extract All**. Slices are extracted to a separate folder inside your assets.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
