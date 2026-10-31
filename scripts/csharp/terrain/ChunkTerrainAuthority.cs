using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using PredatorIsle.Caves;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    [ExportGroup("Authoritative terrain")]
    [Export] public bool authority_only{get;set;}
    [Export(PropertyHint.Range,"32,128,16")] public int authority_radius_metres{get;set;}=64;
    private readonly SortedDictionary<long,Node3D> authorityActors=new();
    private readonly Dictionary<long,CaveStreamer> authorityCaves=new();
    private long? primaryAuthorityActor;
    private long authorityPlanSignature=long.MinValue;
    private double authorityCollisionRefresh;
    private readonly CaveSurfaceCut authoritySurfaceCut=new();
    private long authorityCutSignature=long.MinValue;
    public D get_world_identity()=>TerrainWorldIdentity.Create(world_seed,water_level,_settings_snapshot??settings,cave_settings);
    private IEnumerable<CaveStreamer> CaveStreams()
    {
        if(_cave_streamer is not null)yield return _cave_streamer;
        foreach(var stream in authorityCaves.Values)yield return stream;
    }
    // Network code supplies server-approved actors. This does not trust client coordinates or add RPCs.
    public bool register_collision_actor(long player_id,Node3D actor)
    {
        if(!authority_only||!Valid(actor)||!actor.IsInsideTree()||!actor.GlobalPosition.IsFinite()||(!authorityActors.ContainsKey(player_id)&&authorityActors.Count>=16))return false;
        authorityActors[player_id]=actor;SynchronizeAuthorityCaves();RefreshAuthorityGroundCuts();authorityPlanSignature=long.MinValue;RefreshRings(Vector3.Inf);return true;
    }
    public void unregister_collision_actor(long player_id)
    {
        if(!authorityActors.Remove(player_id))return;SynchronizeAuthorityCaves();RefreshAuthorityGroundCuts();authorityPlanSignature=long.MinValue;
        if(authorityActors.Count>0){RefreshRings(Vector3.Inf);return;}
        DiscardRingStaging();foreach(var value in _active_chunks.Values)_release_node(Obj<MeshInstance3D>(value));_active_chunks.Clear();ringStream?.Dispose();ringStream=null;target=null;_startup_coverage_complete=false;
    }
    private void SynchronizeAuthorityCaves()
    {
        // Joining another player must not close an existing player's cave or remove its collision.
        foreach(long id in authorityCaves.Keys.Where(id=>!authorityActors.ContainsKey(id)).ToArray()){var retired=authorityCaves[id];retired.shutdown();retired.QueueFree();authorityCaves.Remove(id);}
        if(primaryAuthorityActor is null||!authorityActors.ContainsKey(primaryAuthorityActor.Value))
        {
            if(_cave_streamer is not null){_cave_streamer.shutdown();_cave_streamer.QueueFree();_cave_streamer=null;}
            primaryAuthorityActor=authorityActors.Count>0?authorityActors.Keys.First():null;
            if(primaryAuthorityActor is long promoted&&authorityCaves.Remove(promoted,out var existing))_cave_streamer=existing;
        }
        target=primaryAuthorityActor is long primary?authorityActors[primary]:null;if(target is null)return;
        if(ringStream is null)InitializeRings();
        if(cave_settings is null||!cave_settings.Get("enabled").AsBool()||cave_settings.Call("validation_errors").AsGodotArray().Count>0)return;
        foreach(var actor in authorityActors){if(actor.Key==primaryAuthorityActor?_cave_streamer is not null:authorityCaves.ContainsKey(actor.Key))continue;var stream=new CaveStreamer{Name="AuthorityCaves_"+actor.Key};AddChild(stream);stream.initialize(this);if(actor.Key==primaryAuthorityActor)_cave_streamer=stream;else authorityCaves[actor.Key]=stream;}
    }
    private long AuthorityInterestSignature()
    {
        long hash=17;unchecked{foreach(var actor in authorityActors){var cell=world_to_chunk(actor.Value.GlobalPosition);hash=hash*31+actor.Key;hash=hash*31+cell.X;hash=hash*31+cell.Y;}}return hash;
    }
    private D AuthorityColumns()
    {
        var columns=new D();foreach(var stream in CaveStreams())if(stream._surface_transaction is not null&&stream._surface_transaction.committed)foreach(var column in stream._surface_columns.Keys)columns[column]=true;return columns;
    }
    private void ApplyAuthorityGroundCuts(MeshInstance3D node)
    {
        if(!authority_only||node.Mesh is null)return;var shape=node.GetNodeOrNull<CollisionShape3D>("NearTerrainCollision/Heightfield");if(shape is null)return;
        var data=node.Mesh.GetMeta("collision_data",new D()).AsGodotDictionary();if(!data.TryGetValue("ground_faces",out var raw))return;var faces=raw.AsVector3Array();if(faces.Length==0)return;
        var columns=AuthorityColumns();if(columns.Count>0){var clipped=authoritySurfaceCut.ground(faces,node.GlobalPosition,columns);if(!clipped["valid"].AsBool())throw new InvalidOperationException("Authoritative cave ground subtraction rejected.");faces=clipped["faces"].AsVector3Array();}
        shape.Shape=faces.Length==0?null:new ConcavePolygonShape3D{Data=faces};shape.Transform=Transform3D.Identity;
    }
    private void RefreshAuthorityGroundCuts()
    {
        if(!authority_only)return;long signature=17;unchecked{foreach(var stream in CaveStreams())signature=signature*31+(long)(stream._surface_transaction?.GetInstanceId()??0);}
        if(signature==authorityCutSignature)return;authorityCutSignature=signature;foreach(var value in _active_chunks.Values)ApplyAuthorityGroundCuts(Obj<MeshInstance3D>(value));
    }
    private TerrainRingLayout.Plan AuthorityPlan(Vector2 focus,IEnumerable<Rect2> detail)
    {
        // Fixed gameplay residency around all actors: no render distance, shader quality or visual rings.
        var keys=new HashSet<Vector2I>();int radius=Math.Clamp(authority_radius_metres,32,128);
        foreach(var actor in authorityActors.Values)Add(new Rect2(new Vector2(actor.GlobalPosition.X,actor.GlobalPosition.Z)-Vector2.One*radius,Vector2.One*radius*2));
        foreach(var region in detail)Add(region);
        var patches=keys.OrderBy(k=>k.Y).ThenBy(k=>k.X).Select(k=>new TerrainRingLayout.Patch(new Vector3I(k.X,k.Y,0),16,TerrainRingLayout.Mask.None)).ToArray();var bounds=patches.Length>0?patches[0].Bounds:new Rect2(focus,Vector2.Zero);foreach(var patch in patches.Skip(1))bounds=bounds.Merge(patch.Bounds);
        return new TerrainRingLayout.Plan(patches,bounds,focus,16,0){CollisionInterests=authorityActors.Values.Select(actor=>new Vector2(actor.GlobalPosition.X,actor.GlobalPosition.Z)).ToArray()};
        void Add(Rect2 bounds)
        {
            if(!bounds.Position.IsFinite()||!bounds.End.IsFinite())throw new ArgumentException("Nonfinite authoritative terrain interest.");
            int x0=checked((int)Math.Floor(bounds.Position.X/16)),z0=checked((int)Math.Floor(bounds.Position.Y/16)),x1=checked((int)Math.Ceiling(bounds.End.X/16)),z1=checked((int)Math.Ceiling(bounds.End.Y/16));
            for(int z=z0;z<z1;z++)for(int x=x0;x<x1;x++){keys.Add(new Vector2I(x,z));if(keys.Count>4096)throw new InvalidOperationException("Authoritative terrain interest exceeds the 4096-patch limit; existing collision retained.");}
        }
    }
    private Vector3 NearestCollisionActor(Vector3 world)
    {
        Vector3 point=target?.GlobalPosition??Vector3.Inf;double distance=point.DistanceSquaredTo(world);
        foreach(var actor in authorityActors.Values){double next=actor.GlobalPosition.DistanceSquaredTo(world);if(next<distance){distance=next;point=actor.GlobalPosition;}}return point;
    }
    public bool collision_actor_ready(long player_id)
    {
        if(!authorityActors.TryGetValue(player_id,out var actor)||ringStream?.IsCoverageComplete!=true)return false;var cell=world_to_chunk(actor.GlobalPosition);if(!_active_chunks.ContainsKey(new Vector3I(cell.X,cell.Y,0)))return false;
        var stream=primaryAuthorityActor==player_id?_cave_streamer:authorityCaves.GetValueOrDefault(player_id);return stream is null||stream.position_ready(actor.GlobalPosition);
    }
}
