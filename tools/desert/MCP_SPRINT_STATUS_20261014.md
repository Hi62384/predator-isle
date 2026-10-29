# Predator MCP sprint status

Started 2026-10-14 19:27:48 UTC; target handoff by 21:27:48 UTC.
User authorized MCP execution and testing; full original requirements remain in scope but are not accepted by the time target alone.
Only Local Project Tools and Windows Command Tools are used for local files/execution. No native shell/file fallback, Codex CLI, commit, push, animal edit, or extra worker has been used.

Coraline holds the heavy slot. Predator requests the next available short slot for full-project import, current shader/assets validation, actual mesh invariants and current stage profiling. Full-project entry guard remains 3 GiB free RAM. No Godot process has been launched this sprint.

Ownership: this worker owns scripts/desert_sampler.gd, scripts/desert_drainage.gd and tools/desert verification/profiling harnesses. Preserve all pre-existing dirty changes.

Suggested disjoint support tasks for parent assignment (no workers spawned here):
- Read-only salt-crust PBR source/license research. Require a real suitably licensed source; no purchase, login, generated stock or relabeling clay as salt. Return candidate URLs, actual maps, physical scale and license evidence; do not download/modify files.
- Read-only review of shaders/desert_material.gdshaderinc and related shader transport/projection/normal blending. Report concrete defects with locations; do not edit runtime files.
- Read-only audit of tools/desert/USER_REQUIREMENTS.txt against SOURCE_REVIEW_20261014.md and actual implementation. Prioritize significant missing behavior over cosmetic changes.

Connector note: first parallel directory listing returned MCP initialization-required 409 while the independent read succeeded; the sequential directory retry succeeded. No persistent blocker currently established. Use sequential connector calls to avoid initialization races.

Prepared source changes in this sprint (not executed yet):
- check_saved_preset.gd now exits nonzero for a changed full mesh or unexpected non-Grass sample and writes current_saved_preset_grass.json instead of replacing the historical cloud report.
- profile_current_desert.gd now separates cached/cold region and drainage descriptor work, wind/dunes, ordinary versus instrumented sampling, near/far footprints and actual builder height/normal/mesh stages. Checksum comparison guards against instrumentation changing results. No performance claim.
- run_current_verification.ps1 records wider source hashes, archives previous/current outputs in the unique run directory, retains failed reports, and rejects missing/stale reports. Memory/time guards unchanged.
- Sequential connector retry and Windows tools-info succeeded; no pending local approval or command job exists.

Requested next heavy slot: import, shader_assets, profile, invariants, grass (one at a time, with full 3 GiB guard). Parent may grant a shorter prefix. A Windows Command Tools local dialog remains required by that connector; no prompt queued yet.

Historical evidence retained: 1,839 core comparisons, 13,117 canonical assertions, CC0 clay packing/hash verification. No current full-project visual/performance acceptance. Historical hard CPU target failed; current profiling needed before optimization.
