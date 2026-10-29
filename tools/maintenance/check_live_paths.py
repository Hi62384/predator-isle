from pathlib import Path
import re

missing = {}
count = 0
extensions = ('.gd', '.gdshader', '.gdshaderinc', '.tres', '.tscn', '.res', '.json', '.png', '.jpg', '.svg')
for folder in ['scripts', 'shaders', 'materials', 'scenes', 'config']:
    for path in Path(folder).rglob('*'):
        if path.suffix not in ['.gd', '.gdshader', '.gdshaderinc', '.tres', '.tscn']:
            continue
        source = path.read_text(encoding='utf-8-sig')
        for value in re.findall(r'''res://[^"'\s]+''', source):
            if not value.endswith(extensions):
                continue
            count += 1
            if not Path(value[6:]).is_file():
                missing.setdefault(str(path), []).append(value)
print('PRODUCTION_PATHS', count, 'references;missing=', missing)
assert not missing
