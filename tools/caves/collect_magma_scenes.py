"""Freeze completed native scenery runs without rebinding historical tools."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tools/biome_extensions/artifacts'

def local(uri):
    assert uri.startswith('res://') and '..' not in uri
    return ROOT / uri[6:]

def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()

def main():
    guards, captures, rows = {}, {}, []
    historical = {}
    snapshots = {}
    def guard(uri, expected=None):
        actual = digest(local(uri))
        assert expected is None or actual == expected, uri
        guards[uri] = actual
    for group in ['provinces_tubes', 'forms_hosts_depths']:
        uri = f'res://tools/biome_extensions/artifacts/magma_scene_batch_{group}.json'
        guard(uri)
        batch = json.loads(local(uri).read_text(encoding='utf-8-sig'))
        assert batch['passed']
        snapshots.update(batch['tool_snapshots'])
        for row in batch['records']:
            assert row['passed']
            guard(row['report'], row['report_sha256'])
            for path, sha in row['outputs'].items():
                guard(path, sha)
            rows.append(row)
    for target, label in [
        ('profile_collapsed_lava_tube', 'magma_scene_collapsed'),
        ('formation_basaltic_lava_stalactite', 'magma_scene_roof_drips'),
        ('tube_great_volcanic_fissure', 'magma_scene_whole_fissure'),
    ]:
        uri = f'res://tools/biome_extensions/artifacts/render_cave_magma_scene_{target}.json'
        guard(uri)
        outputs = {}
        for suffix in ['out.log', 'err.log', 'engine.log', 'receipt.json']:
            path = f'res://.godot/extensions_{label}.{suffix}'
            guard(path)
            outputs[path] = guards[path]
        rows.append(dict(target=target, report=uri, outputs=outputs))
    contexts, samples, checks = set(), 0, 0
    peak = 0
    for row in rows:
        report = json.loads(local(row['report']).read_text())
        assert report['passed'] and not report['failures']
        checks += report['checks']
        contexts.add((report['host'], report['seed'], tuple(report['site']), report['room_id']))
        for uri, sha in report['source_sha256'].items():
            frozen = OUT / 'revisions/magma_native_breadth_5473f877fd34/evidence' / uri[6:]
            if digest(local(uri)) != sha and frozen.exists() and digest(frozen) == sha:
                frozen_uri = 'res://' + frozen.relative_to(ROOT).as_posix()
                guard(frozen_uri, sha)
                historical[uri] = {'sha256': sha, 'snapshot': frozen_uri}
                continue
            if uri.startswith(('res://scripts/', 'res://shaders/', 'res://materials/')) or uri.endswith('.tres') or uri in ['res://scenes/main.tscn', 'res://project.godot']:
                guard(uri, sha)
            elif digest(local(uri)) == sha:
                guard(uri, sha)
            else:
                snap = snapshots.get(uri, {})
                if snap.get('sha256') == sha:
                    guard(snap['snapshot'], sha)
                else:
                    matches = list((OUT / 'revisions').glob('**/sources/' + uri[6:] + '.txt'))
                    match = next((p for p in matches if digest(p) == sha), None)
                    assert match, ('Missing original historical tool', uri, sha)
                    guard('res://' + match.relative_to(ROOT).as_posix(), sha)
        for uri, sha in report['capture_sha256'].items():
            assert digest(local(uri)) == sha
            captures[uri] = sha
        for walk in report['walks']:
            assert walk['finished'] and not walk['failed'] and walk['waypoint'] == walk['waypoints']
            assert walk['maximum_unsupported_drop_m'] < .75
        controls = report.get('native_checks', {})
        samples += len(controls.get('stationary_renderer_samples', []))
        for uri in row['outputs']:
            if uri.endswith('receipt.json'):
                receipt = json.loads(local(uri).read_text(encoding='utf-8-sig'))
                assert receipt['passed']
                peak = max(peak, (receipt.get('sampled_peak_private_bytes') or 0) / 1048576)
    assert len(rows) == 22 and len(contexts) == 16 and 0 < peak < 2048
    report = dict(passed=True, checks=checks, native_runs=rows, unique_contexts=len(contexts),
                  source_sha256=guards, capture_sha256=captures,
                  stationary_samples=samples, peak_sampled_private_mib=peak,
                  historical_dependencies=historical,
                  aliases={'host_volcanic': 'formation_basaltic_lava_stalactite',
                           'depth_3': 'formation_basaltic_lava_stalactite',
                           'depth_4': 'profile_rough_scoria_chamber'},
                  scope='22 native runs,16 unique physical contexts,25 catalogue targets. Fixed60Hz diagnostic motion and stationary viewport samples; other Godot sessions running. No isolated FPS,reference-art acceptance,cold-start acceptance or all-task completion.')
    destination = OUT / 'check_cave_magma_native_breadth.json'
    destination.write_text(json.dumps(report, indent=2))
    archive = OUT / 'revisions' / ('magma_native_breadth_' + digest(destination)[:12])
    for uri, sha in {**guards, **captures}.items():
        original = local(uri)
        target = archive / 'evidence' / uri[6:]
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            assert digest(target) == sha
        else:
            shutil.copyfile(original, target)
        assert digest(target) == sha
    archive.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(destination, archive / destination.name)
    print(json.dumps(dict(passed=True, runs=len(rows), contexts=len(contexts), captures=len(captures), samples=samples, checks=checks, peak_mib=peak, archive=str(archive))))

if __name__ == '__main__':
    main()
