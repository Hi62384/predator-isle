param([string]$GodotPath='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe')
# Project-only verification. Deliberately has no export/download/Git mutation.
$ErrorActionPreference='Stop'
$desertRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& (Join-Path $PSScriptRoot 'verify_project.ps1') -GodotPath $GodotPath -Render
$desertSteps=@(
    @{Name='final_views'; Script='preview_desert.gd'; Args=''; Timeout=240},
    @{Name='final_matrix'; Script='review_dune_matrix.gd'; Args=''; Timeout=240},
    @{Name='final_rock_relief'; Script='check_rock_relief.gd'; Args=''; Timeout=100},
    @{Name='final_baseline'; Script='benchmark_desert_native.gd'; Args=' -- baseline'; Timeout=100},
    @{Name='final_normal_reference'; Script='benchmark_desert_native.gd'; Args=' -- normal-reference'; Timeout=100},
    @{Name='final_current'; Script='benchmark_desert_native.gd'; Args=''; Timeout=100}
)
foreach ($desertStep in $desertSteps) {
    $desertLog=Join-Path $desertRoot ('.godot\'+$desertStep.Name)
    $desertArguments='--path "'+$desertRoot+'" --windowed --resolution 1280x720 --log-file "'+$desertLog+'.engine.log" --script res://tools/desert/'+$desertStep.Script+$desertStep.Args
    $desertChild=Start-Process -FilePath $GodotPath -WorkingDirectory $desertRoot -ArgumentList $desertArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput ($desertLog+'.out.log') -RedirectStandardError ($desertLog+'.err.log')
    $desertHandle=$desertChild.Handle
    $desertStarted=[DateTime]::UtcNow
    while (-not $desertChild.WaitForExit(500)) {
        $desertText=if (Test-Path -LiteralPath ($desertLog+'.engine.log')) { Get-Content -LiteralPath ($desertLog+'.engine.log') -Raw } else { '' }
        if ($desertText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$desertStarted).TotalSeconds -gt $desertStep.Timeout) {
            $desertChild.Kill();$desertChild.WaitForExit()
            throw ('Failed/timed out: '+$desertStep.Name+'; see '+$desertLog)
        }
    }
    $desertChild.WaitForExit();$desertChild.Refresh()
    $desertText=Get-Content -LiteralPath ($desertLog+'.engine.log') -Raw
    if ($desertChild.ExitCode -ne 0 -or $desertText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|Parse Error') { throw ('Failed '+$desertStep.Name) }
    Write-Output ('PASS '+$desertStep.Name)
}
Write-Output 'Project-only closeout runs finished. Review images and collect evidence separately. No export performed.'
