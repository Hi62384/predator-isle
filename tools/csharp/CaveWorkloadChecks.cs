using Godot;
using System;
using System.Diagnostics;
using System.Linq;
using PredatorIsle.Caves;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class CaveWorkloadChecks
{
    internal static D Measurements { get; private set; } = new();
    internal static void Run(Action<bool, string> require)
    {
        var settings = GD.Load<Resource>("res://config/world/terrain_settings.tres").Duplicate(true);
        foreach (string name in new[] { "grass", "forest", "savanna", "swamp", "jungle", "mountain", "tropical", "badlands", "quarry", "wise_mountains", "volcanic", "spore_forest", "radiation_wasteland", "crystal_wastes", "insect_colony", "alien_infected" }) settings.Set(name + "_coverage", name == "volcanic" ? 100 : 0);
        settings.Set("beaches_enabled", false); settings.Set("rocky_coast_enabled", false);
        var caves = GD.Load<Resource>("res://config/caves/cave_settings.tres");
        using var work = new CaveWorkload();
        require(work.Call("configure", settings, caves, 17, 0.0).AsBool(), "Saved cave configuration rejected");
        var network = work.Get("network").AsGodotObject(); var builder = work.Get("builder").AsGodotObject();
        require(network is CaveNetwork, "Actual worker did not instantiate the C# cave network");
        require(work._colony is CaveColonyNetwork && work._insect_guard is CaveInsectEntryGuard,"Actual worker did not bind native cave family and entrance admission modules");
        require(work._magma_heat is MagmaCaveHeat,"Actual worker did not bind native volcanic heat witnesses");
        var site = new Vector2I(-73, 138); var region = network.Call("region", site).AsGodotDictionary();
        using var referenceWork = GD.Load<GDScript>("res://scripts/caves/workload.gd").New().AsGodotObject();
        var referenceCaves=caves.DuplicateDeep(Resource.DeepDuplicateMode.All);
        foreach(var item in referenceCaves.Get("biome_regions").AsGodotObject().Get("definitions").AsGodotArray())
        {
            var definition=item.AsGodotObject();string id=definition.Get("biome_id").AsString();if(id is "magma" or "frozen")definition.Set("feature_provider",GD.Load<GDScript>($"res://scripts/caves/{id}_features.gd"));
        }
        require(referenceWork.Call("configure", settings, referenceCaves, 17, 0.0).AsBool(), "Reference cave worker configuration rejected");
        using var originalNetwork = GD.Load<GDScript>("res://scripts/caves/network.gd").New().AsGodotObject();
        var configuredNetwork = referenceWork.Get("network").AsGodotObject();
        originalNetwork.Call("configure", configuredNetwork.Get("height"), configuredNetwork.Get("water"), 17, configuredNetwork.Get("max_depth"));
        foreach (string name in new[] { "half_width", "headroom", "minimum_roof", "maximum_grade", "activity", "chamber_variety", "geological_morphology", "seepage_density", "flat_radius", "region_context", "region_decorator", "access_admission" }) originalNetwork.Set(name, configuredNetwork.Get(name));
        referenceWork.Get("_colony").AsGodotObject().Call("configure", referenceWork.Get("builder"), referenceWork.Get("configuration"), originalNetwork);
        referenceWork.Set("network", originalNetwork);
        using var referenceRegions = GD.Load<GDScript>("res://scripts/caves/biome_regions.gd").New().AsGodotObject();
        referenceRegions.Call("configure", referenceWork.Get("builder"), referenceWork.Get("configuration").AsGodotObject().Get("biome_regions"), 17);
        // A bound GDScript Callable crossing the C# property boundary was being dropped.
        // Invoke the original dispatcher explicitly so the oracle includes intended geometry/heat annotations.
        var originalFeatures = GD.Load<GDScript>("res://scripts/caves/biome_features.gd");
        referenceRegions.Set("geometry_provider", Callable.From<D,D>(r => originalFeatures.Call("decorate",r,referenceWork.Get("configuration"),17,new Callable(referenceWork.Get("builder").AsGodotObject(),"_get_height"),referenceWork.Get("_magma_heat")).AsGodotDictionary()));
        referenceWork.Get("network").AsGodotObject().Set("region_finalizer", new Callable(referenceRegions, "decorate"));
        var referenceRegion = referenceWork.Get("network").AsGodotObject().Call("region", site);
        require(GD.VarToBytes(referenceRegion).SequenceEqual(GD.VarToBytes(region)), "Complete volcanic region differs after biome placement migration: " + MigrationComparison.FirstDifference(referenceRegion, region));
        require(region["valid"].AsBool(), "Known normal volcanic region was not admitted");
        using var liquid=new RetainedLiquidGeometry();var liquidReference=GD.Load<GDScript>("res://scripts/retained_liquid_geometry.gd");
        foreach(var item in region["nodes"].AsGodotArray())
        {
            var liquidPoint=item.AsGodotDictionary()["point"].AsVector3();var p=new Vector2(liquidPoint.X,liquidPoint.Z);
            foreach(double radius in new[]{3.0,24.0,100.0})require(GD.VarToBytes(liquidReference.Call("measure",builder,p,radius)).SequenceEqual(GD.VarToBytes(liquid.measure(builder,p,radius))),"Canonical retained liquid rim/level differs");
            var triangle=new[]{liquidPoint,liquidPoint+new Vector3(16,0,0),liquidPoint+new Vector3(0,0,16)};
            for(int i=0;i<3;i++)triangle[i].Y=(float)builder.Call("_get_height",triangle[i].X,triangle[i].Z).AsDouble();
            foreach(double offset in new[]{-10.0,0.0,10.0})
            {
                double level=((double)triangle[0].Y+triangle[1].Y+triangle[2].Y)/3+offset;
                require(GD.VarToBytes(liquidReference.Call("clipped_polygon",builder,triangle[0],triangle[1],triangle[2],level)).SequenceEqual(GD.VarToBytes(liquid.clipped_polygon(builder,triangle[0],triangle[1],triangle[2],level))),"Canonical retained liquid clipped footprint differs");
            }
        }
        require(!liquid.measure(builder,Vector2.Inf,4)["retained"].AsBool()&&!liquid.measure(builder,Vector2.Zero,0)["retained"].AsBool(),"Retained liquid geometry accepted invalid inputs");
        using var originalHeat=GD.Load<GDScript>("res://scripts/caves/magma_heat.gd").New().AsGodotObject();using var nativeHeat=new MagmaCaveHeat();
        foreach(var heat in new GodotObject[]{originalHeat,nativeHeat}){heat.Set("geological_intrusions",true);heat.Call("configure",builder);}
        int hotSamples=0;
        foreach(var item in region["nodes"].AsGodotArray())
        {
            var heatPoint=item.AsGodotDictionary()["point"].AsVector3();
            foreach(float rise in new[]{0f,4f,8f})
            {
                var expectedHeat=originalHeat.Call("sample",heatPoint+Vector3.Up*rise);var currentHeat=nativeHeat.sample(heatPoint+Vector3.Up*rise);
                require(GD.VarToBytes(expectedHeat).SequenceEqual(GD.VarToBytes(currentHeat)),"Witnessed volcanic heat differs: "+MigrationComparison.FirstDifference(expectedHeat,currentHeat));
                if(currentHeat["heat"].AsDouble()>.01)hotSamples++;
            }
        }
        require(hotSamples>0,"Heat fixture never reached a witnessed active source");
        require(GD.VarToBytes(originalHeat.Call("annotate_region",region)).SequenceEqual(GD.VarToBytes(nativeHeat.annotate_region(region))),"Complete cave heat annotation differs");
        require(nativeHeat.sample(Vector3.Inf)["heat"].AsDouble()==0,"Invalid cave point received heat");
        nativeHeat.geological_intrusions=false;require(nativeHeat.cache_counts()==Vector2I.Zero,"Changing intrusion settings retained stale heat caches");
        var volcanicSampler=builder.Get("_extras").AsGodotArray()[2].AsGodotObject();
        for(int i=0;i<40;i++)nativeHeat.source_descriptor(builder,volcanicSampler,new D {["id"]="closed:"+i,["position"]=Vector2.Zero,["chance"]=2.0});
        require(nativeHeat.cache_counts().X==32,"Heat source cache did not respect its FIFO bound");
        var regions = new A { region }; var connections = new A();
        var bundle = new D { ["cell"] = site, ["regions"] = regions, ["connections"] = connections };
        require(work.Call("use_bundle", bundle).AsBool(), "C# cave field rejected actual generated region");
        require(referenceWork.Call("use_bundle", bundle).AsBool(), "Original worker rejected actual generated region");
        foreach (var edge in region["edges"].AsGodotArray())
        {
            var entrance = new D { ["access"] = edge }; var copy = entrance.Duplicate(true);
            require(GD.VarToBytes(work.exposed_columns(entrance)).SequenceEqual(GD.VarToBytes(referenceWork.Call("exposed_columns", copy))), "Worker surface exposure columns differ");
            require(GD.VarToBytes(entrance).SequenceEqual(GD.VarToBytes(copy)), "Worker minimum exposed floor differs");
        }
        require(!work.use_bundle(new D()), "Worker accepted malformed bundle");
        require(!work.portal(bundle, new D(), new A(), new D { [Vector2I.Zero] = true }, false)["valid"].AsBool(), "Worker accepted ownership outside its complete surface mask");
        var managed = work.Get("field").AsGodotObject(); require(managed is PortalCaveField, "Actual worker did not instantiate the C# field");
        var assignment = GD.Load<GDScript>("res://scripts/caves/biome_regions.gd").Call("combine", regions, connections, "default").AsGodotDictionary();
        using var reference = GD.Load<GDScript>("res://scripts/caves/portal_field.gd").New().AsGodotObject();
        reference.Set("maximum_depth", managed.Get("maximum_depth")); reference.Set("minimum_roof", managed.Get("minimum_roof"));
        require(reference.Call("compile", regions, new Callable(builder, "_get_height"), connections, assignment).AsBool(), "Original field rejected actual generated region");
        foreach (string name in new[] { "begins", "ends", "directions", "dimensions", "endpoint_grades", "bins", "chunks", "_biome_fields", "precise_shores", "floor_relief", "thermal_sources" })
            require(GD.VarToBytes(reference.Get(name)).SequenceEqual(GD.VarToBytes(managed.Get(name))), "Actual field metadata differs: " + name);
        var rooms = region["nodes"].AsGodotArray(); var room = rooms[rooms.Count - 1].AsGodotDictionary(); var point = room["point"].AsVector3();
        var key = new Vector3I(Mathf.FloorToInt(point.X / 64), Mathf.FloorToInt(point.Y / 64), Mathf.FloorToInt(point.Z / 64));
        byte[]? expected = null;
        var rows = new A();
        foreach (var field in new[] { reference, managed })
        {
            work.Set("field", field); work.Get("_water_cache").AsGodotDictionary().Clear();
            long start = Stopwatch.GetTimestamp(); var payload = work.Call("build_cell", key).AsGodotDictionary(); double seconds = Stopwatch.GetElapsedTime(start).TotalSeconds;
            require(payload["valid"].AsBool() && payload["arrays"].AsGodotArray().Count > 0, "Actual cave cell did not produce valid geometry");
            var bytes = GD.VarToBytes(payload);
            if (expected == null) expected = bytes; else require(expected.SequenceEqual(bytes), "Complete actual cave worker payload differs after field migration");
            GD.Print($"Actual volcanic cave cell {key}, {(field == managed ? "C#" : "GDScript")} field: {seconds:F3}s; payload bytes {bytes.Length}. Ordered shared-process diagnostic, not an isolated benchmark.");
            rows.Add(new D { ["field"] = field == managed ? "C#" : "GDScript", ["seconds"] = seconds, ["complete_payload_bytes"] = bytes.Length });
        }
        var originalPayload = referenceWork.Call("build_cell", key);
        require(expected!.SequenceEqual(GD.VarToBytes(originalPayload)), "Complete original versus C# worker orchestration payload differs");
        require(region.ContainsKey("cave_floor_relief") && region.ContainsKey("cave_thermal_sources"), "Configured worker silently skipped cave geometry and thermal annotation");
        var entryPoint = region["nodes"].AsGodotArray()[0].AsGodotDictionary()["point"].AsVector3();
        var column = new Vector2I(Mathf.FloorToInt(entryPoint.X/64),Mathf.FloorToInt(entryPoint.Z/64)); var origin = new Vector3(column.X*64,0,column.Y*64);
        var snapshot = new A(); snapshot.Resize((int)Mesh.ArrayType.Max);
        var corners = new[] { Vector3.Zero,new Vector3(64,0,0),new Vector3(0,0,64),new Vector3(64,0,64) };
        for (int i=0;i<corners.Length;i++) corners[i].Y=(float)builder.Call("_get_height",(double)origin.X+corners[i].X,(double)origin.Z+corners[i].Z).AsDouble();
        snapshot[(int)Mesh.ArrayType.Vertex]=corners; snapshot[(int)Mesh.ArrayType.Normal]=Enumerable.Repeat(Vector3.Up,4).ToArray();
        snapshot[(int)Mesh.ArrayType.Color]=Enumerable.Repeat(new Color(1,0,0,0),4).ToArray(); snapshot[(int)Mesh.ArrayType.TexUV]=new Vector2[4]; snapshot[(int)Mesh.ArrayType.TexUV2]=new Vector2[4];
        snapshot[(int)Mesh.ArrayType.Index]=new[] {0,1,2,1,3,2};
        for(int slot=(int)Mesh.ArrayType.Custom0;slot<=(int)Mesh.ArrayType.Custom3;slot++) snapshot[slot]=new float[16];
        var parents=new A {new D { ["id"]="entry",["origin"]=origin,["span"]=64.0,["resolution"]=1,["arrays"]=snapshot,["ground_faces"]=System.Array.Empty<Vector3>() }};
        var columns=new D {[column]=true};
        foreach(bool indexed in new[] {false,true})
        {
            work.configuration.Set("indexed_entry_payload",indexed); referenceWork.Get("configuration").AsGodotObject().Set("indexed_entry_payload",indexed);
            var actual=work.portal(bundle,columns,parents,new D(),true); var original=referenceWork.Call("portal",bundle,columns,parents,new D(),true);
            require(actual["valid"].AsBool(),"C# portal fixture failed: "+actual);
            require(GD.VarToBytes(original).SequenceEqual(GD.VarToBytes(actual)),"Complete portal worker payload differs: "+MigrationComparison.FirstDifference(original,actual));
            require(managed.Get("surface_columns").AsGodotDictionary().Count==0 && managed.Get("surface_limits").AsGodotDictionary().Count==0 && managed.Get("top_height").AsCallable().Target==null,"Portal worker retained its surface snapshot");
        }
        Measurements = new D { ["site"] = site, ["cell"] = key, ["seed"] = 17, ["rows"] = rows,
            ["scope"] = "One actual normally generated volcanic cave cell; complete worker payload exact. Current C# auxiliary modules used in both cases, with original versus native C# scalar field. Ordered nonisolated times, not full-world speedup." };
    }
}
