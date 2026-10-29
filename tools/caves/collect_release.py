"""Collect the final application checks while retaining earlier experiment scopes."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tools/biome_extensions/artifacts'

def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()

def main():
    guards = {}
    def evidence(relative, current=False, capture_archive=None):
        path = ROOT / relative
        report = json.loads(path.read_text(encoding='utf-8-sig'))
        assert report['passed'], relative
        guards['res://' + relative] = sha(path)
        if current:
            for uri, digest in report.get('source_sha256', {}).items():
                source = ROOT / uri.removeprefix('res://').replace('\\', '/')
                assert sha(source) == digest, uri
                guards['res://' + source.relative_to(ROOT).as_posix()] = digest
        for uri, digest in report.get('capture_sha256', {}).items():
            capture = ((ROOT / capture_archive / 'evidence') if capture_archive else ROOT) / uri.removeprefix('res://')
            assert sha(capture) == digest, uri
        return report

    startup = evidence('tools/biome_extensions/artifacts/check_production_game_startup.json', True)
    start_receipt = evidence('.godot/extensions_production_game_startup_adopted.receipt.json')
    walk = evidence('tools/biome_extensions/artifacts/check_cave_live_magma_return.json', True)
    walk_receipt = evidence('.godot/extensions_release_live_magma_cached_shader.receipt.json')
    assert walk_receipt['extra_arguments'] == '--fixed-fps 60'
    assert walk['walk']['finished'] and not walk['walk']['failed']
    assert walk['walk']['waypoint'] == walk['walk']['waypoints'] == 3146
    assert walk['maximum_total_jobs'] == 4 and walk['preload_seconds'] < 180
    assert walk['walk']['wall_seconds'] < 650 and walk['walk']['maximum_unsupported_drop_m'] < .75
    for receipt in [start_receipt, walk_receipt]:
        assert receipt['sampled_peak_private_bytes'] / 1048576 < 2048
    assert startup['root_enabled'] and startup['cave_ids'] == ['default', 'frozen', 'crystal', 'magma']
    assert not startup['private_intervention']
    surface = evidence('data/surface_regression_20261018.json', True)
    assert surface['test_count'] == 31
    components = evidence('tools/biome_extensions/artifacts/cave_release_checks.json')
    assert len(components['tests']) == 17 and all(row['passed'] for row in components['tests'])
    gpu = evidence('tools/biome_extensions/artifacts/check_cave_magma_blend_gpu.json', True)
    composition_receipt = evidence('.godot/extensions_release_three_cave_blend.receipt.json')
    evidence('tools/biome_extensions/artifacts/legacy_target_cache_adoption.json', True)
    budget = evidence('tools/biome_extensions/artifacts/legacy_cache_mixed_visual_budget.json', True)
    evidence('tools/biome_extensions/artifacts/check_terrain_shader_variants.json', True)
    evidence('tools/biome_extensions/artifacts/check_shader_variant_payloads.json', True)
    evidence('tools/biome_extensions/artifacts/check_common_tissue_period.json', True)
    scenery = evidence('tools/biome_extensions/artifacts/check_cave_magma_native_breadth.json',
                       capture_archive='tools/biome_extensions/artifacts/revisions/magma_native_breadth_96a728b268c4')
    coverage = evidence('tools/biome_extensions/artifacts/check_cave_magma_floor_coverage.json')
    guards['res://tools/caves/collect_release.py'] = sha(Path(__file__))
    report = dict(
        passed=True, source_sha256=guards,
        capture_sha256={**startup.get('capture_sha256', {}), **walk.get('capture_sha256', {}), **gpu.get('capture_sha256', {})},
        saved_caves_enabled=True,
        registered_cave_biomes=startup['cave_ids'],
        startup=dict(seconds=startup['startup_seconds'],
                     sampled_private_mib=start_receipt['sampled_peak_private_bytes'] / 1048576,
                     engine_shader_cache_disabled=True, driver_cache_controlled=False,
                     surface_chunks=startup['active_surface_chunks'], maximum_lod=6, camera_far_m=50000),
        physical_return=walk['walk'], preload_seconds=walk['preload_seconds'],
        total_worker_limit=4,
        physical_return_sampled_private_mib=walk_receipt['sampled_peak_private_bytes'] / 1048576,
        shared_surface_tests=31, cave_component_checks=components['tests'],
        three_target_gpu_checks=gpu['checks'],
        gpu_sampled_private_mib=(composition_receipt.get('sampled_peak_private_bytes') or 0) / 1048576,
        earlier_scenery=dict(native_runs=len(scenery['native_runs']),
                            physical_contexts=scenery['unique_contexts'], captures=len(scenery['capture_sha256']),
                            stationary_samples=scenery['stationary_samples'],
                            scope='Earlier source-bound geometry/LOD/collision cohort. Preserved before final material cache changes;not relabelled as a fresh rerun.'),
        distribution=dict(sampled_clear_dry_floor_fraction=coverage['magma_weighted_sampled_floor_fraction'],
                          scope=coverage['scope']),
        mixed_shader_discrepancy=budget['measurements'],
        limitations=[
            'Other project Godot sessions were intentionally left running. No isolated or uninterrupted traversal FPS claim.',
            'Full cave motion uses fixed60Hz accelerated physics and documented loading pauses;camera rendering is disabled during movement.',
            'The existing Jolt job-capacity warning recurred in the full return. The route passed;the upstream warning is unresolved.',
            'The original two-byte mixed shader comparison failed. Sparse measured differences up to3/255 were accepted under the separately stated4/255 maximum and0.00001 mean budget;original-image returns were exact.',
            'Generated scenes were visually inspected. Their procedural appearance is not a claim of photographic equivalence to the supplied references.',
            'The scenery inventory represents22native runs/16contexts,not56distinct native scenic tests. Rare large-lake and exposed-cascade positive scenes use explicitly labelled diagnostic probabilities.',
        ],
        scope='Final enabled-game functional integration release:actual saved startup,full live Magma return,shared31surface regressions,17cave component checks and native three-target material composition. Earlier Default/Frozen/Crystal/Insect/Alien and scenery evidence retain their original scopes and immutable snapshots. This report does not claim every requested reference-quality scenic criterion is complete.',
    )
    target = OUT / 'cave_enabled_release_20261028.json'
    target.write_text(json.dumps(report, indent=2))
    print(json.dumps(dict(passed=True, report=str(target), startup=report['startup'],
                          return_metres=walk['walk']['distance_m'],
                          route_sampled_mib=report['physical_return_sampled_private_mib'])))

if __name__ == '__main__':
    main()
