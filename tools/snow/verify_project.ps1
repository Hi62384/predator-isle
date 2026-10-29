param(
    [string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe',
    [switch]$Render,
    [switch]$AllProjectChecks,
    [switch]$Benchmark,
    [switch]$Review
)
# Local source-project verification only. No exports, downloads or Git mutations.
$ErrorActionPreference = 'Stop'
$snowProject = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$snowLogs = Join-Path $snowProject '.godot\snow_verification'
New-Item -ItemType Directory -Force -Path $snowLogs | Out-Null
$snowCases = @('tools/snow/check_invariants.gd','tools/snow/check_materials.gd','tools/snow/check_lighting.gd')
if ($Render) { $snowCases += @('tools/snow/check_gpu_channels.gd','tools/snow/check_normal_visibility.gd') }
if ($Benchmark) { $snowCases += 'tools/snow/benchmark_snow.gd' }
if ($Review) { $snowCases += 'tools/snow/render_review.gd' }
$snowRecords = @()
foreach ($snowCase in $snowCases) {
    $snowName = [IO.Path]::GetFileNameWithoutExtension($snowCase)
    $snowPrefix = Join-Path $snowLogs $snowName
    $snowGpu = $snowCase -notin @('tools/snow/check_invariants.gd','tools/snow/check_materials.gd','tools/snow/check_lighting.gd')
    $snowArguments = '--path "' + $snowProject + '" --log-file "' + $snowPrefix + '.engine.log" '
    $snowArguments += if ($snowGpu) { '--windowed --resolution 1280x720 ' } else { '--headless ' }
    $snowArguments += '--script res://' + $snowCase
    $snowChild = Start-Process -FilePath $GodotPath -WorkingDirectory $snowProject -ArgumentList $snowArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput ($snowPrefix+'.out.log') -RedirectStandardError ($snowPrefix+'.err.log')
    # Retain the process handle before exit (Windows PowerShell 5.1 otherwise
    # occasionally reports a null ExitCode for an already-completed child).
    $null = $snowChild.Handle
    $snowStarted = [DateTime]::UtcNow
    $snowTimeout = if ($Review) { 420 } else { 150 }
    while (-not $snowChild.WaitForExit(500)) {
        $snowText = if (Test-Path -LiteralPath ($snowPrefix+'.engine.log')) { Get-Content -LiteralPath ($snowPrefix+'.engine.log') -Raw } else { '' }
        if ($snowText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$snowStarted).TotalSeconds -gt $snowTimeout) {
            $snowChild.Kill(); $snowChild.WaitForExit()
            throw ('Failed/timed out: '+$snowCase+'; see '+$snowPrefix+'.engine.log')
        }
    }
    $snowChild.WaitForExit(); $snowChild.Refresh()
    $snowText = Get-Content -LiteralPath ($snowPrefix+'.engine.log') -Raw
    if ($snowChild.ExitCode -ne 0 -or $snowText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|Parse Error') { throw ('Failed: '+$snowCase) }
    $snowRecords += @{script=$snowCase;rendered=$snowGpu;exit_code=$snowChild.ExitCode;elapsed_s=([DateTime]::UtcNow-$snowStarted).TotalSeconds;log=$snowPrefix+'.engine.log'}
    Write-Output ('PASS '+$snowCase)
}
if ($AllProjectChecks) { & (Join-Path $snowProject 'tools\desert\verify_project.ps1') -GodotPath $GodotPath -Render:$Render }
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'artifacts') | Out-Null
$snowRecords | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'artifacts\test_run.json') -Encoding UTF8
Write-Output ('PASS '+$snowRecords.Count+' Snow checks; no export performed')
