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
    private double _firstVisible = -1;
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
            if (count > 0 && _firstVisible < 0) _firstVisible = _elapsed;
            bool collisionReady = false;
            foreach (var entry in terrain.Get("_active_chunks").AsGodotDictionary())
            {
                var node = entry.Value.AsGodotObject() as MeshInstance3D;
                var body = node?.GetNodeOrNull<StaticBody3D>("NearTerrainCollision");
                var shape = body?.GetNodeOrNull<CollisionShape3D>("Heightfield");
                if (entry.Key.AsVector3I().Z == 0 && body?.CollisionLayer == 1 && shape?.Shape != null) { collisionReady = true; break; }
            }
            if (count > 0 && collisionReady)
            {
                if (scene.GetNode("FreeCamera") is not FreeCamera || terrain.Get("_partition").AsGodotObject() is not TerrainPartition || terrain.Get("_ready_cut").AsGodotObject() is not TerrainReadyCut)
                { GD.PushError("Startup did not bind C# runtime modules"); GetTree().Quit(1); return; }
                if (terrain.Get("_collision").AsGodotObject() is not TerrainCollision) { GD.PushError("C# collision was not bound"); GetTree().Quit(1); return; }
                GD.Print($"C# startup check passed: first visible {_firstVisible:F3}s; LOD0 collision ready {_elapsed:F3}s; {count} visible terrain chunks. Actual saved launch scene, shader preparation and near physics. Not a full cut or traversal benchmark.");
                SetProcess(false); GetTree().Quit();
            }
        }
        if (_elapsed > 120) { GD.PushError("C# startup exceeded 120 seconds"); GetTree().Quit(1); }
    }
}
