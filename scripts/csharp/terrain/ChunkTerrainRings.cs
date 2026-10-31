using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    [ExportCategory("Terrain streaming")]
    [Export] public bool nested_rings{get;set;}
    [Export] public TerrainRingSettings ring_settings{get;set;}=GD.Load<TerrainRingSettings>("res://config/world/terrain_rings.tres");
    private TerrainRingLayout? ringLayout;
    private TerrainRingStream? ringStream;
    private TerrainRingBudget? ringBudget;
    private TerrainRingTransitions.Result? ringUploading;
    private D ringNext=new();
    private long ringUploadGeneration=-1,ringSourceRevision;
    private int ringUploadIndex;
    private double ringLastUploadMilliseconds;
    private ulong ringLastPlanTime;
    private readonly List<Rect2> ringFeatureRegions=new();
    private bool ringFeatureRefresh;
    private int ringCaveCursor;
    public D get_ring_progress()=>ringStream is null?new D():new D{["requested"]=ringStream.Requested?.Patches.Length??0,["ready"]=ringStream.ReadyPatches,["pending"]=ringStream.PendingPatches,["jobs"]=ringStream.RunningJobs,["job_stages"]=ringStream.JobStages,["active"]=_active_chunks.Count,["staged"]=_staged.Count,["complete"]=ringStream.IsCoverageComplete,["generation"]=ringStream.Generation,["error"]=ringStream.LastError,["workers"]=ringBudget?.WorkerAllowance??0,["cache_bytes"]=ringStream.ResidentCacheBytes};
    private void InitializeRings()
    {
        authority_only|=OS.HasFeature("dedicated_server")||OS.GetCmdlineUserArgs().Contains("terrain-server");if(authority_only)nested_rings=true;
        if(!nested_rings)return;
        ring_settings=(TerrainRingSettings)ring_settings.Duplicate();
        foreach(string argument in OS.GetCmdlineUserArgs())if(argument.StartsWith("terrain-profile=",StringComparison.OrdinalIgnoreCase)){string name=argument["terrain-profile=".Length..];int selected=Array.FindIndex(new[]{"low","medium","high","ultra"},p=>p.Equals(name,StringComparison.OrdinalIgnoreCase));if(selected<0)throw new ArgumentException("Unknown terrain profile: "+name);ring_settings.apply_profile(selected);}
        if(authority_only){ring_settings.base_patch_metres=16;ring_settings.nearby_vertex_metres=1;ring_settings.outer_rings=0;ring_settings.filtered_distant_heights=false;ring_settings.selective_geometry_refinement=false;Visible=false;}
        var errors=ring_settings.validation_errors();if(errors.Count>0)throw new InvalidOperationException("Invalid ring configuration: "+string.Join(" ",errors));
        chunk_size=ring_settings.base_patch_metres;maximum_lod=ring_settings.outer_rings;chunk_resolution=close_resolution=middle_resolution=ring_settings.subdivisions();worker_count=Math.Max(1,Math.Min(worker_count,ring_settings.maximum_workers));upload_budget_ms=ring_settings.upload_budget_ms;ringLayout=new TerrainRingLayout(chunk_size,maximum_lod);ringStream=new TerrainRingStream(new TerrainRingTopology(),ring_settings.filtered_distant_heights){MaximumWorkers=worker_count,CacheBudgetBytes=(long)ring_settings.cache_mebibytes*1024*1024};ringBudget=new TerrainRingBudget(ring_settings);
    }
    private double TileSpan(int level)=>nested_rings?ring_settings.base_patch_metres*Math.Pow(3,level):chunk_size*(1L<<level);
    private void RefreshRings(Vector3 destination)
    {
        if(ringLayout is null||ringStream is null||!Valid(target))return;var focus=destination.IsFinite()?destination:_teleport_pending?_teleport_destination:target!.GlobalPosition;
        try
        {
            var detail=CaveStreams().SelectMany(stream=>stream.detail_rectangles()).ToList();var plan=authority_only?AuthorityPlan(new Vector2(focus.X,focus.Z),detail):ringLayout.Select(new Vector2(focus.X,focus.Z));if(!authority_only){if(ring_settings.selective_geometry_refinement){float radius=ring_settings.profile>=2?128:96;var interest=new Rect2(new Vector2(focus.X,focus.Z)-Vector2.One*radius,Vector2.One*radius*2);foreach(var region in ringFeatureRegions)if(region.Intersects(interest)){var clipped=region.Intersection(interest);if(clipped.HasArea())detail.Add(clipped);}}plan=TerrainRingRefinement.Apply(plan,detail);}
            if(!ringStream.Request(plan,ring_settings.subdivisions(),ringSourceRevision))return;last_error="";DiscardRingStaging();ringLastPlanTime=Time.GetTicksMsec();_last_plan_position=new Vector2(focus.X,focus.Z);_target_chunk=world_to_chunk(focus);_wanted=new D();foreach(var patch in plan.Patches)_wanted[patch.Key]=true;partition_revision++;_update_water_position();
        }
        catch(Exception error){last_error=error.ToString();GD.PushError("Terrain ring plan rejected; existing terrain retained: "+error.Message);}
    }
    private void TickRings(double delta,Vector3 point)
    {
        if(ringStream is null||ringBudget is null){last_error="Restart the scene after changing the terrain streaming mode.";return;}
        var collisionCell=(point/256f).Floor();if(collisionCell!=_last_structure_collision_cell){_last_structure_collision_cell=collisionCell;foreach(var value in _active_chunks.Values)_update_near_collision(Obj<MeshInstance3D>(value),false,true);}
        ringBudget.Observe(delta,ringLastUploadMilliseconds,ring_settings);if(authority_only){long signature=AuthorityInterestSignature();if(signature!=authorityPlanSignature&&(ringStream.IsCoverageComplete||Time.GetTicksMsec()-ringLastPlanTime>=500)){authorityPlanSignature=signature;RefreshRings(Vector3.Inf);}authorityCollisionRefresh+=delta;if(authorityCollisionRefresh>=1){authorityCollisionRefresh=0;foreach(var value in _active_chunks.Values)_update_near_collision(Obj<MeshInstance3D>(value),false,true);}}
        else if(ringFeatureRefresh&&ringStream.IsCoverageComplete){ringFeatureRefresh=false;RefreshRings(Vector3.Inf);}else if(!_teleport_pending&&world_to_chunk(point)!=_target_chunk&&(ringStream.IsCoverageComplete||Time.GetTicksMsec()-ringLastPlanTime>=500))RefreshRings(Vector3.Inf);
        var caves=CaveStreams().ToArray();int caveJobs=caves.Sum(stream=>stream.job_count()),terrainSlots=Math.Max(0,worker_count-Math.Max(caveJobs,caves.Length>0&&worker_count>1?1:0));ringStream.MaximumWorkers=ringStream.HasCompletedCoverage?Math.Min(worker_count,ringBudget.WorkerAllowance):worker_count;ringStream.CacheBudgetBytes=(long)ring_settings.cache_mebibytes*1024*1024;
        ringStream.Tick(terrainSlots,()=>{var builder=new TerrainMeshBuilder{settings=_settings_snapshot.DuplicateDeep(Resource.DeepDuplicateMode.All),world_seed=world_seed,water_level=water_level,chunk_size=chunk_size};builder._configure_noise();return builder;});
        if(ringStream.LastError.Length>0)last_error=ringStream.LastError;ulong begin=Time.GetTicksUsec();if(ringStream.LastError.Length==0)try{UploadRings();}catch(Exception error){ringStream.RejectPrepared(ringUploadGeneration,error);last_error=error.ToString();DiscardRingStaging();GD.PushError("Terrain publication failed; existing terrain retained: "+error.Message);}ringLastUploadMilliseconds=(Time.GetTicksUsec()-begin)/1000.0;
        double savedBudget=upload_budget_ms;try{upload_budget_ms=Math.Max(.25,ringBudget.UploadMilliseconds-ringLastUploadMilliseconds)/Math.Max(1,caves.Length);for(int index=0;index<caves.Length;index++){var stream=caves[(ringCaveCursor+index)%caves.Length];var actor=authorityCaves.FirstOrDefault(pair=>pair.Value==stream);var protectedPoint=actor.Value is not null&&authorityActors.TryGetValue(actor.Key,out var body)?body.GlobalPosition:point;int otherJobs=caves.Where(other=>other!=stream).Sum(other=>other.job_count());stream.tick(_teleport_pending?_teleport_destination:protectedPoint,protectedPoint,Math.Max(0,worker_count-ringStream.RunningJobs-otherJobs),ringStream.LastError.Length==0&&ringStream.PendingPatches>0);}ringCaveCursor=caves.Length>0?(ringCaveCursor+1)%caves.Length:0;}finally{upload_budget_ms=savedBudget;}
        CommitRings();RefreshAuthorityGroundCuts();
    }
    private void UploadRings()
    {
        if(ringStream is null||ringBudget is null)return;if(ringUploading is null){if(!ringStream.TryPrepare(out ringUploadGeneration,out ringUploading)||ringUploading is null)return;ringNext=new D();ringUploadIndex=0;}
        if(!ringStream.IsCurrent(ringUploadGeneration)){DiscardRingStaging();return;}ulong begin=Time.GetTicksUsec();int uploaded=0;
        while(ringUploadIndex<ringUploading.Meshes.Length)
        {
            var data=ringUploading.Meshes[ringUploadIndex++];var key=data.Patch.Key;
            if(_active_chunks.TryGetValue(key,out var value))
            {
                var prior=Obj<MeshInstance3D>(value);if(prior.GetMeta("ring_source_revision",-1L).AsInt64()==ringSourceRevision&&prior.GetMeta("ring_geometry_fingerprint","").AsString()==data.GeometryFingerprint){ringNext[key]=prior;continue;}
            }
            var result=new D{["arrays"]=data.Arrays,["collision_data"]=data.Collision,["edge_profiles"]=new D(),["extension_data"]=data.ExtensionData,["extension_rows"]=data.ExtensionRows,["extension_mask"]=data.ExtensionMask,["badlands_palette_slot"]=data.BadlandsSlot,["alien_flow"]=data.AlienFlow,["alien_flow_rows"]=data.AlienFlowRows,["features"]=data.Features,["structures"]=data.Structures,["structure_flow"]=data.StructureFlow,["swamp_water"]=data.LocalWater};
            var mesh=Upload(result,key,out _);mesh.SetMeta("terrain_canonical_surface",true);var owned=new A();foreach(var region in data.Patch.OwnedRegions())owned.Add(region);mesh.SetMeta("terrain_owned_regions",owned);_stage_chunk(key,data.Topology.Axis.Length-1,mesh);var node=Obj<MeshInstance3D>(_staged[key]);node.SetMeta("ring_source_revision",ringSourceRevision);node.SetMeta("ring_geometry_fingerprint",data.GeometryFingerprint);ringNext[key]=node;uploaded++;
            if(uploaded>=chunks_created_per_frame||(Time.GetTicksUsec()-begin)/1000.0>=ringBudget.UploadMilliseconds)break;
        }
    }
    private void CommitRings()
    {
        if(ringStream is null||ringStream.LastError.Length>0||ringUploading is null||ringUploadIndex<ringUploading.Meshes.Length)return;if(!ringStream.IsCurrent(ringUploadGeneration)){DiscardRingStaging();return;}
        if(_teleport_pending&&_cave_streamer is not null&&!_cave_streamer.position_ready(_teleport_destination))return;foreach(var stream in CaveStreams())if(!stream.partition_ready(Values(ringNext)))return;if(!ringStream.Acknowledge(ringUploadGeneration))return;
        ulong begin=Time.GetTicksUsec();var focus=_teleport_pending?_teleport_destination:target!.GlobalPosition;var interest=new Rect2(new Vector2(focus.X,focus.Z)-Vector2.One*192,Vector2.One*384);ringFeatureRegions.RemoveAll(region=>!region.Intersects(interest));if(!authority_only)foreach(var region in ringUploading.Meshes.SelectMany(data=>data.RefinementRegions))if(region.Intersects(interest)&&!ringFeatureRegions.Contains(region)){if(ringFeatureRegions.Count>=256)ringFeatureRegions.RemoveAt(0);ringFeatureRegions.Add(region);ringFeatureRefresh=true;}
        foreach(var key in _active_chunks.Keys)if(!ringNext.TryGetValue(key,out var next)||Obj<MeshInstance3D>(next)!=Obj<MeshInstance3D>(_active_chunks[key]))_release_node(Obj<MeshInstance3D>(_active_chunks[key]));_active_chunks=ringNext;_staged.Clear();
        foreach(var value in _active_chunks.Values){var node=Obj<MeshInstance3D>(value);if(!node.Visible)node.SetMeta("published_usec",(long)Time.GetTicksUsec());node.Visible=true;_update_near_collision(node);_collision.activate(node,terrain_collision_enabled);}if(ringStream.IsCoverageComplete)committed_revision=partition_revision;_startup_coverage_complete=ringStream.IsCoverageComplete;_ready_edge_certificates.Clear();foreach(var stream in CaveStreams())stream.partition_committed();ringNext=new D();ringUploading=null;
        if(_teleport_pending){target!.GlobalPosition=_teleport_destination;_teleport_pending=false;_update_water_position();}if(profile_streaming)max_partition_swap_ms=Math.Max(max_partition_swap_ms,(Time.GetTicksUsec()-begin)/1000.0);
    }
    private void DiscardRingStaging()
    {
        foreach(var value in _staged.Values)_release_node(Obj<MeshInstance3D>(value));_staged.Clear();ringNext=new D();ringUploading=null;ringUploadIndex=0;ringUploadGeneration=-1;
    }
    private string RingDebug()
    {
        string message=$"Nested 3×3 rings · {_active_chunks.Count} active · {_staged.Count} staged · {ringStream?.RunningJobs??0} jobs\nCut {committed_revision}/{partition_revision} · {ring_settings.nearby_vertex_metres:0.##} m nearby vertices · {(ringStream?.ResidentCacheBytes??0)/1048576.0:0.0} MiB numerical cache";if(_cave_streamer is not null)message+="\n"+_cave_streamer.debug_text();if(last_error.Length>0)message+="\nTerrain retained after failure: "+last_error;return message;
    }
}
