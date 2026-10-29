"""Collect actual run evidence and fingerprint the delivered local sources/build."""
import hashlib
import json
import subprocess
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8-sig"))


def fingerprint(path):
    item = ROOT / path
    digest = hashlib.sha256()
    with item.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return {"path": path, "bytes": item.stat().st_size, "sha256": digest.hexdigest()}


checks = {}
for label, path in {
    "core": "tools/diagnostics/artifacts/native_core_results.json",
    "canonical": "tools/diagnostics/artifacts/canonical_neighbors.json",
    "invariants_and_cpu": "tools/desert/cpu_checks_windows.json",
    "prepared_resources": "tools/desert/current_shader_assets.json",
    "saved_grass": "tools/desert/current_saved_preset_grass.json",
    "dune_culling": "tools/desert/dune_culling_results.json",
    "height_only_derivatives": "tools/desert/height_only_results.json",
    "normal_sampling_modes": "tools/desert/normal_sampling_results.json",
    "drainage_culling": "tools/desert/drainage_culling_results.json",
    "sparse_halo_and_allocations": "tools/desert/sparse_halo_results.json",
    "far_mesh_budget": "tools/desert/far_mesh_budget_results.json",
    "visible_broad_rock_relief": "tools/desert/rock_relief_results.json",
    "gpu_channels": "tools/diagnostics/artifacts/channel_report.json",
}.items():
    value = read(path)
    assert not value["failures"], (label, value["failures"])
    for path, digest in value.get("source_hashes", {}).items():
        assert fingerprint(path)["sha256"] == digest, ("Stale check", label, path)
    checks[label] = {"passed": True, "report": path, "data": value}

previews = read("tools/desert/artifacts/preview_report.json")
matrix = read("tools/desert/artifacts/dune_matrix.json")
assert matrix["completed"] and not matrix["failures"] and len(matrix["captures"]) == 45
assert len(matrix["landmarks"]) == 15
assert len({row["seed"] for row in matrix["landmarks"]}) == 3
assert len({row["family"] for row in matrix["landmarks"]}) == 5
for path, digest in matrix["source_hashes"].items():
    assert fingerprint(path)["sha256"] == digest, ("Stale dune matrix", path)
for row in matrix["captures"]:
    assert fingerprint(row["file"].removeprefix("res://"))["sha256"] == row["sha256"]
bed_audit = read("tools/desert/drainage_bed_audit.json")
assert all(row["dry_downstream_uphill_steps_over_2m"] == 0 for row in bed_audit["results"])
checks["drainage_beds"] = {"passed": True, "report": "tools/desert/drainage_bed_audit.json", "data": bed_audit, "criterion": "No dry centerline downstream rises over 2 m; wet shore intersections reported separately."}
assert previews["completed"] and len(previews["captures"]) == 72
for path, digest in previews["source_hashes"].items():
    assert fingerprint(path)["sha256"] == digest, ("Stale terrain captures", path)
assert len([row for row in previews["captures"] if "_debug_" not in row["name"]]) == 39
for row in previews["captures"]:
    assert (ROOT / row["file"].removeprefix("res://")).is_file()
    assert fingerprint(row["file"].removeprefix("res://"))["sha256"] == row["sha256"], ("Replaced capture", row["name"])
launches = read("builds/windows/verified_launches.json") if (ROOT / "builds/windows/verified_launches.json").exists() else []
for row in launches:
    assert row["exported"] and not row["failure"] and row["loaded_chunks"] > 0

