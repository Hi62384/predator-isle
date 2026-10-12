# Configure cliff normals

The supplied normal maps are external binary `materials/cliff_texture_*.res`
resources. Keep them external (do not use **Make Unique** on the texture itself).
For replacements, drag an imported normal-map image from FileSystem onto Normal
Texture. This keeps settings small when saved; embedded ImageTextures can expand
into hundreds of megabytes of text. Duplicating a layer does not require making
its texture unique.

## Open the controls

In Godot's **FileSystem** panel, open **res://cliff_normals.tres**. The Inspector
shows the global settings and a **Layers** list. Expand a named layer to edit it.
You can also select **Terrain** in `main.tscn`, then expand **Cliff Normal
Controls → Cliff Normal Settings**. Both point to the same saved resource.

Run the game once after this update. Keep the editor open, edit the saved resource
in the **local** Inspector, then select the root `cliff_normals.tres` resource and
use the Inspector resource menu's **Save** action. The running game checks the
file every half second and applies saved changes to every LOD. File timestamps
have one-second granularity, so allow a second after saving. No terrain rebuild
is required. Texture additions/replacements can briefly pause while repacking.

Remote Inspector changes also apply but are temporary; save changes in the local
resource if you want them next run. Save the root config when editing nested
layers. Changes to separately saved external layer resources require resaving
the root config to trigger its file watcher. This watcher monitors the config,
not external image bytes: restart after replacing an image file in place.

## Per-texture controls

| Control | Meaning |
| --- | --- |
| Label | Name displayed for this configuration |
| Enabled | Temporarily disable without deleting |
| Normal Texture | Drag an OpenGL normal-map texture here; not an albedo |
| Band | Macro or Medium; determines overlap budget and distance fade |
| Strength | This texture's normal intensity, multiplied by global band strength |
| Texture Size Metres | Width of one repeat; bigger = larger rock features |
| Noise Size Metres | Coverage patch size; smaller = more frequent changes |
| Noise Cutoff | Lower = more coverage; higher = fewer patches |
| Noise Edge Softness | Larger = softer/wider coverage transitions |
| Noise Breakup Strength | Amount of smaller coverage breakup; zero disables it |
| Noise Breakup Frequency | Larger = smaller breakup patterns |
| Noise Seed | Changes placement; give different entries different seeds |
| Rotation Degrees | Fixed texture rotation, not camera-dependent |
| Texture Offset | Offset in repeat units |
| Flip Normal Y | Enable for DirectX normals; off for ambientCG NormalGL |

Each texture has its own noise size and cutoff. Changing a cutoff also affects
its priority relative to other layers competing for the limited overlap slots.
Turning a layer off or setting strength to zero removes it from that competition.

## Add, remove or replace

- **Add:** expand Layers, increase its array Size by one, and choose **New
  CliffNormalLayer** in the empty element's resource dropdown. Expand it, name
  it, drag a normal texture into Normal Texture, choose a band, and set a unique
  Noise Seed. Save the root config. Up to **16 entries** are supported.
- **Remove:** use the array element's delete/remove action (or reduce Size for
  the last entry). Save. Use Enabled for reversible experimentation.
- **Replace:** drag another normal image from FileSystem onto the entry's
  Normal Texture field. All other settings stay intact. Save.
- **Duplicate:** duplicate a layer resource and make it unique before editing;
  otherwise two array slots can refer to the same resource. Set a different seed.
- **Reorder:** use the array element's move/drag controls. Seeds and settings
  travel with their entries. Update Isolate Layer if you were using an index.

Add new PNG/JPG normal files inside the project first and let Godot import them.
The runtime packs maps to linear 2K BC5 with mipmaps; new resolutions are resized.
It does not generate a normal map from an ordinary photo. You do not need to edit
the old fixed texture array, source manifest, palette, or shader to change the list.
An empty list or null texture slots are safe. Only the first 16 entries are used.

## Global controls and debugging

- Global Strength: macro, medium and existing base micro normals.
- Max Macro/Medium Layers: 0–2 simultaneous overlays in each band. Higher costs
  more texture sampling. The list can contain more entries than this budget.
- Selection Blend Width: softness of the handoff between competing textures.
- Fade Start/End: distance in metres; changes strength, never texture scale.
- Debug Mode: Combined, Base Only, Macro Only, Medium Only, Coverage, Texture IDs,
  or World Normals. Coverage uses red for macro and green for medium.
- Isolate Layer: zero-based list index, or **-1** for normal mixed rendering.
  Forces that texture at full coverage; keep its band's overlap limit above zero.

**Suggested tuning workflow:** isolate one entry, tune Texture Size and Strength,
then set Isolate Layer back to -1. Use Coverage view while changing Noise Size,
Cutoff and Softness. Finally return Debug Mode to Combined and inspect overlaps.

The resource is now the source of truth. Don't tune duplicate shader parameters
on terrain materials: the config will override them when its values change.
