using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using PredatorIsle.Biomes;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private sealed class WorkerOutcome { public string Error=""; }
    private readonly Dictionary<Vector3I,WorkerOutcome> _workerOutcomes=new();
    public string last_error {get;set;}="";
    private static int Density(double span,double edge,int cap)=>(int)Math.Min(cap,Math.Pow(2,Math.Ceiling(Math.Log(span/edge)/Math.Log(2))));
    private static Vector2[] Corners(Rect2 b)=>new[]{b.Position,b.End,b.Position+new Vector2(b.Size.X,0),b.Position+new Vector2(0,b.Size.Y),b.GetCenter()};
    public int _tile_resolution(Vector3I key)
    {
        var offset=new Vector2I(key.X,key.Y)-_target_chunk;bool close=key.Z==0&&Math.Max(Math.Abs(offset.X),Math.Abs(offset.Y))<=close_detail_radius;
        int resolution=key.Z==1?Math.Max(nearby_parent_resolution,middle_resolution):key.Z==2?Math.Max(32,middle_resolution):key.Z>0?middle_resolution:close?Math.Max(chunk_resolution,close_resolution):chunk_resolution;
        if(_cave_streamer is not null&&_cave_streamer.needs_fine_surface(key))resolution=Math.Max(resolution,Math.Min(128,(int)Math.Ceiling(chunk_size/2)));
        double span=chunk_size*(1<<key.Z);var bounds=new Rect2(new Vector2(key.X,key.Y)*(float)span,Vector2.One*(float)span);
        if(_sampler._extras_enabled&&key.Z>1)
        {
            if(!_extension_mesh_tiles.ContainsKey(key))
            {
                if(_extension_mesh_tiles.Count>=2048)_extension_mesh_tiles.Clear();int owner=_sampler.pure_extension_rect(bounds);
                if(owner<0)
                {
                    double best=double.PositiveInfinity;
                    foreach(float z in new[]{.05f,.5f,.95f})foreach(float x in new[]{.05f,.5f,.95f})
                    {var p=(new Vector2(key.X,key.Y)+new Vector2(x,z))*(float)span;_sampler._biome_weights(p.X,p.Y);for(int i=0;i<8;i++){if(_sampler._extra_weights[i]<.15)continue;double edge=Number(R(TerrainBiomeCatalog.ExtensionKeys[i]),"far_mesh_metres");if(edge<best){owner=i;best=edge;}}}
                }
                _extension_mesh_tiles[key]=owner;
            }
            int id=_extension_mesh_tiles[key].AsInt32();if(id>=0)resolution=Math.Max(resolution,Density(span,Math.Max(Number(R(TerrainBiomeCatalog.ExtensionKeys[id]),"far_mesh_metres"),64),128));
        }
        Refine("forest",_forest_mesh_tiles,1,128,64,_sampler.is_pure_forest_rect);
        Refine("jungle",_jungle_mesh_tiles,1,128,64,_sampler.is_pure_jungle_rect);
        if(P("savanna_coverage")>0&&key.Z>2&&Number(R("savanna"),"far_mesh_metres")>0)
        {
            if(!_savanna_mesh_tiles.ContainsKey(key))
            {
                if(_savanna_mesh_tiles.Count>=2048)_savanna_mesh_tiles.Clear();bool detail=false;
                if(_sampler.is_pure_savanna_rect(bounds))foreach(var p in Corners(bounds)){var w=_sampler._savanna!.region_weights(p);if((double)w[2]+w[4]+w[5]+w[6]+w[11]>.25){detail=true;break;}}
                _savanna_mesh_tiles[key]=detail;
            }
            if(_savanna_mesh_tiles[key].AsBool())resolution=Math.Max(resolution,Density(span,Math.Max(Number(R("savanna"),"far_mesh_metres"),256),64));
        }
        Refine("swamp",_swamp_mesh_tiles,1,128,64,_sampler.is_pure_swamp_rect,false);
        Refine("mountain",_mountain_mesh_tiles,1,128,128,_sampler.is_pure_mountain_rect,false);
        if(P("tropical_coverage")>0&&key.Z>1)
        {
            if(!_tropical_mesh_tiles.ContainsKey(key))
            {
                if(_tropical_mesh_tiles.Count>=2048)_tropical_mesh_tiles.Clear();double edge=0;
                if(_sampler.is_pure_tropical_rect(bounds)){edge=Math.Max(Number(R("tropical"),"far_mesh_metres"),128);double river=TropicalRiverDetail.spacing(_sampler,bounds,key.Z);if(river>0)edge=Math.Min(edge,river);}_tropical_mesh_tiles[key]=edge;
            }
            double selectedEdge=_tropical_mesh_tiles[key].AsDouble();if(selectedEdge>0)resolution=Math.Max(resolution,Density(span,selectedEdge,selectedEdge<Math.Max(Number(R("tropical"),"far_mesh_metres"),128)?128:64));
        }
        if(P("badlands_coverage")>0&&key.Z>0)
        {
            if(!_badlands_mesh_tiles.ContainsKey(key))
            {
                if(_badlands_mesh_tiles.Count>=2048)_badlands_mesh_tiles.Clear();bool pure=_sampler.is_pure_badlands_rect(bounds);var config=R("badlands");double edge=pure?Math.Max(Number(config,"far_mesh_metres"),64):0;
                foreach(var p in Corners(bounds))
                {
                    if(_sampler._island_mask(p.X,p.Y)<=.01)continue;if(!pure){_sampler._biome_weights(p.X,p.Y);if(_sampler._badlands_weight<.15)continue;}var w=_sampler._badlands!.region_weights(p);
                    if(w[5]>.35&&Number(config,"remnants")>0){double detail=Math.Max(Number(config,"remnant_mesh_metres")*(key.Z==1?.5:1),8);edge=edge>0?Math.Min(edge,detail):detail;break;}
                    if((double)w[4]+w[5]+w[6]+w[7]+w[12]+w[13]>.35){double detail=Math.Max(Number(config,"dissected_mesh_metres"),64);edge=edge>0?Math.Min(edge,detail):detail;break;}
                }
                _badlands_mesh_tiles[key]=edge;
            }
            double selectedEdge=_badlands_mesh_tiles[key].AsDouble();if(selectedEdge>0)resolution=Math.Max(resolution,Density(span,selectedEdge,64));
        }
        if((B("rocky_coast_enabled")||B("beaches_enabled"))&&key.Z>1)
        {
            if(!_coast_mesh_tiles.ContainsKey(key)){if(_coast_mesh_tiles.Count>=2048)_coast_mesh_tiles.Clear();var center=(new Vector2(key.X,key.Y)+Vector2.One*.5f)*(float)span;double d=Math.Abs(_sampler._island_mask(center.X,center.Y)*P("island_size")*.5);_coast_mesh_tiles[key]=d<span*2.2+_sampler._coast_limit;}
            if(_coast_mesh_tiles[key].AsBool())resolution=Math.Max(resolution,Density(span,Math.Clamp(Number(R("rocky_coast"),"far_mesh_metres"),64,128),128));
        }
        return resolution;
        void Refine(string biome,D cache,int minimum,double floor,int cap,Func<Rect2,bool> pure,bool positive=true)
        {
            if(P(biome+"_coverage")<=0||key.Z<=minimum||(positive&&Number(R(biome),"far_mesh_metres")<=0))return;
            if(!cache.ContainsKey(key)){if(cache.Count>=2048)cache.Clear();cache[key]=pure(bounds);}if(cache[key].AsBool())resolution=Math.Max(resolution,Density(span,Math.Max(Number(R(biome),"far_mesh_metres"),floor),cap));
        }
    }
    public Vector4I _mesh_key(Vector3I key)=>new(key.X,key.Y,key.Z,_tile_resolution(key));
    public void _refresh_visible_chunks()=>_refresh_visible_chunks(Vector3.Inf);
    public void _refresh_visible_chunks(Vector3 destination)
    {
        if(nested_rings){RefreshRings(destination);return;}
        if(target is null)return;
        if(!destination.IsFinite()&&!_teleport_pending&&_cave_streamer is not null&&_active_chunks.Count>0&&_cave_streamer.defer_surface_plan(target.GlobalPosition))return;
        ulong start=Time.GetTicksUsec();var point=destination.IsFinite()?destination:target.GlobalPosition;_target_chunk=world_to_chunk(point);_last_plan_position=new Vector2(point.X,point.Z);_last_plan_usec=(long)Time.GetTicksUsec();
        _partition.base_size=chunk_size;_partition.maximum_level=maximum_lod;_partition.split_ratio=split_distance_ratio;_partition.merge_ratio=split_distance_ratio+merge_hysteresis;
        if(_cave_streamer is not null)_partition.forced_detail_regions=_cave_streamer.detail_rectangles();else _partition.forced_detail_regions.Clear();
        _wanted=_partition.select(_last_plan_position,_wanted);partition_revision++;_pending_chunks.Clear();
        foreach(var k in Keys(_staged)){var key=k.AsVector3I();if(!_wanted.ContainsKey(key)||Obj<MeshInstance3D>(_staged[key]).GetMeta("resolution").AsInt32()!=_tile_resolution(key)){_release_node(Obj<MeshInstance3D>(_staged[key]));_staged.Remove(key);}}
        foreach(var k in _wanted.Keys){var key=k.AsVector3I();if(_active_chunks.TryGetValue(key,out var node)&&Obj<MeshInstance3D>(node).GetMeta("resolution").AsInt32()==_tile_resolution(key))continue;if(_staged.ContainsKey(key)||_inflight.ContainsKey(key))continue;_pending_chunks.Add(key);}
        var sorted=_pending_chunks.OrderBy(k=>_partition.distance_to(k,_last_plan_position)).ToList();
        if(_startup_coverage_complete)
        {
            var supports=new HashSet<Vector3I>();foreach(var p in _active_chunks.Keys)
            {
                var parent=p.AsVector3I();double d=_partition.distance_to(parent,_last_plan_position);if(d>chunk_size*16)continue;bool near=d<=chunk_size*2,bounded=true;var children=new List<Vector3I>();
                foreach(var c in _wanted.Keys){var child=c.AsVector3I();if(!_ready_cut.contains(parent,child))continue;if(!near&&(child.Z<2||_estimated_sampling_work(_mesh_key(child))>8192)){bounded=false;break;}children.Add(child);}if(bounded)foreach(var c in children)supports.Add(c);
            }
            sorted=sorted.OrderBy(k=>k.Z==0&&_partition.distance_to(k,_last_plan_position)==0?0:supports.Contains(k)?1:2).ThenBy(k=>_partition.distance_to(k,_last_plan_position)).ToList();
        }
        _pending_chunks.Clear();foreach(var key in sorted)_pending_chunks.Add(key);_queued_at.Clear();foreach(var key in _pending_chunks)_queued_at[key]=(long)Time.GetTicksUsec();_update_water_position();
        if(profile_streaming)max_plan_ms=Math.Max(max_plan_ms,(Time.GetTicksUsec()-start)/1000.0);
    }
    public int _estimated_sampling_work(Vector4I key){int vertices=(key.W+3)*(key.W+3);if(chunk_size*(1<<key.Z)/key.W>32)vertices+=4*(key.W+1)*(key.W+1);return vertices;}
    private static T Pop<[MustBeVariant] T>(Godot.Collections.Array<T> a,int index){T value=a[index];a.RemoveAt(index);return value;}
    private static Variant Pop(A a,int index){var value=a[index];a.RemoveAt(index);return value;}
    public void _dispatch_jobs()
    {
        if(last_error.Length>0)return;ulong start=Time.GetTicksUsec();
        while(_pending_chunks.Count>0&&_jobs.Count+(_cave_streamer?.job_count()??0)<worker_count&&_ready_chunks.Count<worker_count*distant_job_batch*2)
        {
            var key=Pop(_pending_chunks,0);if(_inflight.ContainsKey(key)||!_wanted.ContainsKey(key))continue;var cacheKey=_mesh_key(key);
            if(_mesh_cache.TryGetValue(cacheKey,out var cached)){_stage_chunk(key,cacheKey.W,Obj<ArrayMesh>(cached));_mesh_cache.Remove(cacheKey);}
            else
            {
                TerrainMeshBuilder builder;
                if(_idle_builders.Count>0)builder=Pop(_idle_builders,_idle_builders.Count-1);
                else{builder=new TerrainMeshBuilder{settings=_settings_snapshot.DuplicateDeep(Resource.DeepDuplicateMode.All),water_level=water_level,world_seed=world_seed};builder._configure_noise();}
                var batch=new Godot.Collections.Array<Vector4I>{cacheKey};int work=_estimated_sampling_work(cacheKey);_inflight[key]=true;
                while(key.Z>0&&batch.Count<distant_job_batch&&_pending_chunks.Count>0)
                {
                    var next=_pending_chunks[0];if(next.Z==0)break;var nextKey=_mesh_key(next);int nextWork=_estimated_sampling_work(nextKey);if(work+nextWork>4096)break;_pending_chunks.RemoveAt(0);
                    if(_inflight.ContainsKey(next)||!_wanted.ContainsKey(next))continue;batch.Add(nextKey);_inflight[next]=true;work+=nextWork;
                }
                double baseSize=chunk_size;var support=StructureGeometry.support_grids(chunk_size,close_resolution,middle_resolution,maximum_lod);bool indexed=spatial_structure_collision;
                var result=new A();var job=new D{["builder"]=builder,["result"]=result,["batch"]=batch};var readyCut=_ready_cut;var collision=_collision;var outcome=new WorkerOutcome();_workerOutcomes[key]=outcome;
                job["task"]=WorkerThreadPool.AddTask(Callable.From(()=>BuildBatch(builder,batch,baseSize,support,indexed,result,outcome,readyCut,collision)));_jobs[key]=job;
            }
            if(Time.GetTicksUsec()-start>=upload_budget_ms*1000)break;
        }
        _commit_partition();
    }
    private static void BuildBatch(TerrainMeshBuilder builder,Godot.Collections.Array<Vector4I> batch,double baseSize,double[] support,bool indexed,A result,WorkerOutcome outcome,TerrainReadyCut readyCut,TerrainCollision collision)
    {
        try
        {
            foreach(var item in batch)
            {
                long begin=(long)Time.GetTicksUsec();builder.chunk_size=baseSize*(1<<item.Z);var arrays=builder.build(new Vector2I(item.X,item.Y),item.W);var edges=readyCut.edge_profiles(arrays,item.W);
                bool hasFeatures=builder._extras_enabled||(builder._tropical is not null&&Number(builder._tropical.settings,"waterfall_frequency")>0&&builder.settings.Get("water_enabled").AsBool());
                using var featuresBuilder=new TerrainFeatureMeshes();var features=hasFeatures?featuresBuilder.build(builder,new Vector2I(item.X,item.Y)):new D();
                if(item.Z<=1&&features.Count>0&&features["openings"].AsVector4Array().Length>0)features["ground_collision"]=collision.clipped_ground(arrays,features["openings"].AsVector4Array(),item.W);
                using var structureBuilder=new LodBiomeStructureGeometry();var structures=builder._extras_enabled?structureBuilder.build(builder,new Vector2I(item.X,item.Y),support,new Callable(featuresBuilder,"portal_sites")):new A();var flow=new D();
                if(structures.Count>2&&structures[2].VariantType!=Variant.Type.Nil)flow=AlienTissueCoordinates.structure_atlas(builder,structures[2].AsGodotArray(),new Vector2(item.X,item.Y)*(float)builder.chunk_size);
                var collisionData=collision.prepare(arrays,item.W,item.Z<=1,structures,features,indexed);
                result.Add(new D{["key"]=new Vector3I(item.X,item.Y,item.Z),["resolution"]=item.W,["arrays"]=arrays,["edge_profiles"]=edges,["swamp_water"]=builder.build_swamp_water(arrays,item.W),["extension_data"]=builder.built_extension_data,["extension_rows"]=builder.built_extension_rows,["alien_flow"]=builder.built_alien_tissue_flow,["alien_flow_rows"]=builder.built_alien_tissue_flow_rows,["structure_flow"]=flow,["extension_mask"]=builder.built_extension_mask,["badlands_palette_slot"]=builder.built_badlands_palette_slot,["structures"]=structures,["features"]=features,["collision_data"]=collisionData,["begin"]=begin,["end"]=(long)Time.GetTicksUsec()});
            }
        }
        catch(Exception error){outcome.Error=error.ToString();}
    }
}
