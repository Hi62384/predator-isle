using Godot;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Native end-to-end checks of the new graph, implicit volume and mesh.</summary>
internal static class CaveProceduralChecks
{
    internal static D Measurements {get;private set;}=new();
    internal static void Run(Action<bool,string> require)
    {
        var report=new A();var profiles=new HashSet<string>();var samples=new List<(long Seed,Vector2I Cell,double Depth,Vector3 Floor,D Region)>();
        var surface=Callable.From<double,double,double>((x,z)=>100+8*Math.Sin(x*.001)+5*Math.Sin(z*.002));
        var water=Callable.From<double,double,double>((x,z)=>-1000);
        CaveNetwork Make(long seed)
        {
            var network=new CaveNetwork{activity=1,EntrancesPerRegion=4,OceanLevel=0,geological_morphology=true,chamber_variety=true};
            network.configure(surface,water,seed,1200);return network;
        }
        int mouths=0,zero=0,links=0,deepLinks=0,loops=0,totalNodes=0,accessibleNodes=0;
        var accessibleRegions=new HashSet<(long,Vector2I)>();
        var reachableLengthByBand=new Dictionary<int,double>();
        double minSpacing=double.PositiveInfinity;
        foreach(long seed in new long[]{17,73921,2063,118})
        {
            using var network=Make(seed);using var replay=Make(seed);
            var cells=new[]{Vector2I.Zero,Vector2I.Right,Vector2I.Down,new Vector2I(-1,0)};
            var stored=new Dictionary<Vector2I,D>();
            foreach(var cell in cells.Reverse())stored[cell]=replay.region(cell);
            var entrances=new List<Vector3>();
            var seedNodes=new Dictionary<string,Vector3>(StringComparer.Ordinal);
            var seedEdges=new List<D>();
            var seedMouths=new HashSet<string>(StringComparer.Ordinal);
            var roots=new Dictionary<Vector2I,string>();
            foreach(var cell in cells)
            {
                long began=Stopwatch.GetTimestamp();var region=network.region(cell);
                double milliseconds=Stopwatch.GetElapsedTime(began).TotalMilliseconds;
                require(region["valid"].AsBool(),$"Flat/slightly rolling land failed to generate a network: {seed}/{cell}");
                require(GD.VarToBytes(region).SequenceEqual(GD.VarToBytes(stored[cell])),"Discovery order changed region graph");
                var nodes=region["nodes"].AsGodotArray().Select(v=>v.AsGodotDictionary()).ToArray();
                var edges=region["edges"].AsGodotArray().Select(v=>v.AsGodotDictionary()).ToArray();
                var ids=nodes.ToDictionary(n=>n["id"].AsString(),StringComparer.Ordinal);
                roots[cell]=nodes[0]["id"].AsString();
                foreach(var node in nodes)
                {
                    string id=node["id"].AsString();seedNodes.Add(id,node["point"].AsVector3());
                    if(node["level"].AsInt32()==-1)seedMouths.Add(id);
                }
                seedEdges.AddRange(edges);
                var reachable=new HashSet<string>{nodes[0]["id"].AsString()};
                int count;
                do
                {
                    count=reachable.Count;
                    foreach(var e in edges)
                    {
                        string a=e["from"].AsString(),b=e["to"].AsString();
                        require(ids.ContainsKey(a)&&ids.ContainsKey(b),"Dangling graph edge");
                        if(reachable.Contains(a)||reachable.Contains(b)){reachable.Add(a);reachable.Add(b);}
                    }
                }while(count!=reachable.Count);
                require(reachable.Count==nodes.Length,"Disconnected local route network");
                double length=0,grade=0;
                foreach(var edge in edges)
                {
                    var p=edge["points"].AsVector3Array();
                    require(p.Length>=2&&p.All(v=>v.IsFinite()&&v.Y>=-1000.01),"Invalid route coordinates");
                    for(int i=1;i<p.Length;i++)
                    {
                        var d=p[i]-p[i-1];double horizontal=new Vector2(d.X,d.Z).Length();
                        require(horizontal>.001,"Degenerate route segment");
                        grade=Math.Max(grade,Math.Abs(d.Y)/horizontal);length+=d.Length();
                    }
                }
                require(grade<=.201,"Protected return grade exceeded 20 percent");
                var localMouths=nodes.Where(n=>n["level"].AsInt32()==-1).Select(n=>n["point"].AsVector3()).ToArray();
                require(localMouths.Length<=4,"Entrance ceiling exceeded");
                require(localMouths.Length==region["entrances"].AsGodotArray().Count,"Entrance count inconsistent");
                mouths+=localMouths.Length;if(localMouths.Length==0)zero++;
                entrances.AddRange(localMouths);
                var floor=nodes.OrderBy(n=>n["point"].AsVector3().Y).First()["point"].AsVector3();
                int cycles=edges.Length-nodes.Length+1;loops+=cycles;
                var bands=nodes.GroupBy(n=>(int)Math.Floor(n["point"].AsVector3().Y/100)).OrderBy(g=>g.Key).Select(g=>$"{g.Key}:{g.Count()}");
                profiles.Add(string.Join("/",bands)+":"+cycles);
                samples.Add((seed,cell,floor.Y,floor,region));
                report.Add(new D{["seed"]=seed,["region"]=cell,["nodes"]=nodes.Length,["edges"]=edges.Length,["entrances"]=localMouths.Length,["floor_y"]=floor.Y,["target_y"]=region["target_floor_y"],["cycles"]=cycles,["length_metres"]=length,["max_grade"]=grade,["generation_ms"]=milliseconds});
            }
            for(int i=0;i<entrances.Count;i++)for(int j=i+1;j<entrances.Count;j++)
            {
                double distance=new Vector2(entrances[i].X-entrances[j].X,entrances[i].Z-entrances[j].Z).Length();
                minSpacing=Math.Min(minSpacing,distance);require(distance>=399.99,"Entrance separation below 400 metres");
            }
            foreach(var cell in cells.Skip(1))
            {
                var a=network.connections(Vector2I.Zero,cell);
                var b=replay.connections(cell,Vector2I.Zero);
                require(GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b)),"Cross-region connection depends on discovery order");
                links+=a.Count;
                foreach(var edge in a)
                {
                    var link=edge.AsGodotDictionary();seedEdges.Add(link);
                    if(link["growth_role"].AsString()=="deep_region_link")deepLinks++;
                }
            }
            // Unlike a local root-only connectivity check, start at actual
            // surface mouths and traverse the cross-region return routes.
            var adjacent=seedNodes.Keys.ToDictionary(id=>id,id=>new List<string>(),StringComparer.Ordinal);
            foreach(var edge in seedEdges)
            {
                string a=edge["from"].AsString(),b=edge["to"].AsString();
                require(adjacent.ContainsKey(a)&&adjacent.ContainsKey(b),"Dangling cross-region route");
                adjacent[a].Add(b);adjacent[b].Add(a);
            }
            var reached=new HashSet<string>(seedMouths,StringComparer.Ordinal);
            var queue=new Queue<string>(seedMouths);
            while(queue.Count>0)foreach(string next in adjacent[queue.Dequeue()])if(reached.Add(next))queue.Enqueue(next);
            totalNodes+=seedNodes.Count;accessibleNodes+=reached.Count;
            foreach(var root in roots)if(reached.Contains(root.Value))accessibleRegions.Add((seed,root.Key));
            foreach(var edge in seedEdges)
            {
                if(!reached.Contains(edge["from"].AsString())||!reached.Contains(edge["to"].AsString()))continue;
                var points=edge["points"].AsVector3Array();
                for(int i=1;i<points.Length;i++)
                {
                    int band=(int)Math.Floor((points[i-1].Y+points[i].Y)/200)*100;
                    reachableLengthByBand[band]=reachableLengthByBand.GetValueOrDefault(band)+points[i-1].DistanceTo(points[i]);
                }
            }
        }
        require(mouths>0&&zero>0,"Fixture did not exercise both surface access and buried regions");
        require(profiles.Count>=8,"Insufficient diversity in depth and connectivity");
        require(links>0,"No cross-region connection admitted");
        require(samples.Any(x=>x.Depth<=-950),"No graph descended to approximately Y=-1000");
        require(totalNodes>0&&accessibleNodes>=totalNodes*.9,"Too much sampled geometry is disconnected from surface access");
        foreach(int band in new[]{-100,-300,-500,-800,-900,-1000})
            require(reachableLengthByBand.GetValueOrDefault(band)>0,$"No surface-reachable route at depth band {band}");
        var deepest=samples.Where(x=>accessibleRegions.Contains((x.Seed,x.Cell))).OrderBy(x=>x.Depth).First();
        require(deepest.Depth<=-950,"No surface-reachable network descended to approximately Y=-1000");
        using var field=new CaveField{maximum_depth=1200,minimum_roof=10,continuous_route_floors=true};
        long compile=Stopwatch.GetTimestamp();
        require(field.compile(new A{deepest.Region},surface),"Deepest procedural volume failed to compile");
        double compileMs=Stopwatch.GetElapsedTime(compile).TotalMilliseconds;
        require(field.sample(deepest.Floor+Vector3.Up*2)<0,"Deepest graph chamber has no actual walkable air volume");
        var key=field.cell(deepest.Floor+Vector3.Up*2);
        using var mesher=new CaveMesher();
        long meshStart=Stopwatch.GetTimestamp();
        var mesh=mesher.build(field,key,2);
        double meshMs=Stopwatch.GetElapsedTime(meshStart).TotalMilliseconds;
        require(mesh.Count>0,"Deep cave failed to generate geometry");
        var vertices=mesh[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        require(vertices.Length>=3&&vertices.Length%3==0&&vertices.All(v=>v.IsFinite()),"Invalid deep cave mesh");
        // Compare the actual freeform scalar geometry after rotating the major
        // axis. A room must not merely be an orientation-invariant sphere.
        using var roomA=new CaveField{maximum_depth=1200,minimum_roof=10};
        using var roomB=new CaveField{maximum_depth=1200,minimum_roof=10};
        roomA.height=surface;roomB.height=surface;
        var center=new Vector3(32,-500,32);
        require(roomA.append_feature(center,center+new Vector3(10,0,0),new Vector2(24,30),4,3),"Warped room A rejected");
        require(roomB.append_feature(center,center+new Vector3(0,0,10),new Vector2(24,30),4,3),"Warped room B rejected");
        require(roomA.sample(center+Vector3.Up*2)<0&&roomB.sample(center+Vector3.Up*2)<0,"Warped chamber core closed");
        int distinct=0;
        for(int z=-25;z<=25;z+=2)for(int x=-25;x<=25;x+=2)
        {
            var test=center+new Vector3(x,10,z);
            if((roomA.sample(test)<0)!=(roomB.sample(test)<0))distinct++;
        }
        require(distinct>40,"Warped cavern footprint is not materially different after independent axis variation");
        int shafts=0;double maxRoom=0;
        foreach(var sample in samples)
        {
            foreach(var raw in sample.Region["nodes"].AsGodotArray())
                maxRoom=Math.Max(maxRoom,raw.AsGodotDictionary().TryGetValue("chamber_radius",out var radius)?radius.AsDouble():0);
            if(!sample.Region.TryGetValue("vertical_links",out var vertical))continue;
            foreach(var raw in vertical.AsGodotArray())
            {
                var shaft=raw.AsGodotDictionary();var low=shaft["bottom"].AsVector3();var high=shaft["top"].AsVector3();
                require(high.Y-low.Y>=18&&low.X==high.X&&low.Z==high.Z,"Invalid optional fissure");
                shafts++;
            }
        }
        using var shaftField=new CaveField{maximum_depth=1200,minimum_roof=10};
        shaftField.height=surface;
        var foot=new Vector3(32,-570,32);var lip=foot+Vector3.Up*48;
        require(shaftField.append_feature(foot,lip,new Vector2(5,8),5,3),"Vertical fissure rejected");
        for(int i=1;i<=48;i++)require(shaftField.sample(foot+Vector3.Up*i)<0,"Fissure contains an internal rock barrier");
        require(shaftField.sample(foot+Vector3.Right*7+Vector3.Up*24)>0,"Fissure escaped its admitted envelope");
        using var submerged=Make(17);
        submerged.configure(Callable.From<double,double,double>((x,z)=>-2),water,17,1200);
        require(submerged.region(Vector2I.Zero)["entrances"].AsGodotArray().Count==0,"Submerged entrance was admitted");
        Measurements=new D{["regions"]=report,["region_count"]=samples.Count,["entrances"]=mouths,["zero_mouth_regions"]=zero,["minimum_spacing_metres"]=double.IsFinite(minSpacing)?minSpacing:0,["distinct_depth_connectivity_profiles"]=profiles.Count,["links"]=links,["deep_links"]=deepLinks,["cycles"]=loops,["deepest_y"]=deepest.Depth,["deep_cell"]=key,["field_compile_ms"]=compileMs,["mesh_ms"]=meshMs,["mesh_vertices"]=vertices.Length,["field_bytes"]=field.numeric_bytes(),["warped_footprint_different_samples"]=distinct,["optional_vertical_links"]=shafts,["maximum_room_diameter_m"]=maxRoom*2};
        Measurements["surface_reachable_nodes"]=accessibleNodes;Measurements["total_nodes"]=totalNodes;
        Measurements["surface_reachable_regions"]=accessibleRegions.Count;
        var lengthBands=new D();foreach(var band in reachableLengthByBand.OrderBy(pair=>pair.Key))lengthBands[band.Key.ToString()]=band.Value;
        Measurements["reachable_route_metres_by_100m_band"]=lengthBands;
        GD.Print("Procedural cave measurements: "+Json.Stringify(Measurements));
    }
}
