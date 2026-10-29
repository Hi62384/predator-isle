param([string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe')
# Narrow, approved diagnostic only. Does not lower the full-project 3 GiB guard.
# Linux Godot 4.6.3 measured 67.7 MB peak RSS / 6.4 seconds for this fixture.
# Windows is unmeasured: 256 MiB own-child cap, 512 MiB entry / 384 MiB floor.
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$artifacts = Join-Path $PSScriptRoot 'artifacts'
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Recorded Godot path not found.' }
function Free-Ram { return [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024 }
function Text-Sha([string]$Text) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLower() }
    finally { $hash.Dispose() }
}
$before = Free-Ram
if ($before -lt 512MB) { Write-Output ("Bounded core skipped: free RAM {0:N0} MiB; requires 512 MiB." -f ($before / 1MB)); exit 42 }
$expected = @{
    'desert_settings.gd' = '751d0a8c732fb1ea05fede555839badec3942d7e8532f293e82396667a4127ca'
    'desert_sampler.gd' = '9d223ab654285adc1bb35d3f84bccc357251462b375f724a78f4f90c38fdeb3f'
    'desert_drainage.gd' = '5704b71d6b4b9a9c943ac5ae6daf9df9653c199e93b637a4b1f8761b7c6798f3'
}
$source = @{}
foreach ($name in $expected.Keys) {
    $text = [IO.File]::ReadAllText((Join-Path $project ('scripts\' + $name)))
    if ((Text-Sha $text) -ne $expected[$name]) { throw ('Applied source changed; preserving it: ' + $name) }
    $source[$name] = $text
}
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'native_core_check.gd'))
if ((Text-Sha $harness) -ne 'bd8b78e58123e776841040478164e665d4edc3aa4ea73795d40ec83a8d20b232') { throw 'Core harness changed. Review before running.' }
# Unique owned diagnostic directory; no existing project file is overwritten.
$run = Join-Path $artifacts ('bounded_core_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path (Join-Path $run 'scripts') | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
foreach ($name in $source.Keys) {
    $text = $source[$name]
    if ($name -eq 'desert_settings.gd') {
        if (-not $text.StartsWith("class_name DesertSettings`n")) { throw 'Unexpected settings header.' }
        $text = $text.Substring("class_name DesertSettings`n".Length)
    } else {
        if (-not $text.StartsWith("extends RefCounted`n")) { throw 'Unexpected sampler header.' }
        $text = $text.Replace("extends RefCounted`n", "extends RefCounted`nconst DesertSettings = preload(`"res://scripts/desert_settings.gd`")`n")
    }
    [IO.File]::WriteAllText((Join-Path $run ('scripts\' + $name)), $text, $utf8)
}
$projectText = "config_version=5`n[application]`nconfig/name=`"Bounded Desert Core Checks`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n"
[IO.File]::WriteAllText((Join-Path $run 'project.godot'), $projectText, $utf8)
[IO.File]::WriteAllText((Join-Path $run 'native_core_check.gd'), $harness, $utf8)
$out = Join-Path $run 'stdout.log'; $err = Join-Path $run 'stderr.log'
$record = @{ utc = [DateTime]::UtcNow.ToString('o'); scope = 'Isolated applied sampler/settings/drainage only'; engine = $GodotPath; free_ram_before_bytes = $before; minimum_free_ram_bytes = $before; child_peak_working_set_bytes = 0L; source_text_sha256 = $expected; limits = @{ minimum_start_free_bytes = 512MB; minimum_running_free_bytes = 384MB; child_working_set_cap_bytes = 256MB; seconds = 120 }; run_directory = $run; stop_reason = $null; exit_code = $null }
$process = $null; $failure = $null
try {
    # Recheck after PowerShell setup, before creating the only child.
    if ((Free-Ram) -lt 512MB) { throw 'Free RAM fell below entry guard during setup.' }
    $process = Start-Process -FilePath $GodotPath -WorkingDirectory $run -ArgumentList ('--headless --audio-driver Dummy --path "' + $run + '" --script res://native_core_check.gd') -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $watch = [Diagnostics.Stopwatch]::StartNew(); $nextRamCheck = 0.0
    while (-not $process.HasExited) {
        $process.Refresh()
        $record.child_peak_working_set_bytes = [Math]::Max([long]$record.child_peak_working_set_bytes, [long]$process.PeakWorkingSet64)
        if ($process.WorkingSet64 -gt 256MB) { throw 'Own child exceeded 256 MiB working set.' }
        if ($watch.Elapsed.TotalSeconds -gt 120) { throw 'Own child exceeded 120 second limit.' }
        if ($watch.Elapsed.TotalSeconds -ge $nextRamCheck) {
            $free = Free-Ram
            $record.minimum_free_ram_bytes = [Math]::Min([long]$record.minimum_free_ram_bytes, $free)
            if ($free -lt 384MB) { throw 'System free RAM fell below 384 MiB safety floor.' }
            $nextRamCheck = $watch.Elapsed.TotalSeconds + 1.0
        }
        Start-Sleep -Milliseconds 250
    }
    $process.WaitForExit(); $process.Refresh()
    $record.exit_code = $process.ExitCode; $record.elapsed_s = $watch.Elapsed.TotalSeconds
    $stderr = [IO.File]::ReadAllText($err)
    if ($process.ExitCode -ne 0 -or $stderr -match 'SCRIPT ERROR|Parse Error|Assertion failed') { throw 'Core child failed. See its project-local logs.' }
    $result = Get-Content -LiteralPath (Join-Path $run 'tools/diagnostics/artifacts/native_core_results.json') -Raw | ConvertFrom-Json
    if (@($result.failures).Count -ne 0 -or $result.comparisons -ne 1839) { throw 'Core result failed or has an unexpected comparison count.' }
    Write-Output ('Bounded core passed: ' + $run)
    Write-Output ('Engine: ' + $result.engine + '; comparisons: ' + $result.comparisons)
} catch {
    $failure = $_.Exception.Message; $record.stop_reason = $failure
} finally {
    if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $record | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $run 'supervision.json')
    Write-Output ('Supervision: ' + (Join-Path $run 'supervision.json'))
}
if ($null -ne $failure) { Write-Error $failure; exit 1 }
