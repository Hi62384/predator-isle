from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
artifacts = root / 'tools/maintenance/artifacts'
failed = artifacts / 'live_magma_detailed_startup_timeout'
failed.mkdir(parents=True, exist_ok=True)
copies = {}
for suffix in ['out.log', 'err.log', 'engine.log']:
    source = root / ('.godot/extensions_live_magma_detailed_startup.' + suffix)
    if source.exists():
        target = failed / source.name
        shutil.copy2(source, target)
        copies[str(target.relative_to(root)).replace('\\', '/')] = hashlib.sha256(target.read_bytes()).hexdigest()
(failed / 'failure.json').write_text(json.dumps({
    'passed': False, 'reason': 'Owned runner 900-second timeout',
    'last_logged_distance_m': 17177.3797898889,
    'full_route_completed': 'Not established; no completed semantic report',
    'source_snapshot_available': False, 'log_sha256': copies,
    'scope': 'Failure retained. Existing older full-return reports are historical and are not rebound to this attempt.'
}, indent=2), encoding='utf-8')

paths = ['scripts/free_camera.gd', 'scripts/blobs/blob_workshop.gd', 'scripts/chunk_terrain.gd',
         'scripts/terrain_ready_cut.gd', 'scripts/caves/streamer.gd',
         'scripts/biome_extension_structures.gd',
         'scenes/main.tscn', 'project.godot', 'config/world/terrain_settings.tres',
         'tools/check_startup_publication.gd', 'tools/check_biome_transition_width.gd']
report = {
    'date': '2026-10-28', 'all_requested_work_complete': False,
    'implemented': ['Debug panel and main-world Blob hint hidden by default; backtick toggle',
                    'Captured mouse look before GUI input; Escape release and click capture',
                    'Root settings/scenes/docs reorganized and resource references migrated',
                    'Finished startup chunks publish early; complete local replacement groups publish atomically during movement',
                    'Temporary logical LOD gaps require recorded equivalent final grids or actual emitted skirt coverage',
                    'Queued terrain reserves three of four worker slots against cave replenishment',
                    'Protected Hive portal lookup runs only if a Hive root is admitted',
                    'Camera-adjacent 2 m grids; LOD1 8 m and LOD2 32 m base grids',
                    'Saved height blend widened from 12 to 3',
                    'Altitude-dependent depth precision works with diagnostics hidden'],
    'validation': {
        'camera_checks': 15, 'startup_publication_checks': 10,
        'main_world_hint_check': '.godot/extensions_workshop_hint_camera.receipt.json',
        'live_resource_references': '578 checked; none missing',
        'native_layout': '43 moved files; settings and scenes load',
        'editor_import': 'Completed without stderr after editor metadata remap',
        'surface_regression': '31 passed with broader saved biome blend before later local-cut and worker changes; historical source guard retained',
        'detailed_startup_before_local_cut_changes': {
            'first_visible_seconds': 5.457, 'local_full_detail_seconds': 5.466,
            'complete_surroundings_seconds': 50.807, 'sampled_private_mib': 1311.2,
            'scope': 'Saved broad blend and detailed grids before later local-cut/worker changes; not cold-driver-cache or isolated timing'},
        'biome_transitions': 'Three fixed-seed actual borders widened; native same-camera before/after inspected',
        'live_spore_return': {'distance_m': 822.804952993989, 'checks': 159,
                              'maximum_unsupported_drop_m': 0, 'scope': 'Accelerated fixed60Hz; preload pauses; not uninterrupted FPS'},
        'live_magma_return': {'distance_m': 17213.1990420036, 'checks': 168,
                              'maximum_unsupported_drop_m': 0.03810882568359,
                              'motion_seconds': 501.496404, 'sampled_private_mib': 1759.8,
                              'archive': 'tools/biome_extensions/artifacts/revisions/experiment_check_cave_live_magma_return_8c56e58573d4',
                              'scope': 'Archived broad blend and denser terrain before local-cut/worker/lazy-Hive changes; fixed60Hz accelerated physics, rendering disabled during motion, preload pauses; not uninterrupted FPS'},
        'cave_release_checks': '17 passed before later local-cut/worker/lazy-Hive changes; historical evidence retained',
    },
    'remaining': ['Reduce complete background terrain generation cost and remaining local dependency waits',
                  'All-biome shader memory solution; per-tile candidate not adopted',
                  'Reference-level biome/cave appearance and remaining scenic coverage',
                  'Broader rendered performance coverage and remaining measured hitches'],
    'source_sha256': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths},
    'scope': 'Current scoped implementation status, not an all-work completion certificate. Existing archived source-bound evidence stays historical.'
}
near_path = root / 'tools/biome_extensions/artifacts/check_live_near_refinement.json'
near = json.loads(near_path.read_text(encoding='utf-8'))
assert near['passed'] and not near['failures']
for path, expected in near['source_sha256'].items():
    assert hashlib.sha256((root / path.removeprefix('res://')).read_bytes()).hexdigest() == expected, path
