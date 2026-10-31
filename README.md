# Predator Isle

Open `project.godot` in **Godot 4.6.1 .NET** and press **F5** to run the game.
On Windows, double-click **Open Predator Isle.cmd** to build and open the bundled
.NET editor. Opening the project with the standard Godot editor reports
"No loader found" for `.cs` files and cannot launch the game.
Double-click **Run Predator Isle.cmd** to build when inputs have changed, refresh C# registrations and
run the game directly with the bundled .NET engine. This also repairs a missing
C# project flag after the standard editor has saved the project. A "newer scene
format" alert for `world_startup.tscn` can be the standard editor failing to load
its C# script; the scene uses the supported Godot 4 text format.
The standard editor cannot run the migrated C# systems. Install the .NET 8 SDK
and build `PredatorIsle.csproj` before running outside the editor. The local
.NET editor is under `.tools/Godot_v4.6.1-stable_mono_win64/` on this workstation.
The launch scene is `scenes/world_startup.tscn`; the world is `scenes/main.tscn`.

All 142 original runtime modules have C# implementations and bindings under
`scripts/csharp/`. Original GDScript remains as comparison/compatibility source.
The last completed 15-group automated feature suite passed; its scope and measurements are
recorded in `data/feature_validation_latest.json`. The subsequent direct-callback
loading optimization compiles but has no new runtime/timing acceptance yet.
Full scenic/reference-quality
and long underground walking acceptance remain open.
The Hoogie project and its textures are excluded from this work.

Run the C# migration checks after building the game with
`dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- all`.
The runner manages only its own Godot processes, preserves per-run logs under
`.godot/csharp_checks/`, and records current results under `data/csharp_check_*`
and `data/csharp_runner_latest.json`. Its modes are `general`, `field`, `worker`
and `startup`, with additional focused ring, biome, blob, server and rendering
checks; performance measurements cover their recorded cases.

Mouse movement looks around. **Escape** releases the cursor; click the game
to capture it again. **Backtick (`)** shows or hides terrain diagnostics.

The main world now selects world-aligned nested 3×3 terrain rings. The standard
profile uses 16 m nearby patches with 1 m visual vertices; Low uses 2 m and Ultra
uses 0.5 m. Nearby ground collision uses a fixed 1 m CPU grid for every profile.
The startup path can publish the central nine patches while distant work continues.
These behaviors have component tests plus a saved-launch physical move and return.
The saved world uses a broader biome height blend
(`height_blend = 3`) so mountain borders develop more gradually. Restart after
changing world generation settings.

Ring settings, quality profiles, server residency, canonical height changes and
current limitations are described in [the ring streaming notes](docs/terrain/TERRAIN_RING_STREAMING.md).

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
