using System.Diagnostics;
using System.Text.Json;

var root = new DirectoryInfo(Directory.GetCurrentDirectory());
while (root != null && !File.Exists(Path.Combine(root.FullName, "project.godot"))) root = root.Parent;
if (root == null) throw new InvalidOperationException("Run from inside the Predator Isle project.");
string project = root.FullName;
string assembly = Path.Combine(project, ".godot", "mono", "temp", "bin", "Debug", "PredatorIsle.dll");
var compileSources = new[] { "scripts/csharp", "tools/csharp" }.SelectMany(folder => Directory.EnumerateFiles(Path.Combine(project, folder), "*.cs", SearchOption.AllDirectories));
if (!File.Exists(assembly) || compileSources.Any(path => File.GetLastWriteTimeUtc(path) > File.GetLastWriteTimeUtc(assembly)))
    throw new InvalidOperationException("Build PredatorIsle.csproj before running checks; the game assembly is missing or older than its C# sources.");
string? engineOverride = Environment.GetEnvironmentVariable("GODOT_BIN");
string engine = string.IsNullOrWhiteSpace(engineOverride)
    ? Path.Combine(project, ".tools", OperatingSystem.IsWindows() ? "Godot_v4.6.1-stable_mono_win64" : "Godot_v4.6.1-stable_mono_linux_x86_64",
        OperatingSystem.IsWindows() ? "Godot_v4.6.1-stable_mono_win64.exe" : "Godot_v4.6.1-stable_mono_linux.x86_64")
    : Path.GetFullPath(engineOverride);
if (!File.Exists(engine)) throw new FileNotFoundException("Godot 4.6.1 .NET is required. Set GODOT_BIN to its executable or install it in the local .tools folder.", engine);
string[] modes = args.Length == 0 || args.SequenceEqual(new[] { "all" }) ? new[] { "blob", "authority", "lifecycle", "rings", "sampling", "gpu-pipeline", "collision", "gpu-queues", "gpu-sampler", "gpu-terrain", "general", "field", "worker", "network", "cave-procedural", "discovery", "samplers", "placement", "tissue", "beach", "coast", "tropical", "startup" } : args;
static bool IsCaveScene(string mode) => mode.StartsWith("gpu-cave-scene-",StringComparison.Ordinal)
    &&mode.Length=="gpu-cave-scene-".Length+1&&mode[^1] is >= '0' and <= '7';
if (modes.Any(mode => !IsCaveScene(mode)&&!(mode.StartsWith("gpu-biome-",StringComparison.Ordinal)&&
    new[] {"grass","forest","savanna","swamp","jungle","mountain","tropical","badlands","quarry",
        "wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes",
        "insect_colony","alien_infected"}.Contains(mode["gpu-biome-".Length..])) && !new[] { "blob", "authority", "lifecycle", "rings", "sampling", "sampling-benchmark", "terrain-performance", "quarry", "runner-race", "gpu-sampler", "gpu-vertex", "gpu-extension", "gpu-materials", "gpu-caves", "cave-payload", "gpu-all-biomes", "cave-biomes", "gpu-pipeline", "gpu-queues", "gpu-terrain", "collision", "general", "field", "worker", "startup-reference", "startup-grid", "startup-shared", "startup-path", "startup-vulkan", "startup-vulkan-grid", "startup", "network", "discovery", "samplers", "placement", "tissue", "beach", "coast", "tropical" }.Contains(mode))) throw new ArgumentException("Modes: blob, authority, lifecycle, rings, sampling, sampling-benchmark, terrain-performance, gpu-sampler, gpu-pipeline, gpu-queues, gpu-terrain, gpu-caves, gpu-cave-scene-0..7, collision, general, field, worker, startup, network, samplers, placement, tissue, beach, coast, tropical, or all.");
var records = new List<object>();
string logDirectory = Path.Combine(project, ".godot", "csharp_checks", DateTime.UtcNow.ToString("yyyyMMddTHHmmssfff")); Directory.CreateDirectory(logDirectory);
bool passed = true;
// The usual 2-GiB bound protects game checks. Mesa's software Vulkan backend
// can allocate multiple GiB during renderer initialization, so CI may request
// a larger *bounded* limit without changing the default gameplay acceptance.
long memoryLimitMiB=2048;
if(long.TryParse(Environment.GetEnvironmentVariable("PREDATOR_ISLE_TEST_MEMORY_MIB"),out long requestedMiB)
   && requestedMiB is >=2048 and <=6144)
    memoryLimitMiB=requestedMiB;
