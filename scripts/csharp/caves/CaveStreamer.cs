using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using PredatorIsle.Terrain;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Shares the terrain worker allowance and commits complete cave entrance cuts atomically.</summary>
public partial class CaveStreamer : Node3D
{
    public Node3D? host {get;set;}
    public Resource? configuration {get;set;}
    public D _jobs {get;set;}=new();
    public A _idle {get;set;}=new();
    public A _ready {get;set;}=new();
    public D _cells {get;set;}=new();
    public D _wanted {get;set;}=new();
    public A _pending {get;set;}=new();
    public D _inflight {get;set;}=new();
    public D _bundle {get;set;}=new();
    public Vector2I _region {get;set;}=new(int.MaxValue,int.MaxValue);
    public long _generation {get;set;}
    public bool _discovery_pending {get;set;}
    // A partially evaluated cave graph belongs to exactly one worker. Returning
    // that worker to the general pool can restart another worker's cursor.
    // This lease exists only between completed discovery tasks, never while
    // the worker is running.
    private CaveWorkload? parkedDiscoveryWorker;
    public long discovery_worker_resumes {get;private set;}
    public D discovery_progress{get;set;}=new();
    private readonly CaveDiscoveryCache discoveryCache=new();
    public long discovery_cache_bytes=>discoveryCache.ResidentBytes;
    public long discovery_cache_hits=>discoveryCache.Hits;
    public long discovery_cache_misses=>discoveryCache.Misses;
    public Vector3 _last_plan {get;set;}=Vector3.Inf;
    public D _materials {get;set;}=new();
    public string last_error {get;set;}="";
    public string surface_status {get;set;}="awaiting discovery";
    public CaveSurfaceTransaction? _surface_transaction {get;set;}
    public D _surface_snapshot {get;set;}=new();
    public D _surface_owned {get;set;}=new();
    public D _surface_request {get;set;}=new();
    public D _surface_staging {get;set;}=new();
    public CaveSurfaceTransaction? _surface_prepared {get;set;}
    public bool _surface_build_pending {get;set;}
    public SurfaceBatch? _surface_batch {get;set;}
    public long _surface_serial {get;set;}
    public D _surface_columns {get;set;}=new();
    public Vector3 _surface_interest {get;set;}
    public A _rebuild_nodes {get;set;}=new();
    public D _rebuild_columns {get;set;}=new();
    public Vector3 _protected_point {get;set;}
    public long _surface_poll_usec {get;set;}
    public bool _close_surface_on_partition {get;set;}
    public D _detail_columns {get;set;}=new();
    public bool _frontiers_dirty {get;set;}
    public string _biome_debug {get;set;}="";
    public A _biome_runtime_controllers {get;set;}=new();
    private TerrainBiomeNoiseGpu? caveGpu;
    private readonly CaveSurfaceRenderer _renderer=new();
    private readonly CaveSurfaceCut parentCut=new();
    private readonly CaveWaterRenderer _water=new();
    private readonly CaveMaterialPalette _palette=new();
    private readonly CaveStreamFrontiers _frontiers=new();
    private readonly CaveBiomeRegions _regions=new();
    private readonly CaveBiomeMaterials _biomeMaterials=new();
    private readonly CaveFeatureRenderer _features=new();
    private readonly TraversalEnvelope _traversal=new();
    private readonly SurfaceStreamingPolicy _surfacePolicy=new();
    private static Variant Get(D data,string key,Variant fallback=default)=>data.ContainsKey(key)?data[key]:fallback;
    private static Variant ObjectValue(GodotObject? value)=>value==null?default:Variant.From(value);
    private static bool Valid(GodotObject? value)=>GodotObject.IsInstanceValid(value);
    private double Number(string key)=>configuration!.Get(key).AsDouble();
    private bool Flag(string key)=>configuration!.Get(key).AsBool();
    private Resource? Registry=>configuration==null?null:configuration.Get("biome_regions").As<Resource>();
    private bool HostFlag(string key){var value=host!.Get(key);return value.VariantType!=Variant.Type.Bool||value.AsBool();}
    private bool Teleport=>Valid(host)&&host!.Get("_teleport_pending").AsBool();
    // Stable entrance leases survive discovery-map replacement and direction
    // changes. Only a successful surface commit may create a published lease.
    private readonly Dictionary<string,D> publishedMouths=new(StringComparer.Ordinal);
    private static string MouthId(D mouth)=>Get(mouth,"id",mouth["point"].AsVector3().ToString()).AsString();
    private double RetentionRadius=>Number("preload_radius_metres")*3+128;
    private bool RetainMouth(D mouth,Vector3 point)
    {
        var center=mouth["point"].AsVector3();
        var delta=new Vector2(center.X-point.X,center.Z-point.Z);
        return delta.LengthSquared()<=RetentionRadius*RetentionRadius;
    }
    private D HeldColumns(Vector3 point)
    {
        var held=new D();
        if(Teleport||_surface_transaction?.committed!=true)return held;
        foreach(var mouth in publishedMouths.Values)
            if(RetainMouth(mouth,point)||RetainMouth(mouth,_protected_point))
                foreach(var key in mouth["columns"].AsGodotDictionary().Keys)
                    if(_surface_columns.ContainsKey(key))held[key]=true;
        // A transaction from an older or synthetic source may not have IDs.
        if(publishedMouths.Count==0&&surface_distance(point)<=RetentionRadius)
            return _surface_columns.Duplicate();
        return held;
    }
    private bool PreservesHeld(D columns)
    {
        if(Teleport)return true;
        return HeldColumns(_surface_interest).Keys.All(key=>columns.ContainsKey(key));
    }
    private static Vector2I Region(Vector3 point)=>new((int)Math.Floor(point.X/1536.0),(int)Math.Floor(point.Z/1536.0));
    public void initialize(Node3D terrain_node)
    {
        discoveryCache.Clear();host=terrain_node;
        configuration=host.Get("cave_settings").As<Resource>().DuplicateDeep(Resource.DeepDuplicateMode.All);
        // Automatic mode samples full cave mesh latency; explicit GPU mode
        // still exercises the backend on a software graphics device for tests.
        var args=OS.GetCmdlineUserArgs();bool forced=args.Contains("terrain-cave-gpu=on");
        if(caveGpu is null&&terrain_node is ChunkTerrain terrain&&!terrain.authority_only&&
           DisplayServer.GetName()!="headless"&&!args.Contains("terrain-cave-gpu=off")&&
           (forced||ChunkTerrain.UseGpuGeneration(terrain.ring_settings.generation_backend,false,DisplayServer.GetName(),RenderingServer.GetVideoAdapterName())))
        {
            caveGpu=new TerrainBiomeNoiseGpu{Name="CaveLatticeGeneration",ShaderPath=CaveGpuLattice.ShaderPath,TopologyShaderPath=CaveGpuLattice.TopologyShaderPath,RequestTimeoutSeconds=8,
                AdaptivePolicy=!forced&&terrain.ring_settings.generation_backend==2?new TerrainGpuAdaptivePolicy():null};
            AddChild(caveGpu);
        }
        configure_biome_runtime();
    }
    public void configure_biome_runtime()
    {
        foreach(var item in _biome_runtime_controllers)item.AsGodotObject().Call("release");_biome_runtime_controllers.Clear();
        var registry=Registry;if(configuration==null||!Flag("enabled")||registry==null||!registry.Get("enabled").AsBool())return;
        foreach(var item in registry.Get("definitions").AsGodotArray())
        {
            var definition=item.As<Resource>();var providerScript=definition.Get("surface_provider").As<Script>();
            if(!definition.Get("enabled").AsBool()||definition.Get("spawn_chance_percent").AsDouble()<=0||providerScript==null)continue;
            using var provider=providerScript.Call("new").AsGodotObject();if(!provider.HasMethod("create_runtime_controller"))continue;
            var controller=provider.Call("create_runtime_controller",definition.Get("material_configuration"));if(controller.VariantType==Variant.Type.Object&&controller.AsGodotObject()!=null)_biome_runtime_controllers.Add(controller);
        }
    }
    public int job_count()=>_jobs.Count;
    public CaveWorkload? worker()
    {
        if(_idle.Count>0){var value=_idle[^1].As<CaveWorkload>();_idle.RemoveAt(_idle.Count-1);return value;}
        var work=new CaveWorkload{GpuLattice=caveGpu,PublishLocalEntrances=true};if(!work.configure(host!.Get("_settings_snapshot").As<Resource>(),configuration!,host.Get("world_seed").AsInt64(),host.Get("water_level").AsDouble())){work.Dispose();return null;}return work;
    }
    public int dispatch_allowance(long terrain_free_slots,long cave_jobs,bool terrain_waiting)=>dispatch_allowance(terrain_free_slots,cave_jobs,terrain_waiting,4);
    public int dispatch_allowance(long terrain_free_slots,long cave_jobs,bool terrain_waiting,long total_workers)
    {long free=Math.Max(0,terrain_free_slots-cave_jobs),reserved=total_workers>1?1:0;return checked((int)(terrain_waiting?Math.Min(free,Math.Max(0,reserved-cave_jobs)):free));}
    private Vector2 groundSamplePosition=Vector2.Inf;
    private double sampledGround;
    public bool underground_interest(Vector3 point)
    {
        if(host is not ChunkTerrain terrain)return false;
        var horizontal=new Vector2(point.X,point.Z);
        if(!groundSamplePosition.IsFinite()||horizontal!=groundSamplePosition)
        {
            sampledGround=terrain.get_height_at(point);
            groundSamplePosition=horizontal;
        }
        return point.Y<sampledGround;
    }
    private bool wasUnderground;
    private Vector2 previousFocus = Vector2.Inf, flightLead;
    private ulong previousFocusTime;
    internal bool PreparingEntrance => previewPending || initialUpload != null || _surface_batch?.pending() == true || _surface_request.Count > 0;
    public void tick(Vector3 point,Vector3 protected_point,long terrain_free_slots,bool terrain_waiting)
    {
        var focus = new Vector2(point.X,point.Z);
        ulong now = Time.GetTicksUsec();
        if (previousFocus.IsFinite() && now > previousFocusTime)
        {
            float seconds = (now-previousFocusTime)/1000000f;
            var travel = focus-previousFocus;
            flightLead = travel.Length() > 128 ? Vector2.Zero : flightLead.Lerp((travel * (16 / seconds)).LimitLength(700),1-Mathf.Exp(-seconds*3));
        }
        previousFocus=focus; previousFocusTime=now;
        _protected_point=protected_point;collect();var cell=Region(point);
        foreach(var controller in _biome_runtime_controllers)controller.AsGodotObject().Call("update",this,protected_point);
        if(cell!=_region)
        {
            // The old discovery cursor is idle between steps. Old in-flight
            // jobs are NOT parked and remain owned by their thread-pool tasks.
            if(parkedDiscoveryWorker is not null)
            {_idle.Add(parkedDiscoveryWorker);parkedDiscoveryWorker=null;}
            clear_surface_staging();_surface_request=new();_surface_batch=null;_surface_build_pending=false;_rebuild_nodes=new();_rebuild_columns=new();
            CancelInitialUpload();
            previewPending=false;attemptedColumns=null;generatedSurface=null;
            reserve_detail(Teleport?new D():HeldColumns(point));
            _region=cell;_generation++;_wanted.Clear();_pending.Clear();_ready.Clear();_last_plan=Vector3.Inf;_discovery_pending=!discoveryCache.TryGet(cell,out var cached);_bundle=cached;
            if(_bundle.Count==0 && forecastSurface!=null)
            {
                var forecastMap=forecastSurface["map"].AsGodotDictionary();
                if(forecastMap["cell"].AsVector2I()==cell)_bundle=forecastMap;
            }
            discovery_progress=new D{["cached"]=!_discovery_pending};
        }
        PreloadAcrossBoundary(point);
        bool underground=underground_interest(point);
        if(underground!=wasUnderground){_last_plan=Vector3.Inf;wasUnderground=underground;}
        if(underground&&_bundle.Count>0){if(!_last_plan.IsFinite()||_last_plan.DistanceTo(point)>=16)plan(point,protected_point);else if(_pending.Count==0)refill_pending();}
        if(host!.HasMethod("_commit_partition"))service_surface(point);
        if(_surface_batch==null&&_surface_request.Count>0)
        {
            _surface_serial++;var batch=new SurfaceBatch();if(batch.configure(_surface_serial,_generation,_surface_request)){_surface_batch=batch;_surface_build_pending=true;}else surface_status="Invalid bounded surface batch";_surface_request=new();
        }
        int allowance=dispatch_allowance(terrain_free_slots,_jobs.Count,terrain_waiting&&!underground&&!PreparingEntrance,host!.Get("worker_count").AsInt64());
        while(allowance>0&&_ready.Count<8)
        {
            bool portalPending = _surface_batch?.pending() == true;
            bool waitingForMouth = (previewPending || initialUpload!=null || portalPending) && _detail_columns.Count > 0 && _surface_transaction == null;
            bool discoverNow = _discovery_pending && !portalPending && !waitingForMouth;
            if (!discoverNow && !portalPending && !(underground && _pending.Count > 0 && _bundle.Count > 0)) break;
            var resuming=discoverNow&&parkedDiscoveryWorker is not null;
            var work=resuming?parkedDiscoveryWorker:worker();
            if(resuming){parkedDiscoveryWorker=null;discovery_worker_resumes++;}
            if(work==null){last_error="Invalid cave worker configuration";return;}
            var result=new A();long generation=_generation;var job=new D{["work"]=work,["result"]=result,["generation"]=generation,["kind"]=discoverNow?"discovery":"mesh"};Func<D> execute;
            if(discoverNow)
            {
                _discovery_pending=false;var region=_region;
                // Amortize thread-pool dispatch overhead while keeping individual
                // steps small enough to release old interests promptly.
                execute=()=>work.discover_step(region,4,5);
            }
            else if(_surface_batch!=null&&_surface_batch.pending())
            {
                var part=_surface_batch.take();job["kind"]="portal";job["batch_id"]=part["batch_id"];job["part"]=part["part"];
                var bundle=_surface_batch.request["bundle"].AsGodotDictionary();var columns=_surface_batch.request["columns"].AsGodotDictionary();var parents=_surface_batch.request["snapshot"].AsGodotDictionary()["records"].AsGodotArray();var owned=part["columns"].AsGodotDictionary();bool ground=part["part"].AsInt32()==0;
                execute=()=>work.portal(bundle,columns,parents,owned,ground);
            }
            else if(underground&&_pending.Count>0&&_bundle.Count>0)
            {
                var key=_pending[0].AsVector3I();_pending.RemoveAt(0);var bundle=_bundle;job["key"]=key;_inflight[key]=generation;
                execute=()=>work.use_bundle(bundle)?work.build_cell(key):new D{["key"]=key,["arrays"]=new A(),["valid"]=false};
            }
            else{_idle.Add(work);break;}
            long task=WorkerThreadPool.AddTask(Callable.From(()=>result.Add(execute())));_jobs[task]=job;allowance--;
        }
    }
    public void collect()
    {
        foreach(var taskValue in _jobs.Keys.ToArray())
        {
            long task=taskValue.AsInt64();if(!WorkerThreadPool.IsTaskCompleted(task))continue;WorkerThreadPool.WaitForTaskCompletion(task);
            var job=_jobs[task].AsGodotDictionary();_jobs.Remove(task);string kind=job["kind"].AsString();long generation=job["generation"].AsInt64();
            var work=job["work"].As<CaveWorkload>();
            if(kind=="mesh"&&Get(_inflight,job["key"].AsVector3I(),-1).AsInt64()==generation)_inflight.Remove(job["key"]);
            var results=job["result"].AsGodotArray();
            if(kind=="prefetch"){
                prefetchPending=false;
                if(results.Count>0 && Get(results[0].AsGodotDictionary(),"valid",false).AsBool()){
                    forecastSurface=results[0].AsGodotDictionary();
                    if(_bundle.Count==0 && forecastRegion==_region)_bundle=forecastSurface["map"].AsGodotDictionary();
                    attemptedColumns=null;
                }
                _idle.Add(work);continue;
            }
            if(generation!=_generation||results.Count==0){_idle.Add(work);continue;}
            if(kind=="entrance-preview")previewPending=false;
            var data=results[0].AsGodotDictionary();
            if(kind=="entrance-preview")
            {
                _idle.Add(work);
                if(Get(data,"valid",false).AsBool()){
                    generatedSurface=data;
                    generatedSurface["columns"]=job["columns"];
                    generatedSurface["source_columns"]=job["source_columns"];
                    attemptedColumns=null;
                }
                else if(_detail_columns.RecursiveEqual(job["columns"].AsGodotDictionary()))
                {
                    host!.Call("_refresh_visible_chunks",Teleport?host.Get("_teleport_destination").AsVector3():Vector3.Inf);
                }
                continue;
            }
            if(kind=="discovery"&&!data.ContainsKey("error")&&Get(data,"discovery_pending",false).AsBool())
            {
                // An incomplete graph can resume only on this exact worker.
                // Keep it out of the shared pool until it completes, fails,
                // or the player moves to another discovery region.
                if (data.TryGetValue("local_bundle",out var local)) { _bundle = local.AsGodotDictionary(); data.Remove("local_bundle"); }
                parkedDiscoveryWorker=work;discovery_progress=data;_discovery_pending=true;continue;
            }
            _idle.Add(work);
            if(kind=="discovery")
            {if(data.ContainsKey("error")){last_error=data["error"].AsString();continue;}discovery_progress=new D{["complete"]=true};
                if(_bundle.TryGetValue("baked_signature",out var signature))data["baked_signature"]=signature;
                _bundle=data;discoveryCache.Add(_region,data,work.DiscoveryBytes);_last_plan=Vector3.Inf;_biome_debug=_regions.description(Get(data,"cave_biome_regions",new D()).AsGodotDictionary());}
            else if(kind=="portal")
            {
                if(_surface_batch==null||job["batch_id"].AsInt64()!=_surface_batch.id)continue;
                _surface_batch.accept(job["batch_id"].AsInt64(),generation,job["part"].AsInt32(),data);
                if(_surface_batch.failure.Length>0){last_error=surface_status=_surface_batch.failure;_surface_batch=null;_surface_build_pending=false;continue;}
                if(_surface_batch.complete())
                {
                    var assembled=_surface_batch.assemble();var request=_surface_batch.request;_surface_batch=null;_surface_build_pending=false;
                    if(Get(assembled,"valid",false).AsBool())_surface_staging=new D{["request"]=request,["data"]=assembled,["remaining"]=assembled["cells"].AsGodotArray().Duplicate(),["nodes"]=new A()};else surface_status=Get(assembled,"reason","Portal extraction failed").AsString();
                }
            }
            else _ready.Add(data);
        }
        ulong begin=Time.GetTicksUsec();
        while(_ready.Count>0)
        {
            var data=_ready[0].AsGodotDictionary();_ready.RemoveAt(0);var key=data["key"].AsVector3I();if(!_wanted.ContainsKey(key)||_cells.ContainsKey(key))continue;
            if(!data["valid"].AsBool()){last_error="Cave worker field compilation rejected";continue;}
            var interior=material_for(key,Get(data,"biome_ids",new A()).AsGodotArray());if(interior==null){last_error="Cave biome material rejected";continue;}
            MeshInstance3D? node=null;var arrays=data["arrays"].AsGodotArray();var features=Get(data,"features",new A()).AsGodotArray();var frontiers=Get(data,"frontiers",new D()).AsGodotDictionary();
            if(arrays.Count>0)
            {
                var mesh=new ArrayMesh();mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays);mesh.SurfaceSetMaterial(0,interior);
                node=new MeshInstance3D{Mesh=mesh,Position=(Vector3)key*64,CastShadow=HostFlag("terrain_shadows")?GeometryInstance3D.ShadowCastingSetting.DoubleSided:GeometryInstance3D.ShadowCastingSetting.Off};
                var body=new StaticBody3D{Name="CaveCollision",CollisionMask=0,CollisionLayer=HostFlag("terrain_collision_enabled")?1u:0};var shape=new ConcavePolygonShape3D{BackfaceCollision=true};shape.SetFaces(arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array());body.AddChild(new CollisionShape3D{Shape=shape});node.AddChild(body);AddChild(node);
                _water.attach(node,Get(data,"water",new D()).AsGodotDictionary(),Flag("common_vertex_projection"));
            }
            else if(frontiers.Count>0||features.Count>0)
            {node=new MeshInstance3D{Position=(Vector3)key*64};node.AddChild(new StaticBody3D{Name="CaveCollision",CollisionLayer=features.Count>0&&HostFlag("terrain_collision_enabled")?1u:0,CollisionMask=0});AddChild(node);}
            if(node!=null)
            {
                if(!_features.attach(node,features,Registry,Flag("common_vertex_projection"),HostFlag("terrain_shadows"))){node.Free();last_error="Cave biome feature material rejected";continue;}
                _frontiers.attach(node,frontiers,interior,HostFlag("terrain_shadows"));
            }
            _cells[key]=ObjectValue(node);_frontiers_dirty=true;if(Time.GetTicksUsec()-begin>=host!.Get("upload_budget_ms").AsDouble()*1000)break;
        }
        refresh_frontiers();
    }
    private static Variant Get(D data,Vector3I key,Variant fallback)=>data.ContainsKey(key)?data[key]:fallback;
    public void refresh_frontiers(){if(!_frontiers_dirty)return;_frontiers.synchronize(_cells,HostFlag("terrain_collision_enabled"));_frontiers_dirty=false;}
    public void plan(Vector3 point,Vector3 protected_point)
    {
        _last_plan=point;var ranked=new List<(Vector3I Key,double Distance,int Ordinal)>();int ordinal=0;
        foreach(var value in Get(_bundle,"cells",new A()).AsGodotArray())
        {var key=value.AsVector3I();var origin=(Vector3)key*64;double distance=point.DistanceTo(point.Clamp(origin,origin+Vector3.One*64));if(distance<=Number("preload_radius_metres"))ranked.Add((key,distance,ordinal));ordinal++;}
        ranked.Sort((a,b)=>a.Distance!=b.Distance?a.Distance.CompareTo(b.Distance):a.Ordinal.CompareTo(b.Ordinal));_wanted.Clear();foreach(var record in ranked.Take((int)Number("resident_cell_limit")))_wanted[record.Key]=true;
        _pending.Clear();refill_pending();
        foreach(var value in _cells.Keys.ToArray())
        {
            var key=value.AsVector3I();if(_wanted.ContainsKey(key)||_surface_owned.ContainsKey(key))continue;var origin=(Vector3)key*64;if(protected_point.DistanceTo(protected_point.Clamp(origin,origin+Vector3.One*64))<=96)continue;
            var node=_cells[key].As<MeshInstance3D>();if(Valid(node)){node!.GetNode<StaticBody3D>("CaveCollision").CollisionLayer=0;node.QueueFree();}_cells.Remove(key);_frontiers_dirty=true;
        }
        refresh_frontiers();
    }
    public void refill_pending()
    {
        var completed=new HashSet<Vector3I>();foreach(var value in _ready)completed.Add(value.AsGodotDictionary()["key"].AsVector3I());
        foreach(var value in _wanted.Keys){if(_pending.Count>=Number("pending_job_limit"))break;var key=value.AsVector3I();if(!_cells.ContainsKey(key)&&!_inflight.ContainsKey(key)&&!completed.Contains(key))_pending.Add(key);}
    }
    public bool position_ready()=>position_ready(Vector3.Inf);
    public bool position_ready(Vector3 point)
    {if(point.IsFinite()&&!underground_interest(point))return true;if(point.IsFinite()&&(_region!=Region(point)||!_last_plan.IsFinite()||_last_plan.DistanceTo(point)>=16))return false;if(_bundle.Count==0||_bundle.ContainsKey("local_only")||_discovery_pending)return false;foreach(var key in _wanted.Keys)if(!_cells.ContainsKey(key))return false;return true;}
    public bool traversal_ready(Vector3 point)
    {
        if(Flag("seal_stream_frontiers")){if(!_traversal.ready(point,_cells,_wanted))return false;}else if(!_cells.ContainsKey(new Vector3I((int)Math.Floor(point.X/64.0),(int)Math.Floor(point.Y/64.0),(int)Math.Floor(point.Z/64.0))))return false;
        foreach(var value in Get(_bundle,"entrances",new A()).AsGodotArray()){var entrance=value.AsGodotDictionary();if(!entrance_needed(entrance,point)||!entrance["columns"].AsGodotDictionary().ContainsKey(new Vector2I(Mathf.FloorToInt(point.X/64),Mathf.FloorToInt(point.Z/64))))continue;if(_surface_transaction==null||!_surface_transaction.committed)return false;foreach(var column in entrance["columns"].AsGodotDictionary().Keys)if(!_surface_columns.ContainsKey(column))return false;}return true;
    }
    public bool entrance_needed(D entrance,Vector3 point)
    {
        var mouth = entrance["point"].AsVector3();
        double exitFloor = Get(entrance, "minimum_exposed_floor", mouth.Y).AsDouble();
        double radius = Number("preload_radius_metres");
        double distance = new Vector2(point.X - mouth.X, point.Z - mouth.Z).Length();
        return point.Y >= exitFloor - Number("main_route_height_metres") * 2
            ? distance <= radius * 3
            : point.Y >= exitFloor - 80 && distance <= radius;
    }
    public bool defer_surface_plan(Vector3 point)
    {if(configuration==null||!Flag("retain_deep_surface_cut")||_bundle.Count==0||!point.IsFinite()||!Valid(host))return false;double ground=host!.Call("get_height_at",point).AsDouble();return _surfacePolicy.can_defer(point,ground,true,false)&&nearby_columns(point).Count==0;}
    public ShaderMaterial? material_for(Vector3I key)=>material_for(key,new A());
    public ShaderMaterial? material_for(Vector3I key,A biome_ids)
    {
        var region=new Vector2I((int)Math.Floor(key.X/24.0),(int)Math.Floor(key.Z/24.0));int style=0;var pools=new A();double hiveRegion=1;
        foreach(var value in Get(_bundle,"regions",new A()).AsGodotArray()){var data=value.AsGodotDictionary();if(data["id"].AsVector2I()!=region)continue;style=Get(data,"render_style",Get(data,"geology",0)).AsInt32();pools=Get(data,"pools",new A()).AsGodotArray();hiveRegion=Get(data,"hive_region",1.0).AsDouble();break;}
        Variant cacheKey=biome_ids.Count==0?Variant.From(region):Variant.From(region.ToString()+"/"+biome_ids.ToString());if(_materials.ContainsKey(cacheKey))return _materials[cacheKey].As<ShaderMaterial>();if(_materials.Count>=16)_materials.Remove(_materials.Keys.First());
        var material=new ShaderMaterial();
        if(style==7)
        {
            bool variation=true;double strength=.7;var snapshot=Valid(host)?host!.Get("_settings_snapshot").AsGodotObject():null;
            if(snapshot!=null){var alien=snapshot.Get("alien_infected").AsGodotObject();variation=alien.Get("nerve_material_variation").AsBool();strength=alien.Get("normal_strength").AsDouble();}
            material.Shader=GD.Load<Shader>("res://shaders/hive_cave.gdshader");material.SetShaderParameter("biological_colors",GD.Load<Resource>("res://materials/biological_colors_v3.tres"));material.SetShaderParameter("hive_region",hiveRegion);material.SetShaderParameter("alien_tissue_variation_enabled",variation);material.SetShaderParameter("normal_strength",strength);
        }
        else{material.Shader=GD.Load<Shader>("res://shaders/default_cave_rock.gdshader");_palette.bind(material,style,pools,configuration==null||Flag("specialize_insect_palette"));}
        var context=new D{["pools"]=pools,["geology"]=style};if(biome_ids.Count>0){var adapted=_biomeMaterials.shader(material.Shader,biome_ids,Registry);if(adapted==null)return null;material.Shader=adapted;_biomeMaterials.bind(material,biome_ids,Registry,context);}
        material.SetMeta("biome_context",context);bool common=configuration==null||Flag("common_vertex_projection");material.SetShaderParameter("cave_common_projection",common);material.SetMeta("cave_common_projection",common);material.SetMeta("cave_style",style);material.SetMeta("biome_ids",biome_ids);material.SetMeta("biome_registry",ObjectValue(Registry));_materials[cacheKey]=material;return material;
    }
    public void shutdown()
    {
        CancelInitialUpload();
        if(caveGpu is not null&&GodotObject.IsInstanceValid(caveGpu))caveGpu.Shutdown();
        discoveryCache.Clear();
        foreach(var controller in _biome_runtime_controllers)controller.AsGodotObject().Call("release");_biome_runtime_controllers.Clear();foreach(var task in _jobs.Keys)WorkerThreadPool.WaitForTaskCompletion(task.AsInt64());
        locationField?.Dispose();locationField=null;locationBundle=null;
        if(parkedDiscoveryWorker is not null){_idle.Add(parkedDiscoveryWorker);parkedDiscoveryWorker=null;}
        _jobs.Clear();_ready.Clear();_idle.Clear();_surface_batch=null;_surface_request=new();_surface_build_pending=false;_surface_transaction?.reset();clear_surface_staging();_frontiers.synchronize(_cells,false);
        foreach(var value in _cells.Values){var node=value.As<Node3D>();if(Valid(node))node!.GetNode<StaticBody3D>("CaveCollision").CollisionLayer=0;}_cells.Clear();
    }
    public A active_parent_nodes()=>new(host!.Get("_active_chunks").AsGodotDictionary().Values);
    public Godot.Collections.Array<Rect2> detail_rectangles()
    {
        var result=new Godot.Collections.Array<Rect2>();
        foreach(var key in _detail_columns.Keys)
        {
            var bounds=new Rect2((Vector2)key.AsVector2I()*64,Vector2.One*64);
            if(!Teleport && host is ChunkTerrain { nested_rings:true, authority_only:false })
            {
                // A prepared entrance owns its surface and collider. Do not
                // split a distant ring into fine tiles just to make a preview.
                if(_surface_transaction?.committed==true && _surface_columns.ContainsKey(key))continue;
                if((previewPending || initialUpload!=null) && attemptedColumns?.ContainsKey(key)==true)continue;
                var focus=new Vector2(_protected_point.X,_protected_point.Z);
                if(focus.DistanceSquaredTo(focus.Clamp(bounds.Position,bounds.End))>160*160)continue;
            }
            result.Add(bounds);
        }
        return result;
    }
    internal bool AwaitingLocalMap => _bundle.Count == 0 && last_error.Length == 0;
    internal bool DeferFinePreview(Vector3I key) =>
        AwaitingLocalMap && host is ChunkTerrain terrain && terrain._active_chunks.Count==0 ||
        needs_fine_surface(key);
    public bool needs_fine_surface(Vector3I key)
    {if(key.Z!=0)return false;float span=(float)host!.Get("chunk_size").AsDouble();var bounds=new Rect2(new Vector2(key.X,key.Y)*span,Vector2.One*span);foreach(var keyValue in _detail_columns.Keys)if(bounds.Intersects(new Rect2((Vector2)keyValue.AsVector2I()*64,Vector2.One*64)))return true;return false;}
    public void reserve_detail(D columns)
    {if(columns.RecursiveEqual(_detail_columns))return;_detail_columns=columns.Duplicate();_rebuild_nodes=new();host!.Call("_refresh_visible_chunks",Teleport?host.Get("_teleport_destination").AsVector3():Vector3.Inf);}
    public bool partition_ready(A nodes)
    {
        if(Teleport)
        {
            var destination=nearby_columns(host!.Get("_teleport_destination").AsVector3());
            if(destination.Count>0)
            {
                if(_surface_transaction!=null&&destination.RecursiveEqual(_surface_columns)&&_renderer.matches(_surface_snapshot,nodes,_surface_columns))return true;
                _rebuild_nodes=nodes;_rebuild_columns=destination;
                return _surface_prepared!=null&&_surface_prepared.ready_to_commit()&&_surface_staging["request"].AsGodotDictionary()["columns"].AsGodotDictionary().RecursiveEqual(destination)&&_renderer.matches(_surface_staging["request"].AsGodotDictionary()["snapshot"].AsGodotDictionary(),nodes,destination);
            }
            if(_surface_transaction!=null){_close_surface_on_partition=true;return true;}
        }
        // An incoming fine tile at a reserved mouth stays hidden until the
        // prepared entrance is ready. Disjoint terrain continues publishing.
        if(_detail_columns.Count>0 &&
            (initialUpload!=null || previewPending || generatedSurface!=null))
        {
            var incoming=new D();
            foreach(var key in _detail_columns.Keys)
                if(!_surface_columns.ContainsKey(key))incoming[key]=true;
            if(_surface_transaction==null&&nodes.Any(raw=>_renderer.touches(raw.As<MeshInstance3D>(),incoming)))return false;
            // Existing cuts remain live; only the canonical preview may add
            // the new mouth while its products are being uploaded.
            if(_surface_transaction!=null&&_renderer.matches(_surface_snapshot,nodes,_surface_columns))return true;
        }

        // Build against the incoming terrain while it is still staged. Commit
        // its collision, surface cut and cave lining in the same publication.
        if (_bundle.Count > 0 && _detail_columns.Count > 0 && (_surface_transaction == null || !_detail_columns.RecursiveEqual(_surface_columns)))
        {
            if (_surface_prepared != null && _surface_prepared.ready_to_commit())
            {
                var prepared = _surface_staging["request"].AsGodotDictionary();
                if (PreservesHeld(prepared["columns"].AsGodotDictionary()) && prepared["columns"].AsGodotDictionary().RecursiveEqual(_detail_columns) && _renderer.matches(prepared["snapshot"].AsGodotDictionary(),nodes,_detail_columns))
                    return true;
            }
            if (_rebuild_nodes.Count > 0 && _rebuild_nodes.RecursiveEqual(nodes)) return false;
            var staged = _renderer.capture(nodes,_detail_columns);
            if (staged["valid"].AsBool())
            {
                _rebuild_nodes = nodes;
                _rebuild_columns = _detail_columns.Duplicate();
                if (_surface_batch == null && !_surface_build_pending && _surface_staging.Count == 0)
                    _surface_request = new D { ["bundle"]=_bundle, ["snapshot"]=staged, ["columns"]=_rebuild_columns };
                return false;
            }
            _rebuild_nodes = new();
        }
        if(_surface_transaction==null)return true;
        if(_renderer.matches(_surface_snapshot,nodes,_surface_columns))return true;
        if((surface_distance(_protected_point)>Number("preload_radius_metres")*3+128 &&
            !_surface_columns.Keys.Any(key=>_detail_columns.ContainsKey(key)))||Teleport){_close_surface_on_partition=true;return true;}
        if(_surface_prepared?.ready_to_commit()==true)
        {
            var prepared=_surface_staging["request"].AsGodotDictionary();
            if(PreservesHeld(prepared["columns"].AsGodotDictionary())&&_renderer.matches(prepared["snapshot"].AsGodotDictionary(),nodes,prepared["columns"].AsGodotDictionary()))
                return true;
        }
        if (host is ChunkTerrain { nested_rings: true, authority_only: false } && RebindRingParents(nodes))return true;
        _rebuild_nodes=nodes;_rebuild_columns=_surface_columns.Duplicate();
        if(_surface_prepared==null||!_surface_prepared.ready_to_commit())return false;
        var request=_surface_staging["request"].AsGodotDictionary();return PreservesHeld(request["columns"].AsGodotDictionary())&&_renderer.matches(request["snapshot"].AsGodotDictionary(),nodes,request["columns"].AsGodotDictionary());
    }
    // The ring portal is carved on a canonical grid. Changing the LOD around
    // an existing cut only needs new parent masks and clipped parent colliders.
    private CaveSurfaceTransaction? ringRebind;
    private D? ringRebindSources;
    private bool RebindRingParents(A nodes)
    {
        if (_surface_transaction is not { committed: true } current) return false;
        var parents = new A();
        var sources = new D();
        foreach (var value in nodes)
        {
            var node = value.As<MeshInstance3D>();
            if (!_renderer.touches(node, _surface_columns)) continue;
            if (!node.Mesh.GetMeta("terrain_canonical_surface", false).AsBool()) return false;
            parents.Add(node);
            sources[node.GetMeta("tile").AsVector3I().ToString()] = new D
            {
                ["node"] = node, ["origin"] = node.GlobalPosition, ["mesh"] = node.Mesh
            };
        }
        var next = new CaveSurfaceTransaction
        {
            ParentCut = parentCut,
            collision_enabled = current.collision_enabled,
            common_vertex_projection = current.common_vertex_projection
        };
        if (!next.prepare(parents, current.patches, _surface_columns, new Vector2(_protected_point.X,_protected_point.Z), current))
            return false;
        ringRebind = next;
        ringRebindSources = sources;
        return true;
    }
    public void partition_committed()
    {
        if (ringRebind != null)
        {
            if (ringRebind.commit())
            {
                _surface_transaction = ringRebind;
                _surface_snapshot["sources"] = ringRebindSources!;
                clear_surface_staging();
            }
            ringRebind = null;
            ringRebindSources = null;
        }
        if(_close_surface_on_partition){close_surface();_close_surface_on_partition=false;_rebuild_nodes=new();_rebuild_columns=new();}
        if(_surface_prepared!=null&&_surface_prepared.ready_to_commit())
        {
            var request=_surface_staging["request"].AsGodotDictionary();
            if(PreservesHeld(request["columns"].AsGodotDictionary())&&_surface_prepared.commit())
            {
                adopt_surface(_surface_prepared,request["snapshot"].AsGodotDictionary(),_surface_staging["data"].AsGodotDictionary());
                _surface_prepared=null;_surface_staging=new();
            }
            else clear_surface_staging();
            _rebuild_nodes=new();_rebuild_columns=new();
        }
        if(_surface_transaction!=null)foreach(var value in active_parent_nodes())_surface_transaction.apply_node(value.As<MeshInstance3D>());
    }
    public void apply_parent(MeshInstance3D node)=>_surface_transaction?.apply_node(node);
    public void release_parent(MeshInstance3D node)=>_surface_transaction?.release_node(node);
    public void clear_surface_staging()
    {foreach(var value in Get(_surface_staging,"nodes",new A()).AsGodotArray()){var node=value.As<Node>();if(Valid(node))node!.QueueFree();}_surface_staging=new();_surface_prepared=null;}
    public double surface_distance(Vector3 point)
    {double distance=double.PositiveInfinity;var p=new Vector2(point.X,point.Z);foreach(var value in _surface_columns.Keys){var origin=(Vector2)value.AsVector2I()*64;distance=Math.Min(distance,p.DistanceTo(p.Clamp(origin,origin+Vector2.One*64)));}return distance;}
    public void close_surface()
    {
        publishedMouths.Clear();
        _surface_transaction?.reset();foreach(var key in _surface_owned.Keys){var node=_cells.ContainsKey(key)?_cells[key].As<Node>():null;if(Valid(node))node!.QueueFree();_cells.Remove(key);}
        _surface_transaction=null;_surface_owned.Clear();_surface_columns.Clear();_surface_snapshot=new();_last_plan=Vector3.Inf;_frontiers_dirty=true;refresh_frontiers();
    }
    public D nearby_columns(Vector3 point)
    {
        var columns=new D();var nearby=Get(_bundle,"entrances",new A()).AsGodotArray().Select((v,i)=>(Data:v.AsGodotDictionary(),Ordinal:i)).ToList();
        var origin = new Vector2(point.X,point.Z);
        float Score(D entrance)
        {
            var mouth = entrance["point"].AsVector3();
            var offset = new Vector2(mouth.X,mouth.Z)-origin;
            if (Teleport || flightLead.LengthSquared()<1) return offset.LengthSquared();
            float ahead = Mathf.Clamp(offset.Dot(flightLead)/flightLead.LengthSquared(),0,1);
            return (offset-flightLead*ahead).LengthSquared() + offset.LengthSquared()*.015f;
        }
        nearby.Sort((a,b)=>{
            int order=Score(a.Data).CompareTo(Score(b.Data));if(order!=0)return order;
            var p=a.Data["point"].AsVector3();var q=b.Data["point"].AsVector3();
            order=p.X.CompareTo(q.X);return order!=0?order:p.Z.CompareTo(q.Z);
        });
        // Ownership is persistent rather than reconstructed from the current
        // discovery bundle. Even a complete bundle cannot evict a nearby
        // published mouth simply because that mouth isn't in its halo.
        columns=HeldColumns(point);
        // Partial maps cannot build a full replacement containing a mouth from
        // outside their region. Keep its existing transaction; new mouths can
        // append independent products without reconstructing held columns.
        if(_surface_transaction?.committed==true&&!Teleport&&
            (_bundle.ContainsKey("local_only")||_discovery_pending)&&
            _surface_columns.Keys.Any(key=>!columns.ContainsKey(key))&&
            surface_distance(point)<=RetentionRadius)
            columns=_surface_columns.Duplicate();
        foreach (var item in nearby)
        {
            if (!entrance_needed(item.Data,point)) continue;
            var mouthColumns = item.Data["columns"].AsGodotDictionary();
            if (mouthColumns.Count is 0 or >64) continue;
            int additional=mouthColumns.Keys.Count(key=>!columns.ContainsKey(key));
            if(columns.Count+additional>64)continue;
            foreach (var key in mouthColumns.Keys) columns[key]=true;
        }
        return columns;
    }
    private D? attemptedColumns;
    private D? generatedSurface;
    private bool previewPending;
    private bool prefetchPending;
    private Vector2I? forecastRegion;
    private D? forecastSurface;
    // A flight can cross a region boundary before normal discovery finishes.
    // Build the projected landing area's entrance while the current region streams.
    private void PreloadAcrossBoundary(Vector3 point)
    {
        if(prefetchPending || flightLead.LengthSquared()<128*128 || underground_interest(point))return;
        var lead=flightLead.Normalized()*Math.Clamp(flightLead.Length(),448f,560f);
        var ahead=new Vector3(point.X+lead.X,point.Y,point.Z+lead.Y);
        var region=Region(ahead);
        var start=new Vector2(point.X,point.Z);
        if(region==Region(point) || forecastRegion==region)return;
        var work=worker();
        if(work==null)return;
        forecastRegion=region;prefetchPending=true;
        var result=new A();
        long task=WorkerThreadPool.AddTask(Callable.From(()=>{
            var map=work.ReadStartupMap(region) ?? work.BuildLocalMap(region);
            D? best=null;float nearest=float.PositiveInfinity;
            foreach(var raw in map["entrances"].AsGodotArray()){
                var mouth=raw.AsGodotDictionary();var position=mouth["point"].AsVector3();
                var offset=new Vector2(position.X,position.Z)-start;
                float progress=Mathf.Clamp(offset.Dot(lead)/lead.LengthSquared(),0,1);
                float distance=(offset-lead*progress).LengthSquared()+offset.LengthSquared()*.015f;
                if(distance>=nearest || mouth["columns"].AsGodotDictionary().Count is 0 or >64)continue;
                best=mouth;nearest=distance;
            }
            var data=new D{{"valid",true}};
            if(best!=null && !map.ContainsKey("baked_signature")){
                var columns=best["columns"].AsGodotDictionary();
                data=work.BuildEntranceSurface(map,columns);data["columns"]=columns;
            }
            data["map"]=map;
            result.Add(data);
        }));
        _jobs[task]=new D{["kind"]="prefetch",["work"]=work,["result"]=result,["generation"]=_generation};
    }

    internal bool InitialEntranceVisible(Vector2I column) =>
        _surface_snapshot.ContainsKey("initial") && _surface_columns.ContainsKey(column) &&
        _surface_transaction?.committed==true;

    private void ShowInitialEntrance(D columns,bool allowBuild=true)
    {
        if(initialUpload!=null || host is not ChunkTerrain terrain || terrain.authority_only || Teleport ||
           _surface_batch!=null || _surface_build_pending || _surface_request.Count>0 ||
           _rebuild_nodes.Count>0 || columns.RecursiveEqual(_surface_columns) || !PreservesHeld(columns))return;
        var cells=new A();
        var sourceColumns=columns;
        bool append=_surface_transaction?.committed==true &&
            _surface_columns.Keys.All(key=>columns.ContainsKey(key));
        if(append)
        {
            sourceColumns=columns.Duplicate();
            foreach(var key in _surface_columns.Keys)sourceColumns.Remove(key);
        }
        var point=_surface_interest;
        foreach(var value in _bundle["entrances"].AsGodotArray())
        {
            var mouth=value.AsGodotDictionary();
            if(!mouth["columns"].AsGodotDictionary().RecursiveEqual(sourceColumns))continue;
            point=mouth["point"].AsVector3();
            string path=CaveWorkload.EntrancePath(point);
            if(_bundle.TryGetValue("baked_signature",out var signature) && ResourceLoader.Exists(path)){
                var resource=GD.Load<Resource>(path);
                if(resource.GetMeta("signature").AsString()==signature.AsString() &&
                    resource.GetMeta("columns").AsGodotDictionary().RecursiveEqual(sourceColumns))
                    cells=resource.GetMeta("cells").AsGodotArray();
            }
            break;
        }
        if(forecastSurface?.TryGetValue("columns",out var forecastColumns)==true && sourceColumns.RecursiveEqual(forecastColumns.AsGodotDictionary())){
            cells=forecastSurface["cells"].AsGodotArray();
            forecastSurface=null;
        }
        if(generatedSurface!=null && columns.RecursiveEqual(generatedSurface["columns"].AsGodotDictionary()) &&
            sourceColumns.RecursiveEqual(generatedSurface["source_columns"].AsGodotDictionary())){
            cells=generatedSurface["cells"].AsGodotArray();
            generatedSurface=null;
        }
        if(cells.Count==0 && (!allowBuild || previewPending || attemptedColumns?.RecursiveEqual(columns)==true))return;
        attemptedColumns=columns.Duplicate();
        if(cells.Count==0){
            var work=worker();
            if(work==null)return;
            var map=_bundle;
            var result=new A();
            var requested=sourceColumns.Duplicate();
            long task=WorkerThreadPool.AddTask(Callable.From(()=>result.Add(work.BuildEntranceSurface(map,requested))));
            _jobs[task]=new D{["kind"]="entrance-preview",["generation"]=_generation,["work"]=work,["result"]=result,["columns"]=columns,["source_columns"]=requested};
            previewPending=true;
            return;
        }
        var sources=new D();
        var material=(ShaderMaterial)terrain._terrain_material.Duplicate();
        material.SetShaderParameter("chunk_size_metres",64.0);
        foreach(var raw in sourceColumns.Keys)
        {
            var column=raw.AsVector2I();
            sources[column.ToString()]=new D {["origin"]=new Vector3(column.X*64,0,column.Y*64),["material"]=material};
        }
        initialUpload=new EntranceUpload(columns,sourceColumns,sources,cells,point,append);
        if(OS.GetCmdlineUserArgs().Contains("trace"))GD.Print($"Queued entrance {point} at camera {_surface_interest}, cells={cells.Count}");
        if(terrain._active_chunks.Count==0)UploadInitialEntrance(useFrameBudget:false);
    }

    private sealed record EntranceUpload(D Columns,D NewColumns,D Sources,A Cells,Vector3 Mouth,bool Append)
    {
        public int Cursor { get; set; }
        public A Nodes { get; } = new();
    }
    private EntranceUpload? initialUpload;

    private void CancelInitialUpload()
    {
        if(initialUpload is null)return;
        foreach(var item in initialUpload.Nodes)item.As<Node>().QueueFree();
        initialUpload=null;
    }

    private void UploadInitialEntrance(bool useFrameBudget=true)
    {
        if(initialUpload is not {} upload)return;
        var desired=nearby_columns(_surface_interest);
        if(!PreservesHeld(upload.Columns) || !upload.Columns.Keys.All(key=>desired.ContainsKey(key)))
        {CancelInitialUpload();attemptedColumns=null;return;}
        ulong began=Time.GetTicksUsec();
        while(upload.Cursor<upload.Cells.Count)
        {
            var data=upload.Cells[upload.Cursor++].AsGodotDictionary();
            var key=data["key"].AsVector3I();
            var interior=material_for(key,Get(data,"biome_ids",new A()).AsGodotArray());
            if(interior==null){CancelInitialUpload();return;}
            var result=_renderer.node(data,upload.Sources,interior,interior.GetMeta("cave_style",0).AsInt32(),
                HostFlag("terrain_shadows"),Flag("specialize_insect_palette"));
            if(!result["valid"].AsBool()){CancelInitialUpload();return;}
            if(result["node"].AsGodotObject() is MeshInstance3D node)
            {
                AddChild(node);
                upload.Nodes.Add(node);
            }
            if(useFrameBudget && Time.GetTicksUsec()-began>=2000)return;
        }

        var patches=new A(upload.Nodes);
        var products=new A(upload.Cells);
        if(upload.Append)
        {
            if(_surface_transaction?.committed!=true ||
                !_surface_columns.Keys.All(key=>upload.Columns.ContainsKey(key) && !upload.NewColumns.ContainsKey(key)) ||
                _surface_columns.Count+upload.NewColumns.Count!=upload.Columns.Count)
            {
                CancelInitialUpload();
                attemptedColumns=null;
                return;
            }
            foreach(var patch in _surface_transaction.patches)patches.Add(patch);
            foreach(var key in _surface_owned.Keys)products.Add(new D{["key"]=key});
        }
        var parents=new A();
        var liveSources=new D();
        foreach(var item in active_parent_nodes())
        {
            var parent=item.As<MeshInstance3D>();
            if(!_renderer.touches(parent,upload.Columns))continue;
            TerrainGpuGrids.EnsureCpuSurface(parent);
            parents.Add(parent);
            liveSources[parent.GetMeta("tile").AsVector3I().ToString()]=new D
            {
                ["node"]=parent,["origin"]=parent.GlobalPosition,["mesh"]=parent.Mesh
            };
        }
        var transaction=new CaveSurfaceTransaction
        {
            ParentCut=parentCut,collision_enabled=HostFlag("terrain_collision_enabled"),
            common_vertex_projection=Flag("common_vertex_projection")
        };
        if(!transaction.prepare(parents,patches,upload.Columns,new Vector2(upload.Mouth.X,upload.Mouth.Z),_surface_transaction) ||
            !transaction.commit())
        {
            CancelInitialUpload();
            return;
        }
        initialUpload=null;
        clear_surface_staging();
        _surface_batch=null;
        _surface_build_pending=false;
        _surface_request=new();
        _rebuild_nodes=new();
        _rebuild_columns=new();
        adopt_surface(transaction,new D{["sources"]=liveSources,["initial"]=true},new D{["cells"]=products,["columns"]=upload.Columns});
        if(OS.GetCmdlineUserArgs().Contains("trace"))GD.Print($"Published entrance {upload.Mouth} at camera {_surface_interest}");
    }

    public void service_surface(Vector3 point)
    {
        _surface_interest=point;
        long now=(long)Time.GetTicksUsec();
        // Flight prediction affects the common planner and background prefetch only.
        if(initialUpload!=null)
        {
            if(Teleport)CancelInitialUpload();
            else {UploadInitialEntrance();return;}
        }
        if(_surface_staging.Count>0)
        {
            var request=_surface_staging["request"].AsGodotDictionary();var snapshot=request["snapshot"].AsGodotDictionary();var columns=request["columns"].AsGodotDictionary();var desired=_rebuild_nodes.Count>0?_rebuild_nodes:active_parent_nodes();
            if(!PreservesHeld(columns)||!_renderer.matches(snapshot,desired,columns)){clear_surface_staging();surface_status="surface ownership/parents changed; retaining old entrance";return;}
            var remaining=_surface_staging["remaining"].AsGodotArray();
            if(remaining.Count>0)
            {
                var data=remaining[0].AsGodotDictionary();remaining.RemoveAt(0);var interior=material_for(data["key"].AsVector3I(),Get(data,"biome_ids",new A()).AsGodotArray());
                if(interior==null){clear_surface_staging();surface_status="Cave biome material rejected";return;}
                int style=interior.GetMeta("cave_style",0).AsInt32();var built=_renderer.node(data,snapshot["sources"].AsGodotDictionary(),interior,style,HostFlag("terrain_shadows"),Flag("specialize_insect_palette"));
                if(!built["valid"].AsBool()){clear_surface_staging();last_error=surface_status=built["reason"].AsString();return;}
                var node=built["node"].As<Node>();if(node!=null){AddChild(node);_surface_staging["nodes"].AsGodotArray().Add(node);}_renderer.release_uploaded_data(data);return;
            }
            if(_surface_prepared==null)
            {
                var transaction=new CaveSurfaceTransaction{ParentCut=parentCut,collision_enabled=HostFlag("terrain_collision_enabled"),common_vertex_projection=Flag("common_vertex_projection")};var nodes=new A();
                foreach(var value in snapshot["sources"].AsGodotDictionary().Values)nodes.Add(value.AsGodotDictionary()["node"]);
                if(!transaction.prepare(nodes,_surface_staging["nodes"].AsGodotArray(),columns,new Vector2(point.X,point.Z),_surface_transaction,_surface_staging["data"].AsGodotDictionary()["ground"].AsGodotDictionary())){clear_surface_staging();surface_status="surface commit preparation rejected";return;}
                _surface_prepared=transaction;
            }
            if(_rebuild_nodes.Count==0&&!Teleport&&_surface_prepared.ready_to_commit())
            {
                if(PreservesHeld(columns)&&_surface_prepared.commit())
                {adopt_surface(_surface_prepared,snapshot,_surface_staging["data"].AsGodotDictionary());_surface_prepared=null;_surface_staging=new();}
                else clear_surface_staging();
            }return;
        }
        if(_bundle.Count==0||_surface_build_pending||_surface_request.Count>0||now-_surface_poll_usec<250000)return;
        _surface_poll_usec=now;var wantedColumns=nearby_columns(point);if(_rebuild_nodes.Count>0)wantedColumns=_rebuild_columns.Duplicate();
        if(wantedColumns.Count==0)
        {
            if(_surface_transaction!=null&&_rebuild_nodes.Count==0)
            {
                if(Teleport){reserve_detail(new D());surface_status="active retained entrance";return;}
                if(surface_distance(_protected_point)<=Number("preload_radius_metres")*3+128){surface_status="active retained entrance";return;}close_surface();
            }
            attemptedColumns=null;reserve_detail(new D());surface_status="no nearby admitted entrance";return;
        }
        ShowInitialEntrance(wantedColumns);
        if(_rebuild_nodes.Count==0)reserve_detail(wantedColumns);
        // Canonical previews already contain both the opening and its collision.
        // Only extract from the live parents when that path cannot build the cut.
        if (initialUpload != null || previewPending) return;
        // A full live-parent extraction cannot reconstruct a leased mouth from
        // a partial local map. Do not replace a valid cut with an incomplete one.
        if(_bundle.ContainsKey("local_only")&&_surface_transaction?.committed==true)
        {
            var known=new D();
            foreach(var raw in Get(_bundle,"entrances",new A()).AsGodotArray())
                foreach(var key in raw.AsGodotDictionary()["columns"].AsGodotDictionary().Keys)known[key]=true;
            if(wantedColumns.Keys.Any(key=>!known.ContainsKey(key)))return;
        }
        var parents=_rebuild_nodes.Count>0?_rebuild_nodes:active_parent_nodes();
        if(_surface_transaction!=null&&wantedColumns.RecursiveEqual(_surface_columns)&&_renderer.matches(_surface_snapshot,parents,wantedColumns)){surface_status="active";_rebuild_nodes=new();return;}
        var capture=_renderer.capture(parents,wantedColumns);if(!capture["valid"].AsBool()){surface_status=capture["reason"].AsString();return;}
        _surface_request=new D{["bundle"]=_bundle,["snapshot"]=capture,["columns"]=wantedColumns};surface_status="building complete hidden entrance";
    }
    public void adopt_surface(CaveSurfaceTransaction transaction,D snapshot,D data)
    {

        var retained=new D();foreach(var value in transaction.patches){var node=value.As<MeshInstance3D>();retained[node.GetMeta("cave_cell")]=node;}
        foreach(var key in _surface_owned.Keys){var old=_cells.ContainsKey(key)?_cells[key].As<Node>():null;if(Valid(old)&&!retained.Values.Contains(ObjectValue(old)))old!.QueueFree();if(!retained.ContainsKey(key))_cells.Remove(key);}
        _surface_owned.Clear();
        foreach(var value in data["cells"].AsGodotArray())
        {
            var result=value.AsGodotDictionary();var key=result["key"].AsVector3I();var node=retained.ContainsKey(key)?retained[key].As<MeshInstance3D>():null;var old=_cells.ContainsKey(key)?_cells[key].As<MeshInstance3D>():null;
            if(Valid(old)&&old!=node){old!.Visible=false;old.GetNode<StaticBody3D>("CaveCollision").CollisionLayer=0;old.QueueFree();}_cells[key]=ObjectValue(node);_surface_owned[key]=true;
        }
        _surface_transaction=transaction;_surface_columns=data["columns"].AsGodotDictionary().Duplicate();_surface_snapshot=snapshot;
        foreach(string id in publishedMouths.Keys.ToArray())
            if(!publishedMouths[id]["columns"].AsGodotDictionary().Keys.All(key=>_surface_columns.ContainsKey(key)))publishedMouths.Remove(id);
        foreach(var raw in Get(_bundle,"entrances",new A()).AsGodotArray())
        {
            var mouth=raw.AsGodotDictionary();var keys=mouth["columns"].AsGodotDictionary();
            if(keys.Count>0&&keys.Keys.All(key=>_surface_columns.ContainsKey(key)))
                publishedMouths[MouthId(mouth)]=mouth.Duplicate();
        }
        _last_plan=Vector3.Inf;surface_status="active";_frontiers_dirty=true;refresh_frontiers();
    }
    public A surface_materials()
    {
        var result=new A();if(_surface_transaction==null)return result;foreach(var value in _surface_transaction.materials())result.Add(value);
        foreach(var value in _surface_transaction.patches){var node=value.As<MeshInstance3D>();if(Valid(node))for(int i=0;i<node.Mesh.GetSurfaceCount();i++)result.Add(node.Mesh.SurfaceGetMaterial(i));}return result;
    }
    private CaveField? locationField;
    private D? locationBundle;
    public string CaveNameAt(Vector3 point)
    {
        if(_bundle.Count==0 || !_bundle.ContainsKey("regions") || Registry is null)return "";
        if(!ReferenceEquals(locationBundle,_bundle))
        {
            locationField?.Dispose();
            locationField=new CaveField{maximum_depth=Number("maximum_depth_metres"),minimum_roof=Number("minimum_rock_cover_metres")};
            var terrain=(PredatorIsle.Terrain.ChunkTerrain)host!;
            var height=Callable.From<double,double,double>((x,z)=>terrain.get_height_at(new Vector3((float)x,0,(float)z)));
            locationBundle=_bundle;
            if(!locationField.compile(_bundle["regions"].AsGodotArray(),height,_bundle["connections"].AsGodotArray(),
                Get(_bundle,"cave_biome_regions",new D()).AsGodotDictionary())){locationField.Dispose();locationField=null;}
        }
        if(locationField is null || locationField.sample(point)>=0)return "";
        var cell=(Vector3I)(point/64).Floor();
        var ids=locationField.biome_ids_for_cell(cell);
        string best=Registry.Get("fallback_biome_id").AsString();float highest=0;
        for(int offset=0;offset<ids.Count;offset+=4)
        {
            var group=new A();for(int j=offset;j<Math.Min(offset+4,ids.Count);j++)group.Add(ids[j]);
            var weights=locationField.biome_weights_at(point,group);
            for(int j=0;j<group.Count;j++)if(weights[j]>highest){highest=weights[j];best=group[j].AsString();}
        }
        foreach(var item in Registry.Get("definitions").AsGodotArray())
        {
            var definition=item.AsGodotObject();
            if(definition.Get("biome_id").AsString()==best)return definition.Get("display_name").AsString();
        }
        return "Cave";
    }
    public string debug_text()=>$"Shared caves: {_cells.Count}/{_wanted.Count} cells, {_jobs.Count} jobs; entrance {surface_status}\n{_biome_debug}";
}

