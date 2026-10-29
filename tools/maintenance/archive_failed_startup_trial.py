from pathlib import Path
import hashlib
import json
import shutil
import sys

root = Path(__file__).resolve().parents[2]
label, reason = sys.argv[1:3]
assert label.replace('_', '').isalnum()
target = root / 'tools/maintenance/artifacts' / label
target.mkdir(parents=True, exist_ok=False)
files = list((root / '.godot').glob('extensions_' + label + '.*'))
files += [root / p for p in [
    'tools/biome_extensions/check_tile_specialized_startup_candidate.gd',
    'tools/biome_extensions/tile_specialization_patch_candidate.gd',
    'tools/biome_extensions/tile_owner_mask_candidate.gd',
    'scripts/chunk_terrain.gd', 'scripts/biome_extension_structures.gd',
    'scripts/terrain_shader_variants.gd', 'scripts/terrain_shader_preparation.gd',
    'config/world/terrain_settings.tres', 'project.godot',
    'tools/biome_extensions/check_all_owner_compact_loops.gd',
    'tools/biome_extensions/check_all_owner_rendering_device.gd',
    'tools/biome_extensions/packed_terrain_varyings_candidate.gd',
    'tools/biome_extensions/instance_origin_patch_candidate.gd',
    'tools/biome_extensions/check_pure_surface_startup.gd',
    'tools/biome_extensions/check_prepared_tile_programs.gd',
    'tools/biome_extensions/pure_surface_runtime_candidate.gd',
    'tools/biome_extensions/pure_surface_partition_candidate.gd',
    'tools/biome_extensions/pure_owner_shader_candidate.gd',
    'tools/biome_extensions/unreachable_shader_blocks_candidate.gd',
    'shaders/terrain_biomes.gdshader', 'shaders/biological_sampling.gdshaderinc']]
hashes = {}
for source in files:
    relative = source.relative_to(root)
    copy = target / relative
    copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, copy)
    hashes[str(relative).replace('\\', '/')] = hashlib.sha256(copy.read_bytes()).hexdigest()
(target / 'failure.json').write_text(json.dumps({
    'passed': False, 'reason': reason, 'copied_sha256': hashes,
    'scope': 'Failed private native startup;no production adoption. Source copies were taken after the trial;in-memory source interventions are described by the copied candidate scripts.'
}, indent=2), encoding='utf-8')
print('Archived failed trial:', label)
