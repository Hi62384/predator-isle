using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    public void _commit_partition()
    {
        if(committed_revision==partition_revision)return;_publish_startup_chunks();
        foreach(var k in _wanted.Keys)
        {
            var key=k.AsVector3I();if(_staged.ContainsKey(key))continue;
            if(_active_chunks.TryGetValue(key,out var active)&&Obj<MeshInstance3D>(active).GetMeta("resolution").AsInt32()==_tile_resolution(key))continue;
            _commit_ready_region();return;
        }
        if(_teleport_pending&&_cave_streamer is not null&&!_cave_streamer.position_ready(_teleport_destination))return;
        if(_cave_streamer is not null){var candidates=new A();foreach(var key in _wanted.Keys)candidates.Add(_staged.TryGetValue(key,out var node)?node:_active_chunks[key]);if(!_cave_streamer.partition_ready(candidates))return;}
        ulong start=Time.GetTicksUsec();var next=new D();
        foreach(var key in _wanted.Keys){if(_staged.TryGetValue(key,out var node)){next[key]=node;_staged.Remove(key);}else next[key]=_active_chunks[key];}
        foreach(var key in _active_chunks.Keys)if(!next.TryGetValue(key,out var n)||Obj<MeshInstance3D>(n)!=Obj<MeshInstance3D>(_active_chunks[key]))_release_node(Obj<MeshInstance3D>(_active_chunks[key]));
        foreach(var n in next.Values){var node=Obj<MeshInstance3D>(n);if(!node.Visible)node.SetMeta("published_usec",(long)Time.GetTicksUsec());node.Visible=true;_update_near_collision(node);_collision.activate(node,terrain_collision_enabled);}
        _active_chunks=next;committed_revision=partition_revision;_ready_edge_certificates.Clear();_startup_coverage_complete=true;_cave_streamer?.partition_committed();
        if(_teleport_pending){target!.GlobalPosition=_teleport_destination;_teleport_pending=false;_update_water_position();}
        if(profile_streaming)max_partition_swap_ms=Math.Max(max_partition_swap_ms,(Time.GetTicksUsec()-start)/1000.0);
    }
    public void _commit_ready_region()
    {
        long frame=(long)Engine.GetProcessFrames();if(!_startup_coverage_complete||_teleport_pending||_staged.Count==0||_last_incremental_attempt_frame==frame)return;_last_incremental_attempt_frame=frame;
        var cacheKey=new Vector3I(partition_revision,_staging_revision,incremental_cut_swaps);
        if(cacheKey!=_ready_cut_cache_key)
        {
            var activeRes=new D();var readyRes=new D();var wantedRes=new D();var activeProfiles=new D();var readyProfiles=new D();
            foreach(var key in _active_chunks.Keys){var node=Obj<MeshInstance3D>(_active_chunks[key]);activeRes[key]=node.GetMeta("resolution");activeProfiles[key]=node.GetMeta("edge_profiles",new D());}
            foreach(var key in _staged.Keys){var node=Obj<MeshInstance3D>(_staged[key]);readyRes[key]=node.GetMeta("resolution");readyProfiles[key]=node.GetMeta("edge_profiles",new D());}
            foreach(var key in _wanted.Keys)wantedRes[key]=_tile_resolution(key.AsVector3I());
            _ready_cut_cache=_ready_cut.choose(_active_chunks,_wanted,_staged,_partition,_last_plan_position,activeRes,readyRes,wantedRes,activeProfiles,readyProfiles,_ready_cut_diagnostics);_ready_cut_cache_key=cacheKey;
        }
        var change=_ready_cut_cache;if(change.Count==0)return;var next=_active_chunks.Duplicate();
        var remove=change["remove"].AsGodotArray();var add=change["add"].AsGodotArray();foreach(var key in remove)next.Remove(key);foreach(var key in add)next[key]=_staged[key];
        if(_cave_streamer is not null&&!_cave_streamer.partition_ready(Values(next)))return;
        ulong began=Time.GetTicksUsec();foreach(var key in remove)_release_node(Obj<MeshInstance3D>(_active_chunks[key]));foreach(var key in add)_staged.Remove(key);_active_chunks=next;
        foreach(var id in Keys(_ready_edge_certificates))if(!CertificateCurrent(_ready_edge_certificates[id].AsGodotDictionary()))_ready_edge_certificates.Remove(id);
        foreach(var c in Get(change,"edge_certificates",new A()).AsGodotArray())
        {
            var certificate=c.AsGodotDictionary().Duplicate();certificate["a_instance"]=Obj<MeshInstance3D>(_active_chunks[certificate["a"]]).GetInstanceId();certificate["b_instance"]=Obj<MeshInstance3D>(_active_chunks[certificate["b"]]).GetInstanceId();
            _ready_edge_certificates[_ready_cut.edge_id(certificate["a"].AsVector3I(),certificate["b"].AsVector3I())]=certificate;
        }
        foreach(var key in add){var node=Obj<MeshInstance3D>(_active_chunks[key]);node.SetMeta("published_usec",(long)Time.GetTicksUsec());node.Visible=true;_update_near_collision(node);_collision.activate(node,terrain_collision_enabled);}
        _cave_streamer?.partition_committed();_last_incremental_frame=(long)Engine.GetProcessFrames();incremental_cut_swaps++;if(profile_streaming)max_partition_swap_ms=Math.Max(max_partition_swap_ms,(Time.GetTicksUsec()-began)/1000.0);
    }
    private bool CertificateCurrent(D c)=>c.Count>0&&_active_chunks.TryGetValue(c["a"],out var a)&&_active_chunks.TryGetValue(c["b"],out var b)&&Obj<MeshInstance3D>(a).GetInstanceId()==c["a_instance"].AsUInt64()&&Obj<MeshInstance3D>(b).GetInstanceId()==c["b_instance"].AsUInt64();
    public bool is_active_edge_certified(Vector3I a,Vector3I b)=>Math.Abs(a.Z-b.Z)<=1||CertificateCurrent(Get(_ready_edge_certificates,_ready_cut.edge_id(a,b),new D()).AsGodotDictionary());
    public void _publish_startup_chunks()
    {
        if(_startup_coverage_complete||_teleport_pending||_staged.Count==0)return;
        var candidates=Values(_active_chunks);var publish=new Godot.Collections.Array<Vector3I>();
        foreach(var k in _staged.Keys)
        {
            var key=k.AsVector3I();if(!_wanted.ContainsKey(key)||_active_chunks.ContainsKey(key))continue;bool overlaps=false;
            foreach(var a in _active_chunks.Keys){var active=a.AsVector3I();if(_partition.bounds(key).Intersects(_partition.bounds(active))||(_partition.adjacent(key,active)&&Math.Abs(key.Z-active.Z)>1)){overlaps=true;break;}}
            if(overlaps)continue;publish.Add(key);candidates.Add(_staged[key]);
        }
        if(publish.Count==0||(_cave_streamer is not null&&!_cave_streamer.partition_ready(candidates)))return;
        foreach(var key in publish){var node=Obj<MeshInstance3D>(_staged[key]);_staged.Remove(key);node.SetMeta("published_usec",(long)Time.GetTicksUsec());_active_chunks[key]=node;node.Visible=true;_update_near_collision(node);_collision.activate(node,terrain_collision_enabled);}
        _cave_streamer?.partition_committed();
    }
}
