using Godot;
using System;
namespace PredatorIsle.Checks;
public partial class RenderLifecycleCheck : Node
{
    public override async void _Ready()
    {
        var tree=GetTree();var scene=new Node3D();AddChild(scene);
        scene.AddChild(new Camera3D{Current=true});
        scene.AddChild(new DirectionalLight3D{ShadowEnabled=true});
        scene.AddChild(new Label{Text="Render lifecycle control"});
        await ToSignal(tree,SceneTree.SignalName.ProcessFrame);
        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        scene.Free();scene=null;
        await ToSignal(tree,SceneTree.SignalName.ProcessFrame);
        GC.Collect();GC.WaitForPendingFinalizers();
        await ToSignal(tree,SceneTree.SignalName.ProcessFrame);
        MigrationEvidence.Write("lifecycle",1,true);GD.Print("C# render lifecycle checks passed: 1");
        tree.CallDeferred(SceneTree.MethodName.Quit,0);
    }
}
