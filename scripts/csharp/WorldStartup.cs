using Godot;
using System;
using PredatorIsle.Rendering;

namespace PredatorIsle;

public partial class WorldStartup : Control
{
    public override async void _Ready()
    {
        try
        {
            var tree = GetTree();
            await ToSignal(tree, SceneTree.SignalName.ProcessFrame);
            await TerrainShaderPreparation.Prepare(tree, GD.Load<Resource>("res://config/world/terrain_settings.tres"));
            Error result = tree.ChangeSceneToFile("res://scenes/main.tscn");
            if (result != Error.Ok) throw new InvalidOperationException($"Could not open main world: {result}");
        }
        catch (Exception error)
        {
            GD.PushError(error.ToString());
            GetNode<Label>("Title").Text = "PREDATOR ISLE\nWorld loading failed. See the error log.";
        }
    }
}
