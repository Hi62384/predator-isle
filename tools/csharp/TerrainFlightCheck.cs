using Godot;
using PredatorIsle.Terrain;
using System;
using System.Collections.Generic;

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
    private bool sprint, warm, bend, capture;
    private Vector3I? lastCell;
    private double longest;
    private Label fps=null!,speedReadout=null!;
    private int hudStep;
    private readonly HashSet<Vector3I> seen = new();

    public override void _Ready()
    {
        sprint = Array.IndexOf(OS.GetCmdlineUserArgs(),"sprint")>=0;
        warm = Array.IndexOf(OS.GetCmdlineUserArgs(),"warm")>=0;
        bend=Array.IndexOf(OS.GetCmdlineUserArgs(),"turn")>=0;
        capture=Array.IndexOf(OS.GetCmdlineUserArgs(),"capture")>=0;
        var world = GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
        AddChild(world);
        terrain = world.GetNode<ChunkTerrain>("Terrain");
        camera = world.GetNode<Node3D>("FreeCamera");
        fps=world.GetNode<Label>("Interface/FrameRate");
        speedReadout=world.GetNode<Label>("Interface/FlightSpeed");
        origin = camera.GlobalPosition;
        start = Time.GetTicksMsec();
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
        if (flight == 0)
        {
            if (terrain._active_chunks.Count == 0 || warm && terrain.committed_revision!=terrain.partition_revision)
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
        var direction=bend?new Vector3(-1,0,-1).Normalized():Vector3.Right;
        camera.GlobalPosition=origin+direction*speed*(float)Math.Min(t,6)+
            (bend?Vector3.Back:direction)*speed*(float)Math.Max(0,t-6);
        if(capture && t>5 && DisplayServer.GetName()!="headless")
        {
            capture=false;
            using var frame=GetViewport().GetTexture().GetImage();
            frame.SavePng(System.IO.Path.Combine(System.IO.Path.GetTempPath(),"predator-flight-check.png"));
        }
        var cell = terrain.world_to_chunk(camera.GlobalPosition);
        var key = new Vector3I(cell.X,cell.Y,0);
        ticks++;
        if (terrain.HasVisibleFineCell(cell))
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
        SetProcess(false);
        GetTree().Quit(firstSecond>=0 && firstThird>=0 && System.Linq.Enumerable.Count(movingRings,p=>p.Z==1)>=6 && System.Linq.Enumerable.Count(movingRings,p=>p.Z==2)>=3 && seen.Count>=Math.Ceiling(18*16/terrain.chunk_size) && longest<2 && near>=ticks*.8 && terrain.last_error.Length==0 && hudStep==3 && !speedReadout.Visible ? 0 : 1);
    }
}

