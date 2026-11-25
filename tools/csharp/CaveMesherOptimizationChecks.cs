using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Protects exact canonical cave output while eliminating repeated
/// protected-shore probes across the tetrahedral faces of every cave biome.</summary>
internal static class CaveMesherOptimizationChecks
{
    internal static void Run(Action<bool,string> require)
    {
        using var field=new CaveField();
        var height=Callable.From<double,double,double>((x,z)=>200);
        require(field.compile(new A(),height),"Cave optimization fixture failed to configure");
        require(field.append_feature(new Vector3(32,22,32),new Vector3(32,22,32),
            new Vector2(23,32),2,3),"Cave optimization fixture rejected chamber");
        field.precise_shores.Add(new D
        {
            ["center"]=new Vector3(32,22,32),
            ["radius"]=30.0
        });

        using var optimized=new CaveMesher();
        using var reference=GD.Load<GDScript>("res://scripts/caves/mesher.gd").New().AsGodotObject();
        // The mesher uses exactly the same input scalars, winding and shader
        // material geometry as the reference GDScript. GPU cave rendering uses
        // this immutable mesh without changing physics topology.
        var expected=reference.Call("build",field,Vector3I.Zero,4.0).AsGodotArray();
        var actual=optimized.build(field,Vector3I.Zero,4);
        require(expected.Count>0&&actual.Count>0,"Cave fixture did not produce a surface");
        require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),
            "Cached shore intersections changed canonical cave surface geometry");
        require(optimized.RefinedEvaluations>0&&optimized.RefinedCacheHits>0,
            "Test did not exercise reusable protected-shore intersections");

        var after=optimized.build(field,Vector3I.Zero,4);
        require(GD.VarToBytes(actual).SequenceEqual(GD.VarToBytes(after)),
            "Rebuilding the same cave mesh with a recycled mesher changed results");
        require(optimized.RefinedCacheHits>0,
            "Reusable cave mesher failed to reset and rebuild its per-chunk edge cache");

        // Check the regular-lattice reconstruction at nonzero, negative chunk
        // coordinates for all canonical cross-section styles. The two-metre
        // case also compares every captured frontier scalar.
        var chunk=new Vector3I(-3,-1,2);
        for(int style=0;style<8;style++)
        {
            using var styled=new CaveField();
            styled.height=Callable.From<double,double,double>((x,z)=>200);
            var center=(Vector3)chunk*64+new Vector3(32,22,32);
            require(styled.append_feature(center,center,new Vector2(23,32),2,style),
                "Cave cross-section fixture failed to create its chamber");
            double step=style==7?2:4;
            optimized.capture_boundary_values=true;
            reference.Set("capture_boundary_values",true);
            var original=reference.Call("build",styled,chunk,step).AsGodotArray();
            var candidate=optimized.build(styled,chunk,step);
            require(original.Count>0&&GD.VarToBytes(original).SequenceEqual(GD.VarToBytes(candidate)),
                "Reconstructed cave lattice changed style "+style+" geometry");
            require(GD.VarToBytes(reference.Get("boundary_values")).SequenceEqual(GD.VarToBytes(optimized.boundary_values)),
                "Reconstructed cave lattice changed frontier scalars for style "+style);
        }

        // A portal cave's canonical scalar is min(tunnel SDF, surface-Y).
        // The surface is constant along each vertical lattice column. The
        // new mesher must produce exactly the same triangles and normals as
        // the reference after reusing that scalar at all Y coordinates.
        using(var portal=new PortalCaveField{include_surface_air=true})
        {
            portal.height=Callable.From<double,double,double>((x,z)=>180);
            portal.top_height=Callable.From<double,double,double>((x,z)=>180);
            require(portal.append_feature(new Vector3(32,28,32),new Vector3(32,28,32),
                new Vector2(24,32),2,0),
                "Portal cave column fixture failed to create its chamber");
            using var portalReference=GD.Load<GDScript>("res://scripts/caves/portal_mesher.gd").New().AsGodotObject();
            using var portalNative=new PortalCaveMesher();
            var originalMesh=portalReference.Call("build",portal,Vector3I.Zero,4.0).AsGodotArray();
            var cachedMesh=portalNative.build(portal,Vector3I.Zero,4);
            require(originalMesh.Count>0&&
                GD.VarToBytes(originalMesh).SequenceEqual(GD.VarToBytes(cachedMesh)),
                "Cave portal surface-column reuse changed canonical mesh vertices or normals");
            const int axis=17;
            require(portalNative.SurfaceColumnEvaluations==axis*axis&&
                portalNative.SurfaceColumnReuseHits==axis*axis*(axis-1),
                "Native portal cave recomputed surface heights for each vertical voxel");
            portal.include_surface_air=false;
            portalNative.build(portal,Vector3I.Zero,4);
            require(portalNative.SurfaceColumnEvaluations==0&&
                portalNative.SurfaceColumnReuseHits==0,
                "Portal field without surface air incorrectly used the column fast path");
        }
        // Independent adversarial checks of every sign certificate. These
        // cover mixed route/chamber fields, floor relief, roof/depth limits,
        // negative coordinates and all eight styles without a renderer.
        var random=new Random(9167);
        int certified=0,unknown=0;
        using(var signs=new PortalCaveField{include_surface_air=true,minimum_roof=9,maximum_depth=100,opening_rock_cover=4})
        {
            signs.height=Callable.From<double,double,double>((x,z)=>35+x*.01);
            signs.top_height=Callable.From<double,double,double>((x,z)=>38+z*.01);
            for(int style=0;style<8;style++)
            {
                var begin=new Vector3(-15+style*4,-20+style,8);
                require(signs.append_feature(begin,begin+new Vector3(12,3,17),new Vector2(4+style,9),style%2,style),
                    "Certificate route fixture was rejected");
                require(signs.append_feature(begin,begin,new Vector2(9,12),2,style),
                    "Certificate chamber fixture was rejected");
            }
            signs.floor_relief["unregistered_fixture"]=1.0;
            for(int i=0;i<12000;i++)
            {
                var p=new Vector3((float)(random.NextDouble()*100-50),(float)(random.NextDouble()*110-70),(float)(random.NextDouble()*100-40));
                double top=signs.SurfaceHeight(new Vector2(p.X,p.Z)),ground=signs.ground_height(p);
                bool? value=CaveFieldEvaluation.CertifySign(signs,p,ground,top);
                if(!value.HasValue){unknown++;continue;}
                certified++;
                require(value.Value==((float)signs.sample(p)<0),"Conservative cave sign certificate disagreed with canonical SDF at "+p);
            }
        }
        require(certified>1000&&unknown>0,"Cave sign certificate fixture did not exercise both direct and uncertain paths");

        // All cave biome fields share this surface-height memo. Filling the
        // capacity must evict the oldest column, not throw away the entire hot set.
        int probes=0;
        using var heightField=new CaveField();
        heightField.height=Callable.From<double,double,double>((x,z)=>{probes++;return x*.25+z;});
        for(int x=0;x<8192;x++)
            require(heightField.ground_height(new Vector3(x,0,0))==x*.25,
                "Cave column memo changed the authoritative sample at "+x);
        require(probes==8192,"Cave memo re-evaluated an already seen column");
        require(heightField.ground_height(new Vector3(8191,100,0))==8191*.25&&probes==8192,
            "Cave memo failed to share a column across Y coordinates");
        heightField.ground_height(new Vector3(8192,0,0));
        require(heightField.ground_height(new Vector3(8191,100,0))==8191*.25&&probes==8193,
            "Cave memo evicted all live columns at the capacity boundary");
        heightField.ground_height(new Vector3(0,0,0));
        require(probes==8194,"Cave memo did not evict the oldest column");
        heightField.clear();
        heightField.ground_height(new Vector3(8191,0,0));
        require(probes==8195,"Cave memo retained values across a field clear");
    }
}
