# Authorized verification continuation

The user lifted the no-tests restriction on 14 October 2026. Compilation, tests,
native visual checks and performance work are authorized, subject to normal approval
and resource guards. SOURCE_DELIVERY_20261014.json and SOURCE_REVIEW_20261014.md
describe the preceding source-only delivery; they are historical, not a completion
or current validation claim.

Only one worker is used. No model/reasoning override, extra task, commit, push,
reset or animal edit has been requested or performed.

## Native bounded core completed; full-project checks pending

Parent granted the sole bounded-core slot after Coraline released it. Native Godot
4.6.1 completed the current copied sampler/settings/drainage check at 18:24 UTC.
Actual result: **1,839 exact comparisons**, three seeds (73921, 12345, 90317),
**zero failures**. The harness also checks finite heights/controls and bounded
region/site/dune/catchment/tile caches. Exact record equality covers reversed query
order, cache eviction and reconfiguration, including height, material controls,
family, region, fan and crest state. Source hashes are retained alongside results.

Artifacts: `artifacts/current_core_20261014_182443_aab87050/`:
`native_core_results.json`, `source_sha256.json`, `core.stdout.log`,
`core.stderr.log` (empty) and `core.supervision.json`.

Core elapsed: 5.096017 seconds; supervised process elapsed: 5.9967221 seconds.
Peak child working set: **89,182,208 bytes**. System free RAM before child:
**974,061,568 bytes**; minimum during child: **832,212,992 bytes**. Retained limits:
512 MiB entry, 384 MiB running-free floor, 256 MiB own-child cap, 120 seconds.
The child exited with code 0; no RAM guard was crossed. The slot is released.

This parses/executes the three isolated current core modules. It does **not** validate
full-project import, meshes, seams/LOD, Grass, shader/PBR, visuals, streaming or the
CPU nonregression target. No additional heavy job was launched in that slot.

- `run_current_verification.ps1`: selects core/import/invariants/slopes/profile
  sequentially, captures exact source hashes and owned-child logs/resource limits.
  Full-project stages retain the 3 GiB entry guard. The isolated core stage retains
  the existing 512 MiB entry / 384 MiB running-free / 256 MiB child cap, and copies
  actual current sampler/settings/drainage without changing sampling logic.
- `profile_current_desert.gd`: current Desert stage instrumentation for region
  weights, wind, dunes, isolated candidates and drainage, over matching fixed
  footprints. Nested timer overhead is explicitly excluded as acceptance evidence;
  uninstrumented comparable baseline/current measurements remain necessary.
- PowerShell parser check of the new runner passed with no syntax errors. This is
  not Godot parsing, a runtime test, or terrain acceptance.
- Corrected resistant-cap selection on rocky plains: the site's retained style
  value lies inside the rocky selection interval, so cap style is now normalized
  inside that interval instead of using an unreachable threshold.

## Exact resource blocker

Read at 2026-10-14T18:17:08Z: free RAM **1,250,381,824 bytes** (about 1.16 GiB).
Full project minimum: **3,221,225,472 bytes** (3 GiB). No full-project Godot job was
launched. Parent order is Kiwi initial slot, Coraline conditional slot, then Desert.
The bounded-core run subsequently received clearance and completed as recorded
above. Full-project stages remain blocked; no user application has been closed.

The old Windows command tool reports `tunnel_client_not_seen`; workspace tools still
read/write the actual local checkout. Native resource reads needed reviewed sandbox
escalation and succeeded. No approval settings or safeguards were changed.

## Salt source search

Official Poly Haven texture API was retrieved: no asset identifier/tag matched salt.
Official ambientCG API query `q=salt&type=Material&limit=20` returned zero results.
No authentic, suitably licensed salt-crust PBR set was identified by those searches.
An attempted TextureCan search URL did not provide a usable salt result. This is
not proof that no salt asset exists anywhere. Existing Ground033 remains a pale
sediment approximation; no mislabeled asset, spending or regenerated palette.

Remaining work: execute current Godot parsing and canonical/seam/LOD/Grass/slope
checks, resolve failures, obtain measured current bottlenecks, optimize against
comparable baselines, inspect native ground/medium/far views and shader lighting,
measure streaming/GPU/memory and reconcile all 53 acceptance requirements.

## Independent follow-up prepared after slot release

`check_canonical_neighbors.gd` and runner `-Stage canonical` prepare actual builder
height comparisons against the preserved pre-Desert builder for pure Grass and
pure Grass neighbors in a mixed world, plus identical world coordinates and Desert
controls across worker chunk spans 128/256/512/16384 m. The fixture copies actual
code/settings, replacing global class registration with explicit preload constants.
It creates no meshes/GPU terrain. **Not run**; awaits a coordinated slot with
512 MiB entry / 384 MiB floor / 256 MiB cap. It cannot prove mesh seams/rendered LOD.

