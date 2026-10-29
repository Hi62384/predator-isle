param(
    [string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe',
    [switch]$FetchAssets,
    [switch]$Render
)
# Run only through the existing locally approved command workflow, after staged
# edits have been reviewed/applied and no other heavy job is running.
# This script does not apply patches, change approval settings or download at runtime.
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$artifacts = Join-Path $PSScriptRoot 'artifacts'
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot executable not found. Supply the verified installed path.' }
$memory = Get-CimInstance Win32_OperatingSystem
if ([long]$memory.FreePhysicalMemory * 1024 -lt 3GB) { throw 'Less than 3 GiB free RAM. Close other heavy work before approved validation.' }
$environment = @{ utc = [DateTime]::UtcNow.ToString('o'); engine = $GodotPath; free_ram_bytes = [long]$memory.FreePhysicalMemory * 1024; render_requested = [bool]$Render; asset_fetch_requested = [bool]$FetchAssets }
$environment | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $artifacts 'native_environment.json')
function Invoke-Godot([string]$Label, [string]$Arguments, [int]$Seconds = 180) {
    $out = Join-Path $artifacts ($Label + '.stdout.log')
    $err = Join-Path $artifacts ($Label + '.stderr.log')
    $process = Start-Process -FilePath $GodotPath -WorkingDirectory $project -ArgumentList ('--path "' + $project + '" ' + $Arguments) -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $ownedHandle = $process.Handle # Retain native handle until ExitCode is captured.
    if (-not $process.WaitForExit($Seconds * 1000)) {
        # Only this exact child process is stopped, never other Godot/editor jobs.
        $process.Kill(); $process.WaitForExit()
        throw "Timeout: $Label. See project-local logs."
    }
    $process.WaitForExit() # Flush redirected streams after the bounded wait.
    $process.Refresh()
    $stderr = Get-Content -LiteralPath $err -Raw
    $code = $process.ExitCode
    if ($null -eq $code) { throw "Missing child exit code: $Label. Logs/results must be inspected; null is not success." }
    if ($code -ne 0 -or $stderr -match 'SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed') { throw "Failed: $Label. See project-local logs." }
    Write-Output "Passed: $Label"
}
Invoke-Godot 'engine_version' '--headless --version' 30
# Editor scan registers class names and catches resource/import problems once.
Invoke-Godot 'source_import' '--headless --editor --quit' 240
Invoke-Godot 'cpu_invariants' '--headless --script res://tools/desert/check_desert.gd' 240
Invoke-Godot 'drainage_bed_profiles' '--headless --script res://tools/desert/audit_drainage_beds.gd' 180
Invoke-Godot 'drainage_network_crossings' '--headless --script res://tools/desert/audit_network_crossings.gd' 180
Invoke-Godot 'saved_preset_regression' '--headless --script res://tools/desert/check_saved_preset.gd' 180
Invoke-Godot 'fixed_seed_discovery' '--headless --script res://tools/desert/find_previews.gd' 180
if ($FetchAssets) {
    $downloadManifest = Join-Path $project 'assets\textures\desert\downloaded_manifest.json'
    if (-not (Test-Path -LiteralPath $downloadManifest)) { & (Join-Path $PSScriptRoot 'fetch_assets.ps1') }
    $sources = [object[]](ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($downloadManifest)))
    if ($sources.Count -ne 6) { throw 'Expected all six completed source records before packing.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $seen = @{}
    foreach ($asset in $sources) {
        if ($seen.ContainsKey($asset.id)) { throw 'Duplicate source identifier.' }
        $seen[$asset.id] = $true
        if ($asset.id -notin @('Ground092A','Ground054','Gravel020','Rock061','Ground031','Ground033')) { throw 'Unexpected source identifier.' }
        if (@($asset.maps).Count -ne 3) { throw 'Expected exactly three maps per source.' }
        $archivePath = Join-Path $artifacts ('downloads\' + $asset.id + '_2K-JPG.zip')
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLower() -ne $asset.archive_sha256) { throw 'Source archive changed since download.' }
        $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
        try {
        foreach ($map in $asset.maps) {
            if ($map.file -notmatch ('^' + [Regex]::Escape($asset.id) + '_2K-JPG_(Color|NormalGL|Roughness)\.jpg$')) { throw 'Unexpected map filename.' }
            $file = Join-Path $project ('assets\textures\desert\' + $asset.id + '\' + $map.file)
            if ((Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower() -ne $map.sha256) { throw ('Source map changed since verified download: ' + $map.file) }
            $entry = $archive.GetEntry($map.file)
            if ($null -eq $entry) { throw 'Map missing from original archive.' }
            $hash = [Security.Cryptography.SHA256]::Create()
            $stream = $entry.Open()
            try { $entryHash = [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLower() }
            finally { $stream.Dispose(); $hash.Dispose() }
            if ($entryHash -ne $map.sha256) { throw 'Map differs from original archive entry. Existing files preserved.' }
        }
        } finally { $archive.Dispose() }
    }
    Invoke-Godot 'offline_pbr_packing' '--headless --script res://tools/desert/build_palette.gd' 600
    Invoke-Godot 'prepared_asset_import' '--headless --editor --quit' 240
}
if ($Render) {
    # Sequential runs avoid simultaneous GPU/RAM pressure. Settings and viewport match.
    Invoke-Godot 'native_baseline' '--resolution 1440x810 --script res://tools/desert/benchmark_desert_native.gd -- baseline' 600
    Invoke-Godot 'native_current' '--resolution 1440x810 --script res://tools/desert/benchmark_desert_native.gd -- current' 600
    Invoke-Godot 'native_previews' '--resolution 1440x810 --script res://tools/desert/preview_desert.gd' 1200
}
Write-Output 'Validation jobs finished. Inspect JSON metrics, all images and source-map previews before accepting visual/performance requirements.'