baseline = read("tools/desert/artifacts/native_baseline.json")
current = read("tools/desert/artifacts/native_current.json")
normal_reference = read("tools/desert/artifacts/native_normal_reference.json")
assert not baseline["failures"] and not current["failures"]
assert not normal_reference["failures"] and normal_reference["viewport"] == current["viewport"]
assert current["fast_desert_normals"] and not normal_reference["fast_desert_normals"]
assert baseline["viewport"] == current["viewport"]
project_checks=read("tools/desert/project_test_run.json")
assert len(project_checks)==20 and all(row["exit_code"]==0 for row in project_checks)
eligible=subprocess.check_output(["git","ls-files","-c","-o","--exclude-standard","-z"],cwd=ROOT).split(b"\0")
eligible_sizes=sorted([( (ROOT / path.decode("utf-8")).stat().st_size,path.decode("utf-8")) for path in set(eligible) if path and (ROOT / path.decode("utf-8")).is_file()],reverse=True)
assert eligible_sizes[0][0]<50*1024*1024
paths = ["project.godot", "scenes/main.tscn", "export_presets.cfg", "config/world/terrain_settings.tres", "config/biomes/desert_settings.tres", "config/rendering/cliff_normals.tres", "config/rendering/ground_materials.tres", "data/desert_previews.json"]
paths += [str(path.relative_to(ROOT)).replace("\\", "/") for folder in ["scripts", "shaders"] for path in (ROOT / folder).iterdir() if path.suffix != ".uid"]
paths += ["materials/desert_color_roughness_geology.tres", "materials/desert_normals_geology.tres", "materials/desert_color_original_salt.res", "materials/desert_normal_original_salt.res"]
result = {
    "collected_utc": datetime.now(timezone.utc).isoformat(),
    "state": "20 project checks plus a normal-only framebuffer relief check verified; all five dune families rendered in three signed seeds, plus the 72-view geographical sweep. Exact allocation/halo optimization, bounded far-Desert refinement and filtered broad rock gradients retained. CPU baseline parity is still not achieved; no blanket photographic acceptance.",
    "current_receipt": "tools/desert/CLOSEOUT_20261015.txt",
    "export_instruction": "Exports and their launch checks below occurred before the user requested no further exports. No export is performed by this collector.",
    "engine": current["engine"], "renderer": current["renderer"], "adapter": current["adapter"],
    "functional_checks": checks,
    "project_test_run": project_checks,
    "git_eligible_file_sizes": {"over_50_MiB":[],"largest_ten":[{"bytes":size,"path":path} for size,path in eligible_sizes[:10]],"history_note":"155227707-byte old palette blob remains in refs/original/refs/heads/main, but is not reachable from current main/HEAD. No history rewrite performed."},
    "actual_feature_views": 39, "diagnostic_views": 33,
    "preview_report": "tools/desert/artifacts/preview_report.json",
    "dune_matrix": {"report": "tools/desert/artifacts/dune_matrix.json", "captures":45,"families":5,"seeds":3},
    "exported_launches": launches,
    "native_comparison": {"baseline": baseline, "current": current},
    "native_normal_sampling_comparison": {"central_reference": normal_reference, "two_probe": current},
    "sources": [fingerprint(path) for path in sorted(paths)],
    "prior_build": [fingerprint("builds/windows/" + name) for name in ["PredatorIsle.exe", "PredatorIsle.pck"] if (ROOT / "builds/windows" / name).exists()],
    "limitations": [
        "Rock-heavy canonical sampling and chunk generation remain slower than simple Desert; no zero-regression claim.",
        "13 geographical features and five dune families across three seeds were rendered at three distances; photographic parity and every possible seed are not certified.",
        "Ordinary-slope per-triangle texture rotation is removed; steep-face correction remains. Distant Desert edges are bounded at 512m except the 64x64 cap. Angular heightfield silhouettes can still exist; no photographic-parity claim.",
        "The richer biome remains more CPU-expensive than the refreshed simpler baseline. Exact optimizations and work balancing do not imply zero overhead for added geology.",
        "Salt is original procedural PBR per user direction, not a licensed external photoscan.",
        "Star/parabolic dunes, shelter and erosion are bounded approximations, not physical simulations.",
        "Only Windows x86_64 release was built and launched. Other operating systems/GPUs are unverified.",
    ],
}
output = ROOT / "tools/desert/final_verification.json"
output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"Verified evidence collected: {output}")
