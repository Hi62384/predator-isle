using Godot;
using System;
using System.Diagnostics;
using PredatorIsle.Terrain;
using PredatorIsle.Rendering;
using PredatorIsle.Player;
using PredatorIsle.Caves;
using GDictionary = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Runs the preserved planner and the C# port against identical moving cuts.</summary>
public partial class MigrationChecks : Node
{
    private int _checks;
    private string _mode = "general";
    public override async void _Ready()
    {
        try
        {
            if (Array.IndexOf(OS.GetCmdlineUserArgs(), "cave-smoothing") >= 0)
            {
                CaveMesherOptimizationChecks.RunSmoothing(Require);
                GD.Print($"Passed {_checks} cave smoothing checks");
                GetTree().Quit();
                return;
            }
            if (Array.IndexOf(OS.GetCmdlineUserArgs(),"bake-startup-caves")>=0)
            {
                var world=GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
                AddChild(world);
                var terrain=world.GetNode<ChunkTerrain>("Terrain");
                using var work=terrain.GetNode<CaveStreamer>("CaveStreaming").worker()!;
                string signature=work.MapSignature();
                for(int z=-1;z<=1;z++) for(int x=-1;x<=1;x++)
                {
                    var cell=new Vector2I(x,z);
                    using var resource=new Resource();
                    var map=work.BuildLocalMap(cell);
                    resource.SetMeta("map",GD.VarToBytes(map));
                    if(cell==Vector2I.Zero) work.BakeEntranceGeometry(map,signature);
                    resource.SetMeta("signature",signature);
                    Require(ResourceSaver.Save(resource,CaveWorkload.StartupMapPath(cell),ResourceSaver.SaverFlags.Compress)==Error.Ok,"Saving startup cave map failed");
                }
                GetTree().Quit();return;
            }
            if (Array.IndexOf(OS.GetCmdlineUserArgs(),"tributary-layouts") >= 0 ||
                Array.IndexOf(OS.GetCmdlineUserArgs(),"cave-mouths-only") >= 0 ||
                Array.IndexOf(OS.GetCmdlineUserArgs(),"cave-procedural-only") >= 0)
            {
                _mode="cave-procedural";
                CaveProceduralChecks.Run(Require);
                CaveFrontierChecks.Run(this,Require);
                MigrationEvidence.Write(_mode,_checks,true,CaveProceduralChecks.Measurements);
                GD.Print($"C# procedural cave checks passed: {_checks}");
                await Finish();return;
            }
            if (Array.IndexOf(OS.GetCmdlineUserArgs(),"distance-key") >= 0)
            {
                var hud = new CanvasLayer { Name = "Interface" };
                AddChild(hud);
                var label = new Label { Name = "RayDistance" };
                hud.AddChild(label);
                var probeCamera = new FreeCamera();
                AddChild(probeCamera);
                probeCamera.Rotation = Vector3.Zero;
                var wall = new StaticBody3D { Position = new Vector3(0,0,-11) };
                wall.AddChild(new CollisionShape3D { Shape = new BoxShape3D { Size = new Vector3(4,4,2) } });
                AddChild(wall);
                async System.Threading.Tasks.Task PressV()
                {
                    var key = new InputEventKey { PhysicalKeycode = Key.V, Pressed = true };
                    probeCamera._UnhandledInput(key);
                    for(int i=0;i<3;i++) await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);
                }
                await PressV();
                Require(label.Text == $"Distance  {10:0.00} m","Expected 10 m wall hit, got "+label.Text);
                probeCamera.RotateY(Mathf.Pi);
                await PressV();
                Require(label.Text == "No collision in range","Miss retained the previous hit");
                GD.Print("V measured the wall at 10.00 m and reported a miss facing away");
                await Finish();return;
            }
            if(Array.IndexOf(OS.GetCmdlineUserArgs(),"airborne-entrance")>=0)
            {
                using var stream=new CaveStreamer{configuration=GD.Load<Resource>("res://config/caves/cave_settings.tres")};
                var mouth=new Vector3(380,9,935);
                var entrance=new GDictionary{["point"]=mouth};
                Require(stream.entrance_needed(entrance,mouth+Vector3.Up*1500),"Flight altitude blocked surface entrance");
                Require(!stream.entrance_needed(entrance,mouth+Vector3.Right*1000),"Distant mouth requested");
                await Finish();return;
            }
            var flightArg=Array.Find(OS.GetCmdlineUserArgs(),arg=>arg.StartsWith("interior-flight="));
            if(flightArg!=null){
                int seed=int.Parse(flightArg.Split('=')[1]);
                var world=GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
                var terrain=world.GetNode<ChunkTerrain>("Terrain");
                terrain.world_seed=seed;
                AddChild(world);
                var caves=terrain.GetNode<CaveStreamer>("CaveStreaming");
                var flightCamera=world.GetNode<Camera3D>("FreeCamera");
                bool gameLighting=Array.IndexOf(OS.GetCmdlineUserArgs(),"game-lighting")>=0;
                if(!gameLighting)flightCamera.AddChild(new OmniLight3D {OmniRange=35,LightEnergy=2});
                using var work=caves.worker()!;
                GDictionary map=new();
                for(int x=1;x<8;x++){
                    map=work.BuildLocalMap(new Vector2I(x,0));
                    if(map["entrances"].AsGodotArray().Count>0)break;
                }
                GD.Print("Buried split-and-rejoin passages: "+map["regions"].AsGodotArray()[0].AsGodotDictionary()["fracture_passages"].AsGodotArray().Count);
                if(Array.IndexOf(OS.GetCmdlineUserArgs(),"vault-flight")>=0){
                    var nodes=map["regions"].AsGodotArray()[0].AsGodotDictionary()["nodes"].AsGodotArray();
                    var center=nodes[0].AsGodotDictionary()["point"].AsVector3();
                    foreach(var raw in nodes){
                        var n=raw.AsGodotDictionary();
                        if(n["id"].AsString().EndsWith(":1:0")){center=n["point"].AsVector3();break;}
                    }
                    float angle=Mathf.Sin(center.X*.031f+center.Z*.013f)*Mathf.Pi;
                    var across=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
                    var forward=new Vector3(-across.Z,0,across.X);
                    Vector3 Spot(float x,float y,float z)=>center+x*across+y*Vector3.Up+z*forward;
                    if(!gameLighting)foreach(var position in new[]{Spot(-17,5,8),Spot(16,-7,-14),Spot(-3,13,-3)}){
                        world.AddChild(new OmniLight3D{Position=position,OmniRange=64,OmniAttenuation=.5f,LightEnergy=1.7f});
                    }
                    var poses=new[]{Spot(-12,-10,-30),Spot(12,-11,15),Spot(20,10,24)};
                    var aims=new[]{Spot(3,-2,3),Spot(-7,-1,-6),Spot(-14,-4,-12)};
                    flightCamera.GlobalPosition=poses[0];flightCamera.LookAt(aims[0]);
                    var space=flightCamera.GetWorld3D().DirectSpaceState;
                    var deadline=Time.GetTicksMsec()+120000;
                    bool Hit(Vector3 a,Vector3 b)=>space.IntersectRay(PhysicsRayQueryParameters3D.Create(a,b)).Count>0;
                    bool BridgeSupportsCrossing(){
                        for(int x=-18;x<=18;x+=3){
                            float z=4*Mathf.Sin(x*.067f+center.X*.043f)+2.5f*Mathf.Sin(x*.12f+center.X*.043f*.6f);
                            if(!Hit(Spot(x,7,z),Spot(x,-5,z)))return false;
                        }
                        return true;
                    }
                    while(!BridgeSupportsCrossing() ||
                          !Hit(poses[0],poses[0]+Vector3.Down*25) || !Hit(poses[1],poses[1]+Vector3.Down*25)){
                        Require(Time.GetTicksMsec()<deadline,"Chamber bridge or lower floor failed to stream at "+center+" "+caves.debug_text());
                        await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);
                    }
                    for(int n=0;n<3;n++){
                        var startPosition=flightCamera.GlobalPosition;
                        for(int frame=1;frame<=90;frame++){
                            flightCamera.GlobalPosition=startPosition.Lerp(poses[n],frame/90f);
                            flightCamera.LookAt(aims[n]);
                            await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                        }
                        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                        if(gameLighting)Require(flightCamera.GetNodeOrNull<OmniLight3D>("CaveLight")==null,
                            "Cave visibility still depends on a camera light switch");
                        var pathName=System.IO.Path.Combine(System.IO.Path.GetTempPath(),$"vault-{seed}-{n}.png");
                        Require(GetViewport().GetTexture().GetImage().SavePng(pathName)==Error.Ok,"Capture failed");
                        GD.Print($"Vault {seed} at {center} view {n}");
                    }
                    await Finish();return;
                }
                var entrance=map["entrances"].AsGodotArray()[0].AsGodotDictionary();
                var path=entrance["access"].AsGodotDictionary()["points"].AsVector3Array();
                // Follow the entrance through its buried junction into an adjoining passage.
                var route=new System.Collections.Generic.List<Vector3>(path);
                var region=map["regions"].AsGodotArray()[0].AsGodotDictionary();
                string destination=entrance["access"].AsGodotDictionary()["to"].AsString();
                foreach(var item in region["edges"].AsGodotArray()){
                    var next=item.AsGodotDictionary();
                    if(next["entrance"].AsBool() || next["from"].AsString()!=destination)continue;
                    var stations=next["points"].AsVector3Array();
                    if(stations.Length<2 || stations[0].DistanceTo(route[^1])>1)continue;
                    route.AddRange(stations[1..Math.Min(stations.Length,40)]);
                    break;
                }
                path=route.ToArray();
                var columns=entrance["columns"].AsGodotDictionary();
                if (Array.IndexOf(OS.GetCmdlineUserArgs(), "exit-from-below") >= 0)
                {
                    // Start in the surveyed tunnel without visiting this surface or opening the cut first.
                    var underground = Array.FindIndex(path, p =>
                        path[0].DistanceTo(p) >= 30 && terrain.get_height_at(p) - p.Y >= 10);
                    Require(underground > 0, "Exit fixture has no approach below terrain");
                    flightCamera.GlobalPosition = path[underground] + Vector3.Up * 2;
                    flightCamera.LookAt(path[underground-1] + Vector3.Up * 2);
                    ulong entered = Time.GetTicksMsec();
                    while (caves._surface_transaction?.committed != true ||
                           !System.Linq.Enumerable.All(columns.Keys, key => caves._surface_columns.ContainsKey(key)))
                    {
                        Require(caves.underground_interest(flightCamera.GlobalPosition), "Exit test left the cave before publication");
                        Require(Time.GetTicksMsec() - entered < 15000, "Exit stayed sealed below ground: " + caves.surface_status);
                        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                    }
                    GD.Print($"Seed {seed}: Exit {path[0]} opened from below in {Time.GetTicksMsec()-entered} ms at {flightCamera.GlobalPosition}");
                    await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
                    var space = flightCamera.GetWorld3D().DirectSpaceState;
                    var interior = path[underground] + Vector3.Up * 2;
                    using var floorProbe = PhysicsRayQueryParameters3D.Create(interior, interior + Vector3.Down * 12);
                    Require(space.IntersectRay(floorProbe).Count > 0, "Published exit has no tunnel floor");
                    Vector3 outside = path[0] + Vector3.Up * 4;
                    for (int i = underground; i >= 0; i--)
                    {
                        Vector3 target = i > 0 ? path[i - 1] + Vector3.Up * 2 : outside;
                        var from = flightCamera.GlobalPosition;
                        if (new Vector2(from.X - target.X, from.Z - target.Z).LengthSquared() > .001f)
                            flightCamera.LookAt(target);
                        for (int frame = 1; frame <= 6; frame++)
                        {
                            flightCamera.GlobalPosition = from.Lerp(target, frame / 6f);
                            Require(caves._surface_transaction?.committed == true &&
                                System.Linq.Enumerable.All(columns.Keys, key => caves._surface_columns.ContainsKey(key)),
                                "Exit closed again during ascent");
                            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                        }
                    }
                    if (DisplayServer.GetName() != "headless")
                    {
                        flightCamera.LookAt(path[underground] + Vector3.Up * 2);
                        // Let the terrain around the mouth finish its normal startup pass
                        // before capturing the surface. The timing above ends at publication.
                        await ToSignal(GetTree().CreateTimer(3), SceneTreeTimer.SignalName.Timeout);
                        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                        GetViewport().GetTexture().GetImage().SavePng(
                            System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"cave-exit-{seed}.png"));
                    }
                    await Finish();return;
                }
                bool flyIn=Array.IndexOf(OS.GetCmdlineUserArgs(),"approach")>=0;
                flightCamera.GlobalPosition=path[0]+new Vector3(0,flyIn?65:12,flyIn?450:2);
                flightCamera.LookAt(path[0]);
                ulong start=Time.GetTicksMsec(),ground=0;
                var tile=terrain.world_to_chunk(path[0]);
                while(caves._surface_transaction?.committed!=true || !System.Linq.Enumerable.All(columns.Keys,key=>caves._surface_columns.ContainsKey(key))){
                    await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                    if(flyIn){
                        float remaining=Math.Max(0,450-(Time.GetTicksMsec()-start)*.035f);
                        flightCamera.GlobalPosition=path[0]+new Vector3(0,65,remaining+2);
                        flightCamera.LookAt(path[0]);
                    }
                    if(ground==0 && terrain.HasVisibleGround(tile))ground=Time.GetTicksMsec();
                    Require(Time.GetTicksMsec()-start<90000,"Entrance timeout "+caves.surface_status+" "+caves.debug_text()+" "+caves.last_error+" "+caves.discovery_progress+" region="+caves._region+" mouth="+path[0]+" owner="+caves._surface_columns+" expected="+columns);
                }
                ulong open=Time.GetTicksMsec();
                GD.Print($"Seed {seed}, entrance {path[0]} open {open-start} ms, terrain-to-opening {(ground==0?0:open-ground)} ms");
                GD.Print($"Remaining approach distance {flightCamera.GlobalPosition.Z-path[0].Z:0} m");
                Require(ground==0 || open-ground<=3000,"Entrance appeared late relative to visible ground");
                int samples=0;
                for(int i=1;i<path.Length;i++){
                    var from=path[i-1]+Vector3.Up*2;
                    var to=path[i]+Vector3.Up*2;
                    flightCamera.LookAt(to);
                    for(int j=1;j<=3;j++){
                        flightCamera.GlobalPosition=from.Lerp(to,j/3f);
                        await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                    }
                    if(i<3 || (i!=path.Length/2 && i!=path.Length-1 && i!=path.Length/3))continue;
                    ulong deadline=Time.GetTicksMsec()+45000;
                    var space=flightCamera.GetWorld3D().DirectSpaceState;
                    // A junction can open onto a vault with a floor well below route height.
                    using var floorProbe=PhysicsRayQueryParameters3D.Create(to,to+Vector3.Down*32);
                    while(space.IntersectRay(floorProbe).Count==0){
                        Require(Time.GetTicksMsec()<deadline,"Missing floor at "+to);
                        await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);
                    }
                    await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                    var file=System.IO.Path.Combine(System.IO.Path.GetTempPath(),$"cave-flight-{seed}-{samples}.png");
                    GetViewport().GetTexture().GetImage().SavePng(file);
                    GD.Print($"Flight sample {samples++}: {to}");
                }
                Require(samples>=2,"Flight did not traverse passage");
                await Finish();return;
            }
            bool approach = Array.IndexOf(OS.GetCmdlineUserArgs(),"fly-to-beach-mouth")>=0;
            if(approach || Array.IndexOf(OS.GetCmdlineUserArgs(),"live-beach-mouth")>=0)
            {
                bool fromBootstrap = Array.IndexOf(OS.GetCmdlineUserArgs(), "from-world-startup") >= 0;
                ulong boot = Time.GetTicksMsec();
                if (fromBootstrap)
                {
                    // Exercise the same shader preparation as the playable game's startup scene.
                    await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                    TerrainWorkerScripts.Prepare();
                    await TerrainShaderPreparation.Prepare(GetTree(), GD.Load<Resource>("res://config/world/terrain_settings.tres"));
                    GD.Print($"World shader preparation: {Time.GetTicksMsec() - boot} ms");
                }
                ulong start = Time.GetTicksMsec();
                var world=GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
                AddChild(world);
                var terrain=world.GetNode<ChunkTerrain>("Terrain");
                var caves=terrain.GetNode<CaveStreamer>("CaveStreaming");
                var beachCamera=world.GetNode<Node3D>("FreeCamera");
                beachCamera.GlobalPosition=new Vector3(51,85,378);
                beachCamera.LookAt(new Vector3(49.65f,25.48f,371.20f));
                ulong firstOpen=0, firstFineGround=0, firstGround=0;
                ulong next=Time.GetTicksMsec();
                if (approach) beachCamera.GlobalPosition = new Vector3(51,105,1070);
                while(Time.GetTicksMsec()-start<180000)
                {
                    await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                    if (approach)
                    {
                        float remaining = Math.Max(0,700 - (Time.GetTicksMsec()-start)*.035f);
                        beachCamera.GlobalPosition = new Vector3(51,105,370+remaining);
                        beachCamera.LookAt(new Vector3(49.65f,25.48f,371.20f));
                    }
                    bool bakedVisible=caves.InitialEntranceVisible(new Vector2I(0,5));
                    if(firstGround==0 && (bakedVisible || terrain.HasVisibleGround(terrain.world_to_chunk(new Vector3(50,26,371))))) firstGround=Time.GetTicksMsec();
                    if (firstFineGround==0 && terrain.HasVisibleFineCell(terrain.world_to_chunk(new Vector3(50,26,371))))
                        firstFineGround=Time.GetTicksMsec();
                    if(bakedVisible || caves._surface_transaction?.committed==true && caves._surface_columns.ContainsKey(new Vector2I(0,5)))
                    {
                        if (firstOpen == 0)
                        {
                        firstOpen = Time.GetTicksMsec();
                        GD.Print($"Beach mouth visible (initial surface={bakedVisible}) at {Time.GetTicksMsec()-start} ms, distance {Math.Abs(beachCamera.GlobalPosition.Z-370):0} m");
                        if (fromBootstrap)
                        {
                            var cut = caves._surface_transaction!;
                            var parentShader = terrain._terrain_material.Shader;
                            bool shared = false;
                            foreach (var patch in cut.patches)
                            {
                                var mesh = patch.As<MeshInstance3D>().Mesh;
                                for (int i = 0; i < mesh.GetSurfaceCount(); i++)
                                {
                                    if (mesh.SurfaceGetMaterial(i) is not ShaderMaterial material ||
                                        material.GetShaderParameter("cave_surface_payload").VariantType == Variant.Type.Nil) continue;
                                    Require(material.Shader == parentShader, "Entrance surface compiled its own terrain shader");
                                    shared = true;
                                }
                            }
                            Require(shared, "No terrain-facing cave surface was rendered");
                            GD.Print($"Beach uses the prepared terrain shader. Total elapsed from boot: {firstOpen - boot} ms");
                        }
                        if (approach) Require(beachCamera.GlobalPosition.Z > 405,"Entrance missed the approach deadline");
                        }
                        if (Time.GetTicksMsec()-start < (approach ? 20500UL : 32000UL)) continue;
                        GD.Print($"First visible fine beach tile: {(firstFineGround==0 ? -1L : (long)(firstFineGround-start))} ms; mouth: {firstOpen-start} ms");
                        GD.Print($"First ground at any visible layer {(long)firstGround-(long)start} ms, delay to opening {(long)firstOpen-(long)firstGround} ms");
                        Require(firstGround!=0 && (long)firstOpen-(long)firstGround<=3000,"Mouth appeared over three seconds after terrain");
                        Require(firstOpen-start<=3000,"Cold entrance exceeded three seconds");
                        GD.Print($"Cave border segments in rendered cut {terrain.CaveBorderSegments}");
                        Require(terrain.CaveBorderSegments>0,"Cave perimeter missing from seam stitch");
                        Require(firstFineGround!=0 && firstOpen<=firstFineGround,"Fine beach was visible before cave cut");
                        if (DisplayServer.GetName()!="headless")
                        {
                            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                            GetViewport().GetTexture().GetImage().SavePng(System.IO.Path.Combine(System.IO.Path.GetTempPath(),"predator-beach-mouth.png"));
                        }
                        await Finish();return;
                    }
                    if (firstOpen != 0) throw new Exception("Beach entrance disappeared during approach");
                    if(Time.GetTicksMsec()>=next)
                    {GD.Print($"Beach at {Time.GetTicksMsec()-start} ms, ground {terrain.get_height_at(beachCamera.GlobalPosition)}, {caves.surface_status}, {caves.discovery_progress}, {caves.last_error}, active {terrain._active_chunks.Count}, wanted {terrain._wanted.Count}, {terrain.last_error}, columns {caves._detail_columns.Count}, batch {caves._surface_batch?.cursor}/{caves._surface_batch?.received.Count}");next=Time.GetTicksMsec()+250;}
                }
                throw new Exception("Beach entrance failed to open: "+caves.surface_status+" "+caves.last_error);
            }
            if(Array.IndexOf(OS.GetCmdlineUserArgs(),"live-underground")>=0)
            {
                var world=GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
                AddChild(world);
                var terrain=world.GetNode<ChunkTerrain>("Terrain");
                var caveCamera=world.GetNode<Node3D>("FreeCamera");
                var caves=terrain.GetNode<CaveStreamer>("CaveStreaming");
                var key=new Vector3I(8,-1,9);
                caveCamera.GlobalPosition=(Vector3)key*64+Vector3.One*32;
                ulong start=Time.GetTicksMsec();
                while(Time.GetTicksMsec()-start<120000)
                {
                    await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                    if(caves._cells.TryGetValue(key,out var value)&&value.AsGodotObject() is MeshInstance3D node&&node.Mesh!=null&&node.IsVisibleInTree())
                    {
                        GD.Print($"Live underground cell {key} visible after {Time.GetTicksMsec()-start} ms");
                        await Finish();return;
                    }
                }
                throw new Exception("Underground cell timed out: "+caves.debug_text()+" "+caves.discovery_progress+" "+caves.last_error);
            }
            if(Array.IndexOf(OS.GetCmdlineUserArgs(),"world-cave-mouths")>=0)
            {
                using var work=new PredatorIsle.Caves.CaveWorkload();
                Require(work.configure(GD.Load<Resource>("res://config/world/terrain_settings.tres"),
                    GD.Load<Resource>("res://config/caves/cave_settings.tres"),73921,0),"Game cave configuration rejected");
                var position=Vector2I.Zero;
                var region=work.network.region(position);
                Require(region["valid"].AsBool(),"No generated cave network in the origin region");
                var bundle=new Godot.Collections.Dictionary{["cell"]=position,["regions"]=new Godot.Collections.Array{region},["connections"]=new Godot.Collections.Array()};
                Require(work.use_bundle(bundle),"Generated network did not compile");
                int mouths=0;bool underground=false;
                foreach(var item in region["edges"].AsGodotArray())
                {
                    var edge=item.AsGodotDictionary();
                    if(!edge["entrance"].AsBool())continue;
                    var points=edge["points"].AsVector3Array();
                    var entry=new Godot.Collections.Dictionary{["point"]=points[0],["access"]=edge};
                    int columns=work.exposed_columns(entry).Count;
                    if(columns is 0 or >64)continue;
                    mouths++;
                    var inside=points[^1]+Vector3.Up*2;
                    var key=(Vector3I)(inside/64).Floor();
                    if (!underground)
                    {
                        var mesh=work.build_cell(key);
                        underground=mesh["valid"].AsBool() && mesh["arrays"].AsGodotArray().Count>0;
                    }
                    GD.Print($"Game terrain entrance {points[0]}, underground cell {key}");

                }
                GD.Print($"Streamable entrances in origin region: {mouths}");
                Require(mouths<=4,"Excessive surface entrance density");
                Require(mouths==0 || underground,"Admitted entrance has no underground geometry");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"blob-only")){_mode="blob";BlobRuntimeChecks.Run(this,Require);MigrationEvidence.Write(_mode,_checks,true);GD.Print($"C# blob runtime checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"rings-only")){_mode="rings";TerrainRingChecks.Run(Require);MigrationEvidence.Write(_mode,_checks,true);GD.Print($"C# ring checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"terrain-performance-only")){_mode="terrain-performance";TerrainGenerationPerformanceChecks.Run(Require);MigrationEvidence.Write(_mode,_checks,true,TerrainGenerationPerformanceChecks.Measurements);GD.Print($"C# terrain generation performance checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"sampling-only")){_mode="sampling";TerrainSamplingChecks.Run(Require);TerrainFeatureOptimizationChecks.Run(Require);TerrainTrailBoundsChecks.Run(Require);TerrainHeightFilterChecks.Run(Require);
                var measurements=TerrainSamplingBenchmark.Run();measurements["height_filter"]=TerrainHeightFilterChecks.Measurements;MigrationEvidence.Write(_mode,_checks,true,measurements);GD.Print($"C# terrain sampling checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"sampling-benchmark-only")){_mode="sampling-benchmark";MigrationEvidence.Write(_mode,_checks,true,TerrainSamplingBenchmark.Run());GD.Print("C# terrain sampling benchmark checks passed");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-vertex-only"))
            {
                _mode="gpu-vertex";
                await TerrainGpuSamplerChecks.RunVertex(this,Require);
                MigrationEvidence.Write(_mode,_checks,true,TerrainGpuSamplerChecks.Measurements);
                GD.Print($"C# GPU vertex-bake checks passed: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-extension-only"))
            {
                _mode="gpu-extension";
                await TerrainGpuExtensionAtlasRenderedChecks.Run(this,Require);
                await TerrainGpuGridControlRenderedChecks.Run(this,Require);
                await TerrainGpuTrailRenderedChecks.Run(this,Require);
                var results=TerrainGpuExtensionAtlasRenderedChecks.Measurements;
                results["grid_control_mask"]=TerrainGpuGridControlRenderedChecks.Measurements;
                results["trail_bounds"]=TerrainGpuTrailRenderedChecks.Measurements;
                MigrationEvidence.Write(_mode,_checks,true,results);
                GD.Print($"C# GPU extension atlas rendered parity checks passed: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-materials-only"))
            {
                _mode="gpu-materials";
                await TerrainGpuMaterialSamplingChecks.Run(this,Require);
                MigrationEvidence.Write(_mode,_checks,true,TerrainGpuMaterialSamplingChecks.Measurements);
                GD.Print($"C# all-biome GPU material checks passed: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-caves-only"))
            {
                _mode="gpu-caves";
                await CaveGpuPayloadRenderedChecks.Run(this,Require);
                MigrationEvidence.Write(_mode,_checks,true,CaveGpuPayloadRenderedChecks.Measurements);
                GD.Print($"C# GPU cave payload checks passed: {_checks}");
                await Finish();return;
            }
            var selectedCaveScene=System.Linq.Enumerable.FirstOrDefault(OS.GetCmdlineUserArgs(),
                arg=>arg.StartsWith("gpu-cave-scene-",StringComparison.Ordinal)&&arg.EndsWith("-only",StringComparison.Ordinal));
            if(selectedCaveScene is not null)
            {
                _mode=selectedCaveScene[..^"-only".Length];
                Require(int.TryParse(selectedCaveScene["gpu-cave-scene-".Length..^"-only".Length],out int caveSceneIndex)
                    &&caveSceneIndex is >=0 and <8,"Unknown full cave shader case");
                var measurements=await CaveGpuMaterialSceneChecks.Run(this,Require,caveSceneIndex);
                MigrationEvidence.Write(_mode,_checks,true,measurements);
                GD.Print($"C# complete cave shader scene {caveSceneIndex} checks passed: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"cave-payload-only"))
            {
                _mode="cave-payload";CaveGpuPayloadChecks.Run(Require);
                MigrationEvidence.Write(_mode,_checks,true,CaveGpuPayloadChecks.Measurements);
                GD.Print($"C# compact cave payload checks passed: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-sampler-only")){_mode="gpu-sampler";await TerrainGpuSamplerChecks.Run(this,Require);MigrationEvidence.Write(_mode,_checks,true,TerrainGpuSamplerChecks.Measurements);GD.Print($"C# GPU terrain sampler checks passed: {_checks}");await Finish();return;}
            var selectedBiome=System.Linq.Enumerable.FirstOrDefault(OS.GetCmdlineUserArgs(),
                arg=>arg.StartsWith("gpu-biome-",StringComparison.Ordinal)&&arg.EndsWith("-only",StringComparison.Ordinal));
            if(selectedBiome is not null)
            {
                string id=selectedBiome["gpu-biome-".Length..^"-only".Length];
                _mode="gpu-biome-"+id;
                TerrainGpuAllBiomeChecks.Run(Require,id);
                MigrationEvidence.Write(_mode,_checks,true,TerrainGpuAllBiomeChecks.Measurements);
                GD.Print($"C# GPU visual payload and collision check passed for {id}: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-all-biomes-only"))
            {
                _mode="gpu-all-biomes";TerrainGpuAllBiomeChecks.Run(Require);
                MigrationEvidence.Write(_mode,_checks,true,TerrainGpuAllBiomeChecks.Measurements);
                GD.Print($"C# GPU grid tests passed across all surface biomes: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"cave-biomes-only"))
            {
                _mode="cave-biomes";
                FrozenSurfaceChecks.Run(Require);
                MagmaSurfaceChecks.Run(this,Require);
                CrystalSurfaceChecks.Run(Require);
                CaveBiomeRegionChecks.Run(Require);
                CaveBiomeMaterialChecks.Run(this,Require);
                CaveFeatureDispatchChecks.Run(Require);
                CaveRendererChecks.Run(this,Require);
                MigrationEvidence.Write(_mode,_checks,true);
                GD.Print($"C# all cave biome material/feature checks passed: {_checks}");
                await Finish();return;
            }
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-pipeline-only")){_mode="gpu-pipeline";TerrainGpuPipelineChecks.Run(this,Require);MigrationEvidence.Write(_mode,_checks,true);GD.Print($"C# GPU terrain pipeline checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-queues-only")){_mode="gpu-queues";await TerrainGpuPipelineChecks.RunQueues(this,Require);MigrationEvidence.Write(_mode,_checks,true);GD.Print($"C# GPU terrain queue checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"gpu-terrain-only")){_mode="gpu-terrain";await TerrainGpuPipelineChecks.RunRendered(this,Require);MigrationEvidence.Write(_mode,_checks,true,TerrainGpuPipelineChecks.Measurements);GD.Print($"C# GPU terrain collision checks passed: {_checks}");await Finish();return;}
            if(System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(),"collision-only")){_mode="collision";CollisionChecks.Run(this,Require);MigrationEvidence.Write(_mode,_checks,true);GD.Print($"C# collision checks passed: {_checks}");await Finish();return;}
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "quarry-only"))
            {
                _mode="quarry";QuarryRoadChecks.Run(Require);
                MigrationEvidence.Write(_mode,_checks,true);
                GD.Print($"C# quarry road and landscape checks passed: {_checks}");
                await Finish();return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "tropical-only"))
            {
                _mode = "tropical"; TropicalSamplerChecks.Run(Require); BadlandsFanChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# tropical checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "coast-only"))
            {
                _mode = "coast"; CoastSamplerChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# rocky coast checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "beach-only"))
            {
                _mode = "beach"; BeachSamplerChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# beach sampler checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "tissue-only"))
            {
                _mode = "tissue"; AlienSamplerChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# alien tissue checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "placement-only"))
            {
                _mode = "placement"; JunglePlacementChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# jungle placement checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "samplers-only"))
            {
                _mode = "samplers"; ExtensionSamplerChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# extension sampler checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "discovery-only"))
            {
                _mode="discovery"; CaveDiscoveryChecks.Run(Require);
                MigrationEvidence.Write(_mode,_checks,true);
                GD.Print($"C# deterministic cave discovery checks passed: {_checks}");
                await Finish();return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "network-only"))
            {
                _mode = "network"; CaveRouteChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true);
                GD.Print($"C# cave network checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "field-only"))
            {
                _mode = "field";
                CaveFieldChecks.Run(Require);
                CaveMesherOptimizationChecks.Run(Require);
                MigrationEvidence.Write(_mode, _checks, true, CaveFieldChecks.Measurements); GD.Print($"C# cave field checks passed: {_checks}"); await Finish(); return;
            }
            if (System.Linq.Enumerable.Contains(OS.GetCmdlineUserArgs(), "worker-only"))
            {
                _mode = "worker";
                CrystalHelperChecks.Run(Require); CrystalGeometryChecks.Run(Require); FrozenFeatureChecks.Run(Require); MagmaFeatureChecks.Run(Require); MagmaCascadeChecks.Run(Require); MagmaIntrusionChecks.Run(Require); MagmaLakeChecks.Run(Require); MagmaTubeChecks.Run(Require); CaveFormationChecks.Run(Require); CaveSeepageChecks.Run(Require); CaveEntryGuardChecks.Run(Require); CaveWorkloadChecks.Run(Require); MigrationEvidence.Write(_mode, _checks, true, CaveWorkloadChecks.Measurements); GD.Print($"C# actual cave worker checks passed: {_checks}"); await Finish(); return;
            }
            CaveSettingsChecks.Run(Require); CaveDefinitionChecks.Run(Require);
            CaveBiomeRegionChecks.Run(Require);
            CaveSurfaceCutChecks.Run(Require);
            CavePayloadChecks.Run(Require);
            CaveContextChecks.Run(Require);
            CaveTransactionChecks.Run(this, Require);
            CaveRendererChecks.Run(this, Require);
            CaveBiomeMaterialChecks.Run(this, Require);
            FrozenSurfaceChecks.Run(Require);
            MagmaSurfaceChecks.Run(this, Require);
            CrystalSurfaceChecks.Run(Require);
            CaveFeatureDispatchChecks.Run(Require);
            CaveFrontierChecks.Run(this, Require);
            ForestSamplerChecks.Run(Require);
            JungleSamplerChecks.Run(Require);
            JunglePlacementChecks.Run(Require);
            SavannaSamplerChecks.Run(Require);
            SwampSamplerChecks.Run(Require);
            MountainSamplerChecks.Run(Require);
            ExtensionSamplerChecks.Run(Require);
            BeachSamplerChecks.Run(Require);
            CoastSamplerChecks.Run(Require);
            TropicalSamplerChecks.Run(Require); BadlandsFanChecks.Run(Require);
            CheckPlanner();
            CheckShaderVariants();
            CheckReadyCut();
            CheckCaveMesher();
            CheckExistingCaveField();
            CollisionChecks.Run(this, Require);
            CaveRouteChecks.Run(Require);
            SurfaceBatchChecks.Run(Require);
            var camera = new FreeCamera(); AddChild(camera);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            CheckCamera(camera);
            camera.QueueFree();
            var scene = GD.Load<PackedScene>("res://scenes/main.tscn").Instantiate();
            Require(scene.GetNode<Camera3D>("FreeCamera") is FreeCamera, "Main camera is not C#");
            Require(scene.GetNode("Terrain").Get("_partition").AsGodotObject() is TerrainPartition, "Main planner is not C#");
            Require(scene.GetNode("Terrain").Get("_ready_cut").AsGodotObject() is TerrainReadyCut, "Main ready cut is not C#");
            Require(scene.GetNode("Terrain").Get("_collision").AsGodotObject() is TerrainCollision, "Main collision is not C#");
            scene.Free();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            System.GC.Collect(); System.GC.WaitForPendingFinalizers();
            GD.Print($"C# migration checks passed: {_checks}");
            MigrationEvidence.Write(_mode, _checks, true, new GDictionary { ["swamp_maximum_scalar_error_m"] = SwampSamplerChecks.MaximumScalarError,
                ["mountain_maximum_scalar_error_m"] = MountainSamplerChecks.MaximumScalarError,
                ["swamp_precision"] = "At most 1e-12 absolute scalar/state error and identical Float32 extraction values; packed terrain material values must match exactly. No Float64 byte-equality claim across native math libraries." });
            await Finish();
        }
        catch (Exception error)
        {
            MigrationEvidence.Write(_mode, _checks, false, error: error.ToString());
            GD.PushError(error.ToString());
            GetTree().Quit(1);
        }
    }
    private async System.Threading.Tasks.Task Finish()
    {
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        System.GC.Collect(); System.GC.WaitForPendingFinalizers();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        // Return from the managed async continuation before engine teardown.
        // Otherwise its live camera/tree references retain the root render target.
        GetTree().CallDeferred(SceneTree.MethodName.Quit, 0);
    }

    private void CheckExistingCaveField()
    {
        foreach (bool portal in new[] { false, true })
        {
            using var field = GD.Load<GDScript>("res://scripts/caves/portal_field.gd").New().AsGodotObject();
            field.Set("height", Callable.From<double, double, double>((x, z) => 40));
            field.Set("minimum_roof", 2.0); field.Set("include_surface_air", portal);
            Require(field.Call("append_feature", new Vector3(10, 20, 32), new Vector3(54, 22, 32), new Vector2(8, 15), 0).AsBool(), "Existing field fixture rejected");
            if (portal) field.Set("surface_columns", new GDictionary { [Vector2I.Zero] = true });
            using var candidate = portal ? (CaveMesher)new PortalCaveMesher() : new CaveMesher();
            using var reference = GD.Load<GDScript>(portal ? "res://scripts/caves/portal_mesher.gd" : "res://scripts/caves/mesher.gd").New().AsGodotObject();
            foreach (double step in new[] { 2.0, 4.0 })
            {
                var expected = reference.Call("build", field, Vector3I.Zero, step).AsGodotArray();
                var actual = candidate.build(field, Vector3I.Zero, step);
                Require(expected.Count > 0, "Existing field produced empty comparison");
                Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(expected), GD.VarToBytes(actual)), $"Existing field mesh differs: portal={portal}, step={step}");
            }
        }
    }

    private void CheckCaveMesher()
    {
        foreach (bool portal in new[] { false, true })
        foreach (bool shoreline in new[] { false, true })
        foreach (var key in new[] { Vector3I.Zero, new Vector3I(-1, 0, 0) })
        {
            using var volume = new MesherFixture { center = (Vector3)key * 64 + new Vector3(32, 32, 32) };
            if (shoreline) volume.precise_shores.Add(new GDictionary { ["center"] = volume.center, ["radius"] = 20.0 });
            using var candidate = portal ? (CaveMesher)new PortalCaveMesher() : new CaveMesher();
            using var reference = GD.Load<GDScript>(portal ? "res://scripts/caves/portal_mesher.gd" : "res://scripts/caves/mesher.gd").New().AsGodotObject();
            candidate.capture_boundary_values = true; reference.Set("capture_boundary_values", true);
            long start = Stopwatch.GetTimestamp();
            var expected = reference.Call("build", volume, key, 2.0).AsGodotArray();
            double originalMs = Stopwatch.GetElapsedTime(start).TotalMilliseconds;
            start = Stopwatch.GetTimestamp(); var actual = candidate.build(volume, key, 2);
            double managedMs = Stopwatch.GetElapsedTime(start).TotalMilliseconds;
            Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(expected), GD.VarToBytes(actual)), $"Cave mesh payload differs: portal={portal}, shore={shoreline}, key={key}");
            Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(reference.Get("boundary_values")), GD.VarToBytes(candidate.boundary_values)), "Captured face values differ");
            Require(expected.Count > 0, "Empty cave fixture");
            GD.Print($"Cave mesher fixture portal={portal} shore={shoreline} key={key}: GDScript {originalMs:F2} ms; C# {managedMs:F2} ms. Field is native C# for this bounded comparison.");
        }
    }

    private void CheckReadyCut()
    {
        var original = GD.Load<GDScript>("res://scripts/terrain_ready_cut.gd");
        using var cut = new TerrainReadyCut(); using var planner = new TerrainPartition();
        Godot.Collections.Array Arrays(int resolution, bool invalid = false)
        {
            var vertices = new Vector3[(resolution + 1) * (resolution + 1) + 8 * resolution];
            int main = (resolution + 1) * (resolution + 1);
            for (int i = 0; i < vertices.Length; i++) vertices[i] = new Vector3(0, i < main ? 10 : invalid ? 20 : -10, 0);
            var result = new Godot.Collections.Array(); result.Resize((int)Mesh.ArrayType.Max); result[(int)Mesh.ArrayType.Vertex] = vertices; return result;
        }
        var arrays = Arrays(8); var profile = cut.edge_profiles(arrays, 8);
        Require(System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(profile), GD.VarToBytes(original.Call("edge_profiles", arrays, 8))), "Skirt extraction differs");
        var invalidProfile = cut.edge_profiles(Arrays(8, true), 8);
        foreach (int offset in new[] { -3, 0, 2 })
        for (int level = 1; level <= 6; level++)
        for (int side = 0; side < 4; side++)
        {
            int width = 1 << level, origin = offset * width;
            var fine = side switch
            {
                0 => new Vector3I(origin, origin, 0), 1 => new Vector3I(origin + width - 1, origin, 0),
                2 => new Vector3I(origin, origin, 0), _ => new Vector3I(origin, origin + width - 1, 0)
            };
            var coarse = side switch
            {
                0 => new Vector3I(offset - 1, offset, level), 1 => new Vector3I(offset + 1, offset, level),
                2 => new Vector3I(offset, offset - 1, level), _ => new Vector3I(offset, offset + 1, level)
            };
            var resolutions = new GDictionary { [fine] = 8, [coarse] = 8 };
            var profiles = new GDictionary { [fine] = profile, [coarse] = profile };
            var expected = original.Call("covered_edge", fine, coarse, resolutions, profiles, planner).AsGodotDictionary();
            var actual = cut.covered_edge(fine, coarse, resolutions, profiles, planner);
            Require(actual.Count > 0 && System.Linq.Enumerable.SequenceEqual(GD.VarToBytes(expected), GD.VarToBytes(actual)), $"Skirt coverage differs: {fine}/{coarse}");
            profiles[fine] = invalidProfile;
            Require(cut.covered_edge(fine, coarse, resolutions, profiles, planner).Count == 0
                && original.Call("covered_edge", fine, coarse, resolutions, profiles, planner).AsGodotDictionary().Count == 0, "Invalid curtain accepted");
            Require(cut.edge_id(fine, coarse) == original.Call("edge_id", fine, coarse).AsString(), "Certificate edge identity differs");
        }
        var parent = new Vector3I(-1, -1, 2);
        var active = new GDictionary { [parent] = true }; var wanted = new GDictionary(); var ready = new GDictionary();
        foreach (var child in planner.children(parent)) { wanted[child] = true; ready[child] = true; }
        var old = original.Call("choose", active, wanted, ready, planner, Vector2.Zero).AsGodotDictionary();
        var current = cut.choose(active, wanted, ready, planner, Vector2.Zero);
        Require(old.Count > 0 && GD.VarToStr(old) == GD.VarToStr(current), "Complete replacement differs");
        ready.Remove(planner.children(parent)[0]);
        Require(cut.choose(active, wanted, ready, planner, Vector2.Zero).Count == 0, "Incomplete replacement published");
        Require(cut.Call("contains", parent, new Vector3I(-3, -3, 0)).AsBool(), "Cut bridge missing");
    }

    private void CheckShaderVariants()
    {
        var original = GD.Load<GDScript>("res://scripts/terrain_shader_variants.gd");
        using var candidate = new TerrainShaderVariants();
        string source = GD.Load<Shader>("res://shaders/terrain_biomes.gdshader").Code;
        foreach (int mask in new[] { -1, 0, 1, 127, 191, 255, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65535, 65536, 0x5595, 0xAA6A })
        {
            string expected = original.Call("source_for", source, mask).AsString();
            Require(expected == candidate.source_for(source, mask), $"Shader source differs for mask {mask}");
        }
        // Packing family weights moved one shader loop into an include.
        // A stale two-loop assumption silently disabled *all* configured
        // biome shader specialization without producing a compiler error.
        string onlyGrass=candidate.source_for(source,0);
        Require(onlyGrass.StartsWith("// CONFIGURED_TERRAIN_OWNERS_0\n",StringComparison.Ordinal)&&
            !onlyGrass.Contains("for(int i=0;i<8;i++){",StringComparison.Ordinal),
            "Packed atlas shader accidentally disabled all biome variant pruning");
        string quarryOnly=candidate.source_for(source,1<<8);
        Require(quarryOnly.Contains("for(int i=0;i<1;i++){",StringComparison.Ordinal),
            "Packed atlas shader failed to narrow extension material dispatch");
        var unexpected=source.Replace(
            "if(extension_payload_enabled)extension_weight_banks(extension_weights_a,extension_weights_b);",
            "if(extension_payload_enabled)unrecognized_atlas_layout();");
        Require(candidate.source_for(unexpected,1<<8)==unexpected,
            "Unknown one-loop shader dispatch was unsafely specialized");
        foreach (string malformed in new[] { "", source.Replace("jungle_control.z>.999", "jungle_control.z>.998"), source + "for(int i=0;i<8;i++){" })
            Require(original.Call("source_for", malformed, 191).AsString() == candidate.source_for(malformed, 191), "Malformed dispatch handling differs");
        var settings = GD.Load<Resource>("res://config/world/terrain_settings.tres");
        Require(original.Call("configured_mask", settings).AsInt32() == candidate.configured_mask(settings), "Configured shader mask differs");
        Require(candidate.Call("configured_mask", settings).AsInt32() == candidate.configured_mask(settings), "Shader bridge unavailable");
        var shader = GD.Load<Shader>("res://shaders/terrain_biomes.gdshader");
        Require(candidate.select(shader, settings) == candidate.select(shader, settings), "Prepared shader is not reused");
        Require(candidate.select(shader, settings, false) == shader, "Disabled specialization changed shader");
    }

    private void CheckCamera(FreeCamera camera)
    {
        Require(!camera.debug_overlay_visible, "Diagnostics visible by default");
        var overlay = new CanvasLayer(); overlay.AddToGroup("terrain_debug_overlay"); AddChild(overlay);
        camera._set_debug_overlay_visible(true); Require(overlay.Visible, "Grouped hint did not show");
        camera._set_debug_overlay_visible(false); Require(!overlay.Visible, "Grouped hint did not hide"); overlay.QueueFree();
        Require(camera.Far == 50000, "Camera draw distance changed");
        Require(InputMap.HasAction("toggle_debug_overlay") && InputMap.HasAction("freecam_release_mouse"), "Input bindings missing");
        camera._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.WheelUp, Pressed = true });
        Require(camera.move_speed == 42, "Wheel speed differs");
        if (DisplayServer.GetName() != "headless")
        {
            Input.MouseMode = Input.MouseModeEnum.Captured;
            var old = camera.RotationDegrees;
            camera._Input(new InputEventMouseMotion { Relative = new Vector2(20, 10) });
            Require(camera.RotationDegrees.Y < old.Y && camera.RotationDegrees.X < old.X, "Captured look did not turn");
            camera._Input(new InputEventKey { PhysicalKeycode = Key.Escape, Pressed = true });
            Require(Input.MouseMode == Input.MouseModeEnum.Visible, "Escape did not release");
            camera._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true });
            Require(Input.MouseMode == Input.MouseModeEnum.Captured, "Click did not recapture");
            camera._Notification((int)NotificationApplicationFocusOut);
            Require(Input.MouseMode == Input.MouseModeEnum.Visible, "Focus loss did not release");
        }
    }

    private void Require(bool condition, string message)
    {
        _checks++;
        if (!condition) throw new InvalidOperationException(message);
    }

    private void CheckPlanner()
    {
        var script = GD.Load<GDScript>("res://scripts/terrain_partition.gd");
        long originalUsec = 0, managedUsec = 0;
        foreach (double size in new[] { 64.0, 256.0, 1024.0 })
        foreach (int level in new[] { 3, 5, 6 })
        {
            using var reference = script.New().AsGodotObject();
            using var candidate = new TerrainPartition { base_size = size, maximum_level = level };
            reference.Set("base_size", size); reference.Set("maximum_level", level);
            candidate.Set("split_ratio", 1.15);
            Require(candidate.Get("base_size").AsDouble() == size, "C# properties unavailable to transitional callers");
            Require(candidate.Call("parent", new Vector3I(-3, -5, 0)).AsVector3I() == new Vector3I(-2, -3, 1), "C# methods unavailable to transitional callers");
            var oldCut = new GDictionary(); var newCut = new GDictionary();
            foreach (var point in new[]
            {
                Vector2.Zero, new Vector2(-1, -1), new Vector2(-256, 256),
                new Vector2(100, 100), new Vector2(1024, 1024), new Vector2(21000, -19000),
                new Vector2(21001, -19001), new Vector2(-50000, 64000), Vector2.Zero
            })
            {
                long begin = Stopwatch.GetTimestamp();
                oldCut = reference.Call("select", point, oldCut).AsGodotDictionary();
                originalUsec += Stopwatch.GetElapsedTime(begin).Ticks / 10;
                begin = Stopwatch.GetTimestamp();
                newCut = candidate.select(point, newCut);
                managedUsec += Stopwatch.GetElapsedTime(begin).Ticks / 10;
                Require(oldCut.Count == newCut.Count, $"Leaf count differs at {point}/{size}/{level}");
                foreach (var pair in oldCut) Require(newCut.ContainsKey(pair.Key), $"Missing leaf {pair.Key}");
                foreach (var pair in newCut)
                {
                    var key = pair.Key.AsVector3I();
                    Require(reference.Call("parent", key).AsVector3I() == candidate.parent(key), "Negative parent division");
                    Require(reference.Call("bounds", key).AsRect2() == candidate.bounds(key), "Bounds differ");
                    Require(reference.Call("distance_to", key, point).AsDouble() == candidate.distance_to(key, point), "Distance differs");
                }
            }
            var reservation = new Godot.Collections.Array<Rect2> { new(new Vector2(-513, -513), new Vector2(30, 30)) };
            reference.Set("forced_detail_regions", reservation); candidate.forced_detail_regions = reservation;
            var reservedOld = reference.Call("select", Vector2.Zero, oldCut).AsGodotDictionary();
            var reservedNew = candidate.select(Vector2.Zero, newCut);
            Require(reservedOld.Count == reservedNew.Count, "Forced detail count differs");
            foreach (var pair in reservedOld) Require(reservedNew.ContainsKey(pair.Key), "Forced detail leaf differs");
        }
        GD.Print($"Planner diagnostic: GDScript {originalUsec / 1000.0:F3} ms; C# {managedUsec / 1000.0:F3} ms. Same-process bounded fixture, not world loading time.");
    }
}
