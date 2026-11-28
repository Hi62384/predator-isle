using Godot;
using PredatorIsle.Rendering;
using PredatorIsle.Terrain;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class TerrainFlightCheck : Node
{
    private ChunkTerrain terrain = null!;
    private Node3D camera = null!;
    private ulong start, flight, last;
    private readonly HashSet<Vector3I> initialRings=new(),movingRings=new();
    private double firstSecond=-1,firstThird=-1;
    private Vector3 origin;
    private int ticks, near;
    private ulong stopped;
    private double firstReplacement=-1;
    private readonly Dictionary<Vector3I,ulong> atStop=new();
    private bool sprint, warm, bend, capture, auditGround, cavePass;
    private int groundChecks, holes, caveChecks, caveGaps, cavePictures;
    private bool sawBeachEntrance;
    private int beachEntranceDropouts;
    private readonly double[] caveCaptureTimes={3.88,4.18,4.48};
    private readonly Vector3 beachMouth=new(50,26,371);
    private Vector3I? lastCell;
    private double longest;
    private Label fps=null!,speedReadout=null!;
    private int hudStep;

    private readonly HashSet<int> completedLevels = new();
    private readonly ulong[] firstLayer=new ulong[5];
    private ulong thirdComplete;
    private readonly HashSet<int> startupLevels = new();
    private readonly HashSet<Vector3I> seen = new();

    public override async void _Ready()
    {
        SetProcess(false);
        if (Array.IndexOf(OS.GetCmdlineUserArgs(), "from-world-startup") >= 0)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            TerrainWorkerScripts.Prepare();
            await TerrainShaderPreparation.Prepare(GetTree(),
                GD.Load<Resource>("res://config/world/terrain_settings.tres"));
        }
        sprint = Array.IndexOf(OS.GetCmdlineUserArgs(),"sprint")>=0;
        warm = Array.IndexOf(OS.GetCmdlineUserArgs(),"warm")>=0;
        bend=Array.IndexOf(OS.GetCmdlineUserArgs(),"turn")>=0;
        capture=Array.IndexOf(OS.GetCmdlineUserArgs(),"capture")>=0;
        cavePass=Array.IndexOf(OS.GetCmdlineUserArgs(),"cave-pass")>=0;
        auditGround=cavePass || Array.IndexOf(OS.GetCmdlineUserArgs(),"audit-ground")>=0;
        var world = GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
        AddChild(world);
        terrain = world.GetNode<ChunkTerrain>("Terrain");
        camera = world.GetNode<Node3D>("FreeCamera");
        fps=world.GetNode<Label>("Interface/FrameRate");
        speedReadout=world.GetNode<Label>("Interface/FlightSpeed");
        origin = camera.GlobalPosition;
        if(cavePass)
        {
            origin=beachMouth+new Vector3(0,94,-450);
            camera.GlobalPosition=origin;
            camera.LookAt(beachMouth);
        }
        start = Time.GetTicksMsec();
        SetProcess(true);
    }

    public override void _Process(double delta)
    {
        if(hudStep==0 && fps.Text.EndsWith(" FPS"))
        {
            camera._UnhandledInput(new InputEventMouseButton{Pressed=true,ButtonIndex=MouseButton.WheelUp});
            hudStep=1;
        }
        else if(hudStep==1 && speedReadout.IsVisibleInTree() && speedReadout.Text.Contains("42"))
        {
            camera._UnhandledInput(new InputEventMouseButton{Pressed=true,ButtonIndex=MouseButton.WheelDown});
            hudStep=2;
        }
        else if(hudStep==2 && speedReadout.Text.Contains("35"))hudStep=3;
        ulong now = Time.GetTicksMsec();
        if (Array.IndexOf(OS.GetCmdlineUserArgs(),"five-layers") >= 0)
        {
            foreach (var item in terrain._active_chunks.Keys)
            {
                int level = item.AsVector3I().Z;
                if (level < 5 && startupLevels.Add(level))
                {
                    firstLayer[level]=now;
                    GD.Print($"Published layer {level + 1} at {now - start} ms");
                }
            }
            var plan = terrain.RequestedRingPlan;
            if (plan is not null)
            {
                for (int level = 0; level < 5; level++)
                {
                    var patches = plan.Patches.Where(p => p.Key.Z == level).ToArray();
                    if (patches.Length == 0) continue;
                    if (patches.All(p => terrain._active_chunks.ContainsKey(p.Key)) && completedLevels.Add(level))
                    {
                        if(level==2)thirdComplete=now;
                        GD.Print($"Finished layer {level + 1} at {now - start} ms");
                    }
                    int prerequisite=Math.Min(level-1,2);
                    if (level > 0 && startupLevels.Contains(level) && !completedLevels.Contains(prerequisite))
                    {
                        GD.PushError($"Layer {level + 1} appeared before layer {level} finished");
                        GetTree().Quit(1);
                        return;
                    }
                }
            }
            bool complete = startupLevels.Count == 5 && plan is not null &&
                plan.Patches.Where(p => p.Key.Z < 5).All(p => terrain._active_chunks.ContainsKey(p.Key));
            if (complete || now - start > 60000)
            {
                GD.Print($"Five full layers complete={complete} at {now - start} ms");
                long fourthGap=(long)firstLayer[3]-(long)thirdComplete,fifthGap=(long)firstLayer[4]-(long)thirdComplete;
                GD.Print($"From layer 3 completion to first layer 4/5 tiles: {fourthGap}/{fifthGap} ms");
                GetTree().Quit(complete && fourthGap==0 && fifthGap==0 ? 0 : 1);
            }
            return;
        }
        if (flight == 0)
        {
            if (terrain._active_chunks.Count == 0 || warm && terrain.committed_revision!=terrain.partition_revision ||
                auditGround && !(terrain.RequestedRingPlan?.Patches.Where(p=>p.Key.Z<=2).All(p=>terrain._active_chunks.ContainsKey(p.Key)) ?? false))
            {
                if (now-start>90000){GD.PushError("Terrain did not finish test setup");SetProcess(false);GetTree().Quit(1);}
                return;
            }
            GD.Print($"Flight starts with {terrain._active_chunks.Count} published chunks");
            foreach(var item in terrain._active_chunks.Keys)initialRings.Add(item.AsVector3I());
            flight = last = now;
        }
        double t = (now-flight)/1000.0;
        if(t>=12 && Array.IndexOf(OS.GetCmdlineUserArgs(),"settle")>=0)
        {
            if(stopped==0)
            {
                stopped=now;
                foreach(var pair in terrain._active_chunks)atStop[pair.Key.AsVector3I()]=pair.Value.As<MeshInstance3D>().GetInstanceId();
            }
            foreach(var pair in terrain._active_chunks)
                if(firstReplacement<0 && atStop.TryGetValue(pair.Key.AsVector3I(),out var prior) &&
                    prior!=pair.Value.As<MeshInstance3D>().GetInstanceId())firstReplacement=(now-stopped)/1000.0;
            if(terrain.partition_revision!=terrain.committed_revision)
            {
                if(now-stopped>90000){GD.PushError("Terrain failed to settle");SetProcess(false);GetTree().Quit(1);}
                return;
            }
            GD.Print($"After stopping: first same-key replacement {firstReplacement:F2}s, complete {(now-stopped)/1000.0:F2}s");
            now=stopped;t=12;
        }
        float speed=sprint?105:35;
        var direction=cavePass?Vector3.Back:bend?new Vector3(-1,0,-1).Normalized():Vector3.Right;
        camera.GlobalPosition=origin+direction*speed*(float)Math.Min(t,6)+
            (bend?Vector3.Back:direction)*speed*(float)Math.Max(0,t-6);
        if(cavePass && t*speed<445)camera.LookAt(beachMouth);
        if(capture && DisplayServer.GetName()!="headless")
        {
            if(cavePass && cavePictures<caveCaptureTimes.Length && t>=caveCaptureTimes[cavePictures] && t<4.85)
            {
                var frame=GetViewport().GetTexture().GetImage();
                string file=System.IO.Path.Combine(System.IO.Path.GetTempPath(),$"predator-cave-flyby-{cavePictures++}.png");
                System.Threading.Tasks.Task.Run(()=>
                {
                    using(frame)frame.SavePng(file);
                });
            }
            else if(!cavePass && t>5)
            {
                capture=false;
                using var frame=GetViewport().GetTexture().GetImage();
                frame.SavePng(System.IO.Path.Combine(System.IO.Path.GetTempPath(),"predator-flight-check.png"));
            }
        }
        var cell = terrain.world_to_chunk(camera.GlobalPosition);
        var key = new Vector3I(cell.X,cell.Y,0);
        if(auditGround)
        {
            for(int z=-1;z<=1;z++)
            for(int x=-1;x<=1;x++)
            {
                var sample=cell+new Vector2I(x,z);
                groundChecks++;
                if(!terrain.HasVisibleGround(sample))
                {
                    if(holes==0) GD.Print($"First uncovered terrain cell {sample} at {t:F2}s");
                    holes++;
                }
            }
            if (cavePass && camera.GlobalPosition.Z - beachMouth.Z is >= -420 and <= 96)
            {
                var stream=terrain.GetNode<PredatorIsle.Caves.CaveStreamer>("CaveStreaming");
                bool visible = stream._surface_columns.ContainsKey(new Vector2I(0,5));
                if (sawBeachEntrance && !visible) beachEntranceDropouts++;
                sawBeachEntrance |= visible;
                if (Math.Abs(camera.GlobalPosition.Z-beachMouth.Z) < 96)
                {
                    caveChecks++;
                    if (terrain.HasCavePreviewOverlap || !visible ||
                        terrain.CaveBorderSegments == 0 || terrain.UncoveredCaveBorderSegments > 0)
                    {
                        if(caveGaps==0)GD.Print($"First unstitched entrance frame at {t:F2}s, {terrain.UncoveredCaveBorderSegments} missing of {terrain.CaveBorderSegments} segments, overlap={terrain.HasCavePreviewOverlap}, columns={stream._surface_columns}, {stream.surface_status}");
                        caveGaps++;
                    }
                }
            }
        }
        ticks++;
        if (terrain.HasVisibleNearDetail(cell))
        {
            near++;
            seen.Add(key);
            if (lastCell!=key) { lastCell=key; longest = Math.Max(longest,(now-last)/1000.0); last=now; }
        }
        if (ticks%60==0 && Array.IndexOf(OS.GetCmdlineUserArgs(),"trace")>=0)
        {
            var progress=terrain.get_ring_progress();
            GD.Print($"t={t:F1} cell={cell} target={terrain.get_target_chunk()} active={progress["active"]} gen={progress["generation"]} ready={progress["ready"]}/{progress["requested"]} staged={progress["staged"]} jobs={progress["job_stages"]} workers={progress["workers"]} near={near}");
        }
        foreach(var pair in terrain._active_chunks)
        {
            var tile=pair.Key.AsVector3I();
            if(tile.Z is <1 or >2 || initialRings.Contains(tile) || !pair.Value.As<MeshInstance3D>().IsVisibleInTree())continue;
            double span=terrain.chunk_size*Math.Pow(3,tile.Z);
            if(Math.Abs(tile.X-Math.Floor(camera.GlobalPosition.X/span))>1 || Math.Abs(tile.Y-Math.Floor(camera.GlobalPosition.Z/span))>1)continue;
            movingRings.Add(tile);
            if(tile.Z==1 && firstSecond<0)firstSecond=t;
            if(tile.Z==2 && firstThird<0)firstThird=t;
        }
        foreach(var tile in terrain.VisibleMiddle)
        {
            if(initialRings.Contains(tile))continue;
            movingRings.Add(tile);
            if(tile.Z==1 && firstSecond<0)firstSecond=t;
            if(tile.Z==2 && firstThird<0)firstThird=t;
        }
        if(t < 12) return;
        GD.Print($"Moving ring 2/3 newly visible tiles: {System.Linq.Enumerable.Count(movingRings,p=>p.Z==1)}/{System.Linq.Enumerable.Count(movingRings,p=>p.Z==2)}; first seen at {firstSecond:F2}/{firstThird:F2} seconds");
        longest=Math.Max(longest,(now-last)/1000.0);
        GD.Print($"FLIGHT speed={(sprint?105:35)} cells={seen.Count} near={near}/{ticks} longest={longest:F2}s active={terrain._active_chunks.Count} error={terrain.last_error}");
        if(auditGround)GD.Print($"Coverage audit: {groundChecks} terrain samples, {holes} uncovered, {caveChecks} entrance frames, {caveGaps} unstitched");
        if (cavePass) GD.Print($"Beach entrance disappeared in {beachEntranceDropouts} frames after first publication");
        SetProcess(false);
        GetTree().Quit((!auditGround || groundChecks>0 && holes==0 && (!cavePass || caveChecks>0 && caveGaps==0 && beachEntranceDropouts==0)) && firstSecond>=0 && firstThird>=0 && System.Linq.Enumerable.Count(movingRings,p=>p.Z==1)>=6 && System.Linq.Enumerable.Count(movingRings,p=>p.Z==2)>=3 && seen.Count>=Math.Ceiling(18*16/terrain.chunk_size) && longest<2 && near>=ticks*.8 && terrain.last_error.Length==0 && hudStep==3 && !speedReadout.Visible ? 0 : 1);
    }
}

