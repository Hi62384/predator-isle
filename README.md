# Predator Isle

Open `project.godot` in **Godot 4.6.1 .NET** and press **F5** to run the game.
The standard editor cannot run the migrated C# systems. Install the .NET 8 SDK
and build `PredatorIsle.csproj` before running outside the editor. The local
.NET editor is under `.tools/Godot_v4.6.1-stable_mono_win64/` on this workstation.
The launch scene is `scenes/world_startup.tscn`; the world is `scenes/main.tscn`.

C# migration is the current first priority. New runtime code is under
`scripts/csharp/`; preserved GDScript modules remain during the migration as
dependencies and comparison references. The migration is not yet complete.
The Hoogie project and its textures are excluded from this work.

Mouse movement looks around. **Escape** releases the cursor; click the game
to capture it again. **Backtick (`)** shows or hides terrain diagnostics.

Finished nearby chunks appear during initial loading; the distant terrain keeps
generating in the background. Camera-adjacent chunks use a 2 m geometry grid at
the standard chunk size. The saved world uses a broader biome height blend
(`height_blend = 3`) so mountain borders develop more gradually. Restart after
changing world generation settings.

| Folder | Contents |
| --- | --- |
| `config/world/` | Saved world generation preset |
| `config/biomes/` | Surface biome settings |
| `config/caves/` | Shared cave settings, registry and cave-biome definitions |
| `config/rendering/` | Ground material and cliff-normal controls |
| `scenes/` | Game launch and main world scenes |
| `scenes/labs/` | Blob development scenes |
| `scripts/` | Runtime terrain, caves, camera and creature code |
| `shaders/` | Runtime shaders and shared shader functions |
| `materials/` | Packed runtime texture banks and materials |
| `assets/` | Source artwork and textures |
| `docs/` | Terrain notes, material controls, creature reports and workflows |
| `data/` | Preview catalogues, provenance and recorded validation summaries |
| `tools/` | Generation checks, benchmarks and diagnostic tooling |

Generated diagnostic images/reports live under tool-specific `artifacts/`
folders, hidden from Godot's resource browser. Historical evidence is retained
without rewriting its original source hashes. The root resource relocation map
is `config/resource_path_migration.json`; a recoverable migration manifest is
under `tools/maintenance/artifacts/`.

Current implementation details and test limits are in
[the terrain notes](docs/terrain/TERRAIN_TUNING.md).
