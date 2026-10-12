# GitHub publishing and asset sizes

The palette uses the existing `materials/palette_color_roughness.tres` and
`materials/palette_normals.tres`. These small resources reference the individual
compressed image layers. Color remains 2048 x 2048 with roughness in alpha;
normal maps remain 1024 x 1024. No source textures were resized.

The old combined binaries duplicated these layers after GPU readback:
`palette_color_roughness.res` (148.04 MiB) and `palette_normals.res` (30.00 MiB).
They are deleted and ignored so regeneration cannot accidentally recommit them.
Godot's `.godot/` caches and backups are already ignored and need not be uploaded.

## Publishing the current initial commit

At inspection, this repository had one local initial commit,
`b7a72690fa94a62cd1e085e099f68a7f61dc5e7d`, and its GitHub remote had no refs.
The large file is in that commit. A later deletion commit would still upload it.
After applying the ProjectBridge patch, stage these changes in GitHub Desktop
and amend the unpublished initial commit, then publish.

Equivalent terminal commands, only while this is still the unpublished initial
commit and no unrelated changes are staged:

```powershell
git add -- .gitignore scripts/chunk_terrain.gd materials/terrain.tres tools/externalize_cliff_textures.gd tools/check_git_file_sizes.py GITHUB_PUBLISHING.md
git add -u -- materials/palette_color_roughness.res materials/palette_normals.res
python tools/check_git_file_sizes.py
git commit --amend --no-edit
```

The size check must pass before committing. Do not create a separate deletion
commit for this initial publishing problem. If commits have since been published
or more commits exist, review the history before choosing an appropriate cleanup.

Run `python tools/check_git_file_sizes.py` after staging future changes. It checks
actual staged blob sizes against a conservative 50 MiB budget, so ignored caches
and local files are excluded. Keep source images and reusable compressed layers;
avoid saving combined GPU texture arrays that duplicate their contents.
