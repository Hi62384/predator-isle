param([string]$BuildDirectory = '')
$ErrorActionPreference = 'Stop'
$desertRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $BuildDirectory) { $BuildDirectory = Join-Path $desertRoot 'builds\windows' }
$desertExecutable = Join-Path $BuildDirectory 'PredatorIsle.exe'
if (-not (Test-Path -LiteralPath $desertExecutable)) { throw 'Export the Windows Desktop release first.' }
$desertResults = @()
foreach ($desertCase in @(@{name='desert';args='desert-feature=major_canyon'},@{name='grass';args='grass-preview'},@{name='default';args=''})) {
    $desertPrefix = Join-Path $BuildDirectory ('verified_' + $desertCase.name)
    $desertNativeArgs = '--log-file "' + $desertPrefix + '.log" -- smoke-test ' + $desertCase.args + ' smoke-output="' + $desertPrefix + '"'
    # Retain a handle and inspect the log: GUI process startup alone is not a pass.
    $desertChild = Start-Process -FilePath $desertExecutable -ArgumentList $desertNativeArgs -PassThru -WindowStyle Hidden
    $desertHandle = $desertChild.Handle
    $desertStarted = [DateTime]::UtcNow
    while (-not $desertChild.WaitForExit(1000)) {
        if (([DateTime]::UtcNow - $desertStarted).TotalSeconds -gt 130) {
            $desertChild.Kill(); $desertChild.WaitForExit()
            throw ('Owned smoke test timed out: ' + $desertCase.name)
        }
        if (Test-Path -LiteralPath ($desertPrefix + '.log')) {
            $desertRunningLog = Get-Content -LiteralPath ($desertPrefix + '.log') -Raw
            if ($desertRunningLog -match 'SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed|Failed loading resource') {
                $desertChild.Kill(); $desertChild.WaitForExit()
                throw ('Smoke test source/resource error: ' + $desertCase.name + '; see ' + $desertPrefix + '.log')
            }
        }
    }
    $desertChild.WaitForExit(); $desertChild.Refresh()
    $desertLog = Get-Content -LiteralPath ($desertPrefix + '.log') -Raw
    if ($desertChild.ExitCode -ne 0 -or $desertLog -notmatch 'RUNTIME_SMOKE_PASS' -or $desertLog -match 'ERROR:|Assertion failed') {
        throw ('Smoke test failed: ' + $desertCase.name + '; see ' + $desertPrefix + '.log')
    }
    $desertResult = Get-Content -LiteralPath ($desertPrefix + '.json') -Raw | ConvertFrom-Json
    if ($desertResult.failure -or -not $desertResult.exported -or $desertResult.loaded_chunks -le 0) { throw 'Invalid smoke result.' }
    $desertResults += $desertResult
    Write-Output ('PASS exported ' + $desertCase.name + ': ' + $desertResult.loaded_chunks + ' chunks, ' + [Math]::Round($desertResult.elapsed_s,2) + ' seconds')
}
$desertResults | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $BuildDirectory 'verified_launches.json') -Encoding UTF8
