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
