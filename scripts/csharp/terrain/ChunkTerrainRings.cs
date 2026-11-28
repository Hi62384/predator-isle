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
    internal TerrainRingLayout.Plan? RequestedRingPlan => ringStream?.Requested;
    private TerrainRingBudget? ringBudget;
    private readonly TerrainGpuGrids ringGpuGrids=new();
    private TerrainGpuSampler? ringGpuSampler;
    private TerrainRingTransitions.Result? ringUploading;
    private D ringNext=new();
    private long ringUploadGeneration=-1,ringSourceRevision;
    private int ringUploadIndex;
    private double ringLastUploadMilliseconds;
    private ulong ringLastPlanTime;
    private ulong ringPublicationStarted;
    private int ringCaveCursor;
    private Vector2 ringPreviousFocus;
    private bool ringHasPreviousFocus;
    private double ringPrefetchClock;
    public D get_ring_progress()
    {
        if(ringStream is null)return new D();
        return new D
        {
            ["requested"]=ringStream.Requested?.Patches.Length??0,
            ["ready"]=ringStream.ReadyPatches,
            ["pending"]=ringStream.PendingPatches,
            ["jobs"]=ringStream.RunningJobs,
            ["job_stages"]=ringStream.JobStages,
            ["active"]=_active_chunks.Count,
            ["staged"]=_staged.Count,
            ["complete"]=ringStream.IsCoverageComplete,
            ["generation"]=ringStream.Generation,
            ["error"]=ringStream.LastError,
            ["workers"]=ringBudget?.WorkerAllowance??0,
            ["nearby_published"]=ringStream.IsNearbyPublished,
            ["local_publications"]=ringStream.LocalPublications,
            ["shared_samples"]=ringStream.ShareSamples,
            ["gpu_render_grids"]=ringStream.GpuGrids,
            ["generation_backend"]=ring_settings.generation_backend,
            ["gpu_generation_available"]=ringGpuSampler?.Available??false,
            ["gpu_completed_requests"]=ringGpuSampler?.CompletedRequests??0,
            ["gpu_completed_samples"]=ringGpuSampler?.CompletedSamples??0,
            ["gpu_failed_requests"]=ringGpuSampler?.FailedRequests??0,
            ["gpu_readback_bytes"]=ringGpuSampler?.ReadbackBytes??0,
            ["gpu_readbacks"]=ringGpuSampler?.Readbacks??0,
            ["gpu_raw_samples"]=ringGpuSampler?.GeneratedRawSamples??0,
            ["gpu_raw_cache_hits"]=ringGpuSampler?.RawCacheHits??0,
            ["gpu_raw_cache_entries"]=ringGpuSampler?.RawCacheEntries??0,
            ["gpu_render_targets_created"]=ringGpuSampler?.CreatedRenderTargets??0,
            ["gpu_render_targets_reused"]=ringGpuSampler?.ReusedRenderTargets??0,
            ["gpu_plan_textures_reused"]=ringGpuSampler?.ReusedPlanTextures??0,
            ["gpu_vertex_bake_flights"]=ringGpuSampler?.VertexBakeFlights??0,
            ["gpu_biome_noise_scalars"]=ringGpuSampler?.BiomeNoise?.CompletedScalars??0,
            ["gpu_biome_noise_hits"]=ringGpuSampler?.BiomeNoise?.CacheHits??0,
            ["gpu_biome_noise_rejected"]=ringGpuSampler?.BiomeNoise?.Rejected??0,
            ["gpu_biome_shape_scalars"]=ringGpuSampler?.BiomeShape?.CompletedScalars??0,
            ["gpu_biome_shape_hits"]=ringGpuSampler?.BiomeShape?.CacheHits??0,
            ["gpu_biome_shape_rejected"]=ringGpuSampler?.BiomeShape?.Rejected??0,
            ["gpu_parity_rejections"]=ringGpuSampler?.RejectedNumericalBatches??0,
            ["gpu_readback_ms"]=ringGpuSampler?.ReadbackMilliseconds??0,
            ["gpu_last_failure"]=ringGpuSampler?.LastFailure??"",
            ["grid_templates_created"]=ringGpuGrids.TemplatesCreated,
            ["grid_page_uploads"]=ringGpuGrids.PageUploads,
            ["grid_page_bytes_uploaded"]=ringGpuGrids.PageBytesUploaded,
            ["grid_page_cache_hits"]=ringGpuGrids.PageReuseHits,
            ["grid_page_cache_entries"]=ringGpuGrids.CachedPages,
            ["grid_page_cached_bytes"]=ringGpuGrids.CachedPageBytes,
            ["profile"]=ringStream.Profile,
            ["shared_sample_hits"]=ringStream.SharedSampleHits,
            ["shared_sample_misses"]=ringStream.SharedSampleMisses,
            ["canonical_evaluations"]=ringStream.CanonicalEvaluations,
            ["cave_discovery_cache_hits"]=CaveStreams().Sum(stream=>stream.discovery_cache_hits),
            ["cave_discovery_cache_bytes"]=CaveStreams().Sum(stream=>stream.discovery_cache_bytes),
            ["prefetch_patches"]=ringStream.PrefetchPatches,
            ["prefetch_completions"]=ringStream.PrefetchCompletions,
            ["prefetch_hits"]=ringStream.PrefetchHits,
            ["cache_hits"]=ringStream.CacheHits,
            ["cache_misses"]=ringStream.CacheMisses,
            ["cache_bytes"]=ringStream.ResidentCacheBytes,
        };
    }
    private void InitializeRings()
    {
        authority_only|=OS.HasFeature("dedicated_server")||OS.GetCmdlineUserArgs().Contains("terrain-server");if(authority_only)nested_rings=true;
        if(!nested_rings)return;
        ring_settings=(TerrainRingSettings)ring_settings.Duplicate();
        foreach(string argument in OS.GetCmdlineUserArgs())if(argument.StartsWith("terrain-profile=",StringComparison.OrdinalIgnoreCase)){string name=argument["terrain-profile=".Length..];int selected=Array.FindIndex(new[]{"low","medium","high","ultra"},p=>p.Equals(name,StringComparison.OrdinalIgnoreCase));if(selected<0)throw new ArgumentException("Unknown terrain profile: "+name);ring_settings.apply_profile(selected);}
        foreach(string argument in OS.GetCmdlineUserArgs())if(argument.StartsWith("terrain-generation=",StringComparison.OrdinalIgnoreCase))
        {
            string name=argument["terrain-generation=".Length..];int backend=Array.FindIndex(new[]{"cpu","gpu","auto"},value=>value.Equals(name,StringComparison.OrdinalIgnoreCase));
            if(backend<0)throw new ArgumentException("Unknown terrain generation backend: "+name);ring_settings.generation_backend=backend;
        }
        if(authority_only){ring_settings.nearby_vertex_metres=1;ring_settings.outer_rings=0;ring_settings.filtered_distant_heights=false;ring_settings.selective_geometry_refinement=false;ring_settings.generation_backend=0;Visible=false;}
        var errors=ring_settings.validation_errors();if(errors.Count>0)throw new InvalidOperationException("Invalid ring configuration: "+string.Join(" ",errors));
        chunk_size=ring_settings.base_patch_metres;maximum_lod=ring_settings.outer_rings;chunk_resolution=close_resolution=middle_resolution=ring_settings.subdivisions();worker_count=Math.Max(1,Math.Min(worker_count,ring_settings.maximum_workers));upload_budget_ms=ring_settings.upload_budget_ms;ringLayout=new TerrainRingLayout(chunk_size,maximum_lod);
        var topology=new TerrainRingTopology();
        ringStream=new TerrainRingStream(topology,ring_settings.filtered_distant_heights){GenerateShapeRefinement=false,ShareSamples=(ring_settings.shared_samples||OS.GetCmdlineUserArgs().Contains("terrain-shared-samples=on"))&&!OS.GetCmdlineUserArgs().Contains("terrain-shared-samples=off"),GpuGrids=!authority_only&&(ring_settings.gpu_render_grids||OS.GetCmdlineUserArgs().Contains("terrain-render=grid"))&&!OS.GetCmdlineUserArgs().Contains("terrain-render=cpu"),MaximumWorkers=worker_count,CacheBudgetBytes=(long)ring_settings.cache_mebibytes*1024*1024};ringBudget=new TerrainRingBudget(ring_settings);
        if(UseGpuGeneration(ring_settings.generation_backend,authority_only,DisplayServer.GetName(),RenderingServer.GetVideoAdapterName()))
        {
            ringGpuSampler=new TerrainGpuSampler
            {
                Name="TerrainGpuGeneration",ProcessMode=ProcessModeEnum.Always,
                PreferVertexBake=ring_settings.gpu_vertex_bake||OS.GetCmdlineUserArgs().Contains("terrain-gpu-bake=vertex"),
                // Automatic mode measures complete CPU and GPU worker latencies.
                EnableBiomeNoise=(ring_settings.generation_backend!=0||OS.GetCmdlineUserArgs().Contains("terrain-biome-noise=on"))&&
                    !OS.GetCmdlineUserArgs().Contains("terrain-biome-noise=off")
            };AddChild(ringGpuSampler);
            ringStream.GpuPreparation=new TerrainGpuPreparation(ringGpuSampler,topology,ring_settings.filtered_distant_heights,
                ring_settings.generation_backend==2,ring_settings.selective_geometry_refinement);
        }
    }
    internal static bool UseGpuGeneration(int backend,bool authority,string displayServer,string adapter)
    {
        if(backend==0||authority||displayServer.Equals("headless",StringComparison.OrdinalIgnoreCase))return false;
        if(backend==1)return true;
        return !new[]{"llvmpipe","lavapipe","softpipe","swiftshader","software","microsoft basic render"}.Any(name=>adapter.Contains(name,StringComparison.OrdinalIgnoreCase));
    }
    private double TileSpan(int level)=>nested_rings?ring_settings.base_patch_metres*Math.Pow(3,level):chunk_size*(1L<<level);
    private void RefreshRings(Vector3 destination)
    {
        if(ringLayout is null||ringStream is null||!Valid(target))return;var focus=destination.IsFinite()?destination:_teleport_pending?_teleport_destination:target!.GlobalPosition;
        try
        {
            var focusXZ = new Vector2(focus.X,focus.Z);
            var plan = authority_only
                ? AuthorityPlan(focusXZ, CaveStreams().SelectMany(stream=>stream.detail_rectangles()).ToList())
                : TerrainRingRefinement.Apply(ringLayout.Select(focusXZ),CaveStreams().SelectMany(stream=>stream.detail_rectangles()).ToArray());
            if(!ringStream.Request(plan,ring_settings.subdivisions(),ringSourceRevision))return;last_error="";DiscardRingStaging();ringLastPlanTime=Time.GetTicksMsec();_last_plan_position=new Vector2(focus.X,focus.Z);_target_chunk=world_to_chunk(focus);_wanted=new D();foreach(var patch in plan.Patches)_wanted[patch.Key]=true;partition_revision++;_update_water_position();
        }
        catch(Exception error){last_error=error.ToString();GD.PushError("Terrain ring plan rejected; existing terrain retained: "+error.Message);}
    }
    private void TickRings(double delta,Vector3 point)
    {
        if(ringStream is null||ringBudget is null){last_error="Restart the scene after changing the terrain streaming mode.";return;}
        bool trace=OS.GetCmdlineUserArgs().Contains("trace");
        ulong began=Time.GetTicksMsec();
        ulong queued=began;
        void Mark(string phase)
        {
            if(!trace)return;
            ulong now=Time.GetTicksMsec();
            if(now-queued>150)GD.Print($"Terrain flight frame {phase} took {now-queued} ms");
            queued=now;
        }
        var planar=new Vector2(point.X,point.Z);var velocity=ringHasPreviousFocus&&delta>0?(planar-ringPreviousFocus)/(float)delta:Vector2.Zero;ringPreviousFocus=planar;ringHasPreviousFocus=true;ringPrefetchClock+=delta;
        if(!authority_only&&!_teleport_pending&&ringPrefetchClock>=.2){ringPrefetchClock=0;ringStream.Prefetch(planar,velocity);}
        var collisionCell=(point/256f).Floor();if(collisionCell!=_last_structure_collision_cell){_last_structure_collision_cell=collisionCell;foreach(var value in _active_chunks.Values)_update_near_collision(Obj<MeshInstance3D>(value),false,true);}
        ringBudget.Observe(delta,ringLastUploadMilliseconds,ring_settings);if(authority_only){long signature=AuthorityInterestSignature();if(signature!=authorityPlanSignature&&(ringStream.IsCoverageComplete||Time.GetTicksMsec()-ringLastPlanTime>=500)){authorityPlanSignature=signature;RefreshRings(Vector3.Inf);}authorityCollisionRefresh+=delta;if(authorityCollisionRefresh>=1){authorityCollisionRefresh=0;foreach(var value in _active_chunks.Values)_update_near_collision(Obj<MeshInstance3D>(value),false,true);}}
        else if(!_teleport_pending&&(planar / (float)ring_settings.base_patch_metres).Floor()!=(_last_plan_position / (float)ring_settings.base_patch_metres).Floor())
        {
            ulong now=Time.GetTicksMsec();
            // Keep an in-progress upload long enough to go visible. Replacing it
            // every time the camera crosses a cell can starve publication.
            bool publishing=ringUploading is not null&&now-ringPublicationStarted<1250;
            if(!publishing&&(ringStream.IsCoverageComplete||(!ringStream.PublicationInProgress&&now-ringLastPlanTime>=100)))
                RefreshRings(Vector3.Inf);
        }
        var caves=CaveStreams().ToArray();bool underground=caves.Length==1&&caves[0].underground_interest(point);
        int reserve=underground||caves.Any(stream=>stream.PreparingEntrance)?Math.Max(1,worker_count/2):caves.Length>0&&worker_count>1?1:0;
        if(worker_count==1&&Engine.GetProcessFrames()%2==0)reserve=0;
        int caveJobs=caves.Sum(stream=>stream.job_count()),terrainSlots=Math.Max(0,worker_count-Math.Max(caveJobs,reserve));ringStream.MaximumWorkers=ringStream.HasCompletedCoverage?Math.Min(worker_count,ringBudget.WorkerAllowance):worker_count;ringStream.CacheBudgetBytes=(long)ring_settings.cache_mebibytes*1024*1024;
        ringStream.FollowCamera(planar,!authority_only&&!_teleport_pending,velocity);
        ringStream.EntranceSupport = caves.Length==0 ? null : patch => patch.Key.Z==0 && caves.Any(stream=>stream.needs_fine_surface(patch.Key));
        ringStream.AllowLocalPublication=!_teleport_pending;ringStream.Tick(terrainSlots,()=>{var builder=new TerrainMeshBuilder{settings=_settings_snapshot.DuplicateDeep(Resource.DeepDuplicateMode.All),world_seed=world_seed,water_level=water_level,chunk_size=chunk_size};builder._configure_noise();return builder;});
        Mark("jobs");
        if(ringStream.LastError.Length>0)last_error=ringStream.LastError;ulong begin=Time.GetTicksUsec();if(ringStream.LastError.Length==0)try{UploadRings();}catch(Exception error){ringStream.RejectPrepared(ringUploadGeneration,error);last_error=error.ToString();DiscardRingStaging();GD.PushError("Terrain publication failed; existing terrain retained: "+error.Message);}ringLastUploadMilliseconds=(Time.GetTicksUsec()-begin)/1000.0;
        Mark("upload");
        double savedBudget=upload_budget_ms;try{upload_budget_ms=Math.Max(.25,ringBudget.UploadMilliseconds-ringLastUploadMilliseconds)/Math.Max(1,caves.Length);for(int index=0;index<caves.Length;index++){var stream=caves[(ringCaveCursor+index)%caves.Length];var actor=authorityCaves.FirstOrDefault(pair=>pair.Value==stream);var protectedPoint=actor.Value is not null&&authorityActors.TryGetValue(actor.Key,out var body)?body.GlobalPosition:point;int otherJobs=caves.Where(other=>other!=stream).Sum(other=>other.job_count());stream.tick(_teleport_pending?_teleport_destination:protectedPoint,protectedPoint,Math.Max(0,worker_count-ringStream.RunningJobs-otherJobs),ringStream.LastError.Length==0&&ringStream.PendingPatches>0);}ringCaveCursor=caves.Length>0?(ringCaveCursor+1)%caves.Length:0;}finally{upload_budget_ms=savedBudget;}
        Mark("cave");CommitRings();Mark("commit");UpdateFlightSurface(point);Mark("edges");RefreshAuthorityGroundCuts();
    }
    private static D RingUploadPayload(TerrainRingMeshGeometry.Data data,A arrays,bool groundOnly=false)
    {
        return new D{["arrays"]=arrays,["collision_data"]=data.Collision,["edge_profiles"]=new D(),["extension_data"]=data.ExtensionData,["extension_rows"]=data.ExtensionRows,["extension_mask"]=data.ExtensionMask,["badlands_palette_slot"]=data.BadlandsSlot,["alien_flow"]=data.AlienFlow,["alien_flow_rows"]=data.AlienFlowRows,["features"]=data.Features,["structures"]=groundOnly?new A():data.Structures,["structure_flow"]=data.StructureFlow,["swamp_water"]=groundOnly?new A():data.LocalWater};
    }
    private void UploadRings()
    {
        if(ringStream is null||ringBudget is null)return;if(ringUploading is null){if(!ringStream.TryPrepare(out ringUploadGeneration,out ringUploading)||ringUploading is null)return;ringNext=new D();ringUploadIndex=0;ringPublicationStarted=Time.GetTicksMsec();}
        if(!ringStream.IsCurrent(ringUploadGeneration)){DiscardRingStaging();return;}ulong begin=Time.GetTicksUsec();int uploaded=0;
        while(ringUploadIndex<ringUploading.Meshes.Length)
        {
            var data=ringUploading.Meshes[ringUploadIndex++];var key=data.Patch.Key;
            if(_active_chunks.TryGetValue(key,out var value))
            {
                var prior=Obj<MeshInstance3D>(value);if(prior.GetMeta("ring_source_revision",-1L).AsInt64()==ringSourceRevision&&prior.GetMeta("ring_geometry_fingerprint","").AsString()==data.GeometryFingerprint){ringNext[key]=prior;continue;}
            }
            var result=RingUploadPayload(data,data.GpuPage is null?data.Arrays:new A());
            var mesh=Upload(result,key,out _,data);if(data.GpuPage is not null)ringGpuGrids.AttachPayload(mesh,data);mesh.SetMeta("terrain_canonical_surface",true);var owned=new A();foreach(var region in data.Patch.OwnedRegions())owned.Add(region);mesh.SetMeta("terrain_owned_regions",owned);_stage_chunk(key,data.Topology.Axis.Length-1,mesh);var node=Obj<MeshInstance3D>(_staged[key]);node.SetMeta("ring_source_revision",ringSourceRevision);node.SetMeta("ring_geometry_fingerprint",data.GeometryFingerprint);ringNext[key]=node;uploaded++;
            if(uploaded>=chunks_created_per_frame||(Time.GetTicksUsec()-begin)/1000.0>=ringBudget.UploadMilliseconds)break;
        }
    }
    private void CommitRings()
    {
        if(ringStream is null||ringStream.LastError.Length>0||ringUploading is null||ringUploadIndex<ringUploading.Meshes.Length)return;if(!ringStream.IsCurrent(ringUploadGeneration)){DiscardRingStaging();return;}
        if(!authority_only && _cave_streamer?.AwaitingLocalMap==true && _active_chunks.Count==0)return;
        if(_teleport_pending&&_cave_streamer is not null&&!_cave_streamer.position_ready(_teleport_destination))return;foreach(var stream in CaveStreams())if(!stream.partition_ready(Values(ringNext)))return;if(!ringStream.Acknowledge(ringUploadGeneration))return;
        committedRender=ringUploading.Meshes.ToDictionary(data=>data.Patch.Key);
        ulong begin=Time.GetTicksUsec();
        foreach(var key in _active_chunks.Keys)if(!ringNext.TryGetValue(key,out var next)||Obj<MeshInstance3D>(next)!=Obj<MeshInstance3D>(_active_chunks[key]))_release_node(Obj<MeshInstance3D>(_active_chunks[key]));_active_chunks=ringNext;_staged.Clear();
        foreach(var value in _active_chunks.Values){var node=Obj<MeshInstance3D>(value);if(!node.Visible)node.SetMeta("published_usec",(long)Time.GetTicksUsec());node.Visible=true;_update_near_collision(node);_collision.activate(node,terrain_collision_enabled);}
        if(ringStream.IsCoverageComplete)committed_revision=partition_revision;_startup_coverage_complete=ringStream.IsCoverageComplete;_ready_edge_certificates.Clear();foreach(var stream in CaveStreams())stream.partition_committed();ringNext=new D();ringUploading=null;
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
