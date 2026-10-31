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
string engine = Path.Combine(project, ".tools", "Godot_v4.6.1-stable_mono_win64", "Godot_v4.6.1-stable_mono_win64.exe");
if (!File.Exists(engine)) throw new FileNotFoundException("Godot 4.6.1 .NET is required in the local .tools folder.", engine);
string[] modes = args.Length == 0 || args.SequenceEqual(new[] { "all" }) ? new[] { "blob", "authority", "lifecycle", "rings", "general", "field", "worker", "network", "samplers", "placement", "tissue", "beach", "coast", "tropical", "startup" } : args;
if (modes.Any(mode => !new[] { "blob", "authority", "lifecycle", "rings", "general", "field", "worker", "startup", "network", "samplers", "placement", "tissue", "beach", "coast", "tropical" }.Contains(mode))) throw new ArgumentException("Modes: blob, authority, lifecycle, rings, general, field, worker, startup, network, samplers, placement, tissue, beach, coast, tropical, or all.");
var records = new List<object>();
string logDirectory = Path.Combine(project, ".godot", "csharp_checks", DateTime.UtcNow.ToString("yyyyMMddTHHmmssfff")); Directory.CreateDirectory(logDirectory);
bool passed = true;
int modeIndex = 0;
foreach (string mode in modes)
{
    string prefix = Path.Combine(logDirectory, $"{++modeIndex:00}_{mode}");
    var start = new ProcessStartInfo(engine) { WorkingDirectory = project, UseShellExecute = false, CreateNoWindow = true,
        WindowStyle = ProcessWindowStyle.Hidden, RedirectStandardOutput = true, RedirectStandardError = true };
    foreach (string argument in new[] { "--path", project, "--log-file", prefix + ".engine.log" }) start.ArgumentList.Add(argument);
    if (mode is "general" or "startup" or "lifecycle") { start.ArgumentList.Add("--windowed"); start.ArgumentList.Add("--resolution"); start.ArgumentList.Add("640x360"); }
    else start.ArgumentList.Add("--headless");
    if(mode is "startup" or "lifecycle")start.ArgumentList.Add("--verbose");
    start.ArgumentList.Add(mode == "authority" ? "res://tools/csharp/authority_runtime_check.tscn" : mode == "lifecycle" ? "res://tools/csharp/render_lifecycle_check.tscn" : mode == "startup" ? "res://tools/csharp/startup_check.tscn" : "res://tools/csharp/migration_checks.tscn");
    if (mode is "blob" or "rings" or "field" or "worker" or "network" or "samplers" or "placement" or "tissue" or "beach" or "coast" or "tropical") { start.ArgumentList.Add("--"); start.ArgumentList.Add(mode + "-only"); }
    DateTime started = DateTime.UtcNow; long peak = 0; string failure = "";
    using var process = Process.Start(start) ?? throw new IOException("Could not start owned Godot check.");
    Task<string> stdout = process.StandardOutput.ReadToEndAsync(), stderr = process.StandardError.ReadToEndAsync();
    try
    {
        while (!process.WaitForExit(500))
        {
            process.Refresh(); if (process.HasExited) break;
            peak = Math.Max(peak, process.PrivateMemorySize64);
            if ((DateTime.UtcNow - started).TotalSeconds > 180 || process.PrivateMemorySize64 > 2L * 1024 * 1024 * 1024)
            { failure = "Owned check exceeded its 180-second/2GiB bound."; process.Kill(entireProcessTree: true); break; }
        }
    }
    finally
    {
        if (!process.HasExited) process.Kill(entireProcessTree: true);
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
    string reportPath = Path.Combine(project, "data", "csharp_check_" + mode + "_latest.json");
    if (failure.Length == 0)
    {
        if (!File.Exists(reportPath) || File.GetLastWriteTimeUtc(reportPath) < started.AddSeconds(-2)) failure = "No fresh semantic report was produced.";
        else
        {
            using var report = JsonDocument.Parse(await File.ReadAllTextAsync(reportPath));
            if (!report.RootElement.GetProperty("passed").GetBoolean()) failure = "Semantic report failed.";
        }
    }
    bool ok = failure.Length == 0;
    records.Add(new { mode, passed = ok, started_utc = started, completed_utc = DateTime.UtcNow, exit_code = process.ExitCode,
        sampled_peak_private_bytes = peak > 0 ? (long?)peak : null, environment_messages = environmentMessages, log_prefix = prefix, failure });
    Console.WriteLine($"{mode}: {(ok ? "PASS" : "FAIL")}; sampled private peak {(peak > 0 ? (peak / 1048576.0).ToString("F1") + " MiB" : "unsampled")}");
    foreach (string line in output.Split('\n').Where(line => line.Contains("checks passed") || line.Contains("startup check passed") || line.Contains("Actual volcanic cave cell"))) Console.WriteLine(line.Trim());
    if (!ok) { Console.Error.WriteLine(failure); passed = false; }
}
var receipt = new { passed, memory_limit_mib = 2048, deadline_seconds_per_mode = 180, sample_period_ms = 500, records,
    scope = "Only processes started by this runner are managed. Private memory is sampled, not an absolute peak. Existing project sessions are untouched. Certificate-store failures from the restricted execution environment are retained as environment messages; other runtime errors fail the run. No isolated or full-world performance claim." };
string receiptJson = JsonSerializer.Serialize(receipt, new JsonSerializerOptions { WriteIndented = true });
await File.WriteAllTextAsync(Path.Combine(logDirectory, "receipt.json"), receiptJson);
await File.WriteAllTextAsync(Path.Combine(project, "data", "csharp_runner_latest.json"), receiptJson);
return passed ? 0 : 1;
