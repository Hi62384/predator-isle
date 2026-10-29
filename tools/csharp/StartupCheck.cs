using Godot;
using System;
using PredatorIsle.Player;
using PredatorIsle.Terrain;
using PredatorIsle.Rendering;

namespace PredatorIsle.Checks;

public partial class StartupCheck : Node
{
    private double _elapsed;
    private bool _started;
    public override void _Ready()
    {
        // The fixture remains a sibling when WorldStartup replaces the current scene.
        var tree = GetTree();
        Callable.From(() =>
        {
            Reparent(tree.Root);
            _started = true;
            tree.ChangeSceneToFile("res://scenes/world_startup.tscn");
        }).CallDeferred();
    }
    public override void _Process(double delta)
    {
        if (!_started) return;
        _elapsed += delta;
        var scene = GetTree().CurrentScene;
        if (scene != null && scene.SceneFilePath == "res://scenes/main.tscn")
        {
            var terrain = scene.GetNode("Terrain");
            int count = terrain.Call("get_loaded_chunk_count").AsInt32();
            if (count > 0)
            {
                if (scene.GetNode("FreeCamera") is not FreeCamera || terrain.Get("_partition").AsGodotObject() is not TerrainPartition || terrain.Get("_ready_cut").AsGodotObject() is not TerrainReadyCut)
                { GD.PushError("Startup did not bind C# runtime modules"); GetTree().Quit(1); return; }
                GD.Print($"C# startup check passed: {_elapsed:F3}s, {count} visible terrain chunks; actual saved launch scene and shader preparation. Not a full cut or traversal benchmark.");
                SetProcess(false); GetTree().Quit();
            }
        }
        if (_elapsed > 120) { GD.PushError("C# startup exceeded 120 seconds"); GetTree().Quit(1); }
    }
}
