param([string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$utf8 = New-Object Text.UTF8Encoding($false)
function Text-Sha([string]$Text) {
 $h = [Security.Cryptography.SHA256]::Create()
 try { return [BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLower() } finally { $h.Dispose() }
}
$textPins = @{
 'shaders/desert_control_decode.gdshaderinc' = '47be43e7a3aa524123eb729aaab7bae673e01e1689e8cbdb400e6904c5009d84'
 'tools/desert/check_desert_gpu_channels.gd' = 'b85579ebd6b536e62cdd6a9ff61bd12e0d4156d0bac66303e4b6963d23154ed4'
 'tools/desert/check_desert_lighting.gd' = '0e327523ffe30048cd5e3283fa07246ad2255fa3692f294eb9f3a15ea39a2ad6'
 'tools/desert/owned_process.ps1' = '6d1734c2c5368fa932eec46e594590bf4eb362809d305a1dd03cc3d70e79d75a'
}
$binaryPins = @{
 'materials/desert_color_Ground092A.res' = '214bfb6bf50813d50252979fd1f72978337d22e88e720d5a6392c153bc47a8e0'
 'materials/desert_color_Ground054.res' = 'e43bf1898f27e00a330eb6db6680c6762add42a11806e9d7e16a290c171b5a97'
 'materials/desert_color_Gravel020.res' = '2388d4388aae0a52bff46b7ad5179c226f7694074ed2e648ffbc554ff90f29ea'
 'materials/desert_color_Rock061.res' = '4a5af237b49c742656119bc9db0ae419aace05d6ec6a0d6dc3e4fb67b9e400ae'
 'materials/desert_color_Ground031.res' = '6e8f0a948085c12665fc9e305cb8da2fb8eac038fd45308444ec9e3475d863f0'
 'materials/desert_color_Ground033.res' = 'f708a3668a92dfda0241fb7a3d32ca4736b06c5ac21c75600acc7d6fc2e209ac'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Recorded Godot executable missing.' }
if ([long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024 -lt 1GB) { throw 'Optical probes need at least 1 GiB free RAM.' }
$sourceTexts = @{}
foreach ($relative in $textPins.Keys) {
 $text = [IO.File]::ReadAllText((Join-Path $project $relative))
 if ((Text-Sha $text) -ne $textPins[$relative]) { throw ('Preserving changed source: ' + $relative) }
 $sourceTexts[$relative] = $text
}
foreach ($relative in $binaryPins.Keys) {
 if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $project $relative)).Hash.ToLower() -ne $binaryPins[$relative]) { throw ('Preserving changed packed source: ' + $relative) }
}
# Explicit native PS parser gate; the entry script is also parsed by PowerShell before execution.
foreach ($label in @('wrapper','owned_process')) {
 $parseText = $sourceTexts['tools/desert/owned_process.ps1']
 if ($label -eq 'wrapper') { $parseText = [IO.File]::ReadAllText($PSCommandPath) }
 $tokens = $null; $errors = $null
 $null = [System.Management.Automation.Language.Parser]::ParseInput($parseText,[ref]$tokens,[ref]$errors)
 if (@($errors).Count -ne 0) { throw ('PowerShell parse failed: ' + $label + ': ' + ($errors | Out-String)) }
}
. ([ScriptBlock]::Create($sourceTexts['tools/desert/owned_process.ps1'])) # Execute the exact hash-verified in-memory bytes.
$run = Join-Path (Join-Path $PSScriptRoot 'artifacts') ('optical_gates_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run | Out-Null
function Write-NewText([string]$File,[string]$Text) {
 $stream = [IO.File]::Open($File,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
 try { $bytes = $utf8.GetBytes($Text); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
@{text_pins=$textPins;binary_pins=$binaryPins;source_project=$project;scope='Two tiny optical diagnostics; no full world or global settings edits.'} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $run 'input_manifest.json')
# Version preflight has no display, project import or scene. The same owned-process safety floor applies.
$versionAll = @(Invoke-OwnedGodot -Executable $GodotPath -Arguments '--headless --version' -WorkingDirectory $run -LogPrefix (Join-Path $run 'version') -MinimumStartFree 1GB -MinimumRunningFree 512MB -WorkingSetCap 256MB -Seconds 15)
$versionRecords = @($versionAll | Where-Object { $_ -is [System.Collections.IDictionary] -and $_.ContainsKey('exit_code') })
$versionText = [IO.File]::ReadAllText((Join-Path $run 'version.stdout.log')).Trim()
if ($versionRecords.Count -ne 1 -or $versionRecords[0].exit_code -ne 0 -or $versionText -notmatch '(?m)^4\.6\.1\.stable\.official\.') { throw ('Unexpected native Godot identity/version: ' + $versionText) }
@{godot_path=$GodotPath;godot_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $GodotPath).Hash.ToLower();version=$versionText;powershell_version=$PSVersionTable.PSVersion.ToString();powershell_parse_passed=$true;version_supervision=$versionRecords[0]} | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $run 'preflight.json')
$records = @()
foreach ($kind in @('channels','lighting')) {
 $fixture = Join-Path $run $kind
 New-Item -ItemType Directory -Path $fixture | Out-Null
 $height = 512; $seconds = 90; $script = 'tools/desert/check_desert_gpu_channels.gd'
 if ($kind -eq 'lighting') { $height = 540; $seconds = 120; $script = 'tools/desert/check_desert_lighting.gd' }
 $projectText = @'
config_version=5
[application]
config/name="Desert optical diagnostic"
[display]
window/size/viewport_width=960
window/size/viewport_height=HEIGHT
window/size/mode=0
[rendering]
renderer/rendering_method="gl_compatibility"
'@
 $projectText = $projectText.Replace('HEIGHT',[string]$height)
 Write-NewText (Join-Path $fixture 'project.godot') $projectText
 Write-NewText (Join-Path $fixture 'probe.gd') $sourceTexts[$script]
 if ($kind -eq 'channels') {
  New-Item -ItemType Directory -Path (Join-Path $fixture 'shaders') | Out-Null
  Write-NewText (Join-Path $fixture 'shaders/desert_control_decode.gdshaderinc') $sourceTexts['shaders/desert_control_decode.gdshaderinc']
 } else {
  New-Item -ItemType Directory -Path (Join-Path $fixture 'materials') | Out-Null
  foreach ($relative in $binaryPins.Keys) {
   $copied = Join-Path $fixture $relative
   [IO.File]::Copy((Join-Path $project $relative),$copied,$false)
   if ((Get-FileHash -Algorithm SHA256 -LiteralPath $copied).Hash.ToLower() -ne $binaryPins[$relative]) { throw ('Copied packed source changed: ' + $relative) }
  }
 }
 $arguments = '--rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 960x' + $height + ' --max-fps 30 --audio-driver Dummy --path "' + $fixture + '" --script res://probe.gd -- require-render'
 $all = @(Invoke-OwnedGodot -Executable $GodotPath -Arguments $arguments -WorkingDirectory $fixture -LogPrefix (Join-Path $fixture 'run') -MinimumStartFree 1GB -MinimumRunningFree 512MB -WorkingSetCap 512MB -Seconds $seconds)
 # PS 5.1 may emit VoidTaskResult objects; select only the actual helper record.
 $supervision = @($all | Where-Object { $_ -is [System.Collections.IDictionary] -and $_.ContainsKey('exit_code') })
 if ($supervision.Count -ne 1 -or $supervision[0].exit_code -ne 0) { throw 'Expected one successful supervised child.' }
 foreach ($log in @('run.stdout.log','run.stderr.log')) {
  if ([IO.File]::ReadAllText((Join-Path $fixture $log)) -match 'SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed|ERROR:') { throw ('Diagnostic logged an error: ' + $kind + '/' + $log) }
 }
 $reportName = 'tools/diagnostics/artifacts/channel_report.json'; if ($kind -eq 'lighting') { $reportName = 'lighting_report.json' }
 $report = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $fixture $reportName)))
 if (-not $report.completed -or -not $report.actual_render -or $report.renderer -ne 'gl_compatibility' -or [string]::IsNullOrWhiteSpace($report.adapter) -or @($report.failures).Count -ne 0) { throw ('Missing actual GL evidence: ' + $kind) }
 if (@($report.viewport).Count -ne 2 -or $report.viewport[0] -ne 960 -or $report.viewport[1] -ne $height) { throw 'Unexpected actual viewport.' }
 if ($kind -eq 'channels') {
  if ($report.positive_cases -ne 119 -or $report.negative_cases -ne 1 -or $report.pixel_checks -ne 360 -or $report.max_pixel_error_bytes -gt 2 -or -not $report.negative_detected -or $report.rendered_frames -lt 1) { throw 'GPU channel diagnostic failed.' }
  if (-not (Test-Path -LiteralPath (Join-Path $fixture 'tools/diagnostics/artifacts/channel_probe.png') -PathType Leaf)) { throw 'Missing channel framebuffer.' }
 } else {
  if (@($report.captures).Count -ne 10 -or @($report.sources).Count -ne 6) { throw 'Incomplete lighting calibration.' }
  $seen = @{}
  foreach ($capture in $report.captures) {
   if (-not $capture.rendered -or $capture.frame -lt 1 -or @($capture.cards).Count -ne 8 -or $capture.name -notmatch '^[a-z0-9_]+$' -or $seen.ContainsKey($capture.name)) { throw 'Invalid lighting capture record.' }
   $seen[$capture.name] = $true
   $file = Join-Path $fixture ('captures/' + $capture.name + '.png')
   if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -lt 1024) { throw 'Missing lighting framebuffer.' }
  }
 }
 $records += @{diagnostic=$kind;supervision=$supervision[0];report=$reportName;report_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $fixture $reportName)).Hash.ToLower()}
 @{completed=($kind -eq 'lighting');records=$records;run_directory=$run;optical_quality_accepted=$false;note='Actual calibration images require review. This does not certify terrain, Grass, performance or global lighting.'} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $run 'completion.json')
}
Write-Output ('Optical diagnostics completed: ' + $run)