report['validation']['live_near_refinement'] = {
    'cases': near['cases'], 'checks': near['checks'], 'scope': near['scope'],
    'archive': 'tools/biome_extensions/artifacts/revisions/experiment_check_live_near_refinement_ceeb512516c6',
    'maximum_partition_swap_ms': near['maximum_partition_swap_ms'],
    'report_sha256': hashlib.sha256(near_path.read_bytes()).hexdigest(),
}
report['validation']['previous_targeted_checks'] = [
    'final_check_ready_cut', 'final_check_ready_cut_edges', 'final_check_ready_cut_skirts',
    'final_check_coupled_ready_groups', 'final_check_cave_worker_fairness',
    'final_check_startup_publication', 'final_check_biome_transition_width',
    'final_camera_native', 'final_surface_cut',
]
report['validation']['current_ready_cut_checks'] = [
    'ready128_check_ready_cut', 'ready128_check_ready_cut_edges',
    'ready128_check_ready_cut_skirts', 'ready128_check_coupled_ready_groups',
    'ready128_check_edge_coverage_oracle',
]
for label in report['validation']['previous_targeted_checks'] + report['validation']['current_ready_cut_checks']:
    receipt = json.loads((root / ('.godot/extensions_' + label + '.receipt.json')).read_text(encoding='utf-8'))
    assert receipt['passed'], label
report['validation']['headless_mouse_check'] = 'Headless mouse-capture assertions failed; log retained. The native-window rerun passed all 11 assertions.'
short_path = root / 'tools/biome_extensions/artifacts/check_cave_live_short_return.json'
short = json.loads(short_path.read_text(encoding='utf-8'))
assert short['passed'] and not short['failures']
short_changed = [path for path, expected in short['source_sha256'].items()
                 if hashlib.sha256((root / path.removeprefix('res://')).read_bytes()).hexdigest() != expected]
report['validation']['live_spore_return'] = {
    'checks': short['checks'], 'walk': short['walk'], 'scope': short['scope'],
    'archive': 'tools/biome_extensions/artifacts/revisions/experiment_check_cave_live_short_return_3135222fa6e8',
    'report_sha256': hashlib.sha256(short_path.read_bytes()).hexdigest(),
    'historical_after_ready_cut_change': True,
    'current_guard_mismatches': short_changed,
    'unguarded_dependency_changed': 'scripts/terrain_ready_cut.gd; fresh live test now explicitly guards this dependency',
}
rendered_path = root / 'tools/biome_extensions/artifacts/check_cave_live_rendered_spore.json'
rendered = json.loads(rendered_path.read_text(encoding='utf-8'))
assert rendered['passed'] and not rendered['failures']
rendered_changed = [path for path, expected in rendered['source_sha256'].items()
                    if hashlib.sha256((root / path.removeprefix('res://')).read_bytes()).hexdigest() != expected]
report['validation']['normal_rendered_spore_return'] = {
    'checks': rendered['checks'], 'walk': rendered['walk'],
    'measurements': rendered['motion_measurements'], 'scope': rendered['scope'],
    'report_sha256': hashlib.sha256(rendered_path.read_bytes()).hexdigest(),
    'receipt': '.godot/extensions_final_rendered_spore.receipt.json',
    'historical_after_ready_cut_change': True,
    'current_guard_mismatches': rendered_changed,
    'unguarded_dependency_changed': 'scripts/terrain_ready_cut.gd; fresh live test now explicitly guards this dependency',
}
trace_path = root / 'tools/biome_extensions/artifacts/check_cave_rendered_spore_upload_trace.json'
trace = json.loads(trace_path.read_text(encoding='utf-8'))
assert trace['passed'] and not trace['failures']
for path, expected in trace['source_sha256'].items():
    assert hashlib.sha256((root / path.removeprefix('res://')).read_bytes()).hexdigest() == expected, path
report['validation']['current_rendered_spore_profile'] = {
    'checks': trace['checks'], 'walk': trace['walk'],
    'measurements': trace['motion_measurements'],
    'archive': 'tools/biome_extensions/artifacts/revisions/experiment_check_cave_rendered_spore_upload_trace_748b1ccc5742',
    'receipt': '.godot/extensions_rendered_spore_upload_trace.receipt.json',
    'report_sha256': hashlib.sha256(trace_path.read_bytes()).hexdigest(),
    'scope': 'Private timing probes only; production geometry/route/loading policy. Ready-cut dependency explicitly guarded. One observed frame above100ms remains; this is not a zero-hitch acceptance claim.',
}
all_owner_path = root / 'tools/biome_extensions/artifacts/check_all_owner_startup_private.json'
all_owner = json.loads(all_owner_path.read_text(encoding='utf-8'))
all_owner_receipt = json.loads((root / '.godot/extensions_universal_compiler_profile_3g.receipt.json').read_text(encoding='utf-8'))
assert all_owner['passed'] and all_owner['configured_mask'] == 65535 and all_owner_receipt['passed']
for path, expected in all_owner['source_sha256'].items():
    assert hashlib.sha256((root / path.removeprefix('res://')).read_bytes()).hexdigest() == expected, path
report['validation']['all_owner_native_diagnostic'] = {
    'configured_mask': all_owner['configured_mask'],
    'startup_seconds': all_owner['startup_seconds'],
    'shader_preparation_seconds': all_owner['shader_preparation_seconds'],
    'first_visible_seconds': all_owner['first_visible_terrain_seconds'],
    'active_surface_chunks': all_owner['active_surface_chunks'],
    'sampled_peak_private_mib': round(all_owner_receipt['sampled_peak_private_bytes'] / 1048576, 1),
    'memory_limit_mib': all_owner_receipt['memory_limit_mib'],
    'capture_sha256': all_owner['capture_sha256'],
    'report_sha256': hashlib.sha256(all_owner_path.read_bytes()).hexdigest(),
    'scope': 'Actual saved entry and main scene with all sixteen owner coverages changed in memory for this diagnostic. No saved coverage changes; production_adoption=false. Startup and memory are measured, but no rendered traversal/FPS or art acceptance.',
}
(root / 'data/runtime_fix_status_20261028.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('Recorded scoped runtime fixes and retained long-route timeout evidence')
