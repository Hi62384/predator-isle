using Godot;
using System;
using System.IO;
using System.Linq;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class MigrationEvidence
{
    internal static void Write(string name, int checks, bool passed, D? measurements = null, string error = "")
    {
        string root = ProjectSettings.GlobalizePath("res://"); using var guards = new D();
        foreach (string folder in new[] { "scripts", "tools/csharp", "config", "scenes", "shaders" })
            foreach (string path in Directory.EnumerateFiles(Path.Combine(root, folder), "*", SearchOption.AllDirectories).OrderBy(p => p, StringComparer.Ordinal))
            {
                if (!new[] { ".gd", ".cs", ".tres", ".tscn", ".gdshader", ".gdshaderinc" }.Contains(Path.GetExtension(path))) continue;
                string relative = "res://" + Path.GetRelativePath(root, path).Replace('\\', '/');
                guards[relative] = Godot.FileAccess.GetSha256(relative);
            }
        using var report = new D { ["passed"] = passed, ["checks"] = checks, ["mode"] = name, ["utc"] = DateTime.UtcNow.ToString("O"),
            ["display_server"] = DisplayServer.GetName(), ["source_sha256"] = guards, ["measurements"] = measurements ?? new(), ["error"] = error,
            ["scope"] = "Focused C# migration assertions against preserved GDScript references and current scene bindings. Source guards include current runtime code, configuration and shaders. Not complete migration, all-world appearance, isolated performance, or uninterrupted traversal acceptance. Sandboxed engine certificate-store errors are recorded separately in engine logs." };
        using var file = Godot.FileAccess.Open($"res://data/csharp_check_{name}_latest.json", Godot.FileAccess.ModeFlags.Write);
        if (file == null) throw new IOException("Could not save migration evidence");
        file.StoreString(Json.Stringify(report, "  "));
    }
}
