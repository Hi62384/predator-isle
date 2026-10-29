"""Move live root resources and repair live references;never rewrite evidence archives."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re

ROOT = Path(__file__).resolve().parents[2]
FROZEN_PARTS = {'artifacts', 'baseline', 'revisions', 'references', '.git', '.godot'}
TEXT_TYPES = {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres', '.godot', '.cfg', '.ps1', '.py', '.md', '.yml', '.yaml'}

def mapping():
    paths = {}
    for source in ROOT.glob('*_settings.tres'):
        name = source.name
        if name == 'terrain_settings.tres': target = 'config/world/' + name
        elif name == 'cave_settings.tres': target = 'config/caves/' + name
        else: target = 'config/biomes/' + name
        paths[name] = target
    paths.update({
        'cave_biome_regions.tres': 'config/caves/cave_biome_regions.tres',
        'cliff_normals.tres': 'config/rendering/cliff_normals.tres',
        'ground_materials.tres': 'config/rendering/ground_materials.tres',
        'main.tscn': 'scenes/main.tscn',
        'world_startup.tscn': 'scenes/world_startup.tscn',
        'blob_lab.tscn': 'scenes/labs/blob_lab.tscn',
        'blob_locomotion_lab.tscn': 'scenes/labs/blob_locomotion_lab.tscn',
        'TERRAIN_TUNING.md': 'docs/terrain/TERRAIN_TUNING.md',
        'CLIFF_NORMAL_CONTROLS.md': 'docs/materials/CLIFF_NORMAL_CONTROLS.md',
        'GROUND_MATERIAL_CONTROLS.md': 'docs/materials/GROUND_MATERIAL_CONTROLS.md',
        'BLOB_GENERATOR.md': 'docs/blobs/BLOB_GENERATOR.md',
        'BLOB_V4_REPORT.md': 'docs/blobs/BLOB_V4_REPORT.md',
        'GITHUB_PUBLISHING.md': 'docs/workflows/GITHUB_PUBLISHING.md',
    })
    for source in ROOT.glob('*_cave_definition.tres'):
        paths[source.name] = 'config/caves/biomes/' + source.name
    for name in ['canonical_neighbors.json', 'native_core_results.json', 'channel_report.json', 'channel_probe.png', 'channel_probe.png.import']:
        if (ROOT / name).is_file(): paths[name] = 'tools/diagnostics/artifacts/' + name
    return paths

def live_files():
    for directory in [ROOT, ROOT/'scripts', ROOT/'shaders', ROOT/'materials', ROOT/'scenes', ROOT/'config', ROOT/'tools', ROOT/'docs', ROOT/'.github']:
        if not directory.exists(): continue
        if directory == ROOT:
            candidates = directory.iterdir()
        else:
            files = []
            for folder, children, names in os.walk(directory):
                children[:] = [name for name in children if name not in FROZEN_PARTS]
                files.extend(Path(folder)/name for name in names)
            candidates = files
        for path in candidates:
            if not path.is_file() or path.suffix not in TEXT_TYPES: continue
            relative = path.relative_to(ROOT)
            if any(part in FROZEN_PARTS for part in relative.parts): continue
            if path.resolve() == Path(__file__).resolve(): continue
            yield path

def rewrite(text, paths):
    for old, new in paths.items():
        # Replace complete project URI or bare quoted path,never a basename
        # already nested in an archive or in its new destination.
        text = text.replace('res://' + old, 'res://' + new)
        text = re.sub(r'([\"\'])' + re.escape(old) + r'(?=\1)', lambda match: match.group(1) + new, text)
    return text

def digest(data): return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser();parser.add_argument('--apply', action='store_true');args = parser.parse_args()
    paths = mapping();edits = []; frozen_references = []
    for path in live_files():
        before = path.read_bytes()
        try: text = before.decode('utf-8')
        except UnicodeDecodeError: continue
        after = rewrite(text, paths).encode('utf-8')
        if after != before: edits.append((path, before, after))
    for directory in [ROOT/'tools/caves/references', ROOT/'tools/biome_extensions/references']:
        if directory.exists():
            for path in directory.rglob('*.gd'):
                text = path.read_text(encoding='utf-8')
                matches = [name for name in paths if 'res://' + name in text]
                if matches: frozen_references.append({'file':str(path.relative_to(ROOT)), 'old_paths':matches})
    print(json.dumps({'moves':paths,'live_text_files_to_update':len(edits),'frozen_reference_dependencies':frozen_references},indent=2))
    if not args.apply:return
    assert not frozen_references, 'Preserved reference dependencies require an explicit compatibility loader before migration'
    for old, new in paths.items():
        assert (ROOT/old).is_file(), old
        assert not (ROOT/new).exists(), new
        assert (ROOT/new).resolve().is_relative_to(ROOT.resolve())
    manifest = {'moves':{}, 'rewritten_files':[], 'scope':'Live project path migration only. Archived numeric/render evidence and original source hashes are never rewritten.'}
    backup = ROOT/'tools/maintenance/artifacts/before_project_organization'
    # A recoverable copy of only the small live files being changed/moved.
    originals = {path:path.read_bytes() for path,_,_ in edits}
    originals.update({ROOT/name:(ROOT/name).read_bytes() for name in paths})
    for path, data in originals.items():
        target = backup/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
        if target.exists(): assert target.read_bytes() == data, 'Never replace a differing pre-migration snapshot'
        else:target.write_bytes(data)
    for path, before, after in edits:
        assert path.read_bytes() == before, 'Concurrent file changed;abort before overwriting '+str(path)
        path.write_bytes(after);manifest['rewritten_files'].append({'path':path.relative_to(ROOT).as_posix(),'before_sha256':digest(before),'after_sha256':digest(after)})
    for old, new in paths.items():
        source=ROOT/old;target=ROOT/new;target.parent.mkdir(parents=True,exist_ok=True);source.rename(target)
        manifest['moves'][old]={'target':new,'sha256':digest(target.read_bytes())}
    (ROOT/'config/resource_path_migration.json').write_text(json.dumps(paths,indent=2)+'\n',encoding='utf-8')
    for directory in [backup.parent, ROOT/'tools/diagnostics/artifacts']:
        directory.mkdir(parents=True,exist_ok=True);(directory/'.gdignore').write_text('')
    (backup.parent/'project_organization_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('APPLIED',len(paths),'moves and',len(edits),'live reference edits')

if __name__ == '__main__':main()
