param([switch]$Run)
$ErrorActionPreference = 'Stop'
try {
    $projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $editorPath = Join-Path $projectRoot '.tools\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe'
    if ($env:PREDATOR_GODOT_DOTNET) { $editorPath = [IO.Path]::GetFullPath($env:PREDATOR_GODOT_DOTNET) }
    if (-not (Test-Path -LiteralPath $editorPath -PathType Leaf)) {
        throw 'Godot .NET was not found. Install Godot 4.6.1 .NET and set PREDATOR_GODOT_DOTNET to its executable.'
    }
    $engineVersion = (& $editorPath --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $engineVersion -notmatch 'mono') {
        throw 'The selected Godot editor has no C# support. Select the .NET edition, whose version includes mono.'
    }
    if ($engineVersion -notmatch '^4\.6\.1\.stable\.mono\.') {
        throw "This project requires Godot 4.6.1 .NET. The selected editor reports $engineVersion."
    }
    # A standard Godot editor can remove this flag when saving project settings.
    # Repair it on every supported launch before the .NET editor imports scenes.
    $projectFile = Join-Path $projectRoot 'project.godot'
    $projectText = [IO.File]::ReadAllText($projectFile)
    $repairedText = [regex]::Replace($projectText, '(?m)^config/features=PackedStringArray\(([^\r\n]*)\)', {
        param($match)
        if ($match.Groups[1].Value -match '"C#"') { return $match.Value }
        return 'config/features=PackedStringArray("C#", ' + $match.Groups[1].Value + ')'
    })
    if ($repairedText -ne $projectText) { [IO.File]::WriteAllText($projectFile, $repairedText) }
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) { throw 'Install the .NET 8 SDK before opening this C# project.' }
    # Cache only a successful build of these exact inputs and output. Include
    # paths as well as hashes so adding/removing a source invalidates the cache.
    $assemblyPath = Join-Path $projectRoot '.godot\mono\temp\bin\Debug\PredatorIsle.dll'
    $buildStampPath = Join-Path $projectRoot '.godot\launcher_build_stamp.json'
    $requiredOutputs = @('GodotSharp.dll', 'GodotSharpEditor.dll', 'PredatorIsle.dll', 'PredatorIsle.deps.json', 'PredatorIsle.runtimeconfig.json', 'PredatorIsle.pdb') |
        ForEach-Object { Join-Path (Split-Path -Parent $assemblyPath) $_ }
    $requiredOutputs += Join-Path $projectRoot '.godot\mono\temp\obj\project.assets.json'
    $sdkVersion = (& $dotnet.Source --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not determine the .NET SDK version.' }
    $buildInputs = @(
        Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts\csharp') -Filter '*.cs' -File -Recurse
        Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools\csharp') -Filter '*.cs' -File -Recurse
        Get-ChildItem -LiteralPath $projectRoot -File | Where-Object { $_.Extension -in @('.csproj', '.props', '.targets', '.sln', '.slnx') -or $_.Name -in @('global.json', 'NuGet.Config', 'nuget.config') }
    )
    $ancestor = [IO.DirectoryInfo]$projectRoot
    while ($null -ne $ancestor) {
        foreach ($name in @('Directory.Build.props', 'Directory.Build.targets', 'Directory.Packages.props', 'global.json', 'NuGet.Config', 'nuget.config')) {
            $ancestorInput = Join-Path $ancestor.FullName $name
            if (Test-Path -LiteralPath $ancestorInput -PathType Leaf) { $buildInputs += Get-Item -LiteralPath $ancestorInput }
        }
        $ancestor = $ancestor.Parent
    }
    $buildInputs = $buildInputs | Sort-Object FullName -Unique
    $buildSignature = $engineVersion + '|' + $sdkVersion + '|' + (($buildInputs | ForEach-Object {
        $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }) -join '|')
    $needsBuild = $true
    if ((Test-Path -LiteralPath $assemblyPath) -and (Test-Path -LiteralPath $buildStampPath)) {
        try {
            $buildStamp = Get-Content -LiteralPath $buildStampPath -Raw | ConvertFrom-Json
            $needsBuild = $buildStamp.signature -ne $buildSignature -or $null -eq $buildStamp.outputs
            foreach ($outputPath in $requiredOutputs) {
                if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { $needsBuild = $true; break }
                if ($buildStamp.outputs.$outputPath -ne (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash) { $needsBuild = $true; break }
            }
        } catch { $needsBuild = $true }
    }
    if ($needsBuild) {
        Write-Host 'Building Predator Isle...'
        Push-Location -LiteralPath $projectRoot
        try {
            & $dotnet.Source build (Join-Path $projectRoot 'PredatorIsle.csproj') --nologo
            if ($LASTEXITCODE -ne 0) { throw 'The C# build failed. The editor was not opened; see the build errors above.' }
        } finally { Pop-Location }
        $outputHashes = @{}
        foreach ($outputPath in $requiredOutputs) {
            if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw "The build did not produce $outputPath" }
            $outputHashes[$outputPath] = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
        }
        @{ signature = $buildSignature; outputs = $outputHashes } |
            ConvertTo-Json | Set-Content -LiteralPath $buildStampPath -Encoding UTF8
    } else {
        Write-Host 'C# build is up to date.'
    }
    if ($Run) {
        Write-Host 'Refreshing C# scene registrations...'
        $importLog = Join-Path $projectRoot '.godot\launcher_import.log'
        $importArguments = @('--headless', '--editor', '--import', '--quit', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $importLog + '"'))
        $importProcess = Start-Process -FilePath $editorPath -ArgumentList $importArguments -WorkingDirectory $projectRoot -WindowStyle Hidden -Wait -PassThru
        if ($importProcess.ExitCode -ne 0) { throw "C# scene import failed. See $importLog" }
    }
    Write-Host "Opening Godot .NET ($engineVersion)..."
    $editorArguments = @('--path', ('"' + $projectRoot + '"'))
    if (-not $Run) { $editorArguments = @('--editor') + $editorArguments }
    Start-Process -FilePath $editorPath -ArgumentList $editorArguments -WorkingDirectory $projectRoot -WindowStyle Normal
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
