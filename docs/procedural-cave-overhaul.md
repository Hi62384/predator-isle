# Procedural cave layout compatibility and verification

Cave layout version 10 replaces the old four-level network generator. The same
world seed now deliberately produces different underground routes and mouths
than older releases; stale baked maps and entrance payloads must not be reused.
Clients and authority servers must run the same layout version and configuration.
Surface terrain seeds remain unchanged. Existing saved underground positions
may need to be relocated to a safe surface position when upgrading.

Ordinary entrances use a maximum of four per region and a 400 m exclusion
distance. Local mouth count is independent of underground route density.
Procedural growth admits routes and rooms against the terrain envelope,
preserving graded return routes. Optional shafts supplement those routes.
Visible streaming closure walls are removed; temporary collision protection
remains until neighboring geometry is ready.

Cave-enabled worlds select the stitched ring terrain topology, including when
an older scene requests the legacy skirt-based quadtree. This avoids deep
vertical LOD skirts intersecting caves. CPU and GPU rendering remain supported;
the legacy quadtree is retained for worlds without caves. The main scene
already uses stitched rings.

Native checks:
- cave-procedural: graph reproducibility, entrance separation, elevation,
  cross-region reachability, route grades, real field and deep mesh extraction.
- cave-visual: rendered actual room/tunnel/exterior contact sheets and SVG
  network profiles (CI artifacts, not illustrative concept art).
- field, cave-payload, cave-biomes, cave-worker, cave-network, cave-discovery:
  canonical numerical and geometry regression fixtures.
- gpu-caves and gpu-cave-scene-* on Compatibility, Forward+ and Mobile:
  GPU/CPU numerical and actual mesh comparisons.

GitHub Actions artifacts and numerical reports are the source of verification
results. Software-rendered CI does not establish physical GPU frame-time
performance. A real free-flight reproduction of the originally reported
underground faces and mouth flashing is still necessary before claiming those
visual symptoms have been eliminated in every scenario.
