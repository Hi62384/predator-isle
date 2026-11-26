using Godot;
using System;
using System.Linq;
using PredatorIsle.Rendering;
using PredatorIsle.Terrain;

namespace PredatorIsle;

public partial class WorldStartup : Control
{
    public override async void _Ready()
    {
        try
        {
            var tree = GetTree();
            await ToSignal(tree, SceneTree.SignalName.ProcessFrame);
            ulong started = Time.GetTicksUsec();
            TerrainWorkerScripts.Prepare();
            bool authority=OS.HasFeature("dedicated_server")||OS.GetCmdlineUserArgs().Contains("terrain-server");
            if(!authority)
            {
                GetNode<Label>("Title").Text = "PREDATOR ISLE\nPreparing terrain shaders (first launch may take longer)...";
                await ToSignal(tree, SceneTree.SignalName.ProcessFrame);
                GD.Print("Startup: preparing terrain shaders");
                await TerrainShaderPreparation.Prepare(tree, GD.Load<Resource>("res://config/world/terrain_settings.tres"));
                GD.Print($"Startup: terrain shaders ready in {(Time.GetTicksUsec() - started) / 1000000.0:F2}s; loading world");
                GetNode<Label>("Title").Text = "PREDATOR ISLE\nLoading your world...";
                await ToSignal(tree, SceneTree.SignalName.ProcessFrame);
            }
            Error result = tree.ChangeSceneToFile(authority?"res://scenes/terrain_server.tscn":"res://scenes/main.tscn");
            if (result != Error.Ok) throw new InvalidOperationException($"Could not open main world: {result}");
        }
        catch (Exception error)
        {
            GD.PushError(error.ToString());
            GetNode<Label>("Title").Text = "PREDATOR ISLE\nWorld loading failed. See the error log.";
        }
    }
}
