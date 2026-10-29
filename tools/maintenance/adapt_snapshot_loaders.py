from pathlib import Path
import re

# Adapt live tests only. Historical baselines/archives stay byte-for-byte intact.
skip = {'baseline', 'baselines', 'references', 'artifacts', 'revisions'}
changed = []
for path in Path('tools').rglob('*.gd'):
    if skip.intersection(path.parts):
        continue
    source = path.read_text(encoding='utf-8-sig')
    result = re.sub(r'\bload\(("res://tools/[^"\n]+/(?:baseline|references)/[^"\n]+\.gd")\)',
                    r'preload("res://tools/maintenance/resource_paths.gd").load_snapshot(\1)', source)
    if result != source:
        path.write_text(result, encoding='utf-8')
        changed.append(str(path))
print('Adapted immutable snapshot loaders:', len(changed), changed)