// Godot workers often exit between WaitForExit(500) and a memory probe.
// A process lifetime race is not a failed terrain assertion; the runner must
// still collect the child exit code and its semantic report.
static bool TrySampleRunningMemory(Process process,out long sampledBytes)
{
    sampledBytes=0;
    try
    {
        process.Refresh();
        if(process.HasExited)return false;
        sampledBytes=process.PrivateMemorySize64;
        return true;
    }
    catch(InvalidOperationException) when(process.HasExited){return false;}
}
static void StopOwnedProcess(Process process)
{
    try{if(!process.HasExited)process.Kill(entireProcessTree:true);}
    catch(InvalidOperationException) when(process.HasExited){}
}
// This standalone probe validates that a short-lived child can exit before
// or during memory collection without crashing the entire check launcher.
if (modes.SequenceEqual(new[] { "runner-race" }))
{
    for(int attempt=0;attempt<24;attempt++)
    {
        var info=new ProcessStartInfo("dotnet")
        {
            RedirectStandardOutput=true,RedirectStandardError=true,
            UseShellExecute=false,CreateNoWindow=true
        };
        info.ArgumentList.Add("--version");
        using var quick=Process.Start(info)??throw new IOException("Could not launch short-lived runtime probe.");
        while(!quick.WaitForExit(1))
            if(!TrySampleRunningMemory(quick,out _))break;
        quick.WaitForExit();
        if(TrySampleRunningMemory(quick,out _)||quick.ExitCode!=0)
            throw new InvalidOperationException("Short-lived process exit/memory probe failed.");
    }
    Console.WriteLine("runner-race: PASS (24 short-lived child processes)");
    return 0;
}
int modeIndex = 0;
foreach (string mode in modes)
{
    string prefix = Path.Combine(logDirectory, $"{++modeIndex:00}_{mode}");
    var start = new ProcessStartInfo(engine) { WorkingDirectory = project, UseShellExecute = false, CreateNoWindow = true,
        WindowStyle = ProcessWindowStyle.Hidden, RedirectStandardOutput = true, RedirectStandardError = true };
    foreach (string argument in new[] { "--path", project, "--log-file", prefix + ".engine.log" }) start.ArgumentList.Add(argument);
    // The virtual X runner lacks an ALSA device. The test may select
    // Godot's Dummy audio driver rather than masking any other engine error.
    if (Environment.GetEnvironmentVariable("PREDATOR_ISLE_TEST_DUMMY_AUDIO") == "1")
    { start.ArgumentList.Add("--audio-driver"); start.ArgumentList.Add("Dummy"); }
    if (mode is "general" or "lifecycle" or "gpu-sampler" or "gpu-vertex" or "gpu-extension" or "gpu-materials" or "gpu-caves" or "gpu-queues" or "gpu-terrain" || mode.StartsWith("startup",StringComparison.Ordinal)||IsCaveScene(mode)) { start.ArgumentList.Add("--windowed"); start.ArgumentList.Add("--resolution"); start.ArgumentList.Add("640x360"); }
    else start.ArgumentList.Add("--headless");
    // Renderer equivalence checks can explicitly select either Vulkan renderer.
    // Keep the regular user workflow on its saved Compatibility renderer.
    string? testRenderer=Environment.GetEnvironmentVariable("PREDATOR_ISLE_TEST_RENDER_METHOD");
    if((IsCaveScene(mode)||mode is "gpu-sampler" or "gpu-vertex" or "gpu-extension" or "gpu-materials" or "gpu-caves" or "gpu-terrain" or "gpu-queues") &&
       (testRenderer=="forward_plus"||testRenderer=="mobile"))
    {
        start.ArgumentList.Add("--rendering-method"); start.ArgumentList.Add(testRenderer);
        start.ArgumentList.Add("--rendering-driver"); start.ArgumentList.Add("vulkan");
    }
    if(mode is "startup" or "lifecycle")start.ArgumentList.Add("--verbose");
    if(mode.StartsWith("startup-vulkan",StringComparison.Ordinal)){start.ArgumentList.Add("--rendering-method");start.ArgumentList.Add("forward_plus");start.ArgumentList.Add("--rendering-driver");start.ArgumentList.Add("vulkan");}
    start.ArgumentList.Add(mode == "authority" ? "res://tools/csharp/authority_runtime_check.tscn" : mode == "lifecycle" ? "res://tools/csharp/render_lifecycle_check.tscn" : mode.StartsWith("startup",StringComparison.Ordinal) ? "res://tools/csharp/startup_check.tscn" : "res://tools/csharp/migration_checks.tscn");
    if (mode is "blob" or "rings" or "sampling" or "sampling-benchmark" or "terrain-performance" or "quarry" or "gpu-sampler" or "gpu-vertex" or "gpu-extension" or "gpu-materials" or "gpu-caves" or "gpu-all-biomes" or "cave-biomes" or "cave-payload" or "gpu-pipeline" or "gpu-queues" or "gpu-terrain" or "collision" or "field" or "worker" or "network" or "cave-procedural" or "discovery" or "samplers" or "placement" or "tissue" or "beach" or "coast" or "tropical" || mode.StartsWith("gpu-biome-",StringComparison.Ordinal)||IsCaveScene(mode)) { start.ArgumentList.Add("--"); start.ArgumentList.Add(mode + "-only"); }
    if(mode=="startup-reference"){start.ArgumentList.Add("--");start.ArgumentList.Add("terrain-render=cpu");start.ArgumentList.Add("terrain-generation=cpu");start.ArgumentList.Add("terrain-shared-samples=off");}
    if(mode is "startup-grid" or "startup-vulkan-grid"){start.ArgumentList.Add("--");start.ArgumentList.Add("terrain-render=grid");}
    if(mode=="startup-path"){start.ArgumentList.Add("--");start.ArgumentList.Add("terrain-path-check");}
    if(mode=="startup-shared"){start.ArgumentList.Add("--");start.ArgumentList.Add("terrain-render=cpu");start.ArgumentList.Add("terrain-shared-samples=on");}
    DateTime started = DateTime.UtcNow; long peak = 0; string failure = "";
    using var process = Process.Start(start) ?? throw new IOException("Could not start owned Godot check.");
    Task<string> stdout = process.StandardOutput.ReadToEndAsync(), stderr = process.StandardError.ReadToEndAsync();
    try
    {
        while (!process.WaitForExit(500))
        {
            if(!TrySampleRunningMemory(process,out long usedBytes))break;
            peak=Math.Max(peak,usedBytes);
            if((DateTime.UtcNow-started).TotalSeconds>180||usedBytes>memoryLimitMiB*1024L*1024)
            {
                failure=$"Owned check exceeded its 180-second/{memoryLimitMiB}MiB bound.";
                StopOwnedProcess(process);
                break;
            }
        }
    }
    finally
    {
        StopOwnedProcess(process);
        await process.WaitForExitAsync();
    }
    string output = await stdout, errors = await stderr;
    await File.WriteAllTextAsync(prefix + ".out.log", output); await File.WriteAllTextAsync(prefix + ".err.log", errors);
    string[] lines = (output + "\n" + errors).Split('\n');
    var environmentMessages = lines.Where(line => line.Trim() == "ERROR: Failed to read the root certificate store.").Select(line => line.Trim()).Distinct().ToArray();
    var runtimeErrors = lines.Where(line => (line.Contains("ERROR:") || line.Contains("Assertion failed") || line.Contains("Parse Error"))
        && line.Trim() != "ERROR: Failed to read the root certificate store.").ToArray();
    if (process.ExitCode != 0) failure += $" Godot exit code {process.ExitCode}.";
    if (runtimeErrors.Length > 0) failure += " " + string.Join("\n", runtimeErrors);
    string reportPath = Path.Combine(project, "data", "csharp_check_" + (mode.StartsWith("startup",StringComparison.Ordinal)?"startup":mode) + "_latest.json");
    if (failure.Length == 0)
    {
        if (!File.Exists(reportPath) || File.GetLastWriteTimeUtc(reportPath) < started.AddSeconds(-2)) failure = "No fresh semantic report was produced.";
        else
        {
            using var report = JsonDocument.Parse(await File.ReadAllTextAsync(reportPath));
            if (!report.RootElement.GetProperty("passed").GetBoolean()) failure = "Semantic report failed.";
        }
    }
    if(File.Exists(reportPath))File.Copy(reportPath,prefix+".semantic.json",true);
    string capture=Path.Combine(project,"data","startup_verified_render.png");if(mode.StartsWith("startup",StringComparison.Ordinal)&&File.Exists(capture)&&File.GetLastWriteTimeUtc(capture)>=started.AddSeconds(-2))File.Copy(capture,prefix+".png",true);
    bool ok = failure.Length == 0;
    records.Add(new { mode, passed = ok, started_utc = started, completed_utc = DateTime.UtcNow, exit_code = process.ExitCode,
        sampled_peak_private_bytes = peak > 0 ? (long?)peak : null, environment_messages = environmentMessages, log_prefix = prefix, failure });
    Console.WriteLine($"{mode}: {(ok ? "PASS" : "FAIL")}; sampled private peak {(peak > 0 ? (peak / 1048576.0).ToString("F1") + " MiB" : "unsampled")}");
    foreach (string line in output.Split('\n').Where(line => line.Contains("checks passed") || line.Contains("startup check passed") || line.Contains("Actual volcanic cave cell"))) Console.WriteLine(line.Trim());
    if (!ok) { Console.Error.WriteLine(failure); passed = false; }
}
var receipt = new { passed, memory_limit_mib = memoryLimitMiB, deadline_seconds_per_mode = 180, sample_period_ms = 500, records,
    scope = "Only processes started by this runner are managed. Private memory is sampled, not an absolute peak. Existing project sessions are untouched. Certificate-store failures from the restricted execution environment are retained as environment messages; other runtime errors fail the run. No isolated or full-world performance claim." };
string receiptJson = JsonSerializer.Serialize(receipt, new JsonSerializerOptions { WriteIndented = true });
await File.WriteAllTextAsync(Path.Combine(logDirectory, "receipt.json"), receiptJson);
await File.WriteAllTextAsync(Path.Combine(project, "data", "csharp_runner_latest.json"), receiptJson);
return passed ? 0 : 1;
