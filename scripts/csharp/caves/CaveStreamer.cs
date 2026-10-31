using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
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
    private readonly CaveSurfaceRenderer _renderer=new();
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
    private bool Teleport=>host!.Get("_teleport_pending").AsBool();
    private static Vector2I Region(Vector3 point)=>new((int)Math.Floor(point.X/1536.0),(int)Math.Floor(point.Z/1536.0));
    public void initialize(Node3D terrain_node)
    {host=terrain_node;configuration=host.Get("cave_settings").As<Resource>().DuplicateDeep(Resource.DeepDuplicateMode.All);configure_biome_runtime();}
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
        var work=new CaveWorkload();if(!work.configure(host!.Get("_settings_snapshot").As<Resource>(),configuration!,host.Get("world_seed").AsInt64(),host.Get("water_level").AsDouble())){work.Dispose();return null;}return work;
    }
    public int dispatch_allowance(long terrain_free_slots,long cave_jobs,bool terrain_waiting)=>dispatch_allowance(terrain_free_slots,cave_jobs,terrain_waiting,4);
    public int dispatch_allowance(long terrain_free_slots,long cave_jobs,bool terrain_waiting,long total_workers)
    {long free=Math.Max(0,terrain_free_slots-cave_jobs),reserved=total_workers>1?1:0;return checked((int)(terrain_waiting?Math.Min(free,Math.Max(0,reserved-cave_jobs)):free));}
    public void tick(Vector3 point,Vector3 protected_point,long terrain_free_slots,bool terrain_waiting)
    {
        _protected_point=protected_point;collect();var cell=Region(point);
        foreach(var controller in _biome_runtime_controllers)controller.AsGodotObject().Call("update",this,protected_point);
        if(cell!=_region)
        {
            clear_surface_staging();_surface_request=new();_surface_batch=null;_surface_build_pending=false;_rebuild_nodes=new();_rebuild_columns=new();
            _region=cell;_generation++;_bundle=new();_wanted.Clear();_pending.Clear();_ready.Clear();_last_plan=Vector3.Inf;_discovery_pending=true;
        }
        if(_bundle.Count>0){if(!_last_plan.IsFinite()||_last_plan.DistanceTo(point)>=16)plan(point,protected_point);else if(_pending.Count==0)refill_pending();}
        if(host!.HasMethod("_commit_partition"))service_surface(point);
        if(_surface_batch==null&&_surface_request.Count>0)
        {
            _surface_serial++;var batch=new SurfaceBatch();if(batch.configure(_surface_serial,_generation,_surface_request)){_surface_batch=batch;_surface_build_pending=true;}else surface_status="Invalid bounded surface batch";_surface_request=new();
        }
        int allowance=dispatch_allowance(terrain_free_slots,_jobs.Count,terrain_waiting,host.Get("worker_count").AsInt64());
        while(allowance>0&&_ready.Count<8)
        {
            var work=worker();if(work==null){last_error="Invalid cave worker configuration";return;}
            var result=new A();long generation=_generation;var job=new D{["work"]=work,["result"]=result,["generation"]=generation,["kind"]=_discovery_pending?"discovery":"mesh"};Func<D> execute;
            if(_discovery_pending){_discovery_pending=false;var region=_region;execute=()=>work.discover(region);}
            else if(_surface_batch!=null&&_surface_batch.pending())
            {
                var part=_surface_batch.take();job["kind"]="portal";job["batch_id"]=part["batch_id"];job["part"]=part["part"];
                var bundle=_bundle;var columns=_surface_batch.request["columns"].AsGodotDictionary();var parents=_surface_batch.request["snapshot"].AsGodotDictionary()["records"].AsGodotArray();var owned=part["columns"].AsGodotDictionary();bool ground=part["part"].AsInt32()==0;
                execute=()=>work.portal(bundle,columns,parents,owned,ground);
            }
            else if(_pending.Count>0&&_bundle.Count>0)
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
            var job=_jobs[task].AsGodotDictionary();_jobs.Remove(task);_idle.Add(job["work"]);string kind=job["kind"].AsString();long generation=job["generation"].AsInt64();
            if(kind=="mesh"&&Get(_inflight,job["key"].AsVector3I(),-1).AsInt64()==generation)_inflight.Remove(job["key"]);
            var results=job["result"].AsGodotArray();if(generation!=_generation||results.Count==0)continue;var data=results[0].AsGodotDictionary();
            if(kind=="discovery")
            {if(data.ContainsKey("error")){last_error=data["error"].AsString();continue;}_bundle=data;_last_plan=Vector3.Inf;_biome_debug=_regions.description(Get(data,"cave_biome_regions",new D()).AsGodotDictionary());}
            else if(kind=="portal")
            {
                if(_surface_batch==null||job["batch_id"].AsInt64()!=_surface_batch.id)continue;
                _surface_batch.accept(job["batch_id"].AsInt64(),generation,job["part"].AsInt32(),data);
                if(_surface_batch.failure.Length>0){surface_status=_surface_batch.failure;_surface_batch=null;_surface_build_pending=false;continue;}
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
    {if(point.IsFinite()&&(_region!=Region(point)||!_last_plan.IsFinite()||_last_plan.DistanceTo(point)>=16))return false;if(_bundle.Count==0||_discovery_pending)return false;foreach(var key in _wanted.Keys)if(!_cells.ContainsKey(key))return false;return true;}
    public bool traversal_ready(Vector3 point)
    {
        if(Flag("seal_stream_frontiers")){if(!_traversal.ready(point,_cells,_wanted))return false;}else if(!_cells.ContainsKey(new Vector3I((int)Math.Floor(point.X/64.0),(int)Math.Floor(point.Y/64.0),(int)Math.Floor(point.Z/64.0))))return false;
        foreach(var value in Get(_bundle,"entrances",new A()).AsGodotArray()){var entrance=value.AsGodotDictionary();if(!entrance_needed(entrance,point))continue;if(_surface_transaction==null||!_surface_transaction.committed)return false;foreach(var column in entrance["columns"].AsGodotArray())if(!_surface_columns.ContainsKey(column))return false;}return true;
    }
    public bool entrance_needed(D entrance,Vector3 point)
    {var mouth=entrance["point"].AsVector3();return point.Y>=Get(entrance,"minimum_exposed_floor",mouth.Y).AsDouble()-Number("main_route_height_metres")*2&&point.DistanceTo(mouth)<=Number("preload_radius_metres");}
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
        foreach(var controller in _biome_runtime_controllers)controller.AsGodotObject().Call("release");_biome_runtime_controllers.Clear();foreach(var task in _jobs.Keys)WorkerThreadPool.WaitForTaskCompletion(task.AsInt64());
        _jobs.Clear();_ready.Clear();_idle.Clear();_surface_batch=null;_surface_request=new();_surface_build_pending=false;_surface_transaction?.reset();clear_surface_staging();_frontiers.synchronize(_cells,false);
        foreach(var value in _cells.Values){var node=value.As<Node3D>();if(Valid(node))node!.GetNode<StaticBody3D>("CaveCollision").CollisionLayer=0;}_cells.Clear();
    }
    public A active_parent_nodes()=>new(host!.Get("_active_chunks").AsGodotDictionary().Values);
    public Godot.Collections.Array<Rect2> detail_rectangles(){var result=new Godot.Collections.Array<Rect2>();foreach(var key in _detail_columns.Keys)result.Add(new Rect2((Vector2)key.AsVector2I()*64,Vector2.One*64));return result;}
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
        if(_surface_transaction==null)return true;if(_renderer.matches(_surface_snapshot,nodes,_surface_columns))return true;
        if(surface_distance(_protected_point)>96||Teleport){_close_surface_on_partition=true;return true;}
        _rebuild_nodes=nodes;_rebuild_columns=_surface_columns.Duplicate();
        if(_surface_prepared==null||!_surface_prepared.ready_to_commit())return false;
        var request=_surface_staging["request"].AsGodotDictionary();return _renderer.matches(request["snapshot"].AsGodotDictionary(),nodes,request["columns"].AsGodotDictionary());
    }
    public void partition_committed()
    {
        if(_close_surface_on_partition){close_surface();_close_surface_on_partition=false;_rebuild_nodes=new();_rebuild_columns=new();}
        if(_surface_prepared!=null&&_surface_prepared.ready_to_commit())
        {
            if(_surface_prepared.commit())adopt_surface(_surface_prepared,_surface_staging["request"].AsGodotDictionary()["snapshot"].AsGodotDictionary(),_surface_staging["data"].AsGodotDictionary());
            _surface_prepared=null;_surface_staging=new();_rebuild_nodes=new();_rebuild_columns=new();
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
        _surface_transaction?.reset();foreach(var key in _surface_owned.Keys){var node=_cells.ContainsKey(key)?_cells[key].As<Node>():null;if(Valid(node))node!.QueueFree();_cells.Remove(key);}
        _surface_transaction=null;_surface_owned.Clear();_surface_columns.Clear();_surface_snapshot=new();_last_plan=Vector3.Inf;_frontiers_dirty=true;refresh_frontiers();
    }
    public D nearby_columns(Vector3 point)
    {
        var columns=new D();var nearby=Get(_bundle,"entrances",new A()).AsGodotArray().Select((v,i)=>(Data:v.AsGodotDictionary(),Ordinal:i)).ToList();
        var p=new Vector2(point.X,point.Z);
        nearby.Sort((a,b)=>{var ap=a.Data["point"].AsVector3();var bp=b.Data["point"].AsVector3();int order=new Vector2(ap.X,ap.Z).DistanceSquaredTo(p).CompareTo(new Vector2(bp.X,bp.Z).DistanceSquaredTo(p));return order!=0?order:a.Ordinal.CompareTo(b.Ordinal);});
        foreach(var item in nearby){if(!entrance_needed(item.Data,point))continue;var complete=columns.Duplicate();foreach(var key in item.Data["columns"].AsGodotArray())complete[key]=true;if(complete.Count<=64)columns=complete;}return columns;
    }
    public void service_surface(Vector3 point)
    {
        _surface_interest=point;
        if(_surface_staging.Count>0)
        {
            var request=_surface_staging["request"].AsGodotDictionary();var snapshot=request["snapshot"].AsGodotDictionary();var columns=request["columns"].AsGodotDictionary();var desired=_rebuild_nodes.Count>0?_rebuild_nodes:active_parent_nodes();
            if(!_renderer.matches(snapshot,desired,columns)){clear_surface_staging();surface_status="surface parents changed; retaining old entrance";return;}
            var remaining=_surface_staging["remaining"].AsGodotArray();
            if(remaining.Count>0)
            {
                var data=remaining[0].AsGodotDictionary();remaining.RemoveAt(0);var interior=material_for(data["key"].AsVector3I(),Get(data,"biome_ids",new A()).AsGodotArray());
                if(interior==null){clear_surface_staging();surface_status="Cave biome material rejected";return;}
                int style=interior.GetMeta("cave_style",0).AsInt32();var built=_renderer.node(data,snapshot["sources"].AsGodotDictionary(),interior,style,HostFlag("terrain_shadows"),Flag("specialize_insect_palette"));
                if(!built["valid"].AsBool()){clear_surface_staging();surface_status=built["reason"].AsString();return;}
                var node=built["node"].As<Node>();if(node!=null){AddChild(node);_surface_staging["nodes"].AsGodotArray().Add(node);}_renderer.release_uploaded_data(data);return;
            }
            if(_surface_prepared==null)
            {
                var transaction=new CaveSurfaceTransaction{collision_enabled=HostFlag("terrain_collision_enabled"),common_vertex_projection=Flag("common_vertex_projection")};var nodes=new A();
                foreach(var value in snapshot["sources"].AsGodotDictionary().Values)nodes.Add(value.AsGodotDictionary()["node"]);
                if(!transaction.prepare(nodes,_surface_staging["nodes"].AsGodotArray(),columns,new Vector2(point.X,point.Z),_surface_transaction,_surface_staging["data"].AsGodotDictionary()["ground"].AsGodotDictionary())){clear_surface_staging();surface_status="surface commit preparation rejected";return;}
                _surface_prepared=transaction;
            }
            if(_rebuild_nodes.Count==0&&!Teleport&&_surface_prepared.ready_to_commit())
            {if(_surface_prepared.commit())adopt_surface(_surface_prepared,snapshot,_surface_staging["data"].AsGodotDictionary());_surface_prepared=null;_surface_staging=new();}return;
        }
        long now=(long)Time.GetTicksUsec();if(_bundle.Count==0||_surface_build_pending||_surface_request.Count>0||now-_surface_poll_usec<250000)return;
        _surface_poll_usec=now;var wantedColumns=nearby_columns(point);if(_rebuild_nodes.Count>0)wantedColumns=_rebuild_columns.Duplicate();
        if(wantedColumns.Count==0)
        {
            if(_surface_transaction!=null&&_rebuild_nodes.Count==0)
            {
                if(Teleport){reserve_detail(new D());surface_status="active retained entrance";return;}
                if(surface_distance(_protected_point)<=96){surface_status="active retained entrance";return;}close_surface();
            }
            reserve_detail(new D());surface_status="no nearby admitted entrance";return;
        }
        reserve_detail(wantedColumns);var parents=_rebuild_nodes.Count>0?_rebuild_nodes:active_parent_nodes();
        if(_surface_transaction!=null&&wantedColumns.RecursiveEqual(_surface_columns)&&_renderer.matches(_surface_snapshot,parents,wantedColumns)){surface_status="active";_rebuild_nodes=new();return;}
        var capture=_renderer.capture(parents,wantedColumns);if(!capture["valid"].AsBool()){surface_status=capture["reason"].AsString();return;}
        _surface_request=new D{["snapshot"]=capture,["columns"]=wantedColumns};surface_status="building complete hidden entrance";
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
        _surface_transaction=transaction;_surface_columns=data["columns"].AsGodotDictionary().Duplicate();_surface_snapshot=snapshot;_last_plan=Vector3.Inf;surface_status="active";_frontiers_dirty=true;refresh_frontiers();
    }
    public A surface_materials()
    {
        var result=new A();if(_surface_transaction==null)return result;foreach(var value in _surface_transaction.materials())result.Add(value);
        foreach(var value in _surface_transaction.patches){var node=value.As<MeshInstance3D>();if(Valid(node))for(int i=0;i<node.Mesh.GetSurfaceCount();i++)result.Add(node.Mesh.SurfaceGetMaterial(i));}return result;
    }
    public string debug_text()=>$"Shared caves: {_cells.Count}/{_wanted.Count} cells, {_jobs.Count} jobs; entrance {surface_status}\n{_biome_debug}";
}
