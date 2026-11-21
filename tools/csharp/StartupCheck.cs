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
    private readonly DateTimeOffset fixtureStarted=DateTimeOffset.UtcNow;
    private int lastProgress;
    private int traversal;
    private Vector3 startPosition;
    private double fullCoverageSeconds;
    private Godot.Collections.Dictionary? measurements;
    private readonly Godot.Collections.Array movementMeasurements=new();
    private double movementStart;
    private bool nearbyMeasured;
    private int pathPhase,pathGroundChecks;
    private double phaseStart,nextPathProbe;
    private Vector3 teleportDestination,heldPosition;
    private readonly System.Collections.Generic.List<double> frameMilliseconds=new(),gpuMilliseconds=new();
    private readonly Godot.Collections.Array pathMeasurements=new();
    private bool measureGpu;
    public override void _Ready()
    {
        // The fixture remains a sibling when WorldStartup replaces the current scene.
        var tree = GetTree();
        if(DisplayServer.GetName()!="headless"){GetWindow().Mode=Window.ModeEnum.Windowed;GetWindow().Size=new Vector2I(1920,1080);}
        measureGpu=System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"terrain-path-check");if(measureGpu)RenderingServer.ViewportSetMeasureRenderTime(GetViewport().GetViewportRid(),true);
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
        if(_firstVisible>0){frameMilliseconds.Add(delta*1000);if(measureGpu){double gpu=RenderingServer.ViewportGetMeasuredRenderTimeGpu(GetViewport().GetViewportRid());if(gpu>0)gpuMilliseconds.Add(gpu);}}
        var scene = GetTree().CurrentScene;
        if (scene != null && scene.SceneFilePath == "res://scenes/main.tscn")
        {
            var terrain = scene.GetNode("Terrain");
            var camera=scene.GetNode<FreeCamera>("FreeCamera");camera.SetProcess(false);camera.SetProcessInput(false);camera.SetProcessUnhandledInput(false);Input.MouseMode=Input.MouseModeEnum.Visible;
            int count = terrain.Call("get_loaded_chunk_count").AsInt32();
            if(pathPhase>0){CheckPath(terrain,camera,count);return;}
            if(traversal>0)
            {
                if(count==0||terrain.Get("last_error").AsString().Length>0){GD.PushError("Traversal lost its published terrain or hit a worker error");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                var point=camera.GlobalPosition;var planned=terrain.Get("_last_plan_position").AsVector2();
                var progress=terrain.Call("get_ring_progress").AsGodotDictionary();
                if(!nearbyMeasured&&planned.DistanceTo(new Vector2(point.X,point.Z))<.1&&progress["nearby_published"].AsBool()&&NearbyGroundReady(terrain,camera))
                {
                    nearbyMeasured=true;double seconds=_elapsed-movementStart;movementMeasurements.Add(new Godot.Collections.Dictionary{["step"]=traversal,["nearby_collision_seconds"]=seconds,["full_cut_already_ready"]=progress["complete"],["local_publications"]=progress["local_publications"],["destination"]=point});GD.Print($"Movement {traversal}: nearby 3x3 with physical ground {seconds:F3}s; full cut ready {progress["complete"]}");
                }
                if(planned.DistanceTo(new Vector2(point.X,point.Z))<.1&&terrain.Get("_startup_coverage_complete").AsBool()&&terrain.Get("committed_revision").AsInt64()==terrain.Get("partition_revision").AsInt64())
                {
                    using var query=PhysicsRayQueryParameters3D.Create(new Vector3(point.X,2000,point.Z),new Vector3(point.X,-1000,point.Z),1);
                    var hit=camera.GetWorld3D().DirectSpaceState.IntersectRay(query);
                    if(hit.Count==0){GD.PushError("Moved terrain has no physical ground");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                    double expected=terrain.Call("get_height_at",point).AsDouble();
                    if(Math.Abs(hit["position"].AsVector3().Y-expected)>.5){GD.PushError("Moved terrain collision differs from canonical ground");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                    if(!nearbyMeasured){GD.PushError("Full cut reported ready before the nearby nine physical owners were usable");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();return;}
                    if(traversal<4){traversal++;movementStart=_elapsed;nearbyMeasured=false;camera.GlobalPosition=traversal==3?startPosition+new Vector3(96,0,64):startPosition;}
                    else {GD.Print($"C# startup traversal checks passed: full coverage {fullCoverageSeconds:F3}s, moves and returns {_elapsed:F3}s");if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"terrain-path-check")){pathPhase=1;phaseStart=_elapsed;nextPathProbe=_elapsed;}else{SetProcess(false);Callable.From(()=>CaptureAndFinish()).CallDeferred();}}
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
                    ["fixture_started_utc"]=fixtureStarted.ToString("O"),
                    ["lod0_collision_seconds"] = _firstCollision, ["cave_discovery_seconds"] = _caveDiscovery,
                    ["full_coverage_and_cave_bundle_seconds"] = _elapsed, ["visible_chunks"] = count, ["ring_progress"]=terrain.Call("get_ring_progress"),["main_startup_stages"]=terrain.Get("startup_timings"), ["cache_state"] = "uncontrolled" };
                fullCoverageSeconds=_elapsed;startPosition=camera.GlobalPosition;traversal=1;movementStart=_elapsed;camera.GlobalPosition=startPosition+new Vector3(16,0,0);
            }
        }
        if (_elapsed > 120) { GD.PushError("C# startup exceeded 120 seconds");SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred(); }
    }
    private void CheckPath(Node terrain,FreeCamera camera,int count)
    {
        if(count==0||terrain.Get("last_error").AsString().Length>0||_elapsed>170){Fail("Continuous movement/teleport lost coverage, hit a worker error or exceeded its deadline");return;}
        if(pathPhase==1)
        {
            camera.GlobalPosition=startPosition+Vector3.Right*(float)(Math.Min(16,_elapsed-phaseStart)*12);
            if(_elapsed>=nextPathProbe)
            {
                nextPathProbe=_elapsed+.2;var point=camera.GlobalPosition;
                using var query=PhysicsRayQueryParameters3D.Create(new Vector3(point.X,2000,point.Z),new Vector3(point.X,-1000,point.Z),1);var hit=camera.GetWorld3D().DirectSpaceState.IntersectRay(query);
                if(hit.Count==0||Math.Abs(hit["position"].AsVector3().Y-terrain.Call("get_height_at",point).AsDouble())>.5){Fail("Continuous movement entered missing or incorrect physical ground");return;}pathGroundChecks++;
            }
            if(_elapsed-phaseStart<16)return;
            pathMeasurements.Add(new Godot.Collections.Dictionary{["kind"]="continuous_movement",["seconds"]=_elapsed-phaseStart,["speed_metres_per_second"]=12,["distance_metres"]=192,["physical_ground_probes"]=pathGroundChecks,["progress"]=terrain.Call("get_ring_progress")});pathPhase=2;
        }
        if(pathPhase==2)
        {
            if(!terrain.Call("get_ring_progress").AsGodotDictionary()["complete"].AsBool())return;
            teleportDestination=startPosition+new Vector3(2048,0,-1536);teleportDestination.Y=(float)Math.Max(terrain.Call("get_height_at",teleportDestination).AsDouble()+30,30);heldPosition=camera.GlobalPosition;phaseStart=_elapsed;pathPhase=3;terrain.Call("request_teleport",teleportDestination);return;
        }
        if(terrain.Get("_teleport_pending").AsBool())
        {if(camera.GlobalPosition.DistanceTo(heldPosition)>.001)Fail("Teleport moved the camera before destination readiness");return;}
        if(camera.GlobalPosition.DistanceTo(teleportDestination)>.001){Fail("Teleport did not arrive at its requested destination");return;}
        if(!NearbyGroundReady(terrain,camera))return; // Physics broadphase follows the atomic cut on the next tick.
        pathMeasurements.Add(new Godot.Collections.Dictionary{["kind"]=pathPhase==3?"uncached_teleport":"cached_return_teleport",["seconds"]=_elapsed-phaseStart,["progress"]=terrain.Call("get_ring_progress")});
        if(pathPhase==3){heldPosition=camera.GlobalPosition;teleportDestination=startPosition;phaseStart=_elapsed;pathPhase=4;terrain.Call("request_teleport",teleportDestination);return;}
        GD.Print($"C# continuous movement and atomic teleport checks passed: {pathGroundChecks} physical probes");SetProcess(false);Callable.From(()=>CaptureAndFinish()).CallDeferred();
        void Fail(string reason){GD.PushError(reason);SetProcess(false);Callable.From(()=>Cleanup(1)).CallDeferred();}
    }
    private static bool NearbyGroundReady(Node terrain,FreeCamera camera)
    {
        var active=terrain.Get("_active_chunks").AsGodotDictionary();var position=camera.GlobalPosition;int cx=(int)Math.Floor(position.X/16),cz=(int)Math.Floor(position.Z/16);
        for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++)
        {
            var key=new Vector3I(cx+dx,cz+dz,0);if(!active.TryGetValue(key,out var entry))return false;
            var node=entry.As<MeshInstance3D>();var body=node.GetNodeOrNull<StaticBody3D>("NearTerrainCollision");if(!node.Visible||body?.CollisionLayer!=1||body.GetNodeOrNull<CollisionShape3D>("Heightfield")?.Shape is null)return false;
            var point=new Vector3((cx+dx+.5f)*16,0,(cz+dz+.5f)*16);
            using var query=PhysicsRayQueryParameters3D.Create(point+Vector3.Up*2000,point-Vector3.Up*1000,1);var hit=camera.GetWorld3D().DirectSpaceState.IntersectRay(query);
            if(hit.Count==0||Math.Abs(hit["position"].AsVector3().Y-terrain.Call("get_height_at",point).AsDouble())>.5)return false;
        }
        return true;
    }
    private async void CaptureAndFinish()
    {
        // Animated swash otherwise changes the reference image with load duration.
        // Capture-only control: ordinary gameplay materials retain their settings.
        var terrain=GetTree().CurrentScene.GetNode("Terrain");
        foreach(var value in terrain.Get("_active_chunks").AsGodotDictionary().Values)
        {
            var node=value.As<MeshInstance3D>();
            if(node.Mesh?.SurfaceGetMaterial(0) is ShaderMaterial material)material.SetShaderParameter("beach_swash",0.0);
        }
        var frozen=new System.Collections.Generic.HashSet<ulong>();
        foreach(var item in GetTree().CurrentScene.FindChildren("*","MeshInstance3D",true,false))
        {
            var mesh=(MeshInstance3D)item;if(mesh.Mesh is null)continue;
            for(int slot=0;slot<mesh.Mesh.GetSurfaceCount();slot++)
                if(mesh.GetActiveMaterial(slot) is ShaderMaterial material&&frozen.Add(material.GetInstanceId())&&material.Shader is not null&&material.Shader.Code.Contains("TIME",StringComparison.Ordinal))
                    material.Shader=new Shader{Code=System.Text.RegularExpressions.Regex.Replace(material.Shader.Code,"\\bTIME\\b","0.0")};
        }
        await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        using(var pixels=GetViewport().GetTexture().GetImage())
        {
            measurements!["render_width"]=pixels.GetWidth();measurements["render_height"]=pixels.GetHeight();
            if(pixels.SavePng("res://data/startup_verified_render.png")!=Error.Ok){GD.PushError("Could not save rendered startup proof");Cleanup(1);return;}
        }
        measurements!["move_and_return_complete_seconds"]=clock.Elapsed.TotalSeconds;
        measurements["movement_nearby_milestones"]=movementMeasurements;
        measurements["extended_path"]=pathMeasurements;
        measurements["frame_time_after_first_visible_ms"]=Percentiles(frameMilliseconds);
        measurements["viewport_gpu_time_ms"]=Percentiles(gpuMilliseconds);
        measurements["frame_measurement_scope"]="Fixture process delta after first visible terrain, includes streaming and VSync; GPU values are viewport timestamps where the renderer reports them. No isolated minimum-spec claim.";
        measurements["final_ring_progress"]=terrain.Call("get_ring_progress");
        int gridInstances=0,materializedCpuArrays=0;var sharedMeshes=new System.Collections.Generic.HashSet<Rid>();
        foreach(var value in terrain.Get("_active_chunks").AsGodotDictionary().Values)
        {
            var node=value.As<MeshInstance3D>();var grid=node.GetNodeOrNull<MeshInstance3D>("TerrainGrid");if(grid?.Mesh is null||!grid.Visible)continue;
            gridInstances++;sharedMeshes.Add(grid.Mesh.GetRid());
            if(node.Mesh.GetMeta("terrain_cpu_payload").As<TerrainCpuSurfacePayload>().Data.CpuArraysMaterialized)materializedCpuArrays++;
            if(node.Mesh.GetSurfaceCount()!=1||((ArrayMesh)node.Mesh).SurfaceGetArrayLen(0)!=3){GD.PushError("GPU grid path uploaded a full CPU render mesh as well");Cleanup(1);return;}
        }
        measurements["active_grid_instances"]=gridInstances;measurements["active_shared_grid_buffers"]=sharedMeshes.Count;
        measurements["gpu_patches_with_materialized_cpu_render_arrays"]=materializedCpuArrays;
        if(materializedCpuArrays>0){GD.PushError("Ordinary GPU terrain eagerly materialized its CPU fallback arrays");Cleanup(1);return;}
        if(terrain.Call("get_ring_progress").AsGodotDictionary()["gpu_render_grids"].AsBool()&&(gridInstances<9||sharedMeshes.Count>=gridInstances)){GD.PushError("Configured GPU terrain did not reuse mesh buffers");Cleanup(1);return;}
        measurements["move_distance_metres"]=new Vector3(96,0,64).Length();
        measurements["render_capture"]="res://data/startup_verified_render.png";
        measurements["capture_beach_swash"]=0.0;
        measurements["capture_standalone_shader_time"]=0.0;
        MigrationEvidence.Write("startup",4,true,measurements);
        Cleanup();
    }
    private static Godot.Collections.Dictionary Percentiles(System.Collections.Generic.List<double> values)
    {
        values.Sort();if(values.Count==0)return new(){["samples"]=0};double At(double p)=>values[(int)Math.Clamp(Math.Ceiling(values.Count*p)-1,0,values.Count-1)];
        return new(){["samples"]=values.Count,["p50"]=At(.5),["p95"]=At(.95),["p99"]=At(.99),["max"]=values[^1]};
    }
    private async void Cleanup(int exitCode=0)
    {
        if(exitCode!=0)MigrationEvidence.Write("startup",0,false,measurements,"Startup or physical move-and-return failed; inspect this run's engine log.");
        var tree=GetTree();tree.CurrentScene?.Free();await ToSignal(tree,SceneTree.SignalName.ProcessFrame);GC.Collect();GC.WaitForPendingFinalizers();await ToSignal(tree,SceneTree.SignalName.ProcessFrame);tree.CallDeferred(SceneTree.MethodName.Quit,exitCode);
    }
}
