# Explicitly owned process, retained native handle, streamed logs and bounded memory.
# Only the child created by this function may be stopped.
function Invoke-OwnedGodot {
    param([string]$Executable, [string]$Arguments, [string]$WorkingDirectory, [string]$LogPrefix,
          [long]$MinimumStartFree = 768MB, [long]$MinimumRunningFree = 384MB,
          [long]$WorkingSetCap = 384MB, [int]$Seconds = 120)
    $freeBefore = [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024
    if ($freeBefore -lt $MinimumStartFree) { throw ('Insufficient free RAM before child: ' + $freeBefore) }
    $record = @{ utc = [DateTime]::UtcNow.ToString('o'); free_before_bytes = $freeBefore; minimum_free_bytes = $freeBefore; peak_child_working_set_bytes = 0L; exit_code = $null; elapsed_s = 0.0; failure = $null; arguments = $Arguments; limits = @{ start_free_bytes = $MinimumStartFree; running_free_bytes = $MinimumRunningFree; child_cap_bytes = $WorkingSetCap; seconds = $Seconds } }
    $process = New-Object System.Diagnostics.Process
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Executable; $info.Arguments = $Arguments; $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $process.StartInfo = $info
    $outFile = $null; $errFile = $null; $outTask = $null; $errTask = $null; $started = $false; $failure = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $outFile = [IO.File]::Open($LogPrefix + '.stdout.log', [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $errFile = [IO.File]::Open($LogPrefix + '.stderr.log', [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $started = $process.Start()
        if (-not $started) { throw 'Godot child did not start.' }
        $ownedHandle = $process.Handle # Keep the same owned process handle through ExitCode capture.
        $outTask = $process.StandardOutput.BaseStream.CopyToAsync($outFile)
        $errTask = $process.StandardError.BaseStream.CopyToAsync($errFile)
        $nextRamCheck = 0.0
        while (-not $process.WaitForExit(250)) {
            try {
                $process.Refresh()
                $record.peak_child_working_set_bytes = [Math]::Max([long]$record.peak_child_working_set_bytes, [long]$process.PeakWorkingSet64)
                if ($process.WorkingSet64 -gt $WorkingSetCap) { throw 'Own child exceeded working-set cap.' }
            } catch { if (-not $process.HasExited) { throw } }
            if ($watch.Elapsed.TotalSeconds -gt $Seconds) { throw 'Own child exceeded time limit.' }
            if ($watch.Elapsed.TotalSeconds -ge $nextRamCheck) {
                $free = [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024
                $record.minimum_free_bytes = [Math]::Min([long]$record.minimum_free_bytes, $free)
                if ($free -lt $MinimumRunningFree) { throw 'System free RAM crossed the running safety floor.' }
                $nextRamCheck = $watch.Elapsed.TotalSeconds + 1.0
            }
        }
        $process.WaitForExit()
        $outTask.GetAwaiter().GetResult(); $errTask.GetAwaiter().GetResult()
        $outFile.Flush(); $errFile.Flush()
        $outFile.Dispose(); $outFile = $null; $errFile.Dispose(); $errFile = $null # Release writer handles before ReadAllText.
        $code = $process.ExitCode
        if ($null -eq $code) { throw 'No exit code was captured; null is neither success nor a child failure.' }
        $record.exit_code = [int]$code
        if ($code -ne 0) { throw ('Godot child returned ' + $code) }
        $stderr = [IO.File]::ReadAllText($LogPrefix + '.stderr.log')
        if ($stderr -match 'SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed') { throw 'Godot logged an error. See stderr.' }
    } catch { $failure = $_.Exception.Message; $record.failure = $failure }
    finally {
        if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        foreach ($task in @($outTask,$errTask)) { if ($null -ne $task) { try { $task.GetAwaiter().GetResult() } catch { if ($null -eq $failure) { $failure = 'Log stream copy failed.'; $record.failure = $failure } } } }
        if ($null -ne $outFile) { $outFile.Dispose() }; if ($null -ne $errFile) { $errFile.Dispose() }
        $record.elapsed_s = $watch.Elapsed.TotalSeconds
        $record | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 ($LogPrefix + '.supervision.json')
        $process.Dispose()
    }
    if ($null -ne $failure) { throw $failure }
    return $record
}
