param([string]$Feature='lowland_rainforest')
$ErrorActionPreference='Stop'
$jungleProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$jungleManifest=Get-Content -LiteralPath (Join-Path $jungleProject 'data\jungle_previews.json') -Raw | ConvertFrom-Json
if($Feature -notin $jungleManifest.features.PSObject.Properties.Name){throw 'Unknown Jungle feature. See data/jungle_previews.json.'}
# Explicitly requested interactive preview. Does not change presets or export.
& 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe' --path $jungleProject --windowed -- jungle-preview ('jungle-feature='+$Feature)
