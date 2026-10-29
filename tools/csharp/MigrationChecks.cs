using Godot;
using System;
using System.Diagnostics;
using PredatorIsle.Terrain;
using PredatorIsle.Rendering;
using PredatorIsle.Player;
using PredatorIsle.Caves;
using GDictionary = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Runs the preserved planner and the C# port against identical moving cuts.</summary>
public partial class MigrationChecks : Node
{
    private int _checks;
    public override async void _Ready()
    {
        try
        {
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "field-only"))
            {
                CaveFieldChecks.Run(Require); GD.Print($"C# cave field checks passed: {_checks}"); GetTree().Quit(); return;
            }
            CheckPlanner();
            CheckShaderVariants();
            CheckReadyCut();
            CheckCaveMesher();
            CheckExistingCaveField();
            CollisionChecks.Run(this, Require);
            CaveRouteChecks.Run(Require);
            SurfaceBatchChecks.Run(Require);
            var camera = new FreeCamera(); AddChild(camera);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            CheckCamera(camera);
            camera.QueueFree();
            var scene = GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
            Require(scene.GetNode<Camera3D>("FreeCamera") is FreeCamera, "Main camera is not C#");
            Require(scene.GetNode("Terrain").Get("_partition").AsGodotObject() is TerrainPartition, "Main planner is not C#");
            Require(scene.GetNode("Terrain").Get("_ready_cut").AsGodotObject() is TerrainReadyCut, "Main ready cut is not C#");
            Require(scene.GetNode("Terrain").Get("_collision").AsGodotObject() is TerrainCollision, "Main collision is not C#");
            scene.Free();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            System.GC.Collect(); System.GC.WaitForPendingFinalizers();
            GD.Print($"C# migration checks passed: {_checks}");
            GetTree().Quit();
        }
        catch (Exception error)
        {
            GD.PushError(error.ToString());
            GetTree().Quit(1);
        }
    }

    private void CheckExistingCaveField()
    {
        foreach (bool portal in new[] { false, true })
        {
            using var field = GD.Load<GDScript>("res://scripts/caves/portal_field.gd").New().AsGodotObject();
            field.Set("height", Callable.From<double, double, double>((x, z) => 40));
            field.Set("minimum_roof", 2.0); field.Set("include_surface_air", portal);
            Require(field.Call("append_feature", new Vector3(10, 20, 32), new Vector3(54, 22, 32), new Vector2(8, 15), 0).AsBool(), "Existing field fixture rejected");
            if (portal) field.Set("surface_columns", new GDictionary { [Vector2I.Zero] = true });
            using var candidate = portal ? (CaveMesher)new PortalCaveMesher() : new CaveMesher();
            using var reference = GD.Load<GDScript>(portal ? "res://scripts/caves/portal_mesher.gd" : "res://scripts/caves/mesher.gd").New().AsGodotObject();
            foreach (double step in new[] { 2.0, 4.0 })
            {
                var expected = reference.Call("build", field, Vector3I.Zero, step).AsGodotArray();
                var actual = candidate.build(field, Vector3I.Zero, step);
                Require(expected.Count > 0, "Existing field produced empty comparison");
                Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(expected), GD.VarToBytes(actual)), $"Existing field mesh differs: portal={portal}, step={step}");
            }
        }
    }

    private void CheckCaveMesher()
    {
        foreach (bool portal in new[] { false, true })
        foreach (bool shoreline in new[] { false, true })
        foreach (var key in new[] { Vector3I.Zero, new Vector3I(-1, 0, 0) })
        {
            using var volume = new MesherFixture { center = (Vector3)key * 64 + new Vector3(32, 32, 32) };
            if (shoreline) volume.precise_shores.Add(new GDictionary { ["center"] = volume.center, ["radius"] = 20.0 });
            using var candidate = portal ? (CaveMesher)new PortalCaveMesher() : new CaveMesher();
            using var reference = GD.Load<GDScript>(portal ? "res://scripts/caves/portal_mesher.gd" : "res://scripts/caves/mesher.gd").New().AsGodotObject();
            candidate.capture_boundary_values = true; reference.Set("capture_boundary_values", true);
            long start = Stopwatch.GetTimestamp();
            var expected = reference.Call("build", volume, key, 2.0).AsGodotArray();
            double originalMs = Stopwatch.GetElapsedTime(start).TotalMilliseconds;
            start = Stopwatch.GetTimestamp(); var actual = candidate.build(volume, key, 2);
            double managedMs = Stopwatch.GetElapsedTime(start).TotalMilliseconds;
            Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(expected), GD.VarToBytes(actual)), $"Cave mesh payload differs: portal={portal}, shore={shoreline}, key={key}");
            Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(reference.Get("boundary_values")), GD.VarToBytes(candidate.boundary_values)), "Captured face values differ");
            Require(expected.Count > 0, "Empty cave fixture");
            GD.Print($"Cave mesher fixture portal={portal} shore={shoreline} key={key}: GDScript {originalMs:F2} ms; C# {managedMs:F2} ms. Field is native C# for this bounded comparison.");
        }
    }

    private void CheckReadyCut()
    {
        var original = GD.Load<GDScript>("res://scripts/terrain_ready_cut.gd");
        using var cut = new TerrainReadyCut(); using var planner = new TerrainPartition();
        Godot.Collections.Array Arrays(int resolution, bool invalid = false)
        {
            var vertices = new Vector3[(resolution + 1) * (resolution + 1) + 8 * resolution];
            int main = (resolution + 1) * (resolution + 1);
            for (int i = 0; i < vertices.Length; i++) vertices[i] = new Vector3(0, i < main ? 10 : invalid ? 20 : -10, 0);
            var result = new Godot.Collections.Array(); result.Resize((int)Mesh.ArrayType.Max); result[(int)Mesh.ArrayType.Vertex] = vertices; return result;
        }
        var arrays = Arrays(8); var profile = cut.edge_profiles(arrays, 8);
        Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(profile), GD.VarToBytes(original.Call("edge_profiles", arrays, 8))), "Skirt extraction differs");
        var invalidProfile = cut.edge_profiles(Arrays(8, true), 8);
        foreach (int offset in new[] { -3, 0, 2 })
        for (int level = 1; level <= 6; level++)
        for (int side = 0; side < 4; side++)
        {
            int width = 1 << level, origin = offset * width;
            var fine = side switch
            {
                0 => new Vector3I(origin, origin, 0), 1 => new Vector3I(origin + width - 1, origin, 0),
                2 => new Vector3I(origin, origin, 0), _ => new Vector3I(origin, origin + width - 1, 0)
            };
            var coarse = side switch
            {
                0 => new Vector3I(offset - 1, offset, level), 1 => new Vector3I(offset + 1, offset, level),
                2 => new Vector3I(offset, offset - 1, level), _ => new Vector3I(offset, offset + 1, level)
            };
            var resolutions = new GDictionary { [fine] = 8, [coarse] = 8 };
            var profiles = new GDictionary { [fine] = profile, [coarse] = profile };
            var expected = original.Call("covered_edge", fine, coarse, resolutions, profiles, planner).AsGodotDictionary();
            var actual = cut.covered_edge(fine, coarse, resolutions, profiles, planner);
            Require(actual.Count > 0 && System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(expected), GD.VarToBytes(actual)), $"Skirt coverage differs: {fine}/{coarse}");
            profiles[fine] = invalidProfile;
            Require(cut.covered_edge(fine, coarse, resolutions, profiles, planner).Count == 0
                && original.Call("covered_edge", fine, coarse, resolutions, profiles, planner).AsGodotDictionary().Count == 0, "Invalid curtain accepted");
            Require(cut.edge_id(fine, coarse) == original.Call("edge_id", fine, coarse).AsString(), "Certificate edge identity differs");
        }
        var parent = new Vector3I(-1, -1, 2);
        var active = new GDictionary { [parent] = true }; var wanted = new GDictionary(); var ready = new GDictionary();
        foreach (var child in planner.children(parent)) { wanted[child] = true; ready[child] = true; }
        var old = original.Call("choose", active, wanted, ready, planner, Vector2.Zero).AsGodotDictionary();
        var current = cut.choose(active, wanted, ready, planner, Vector2.Zero);
        Require(old.Count > 0 && GD.VarToStr(old) == GD.VarToStr(current), "Complete replacement differs");
        ready.Remove(planner.children(parent)[0]);
        Require(cut.choose(active, wanted, ready, planner, Vector2.Zero).Count == 0, "Incomplete replacement published");
        Require(cut.Call("contains", parent, new Vector3I(-3, -3, 0)).AsBool(), "Cut bridge missing");
    }

    private void CheckShaderVariants()
    {
        var original = GD.Load<GDScript>("res://scripts/terrain_shader_variants.gd");
        using var candidate = new TerrainShaderVariants();
        string source = GD.Load<Shader>("res://shaders/terrain_biomes.gdshader").Code;
        foreach (int mask in new[] { -1, 0, 1, 127, 191, 255, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65535, 65536, 0x5595, 0xAA6A })
        {
            string expected = original.Call("source_for", source, mask).AsString();
            Require(expected == candidate.source_for(source, mask), $"Shader source differs for mask {mask}");
        }
        foreach (string malformed in new[] { "", source.Replace("jungle_control.z>.999", "jungle_control.z>.998"), source + "for(int i=0;i<8;i++){" })
            Require(original.Call("source_for", malformed, 191).AsString() == candidate.source_for(malformed, 191), "Malformed dispatch handling differs");
        var settings = GD.Load<Resource>("res://config/world/terrain_settings.tres");
        Require(original.Call("configured_mask", settings).AsInt32() == candidate.configured_mask(settings), "Configured shader mask differs");
        Require(candidate.Call("configured_mask", settings).AsInt32() == candidate.configured_mask(settings), "Shader bridge unavailable");
        var shader = GD.Load<Shader>("res://shaders/terrain_biomes.gdshader");
        Require(candidate.select(shader, settings) == candidate.select(shader, settings), "Prepared shader is not reused");
        Require(candidate.select(shader, settings, false) == shader, "Disabled specialization changed shader");
    }

    private void CheckCamera(FreeCamera camera)
    {
        Require(!camera.debug_overlay_visible, "Diagnostics visible by default");
        var overlay = new CanvasLayer(); overlay.AddToGroup("terrain_debug_overlay"); AddChild(overlay);
        camera._set_debug_overlay_visible(true); Require(overlay.Visible, "Grouped hint did not show");
        camera._set_debug_overlay_visible(false); Require(!overlay.Visible, "Grouped hint did not hide"); overlay.QueueFree();
        Require(camera.Far == 50000, "Camera draw distance changed");
        Require(InputMap.HasAction("toggle_debug_overlay") && InputMap.HasAction("freecam_release_mouse"), "Input bindings missing");
        camera._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.WheelUp, Pressed = true });
        Require(camera.move_speed == 42, "Wheel speed differs");
        if (DisplayServer.GetName() != "headless")
        {
            Input.MouseMode = Input.MouseModeEnum.Captured;
            var old = camera.RotationDegrees;
            camera._Input(new InputEventMouseMotion { Relative = new Vector2(20, 10) });
            Require(camera.RotationDegrees.Y < old.Y && camera.RotationDegrees.X < old.X, "Captured look did not turn");
            camera._Input(new InputEventKey { PhysicalKeycode = Key.Escape, Pressed = true });
            Require(Input.MouseMode == Input.MouseModeEnum.Visible, "Escape did not release");
            camera._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true });
            Require(Input.MouseMode == Input.MouseModeEnum.Captured, "Click did not recapture");
            camera._Notification((int)NotificationApplicationFocusOut);
            Require(Input.MouseMode == Input.MouseModeEnum.Visible, "Focus loss did not release");
        }
    }

    private void Require(bool condition, string message)
    {
        _checks++;
        if (!condition) throw new InvalidOperationException(message);
    }

    private void CheckPlanner()
    {
        var script = GD.Load<GDScript>("res://scripts/terrain_partition.gd");
        long originalUsec = 0, managedUsec = 0;
        foreach (double size in new[] { 64.0, 256.0, 1024.0 })
        foreach (int level in new[] { 3, 5, 6 })
        {
            using var reference = script.New().AsGodotObject();
            using var candidate = new TerrainPartition { base_size = size, maximum_level = level };
            reference.Set("base_size", size); reference.Set("maximum_level", level);
            candidate.Set("split_ratio", 1.15);
            Require(candidate.Get("base_size").AsDouble() == size, "C# properties unavailable to transitional callers");
            Require(candidate.Call("parent", new Vector3I(-3, -5, 0)).AsVector3I() == new Vector3I(-2, -3, 1), "C# methods unavailable to transitional callers");
            var oldCut = new GDictionary(); var newCut = new GDictionary();
            foreach (var point in new[]
            {
                Vector2.Zero, new Vector2(-1, -1), new Vector2(-256, 256),
                new Vector2(100, 100), new Vector2(1024, 1024), new Vector2(21000, -19000),
                new Vector2(21001, -19001), new Vector2(-50000, 64000), Vector2.Zero
            })
            {
                long begin = Stopwatch.GetTimestamp();
                oldCut = reference.Call("select", point, oldCut).AsGodotDictionary();
                originalUsec += Stopwatch.GetElapsedTime(begin).Ticks / 10;
                begin = Stopwatch.GetTimestamp();
                newCut = candidate.select(point, newCut);
                managedUsec += Stopwatch.GetElapsedTime(begin).Ticks / 10;
                Require(oldCut.Count == newCut.Count, $"Leaf count differs at {point}/{size}/{level}");
                foreach (var pair in oldCut) Require(newCut.ContainsKey(pair.Key), $"Missing leaf {pair.Key}");
                foreach (var pair in newCut)
                {
                    var key = pair.Key.AsVector3I();
                    Require(reference.Call("parent", key).AsVector3I() == candidate.parent(key), "Negative parent division");
                    Require(reference.Call("bounds", key).AsRect2() == candidate.bounds(key), "Bounds differ");
                    Require(reference.Call("distance_to", key, point).AsDouble() == candidate.distance_to(key, point), "Distance differs");
                }
            }
            var reservation = new Godot.Collections.Array<Rect2> { new(new Vector2(-513, -513), new Vector2(30, 30)) };
            reference.Set("forced_detail_regions", reservation); candidate.forced_detail_regions = reservation;
            var reservedOld = reference.Call("select", Vector2.Zero, oldCut).AsGodotDictionary();
            var reservedNew = candidate.select(Vector2.Zero, newCut);
            Require(reservedOld.Count == reservedNew.Count, "Forced detail count differs");
            foreach (var pair in reservedOld) Require(reservedNew.ContainsKey(pair.Key), "Forced detail leaf differs");
        }
        GD.Print($"Planner diagnostic: GDScript {originalUsec / 1000.0:F3} ms; C# {managedUsec / 1000.0:F3} ms. Same-process bounded fixture, not world loading time.");
    }
}
