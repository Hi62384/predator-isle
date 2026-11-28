using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

internal static class CaveFieldCompiler
{
    // Gradually widen and lift one side of a buried reach. Skipping the
    // near-surface stations keeps galleries from becoming accidental mouths.
    private static bool AddGallery(CaveField f, D edge, Vector3 a,Vector3 b,Vector2 size,
        float swell,double phase,int style,double station,double length)
    {
        var tangent=new Vector2(b.X-a.X,b.Z-a.Z).Normalized();
        var normal=new Vector3(-tangent.Y,0,tangent.X);
        int form=Math.Clamp((int)(phase*3/Math.Tau),0,2);
        float width=size.X*(1+swell*(form==1 ? .65f : 2.4f));
        float height=size.Y*(1+swell*(form==0 ? .25f : 1.9f));
        // A high side opening leaves an exposed rock shelf. In split galleries
        // the side passage sweeps away from the main path around a solid rib.
        float side=MathF.Cos((float)phase)>=0 ? 1 : -1;
        float separation=form==2 ? width+size.X*1.7f : width*.66f;
        var offset=normal*(swell*swell*separation*side);
        offset.Y=form==1 ? swell*size.Y*.72f : swell*swell*size.Y*.32f;
        if(Flag(edge,"procedural_profile"))
        {
            float local=(float)(phase+station/(38+phase*5));
            // Spatially coherent alternating erosion shelves and narrow
            // fractures. Keep the extra reach inside a small lateral reserve
            // so adjacent supported routes are not consumed by expansion.
            width=size.X*(1+swell*(.10f+.18f*MathF.Abs(MathF.Sin(local))));
            height=size.Y*(1+swell*(.25f+.85f*MathF.Abs(MathF.Cos(local))));
            offset=normal*(swell*Math.Min(size.X*.18f,.7f)*MathF.Sin(local));
            offset.Y=swell*size.Y*.16f*MathF.Abs(MathF.Sin(local*.61f));
            if(f.ground_height(a+offset)-a.Y<f.minimum_roof+height+offset.Y+4 || f.ground_height(b+offset)-b.Y<f.minimum_roof+height+offset.Y+4)return true;
        }
        if(!f.append_feature(a+offset,b+offset,new Vector2(width,height),0,style))return false;
        if(f.BiomeFields.Count>0)f.bind_feature_biomes(f.Begins.Count-1,Text(edge,"from"),Text(edge,"to"),station,station+a.DistanceTo(b),length);
        return true;
    }
    // Seeded asymmetric rooms use the same bounded primitives on CPU and GPU.
    // Keep a central walking volume and extensions inside the admitted footprint.
    private static bool AddProceduralRoom(CaveField f,D node,Vector3 p,float radius,float roof,int style,Vector2I region)
    {
        long seed=node["shape_seed"].AsInt64();
        float R(int salt)=>(float)CaveNetwork.SeededRandom(region,seed,salt);
        string id=Text(node,"biome_parent",Text(node,"id"));
        bool Add(Vector3 a,Vector3 b,float r,float h,int kind)
        {
            if(!f.append_feature(a,b,new Vector2(r,h),kind,style))return false;
            if(f.BiomeFields.Count>0)f.bind_feature_biomes(f.Begins.Count-1,id,id,0,0,0);
            return true;
        }
        float core=Math.Min(radius,Math.Max((float)Num(node,"half_width",4)+1,Math.Min(11,radius*(.26f+.16f*R(1)))));
        float coreHeight=Math.Min(roof,Math.Max((float)Num(node,"headroom",8),Math.Min(13,roof*(.40f+.22f*R(2)))));
        if(!Add(p,p,core,coreHeight,2))return false;
        if(radius-core<2)return true;
        float bearing=node.ContainsKey("geology_bearing")?(float)Num(node,"geology_bearing")+(R(3)-.5f)*2.3f:R(3)*Mathf.Tau;
        // A continuously warped anisotropic volume, not a ring of identical
        // spheres. Its encoded axis also carries the minor horizontal radius.
        float minor=Math.Max(3,radius*(.20f+.76f*R(6)));
        var majorAxis=new Vector3(Mathf.Cos(bearing),0,Mathf.Sin(bearing));
        if(!Add(p,p+majorAxis*minor,radius,roof,4))return false;
        int count=(int)(R(4)*3);
        float directionBias=R(5);
        for(int k=0;k<count;k++)
        {
            int salt=10+k*7;
            float angle=bearing+(directionBias>.5f?(k%2)*Mathf.Pi+(R(salt)-.5f)*1.25f:k*2.399963f+(R(salt)-.5f)*1.1f);
            var axis=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
            float r=Math.Min(18,Math.Max(3,radius*(.24f+.26f*R(salt+1))));
            float extent=Math.Min(radius-r,core+r*.5f)*(.68f+.32f*R(salt+2));
            if(extent<1)continue;
            float h=Math.Min(roof,Math.Max(4,roof*(.38f+.62f*R(salt+3))));
            var end=p+axis*extent;
            if(R(salt+4)<.52f)
            {
                if(!Add(p+axis*Math.Max(0,extent-r),end,r,h,0))return false;
            }
            else if(!Add(end,end,r,h,2))return false;
        }
        return true;
    }
    internal static bool Compile(CaveField f, A regions, Callable surface, A extraEdges, D assignment)
    {
        f.clear(); f.height = surface;
        if (surface.Delegate == null && (!GodotObject.IsInstanceValid(surface.Target) || !surface.Target!.HasMethod(surface.Method))) return false;
        bool Failed() { f.clear(); return false; }
        var specialized = new A();
        foreach (var item in Arr(assignment, "candidates"))
        {
            var candidate = item.AsGodotDictionary(); string id = Text(candidate, "biome_id");
            if (id == Text(assignment, "fallback", "default")) continue;
            specialized.Add(candidate); f.BiomeFields[id] = new();
        }
        if (specialized.Count > 0) { f._biome_assignment = assignment.Duplicate(); f._biome_assignment["candidates"] = specialized; }
        var edges = extraEdges.Duplicate();
        foreach (var item in regions)
        {
            var region = item.AsGodotDictionary(); if (!Flag(region, "valid")) continue;
            int family = Int(region, "cave_family", -1);
            if (f.enable_thermal_sources && family is not (6 or 7))
                foreach (var source in Arr(region, "cave_thermal_sources")) if (!f.append_thermal_source(source.AsGodotDictionary())) return Failed();
            foreach (var pair in Dict(region, "cave_floor_relief"))
            {
                string id = pair.Key.AsString(); var strength = pair.Value;
                if (!f.BiomeFields.ContainsKey(id) || strength.VariantType is not (Variant.Type.Float or Variant.Type.Int)) return Failed();
                double value = strength.AsDouble(); if (!double.IsFinite(value) || value < 0 || value > 1) return Failed();
                f.floor_relief[id] = Math.Max(Num(f.floor_relief, id), value);
                if (f.floor_relief.Count > 4) return Failed();
            }
            if (f.BiomeFields.Count > 0 && family is 6 or 7) f._biome_locks[region["id"]] = true;
            int style = Int(region, "cross_section_style");
            var regionEdges = Arr(region, "edges").Duplicate(); foreach (var edge in Arr(region, "pocket_passages")) regionEdges.Add(edge);
            foreach(var passage in Arr(region,"fracture_passages"))regionEdges.Add(passage);
            foreach (var raw in regionEdges)
            {
                var edge = raw.AsGodotDictionary(); var decorated = edge.Duplicate(); decorated["cross_section_style"] = Flag(edge, "retain_cross_section_style") ? Int(edge, "cross_section_style", style) : style; edges.Add(decorated);
            }
            foreach(var raw in Arr(region,"vertical_links"))
            {
                var shaft=raw.AsGodotDictionary();
                var low=shaft["bottom"].AsVector3();var high=shaft["top"].AsVector3();
                var size=new Vector2((float)Num(shaft,"radius"),(float)Num(shaft,"headroom"));
                if(!f.append_feature(low,high,size,5,style))return Failed();
                if(f.BiomeFields.Count>0)f.bind_feature_biomes(f.Begins.Count-1,Text(shaft,"from"),Text(shaft,"to"),0,low.DistanceTo(high),low.DistanceTo(high));
                foreach(bool upper in new[]{false,true})
                {
                    var a=shaft[upper?"upper_access":"lower_access"].AsVector3();var b=upper?high:low;
                    if(!f.append_feature(a,b,new Vector2(4,8),0,style))return Failed();
                    string id=Text(shaft,upper?"to":"from");
                    if(f.BiomeFields.Count>0)f.bind_feature_biomes(f.Begins.Count-1,id,id,0,0,0);
                }
            }
            var rooms = Arr(region, "nodes").Duplicate(); foreach (var room in Arr(region, "pockets")) rooms.Add(room);
            foreach (var raw in Arr(region, "pools"))
            {
                var pool = raw.AsGodotDictionary(); var center = pool["center"].AsVector3(); double radius = Num(pool, "radius");
                if (Flag(pool, "precise_shore"))
                {
                    if (f.precise_shores.Count >= 128) return Failed();
                    f.precise_shores.Add(new D { ["center"] = center, ["radius"] = radius });
                }
                if (Flag(pool, "crystal_large_lake") || Flag(pool, "protected_dry_bank"))
                {
                    if (f._protected_shores.Count >= 128) return Failed();
                    f._protected_shores.Add(new D { ["center"] = center, ["inner"] = radius + .75, ["outer"] = radius + 3.25, ["low"] = center.Y - .75, ["high"] = center.Y + 8.0 });
                }
                string parent = Text(pool, "id"); if (parent.EndsWith(":seepage", StringComparison.Ordinal)) parent = parent[..^8];
                var bed = Dict(pool, "bed").Duplicate(); bed["biome_parent"] = parent; rooms.Add(bed);
                foreach (string name in new[] { "bed_lobes", "bank_lobes" })
                    foreach (var lobe in Arr(pool, name)) { var part = lobe.AsGodotDictionary().Duplicate(); part["biome_parent"] = parent; rooms.Add(part); }
                foreach (string name in new[] { "stream_edges", "bank_access" })
                    foreach (var access in Arr(pool, name)) { var part = access.AsGodotDictionary().Duplicate(); part["cross_section_style"] = style; part["biome_parent"] = parent; edges.Add(part); }
            }
            foreach (var raw in rooms)
            {
                var node = raw.AsGodotDictionary(); if (Int(node, "level", -1) < 0) continue;
                var point = node["point"].AsVector3();
                float radius=(float)Num(node,"chamber_radius"), roof=(float)Num(node,"chamber_height");
                if(node.ContainsKey("shape_seed") && region.ContainsKey("cross_section_style"))
                {
                    if(!AddProceduralRoom(f,node,point,radius,roof,Int(node,"cross_section_style",style),region["id"].AsVector2I()))return Failed();
                    continue;
                }
                // Non-procedural helpers (pool beds, specialized chambers and
                // historical fixtures) retain their exact authored footprint.
                // Never infer a second morphology generator from an ID suffix.
                if(!f.append_feature(point,point,new Vector2(radius,roof),2,Int(node,"cross_section_style",style)))return Failed();
                if(f.BiomeFields.Count>0)
                {
                    string id=Text(node,"biome_parent",Text(node,"id"));
                    f.bind_feature_biomes(f.Begins.Count-1,id,id,0,0,0);
                }
            }
        }
        foreach (var raw in edges)
        {
            var edge = raw.AsGodotDictionary(); var points = edge["points"].AsVector3Array(); double length = 0, station = 0;
            var size = new Vector2((float)Num(edge,"half_width"), (float)Num(edge,"headroom"));
            bool varied = edge.ContainsKey("profile_phase");
            bool procedural=Flag(edge,"procedural_profile");
            double phase = Num(edge,"profile_phase");
            if (f.BiomeFields.Count > 0) for (int i = 1; i < points.Length; i++) length += points[i - 1].DistanceTo(points[i]);
            for (int i = 0; i < points.Length - 1; i++)
            {
                var section = size;
                if (varied)
                {
                    var midpoint = (points[i]+points[i+1])*.5f;
                    double bedding = Math.Sin(midpoint.X*.041 + midpoint.Z*.027 + phase);
                    double fissure = Math.Sin(midpoint.Z*.068 - midpoint.X*.035 + phase);
                    // Never shrink the protected return-route section.
                    if(!procedural){section.X *= (float)(.72 + .28*bedding);section.Y *= (float)(.72 + .28*fissure);}
                    else if(!Flag(edge,"entrance"))
                    {
                        section.X*=1+(float)(.10*(1+bedding));
                        section.Y*=1+(float)(.15*(1+fissure));
                    }
                }
                if(varied && !edge.ContainsKey("bypass") && (!Flag(edge,"entrance") || i>5)){
                    double distance=station+points[i].DistanceTo(points[i+1])*.5;
                    float swell=procedural?Mathf.SmoothStep(.42f,.98f,(float)(.63*Math.Sin(distance/(24+phase*4)+phase)+.37*Math.Sin(distance/(8+phase)+phase*2))):Mathf.SmoothStep(.23f,.95f,(float)Math.Sin(distance/(17+phase*2)+phase));
                    if(swell>.03f && !AddGallery(f,edge,points[i],points[i+1],size,swell,phase,Int(edge,"cross_section_style"),station,length))return Failed();
                }
                if (!f.append_feature(points[i], points[i + 1], section, Flag(edge, "entrance") ? 1 : 0, Int(edge, "cross_section_style"))) return Failed();
                int feature = f.Begins.Count - 1;
                if (f.continuous_route_floors)
                {
                    if (i > 0) f.EndpointGrades[feature * 2] = ((double)points[i].Y - points[i - 1].Y) / Math.Max(new Vector2(points[i].X - points[i - 1].X, points[i].Z - points[i - 1].Z).Length(), .000001);
                    if (i + 2 < points.Length) f.EndpointGrades[feature * 2 + 1] = ((double)points[i + 2].Y - points[i + 1].Y) / Math.Max(new Vector2(points[i + 2].X - points[i + 1].X, points[i + 2].Z - points[i + 1].Z).Length(), .000001);
                }
                if (f.BiomeFields.Count == 0)station+=points[i].DistanceTo(points[i+1]);
                else
                {
                    double end = station + points[i].DistanceTo(points[i + 1]); string parent = Text(edge, "biome_parent");
                    f.bind_feature_biomes(feature, parent.Length == 0 ? Text(edge, "from") : parent, parent.Length == 0 ? Text(edge, "to") : parent, station, end, parent.Length == 0 ? length : 0); station = end;
                }
            }
        }
        foreach (var bucket in f.Bins.Values) f.references += bucket.Count;
        f.InvalidatePacked(); return true;
    }
}