All 18 original ambientCG map hashes matched fresh reads. An official CC0 cracked
riverbed clay scan was downloaded with verified size/MD5 and retained SHA256/license
provenance; all three source maps were inspected. Separate palette packing/binding
source is prepared, preserving original resources. Packing and shader validation
are pending. See [MATERIAL_RESEARCH_20261014.md](MATERIAL_RESEARCH_20261014.md).

## Native canonical-neighbor check completed

Granted slot executed `-Stage canonical` on native Godot 4.6.1 at 18:38 UTC.
Actual result: **13,117 assertions**, **zero failures**; **1,566** pure-Grass
neighbor locations across three seeds and **2,304** exact equivalent-coordinate/
Desert-control comparisons across 128/256/512/16384 m worker spans. Pure Grass
canonical heights and geological controls also match the preserved pre-Desert
builder, including altered Desert settings. This is height/control sampling,
not generated mesh, shader, seam, visual or performance acceptance.

Artifacts: `artifacts/current_canonical_20261014_183801_0318f260/`, including
`canonical_neighbors.json`, source hashes and `canonical.supervision.json`.
Query-check elapsed: 0.432411 seconds; supervised child elapsed: 1.4388304 seconds.
Peak child working set: **100,929,536 bytes**. Free RAM before: **2,143,019,008**;
minimum while running: **2,088,005,632 bytes**. Exit 0, no guard crossed. A copied
settings-resource UID warning resolved through its correct text path; no error.
The child exited and slot was released. No full-project job was attempted.

`run_clay_preparation.ps1` is now prepared for a separate coordinated packing slot.
It uses the existing isolated asset limits: **768 MiB entry**, **384 MiB running
floor**, **384 MiB child cap**, **180 seconds**. It stages exact source maps and
original resources, validates compressed formats/mips/byte counts, rechecks all
original material hashes, refuses existing/conflicting outputs, then publishes only
four new resources with hash-verified readback. PowerShell syntax parsed without
errors; **no packing child has launched yet**. Full-project 3 GiB guard remains.

## Clay palette packed and published

Parent granted the sole isolated-packing slot. Native Godot 4.6.1 completed at
18:42 UTC, exit 0, no stderr errors. Actual formats were checked in the packer:
2K DXT5/BC3 color plus linear roughness alpha, **5,592,432 bytes**; 1K RGTC_RG/BC5
OpenGL XY normals, **1,398,128 bytes**; both contain mipmaps. Output checks confirmed
expected byte counts and CC0 metadata. All **14 original material resource hashes**
were rechecked unchanged before publication. Four new resources were published
only after output/conflict checks and their copied SHA256 readbacks matched.

Receipt: `clay_palette_delivery.json`. Owned-child logs and original hash manifest:
`artifacts/current_clay_20261014_184214_34b98218/`. Peak child working set:
**143,089,664 bytes**; free RAM before: **3,934,302,208 bytes**; minimum during:
**3,813,941,248 bytes**. Supervised elapsed: **0.9768567 seconds**. Existing packing
guards (768 MiB entry, 384 MiB floor/cap) were preserved and never crossed. The child
exited and the slot was released for Kiwi. No full-project Godot launch occurred.

Runtime binding will select the published alternative six-layer arrays and 2 m clay
repeat on the next terrain session. Actual array loading/shader binding, compressed
normal lighting and rendered appearance still require current full-project checks.
The improved free-RAM reading is evidence for a future resource recheck, not permission
to overlap another project's slot. Authentic salt-crust material remains missing.

## Resumed after computer restart

User explicitly resumed after restart. Actual dirty-tree work and all four clay
delivery hashes were reread; **4/4** prepared resources match. Earlier 1,839 core
and 13,117 canonical assertions/receipts remain preserved. No repeat of those
passing runs has been launched.

Post-restart read at 18:59:19Z: free RAM **2,803,150,848 bytes**, total physical
**16,388,108,288 bytes**. Existing Godot PID 9380 was visible with working set
173,907,968 bytes; it was not launched/closed by this resumed turn. Full-project
minimum remains **3,221,225,472 bytes**. Heavy slot order: Kiwi, Coraline, Predator.
No overlapping or blocked full-project attempt occurred.

`run_current_verification.ps1` now selects full-project import, shader/assets,
invariants, slopes, profiling, saved-preset Grass, drainage, crossings and discovery.
`check_shader_assets.gd` prepares actual script/shader/palette/settings compatibility
checks. The native capture harness now rejects headless execution explicitly.
Runner PowerShell syntax passed; new Godot checks await the coordinated slot and
fresh RAM guard. Full visual, GPU/streaming and performance acceptance remains open.
