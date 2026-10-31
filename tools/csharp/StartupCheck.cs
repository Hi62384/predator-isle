using Godot;
using System;
using System.Diagnostics;
using PredatorIsle.Player;
using PredatorIsle.Terrain;
using PredatorIsle.Rendering;
using PredatorIsle.Caves;

namespace PredatorIsle.Checks;

public partial class StartupCheck : Node
{
    private double _elapsed;
    private bool _started;
    private double _firstVisible = -1;
    private double _firstCollision = -1;
    private double _caveDiscovery = -1;
    private readonly Stopwatch clock=Stopwatch.StartNew();
    private int lastProgress;
    private int traversal;
    private Vector3 startPosition;
    private double fullCoverageSeconds;
    private Godot.Collections.Dictionary? measurements;
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
        _elapsed = clock.Elapsed.TotalSeconds;
        var scene = GetTree().CurrentScene;
        if (scene != null && scene.SceneFilePath == "res://scenes/main.tscn")
        {
            var terrain = scene.GetNode("Terrain");
            var camera=scene.GetNode<FreeCamera>("FreeCamera");camera.SetProcess(false);camera.SetProcessInput(false);camera.SetProcessUnhandledInput(false);Input.MouseMode=Input.MouseModeEnum.Visible;
            int count = terrain.Call("get_loaded_chunk_count").AsInt32();
            if(traversal>0)
            {
                if(count==0||terrain.Get("last_error").AsString().Length>0){GD.PushError("Traversal lost its published terrain or hit a worker error");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                var point=camera.GlobalPosition;var planned=terrain.Get("_last_plan_position").AsVector2();
                if(planned.DistanceTo(new Vector2(point.X,point.Z))<.1&&terrain.Get("_startup_coverage_complete").AsBool()&&terrain.Get("committed_revision").AsInt64()==terrain.Get("partition_revision").AsInt64())
                {
                    using var query=PhysicsRayQueryParameters3D.Create(new Vector3(point.X,2000,point.Z),new Vector3(point.X,-1000,point.Z),1);
                    var hit=camera.GetWorld3D().DirectSpaceState.IntersectRay(query);
                    if(hit.Count==0){GD.PushError("Moved terrain has no physical ground");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                    double expected=terrain.Call("get_height_at",point).AsDouble();
                    if(Math.Abs(hit["position"].AsVector3().Y-expected)>.5){GD.PushError("Moved terrain collision differs from canonical ground");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                    if(traversal==1){traversal=2;camera.GlobalPosition=startPosition;}
                    else {GD.Print($"C# startup traversal checks passed: full coverage {fullCoverageSeconds:F3}s, move and return {_elapsed:F3}s");SetProcess(false);Callable.From(()=>CaptureAndFinish()).CallDeferred();}
                }
                if(_elapsed>170){GD.PushError("Terrain move and return exceeded 170 seconds");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();}return;
            }
            if((int)_elapsed/10>lastProgress){lastProgress=(int)_elapsed/10;GD.Print($"Startup {_elapsed:F1}s: {Json.Stringify(terrain.Call("get_ring_progress"))}; stages {Json.Stringify(terrain.Get("startup_timings"))}");}
            if (count > 0 && _firstVisible < 0) _firstVisible = _elapsed;
            bool collisionReady = false;
            foreach (var entry in terrain.Get("_active_chunks").AsGodotDictionary())
            {
                var node = entry.Value.AsGodotObject() as MeshInstance3D;
                var body = node?.GetNodeOrNull<StaticBody3D>("NearTerrainCollision");
                var shape = body?.GetNodeOrNull<CollisionShape3D>("Heightfield");
                if (entry.Key.AsVector3I().Z == 0 && body?.CollisionLayer == 1 && shape?.Shape != null) { collisionReady = true; break; }
            }
            var streamer = terrain.Get("_cave_streamer").AsGodotObject();
            bool caveBundleReady = streamer != null && streamer.Get("_bundle").AsGodotDictionary().Count > 0;
            if (collisionReady && _firstCollision < 0) _firstCollision = _elapsed;
            if (caveBundleReady && _caveDiscovery < 0) _caveDiscovery = _elapsed;
            if (count > 9 && collisionReady && caveBundleReady && terrain.Get("_startup_coverage_complete").AsBool())
            {
                if (scene.GetNode("FreeCamera") is not FreeCamera || terrain.Get("_partition").AsGodotObject() is not TerrainPartition || terrain.Get("_ready_cut").AsGodotObject() is not TerrainReadyCut)
                { GD.PushError("Startup did not bind C# runtime modules"); GetTree().Quit(1); return; }
                if (terrain.Get("_collision").AsGodotObject() is not TerrainCollision) { GD.PushError("C# collision was not bound"); GetTree().Quit(1); return; }
                var placementReference=GD.Load<GDScript>("res://scripts/jungle_placement.gd");var queryBuilder=terrain.Get("_sampler").AsGodotObject();var queryPoint=new Vector3(24,0,24);var queryBounds=new Rect2(24,24,8,8);
                if(!System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(placementReference.Call("habitat",queryBuilder,queryPoint.X,queryPoint.Z)),GD.VarToBytes(terrain.Call("get_jungle_habitat_at",queryPoint)))||!System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(placementReference.Call("candidates",queryBuilder,queryBounds,24,2,0)),GD.VarToBytes(terrain.Call("get_jungle_spawn_candidates",queryBounds,24,2,0))))
                { GD.PushError("Main terrain controller Jungle placement interface differs"); GetTree().Quit(1); return; }
                bool nativeWorker = false;
                foreach (var item in streamer!.Get("_idle").AsGodotArray()) if (item.AsGodotObject() is CaveWorkload) nativeWorker = true;
                foreach (var item in streamer!.Get("_jobs").AsGodotDictionary().Values) if (item.AsGodotDictionary()["work"].AsGodotObject() is CaveWorkload) nativeWorker = true;
                if (!nativeWorker) { GD.PushError("Actual cave streamer did not retain a C# worker"); GetTree().Quit(1); return; }
                GD.Print($"C# startup check passed: first visible {_firstVisible:F3}s; LOD0 collision {_firstCollision:F3}s; cave discovery {_caveDiscovery:F3}s; {count} visible terrain chunks. Actual saved launch scene and complete initial terrain coverage.");
                measurements = new Godot.Collections.Dictionary { ["first_visible_seconds"] = _firstVisible,
                    ["lod0_collision_seconds"] = _firstCollision, ["cave_discovery_seconds"] = _caveDiscovery,
                    ["full_coverage_and_cave_bundle_seconds"] = _elapsed, ["visible_chunks"] = count, ["ring_progress"]=terrain.Call("get_ring_progress"),["main_startup_stages"]=terrain.Get("startup_timings"), ["cache_state"] = "uncontrolled" };
                fullCoverageSeconds=_elapsed;startPosition=camera.GlobalPosition;traversal=1;camera.GlobalPosition=startPosition+new Vector3(96,0,64);
            }
        }
        if (_elapsed > 120) { GD.PushError("C# startup exceeded 120 seconds");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred(); }
    }
    private async void CaptureAndFinish()
    {
        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        using(var pixels=GetViewport().GetTexture().GetImage())
            if(pixels.SavePng("res://data/startup_verified_render.png")!=Error.Ok){GD.PushError("Could not save rendered startup proof");Cleanup(1);return;}
        measurements!["move_and_return_complete_seconds"]=clock.Elapsed.TotalSeconds;
        measurements["move_distance_metres"]=new Vector3(96,0,64).Length();
        measurements["render_capture"]="res://data/startup_verified_render.png";
        MigrationEvidence.Write("startup",4,true,measurements);
        Cleanup();
    }
    private async void Cleanup(int exitCode=0)
    {
        if(exitCode!=0)MigrationEvidence.Write("startup",0,false,measurements,"Startup or physical move-and-return failed; inspect this run's engine log.");
        var tree=GetTree();tree.CurrentScene?.Free();await ToSignal(tree,SceneTree.SignalName.ProcessFrame);GC.Collect();GC.WaitForPendingFinalizers();await ToSignal(tree,SceneTree.SignalName.ProcessFrame);tree.CallDeferred(SceneTree.MethodName.Quit,exitCode);
    }
}
