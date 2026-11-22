using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using PredatorIsle.Terrain;
namespace PredatorIsle.Checks;

/// <summary>Verifies that shared-corner pool caching preserves the complete mesh.</summary>
internal static class TerrainFeatureOptimizationChecks
{
    internal static void Run(Action<bool,string> require)
    {
        using var legacyField=new TerrainPoolTestField();
        using var optimizedField=new TerrainPoolTestField();
        using var previous=new TerrainFeatureMeshes{builder=legacyField};
        using var current=new TerrainFeatureMeshes{builder=optimizedField};
        using var retained=new RetainedLiquidGeometry();
        var position=Vector2.Zero;const double radius=16;
        var color=new Color(1,.24f,.025f);
        var measurement=retained.measure(legacyField,position,radius);
        require(measurement["retained"].AsBool(),"Synthetic basin failed to retain liquid");
        double level=measurement["surface_y"].AsDouble(),step=radius/12;
        // The original uncached quad algorithm, implemented independently
        // in the test to catch any changed triangle or color ordering.
        for(int z=-12;z<12;z++)for(int x=-12;x<12;x++)
        {
            if(new Vector2(x+.5f,z+.5f).Length()>11.4)continue;
            var vertices=new List<Vector3>();
            foreach(var offset in new[]{new Vector2(x,z),new Vector2(x+1,z),
                new Vector2(x+1,z+1),new Vector2(x,z+1)})
            {
                var p=position+offset*(float)step;
                vertices.Add(new Vector3(p.X,(float)legacyField._get_height(p.X,p.Y),p.Y));
            }
            previous.clipped_liquid(vertices[0],vertices[1],vertices[2],level,color);
            previous.clipped_liquid(vertices[0],vertices[2],vertices[3],level,color);
        }
        require(current.pool(position,radius,color),"Optimized pool rejected a valid basin");
        var expected=previous.arrays();var actual=current.arrays();
        require(expected.Count>0&&actual.Count>0,"Pool fixture emitted no triangles");
        require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),
            "Pool corner caching changed a vertex, normal, color or triangle order");
        require(optimizedField.HeightCalls<legacyField.HeightCalls,
            "Cached liquid pool performed as many height evaluations as legacy");

        // An independent copy of the old clipping algorithm protects triangle
        // winding, threshold comparisons, midpoint precision and intersection
        // order when the hot path switches from a List to stack storage.
        var clipper=new RetainedLiquidGeometry();
        for(int mask=0;mask<8;mask++)
        {
            var a=new Vector3(-2,(mask&1)!=0?8:15,-2);
            var b=new Vector3(3,(mask&2)!=0?8:15,1);
            var c=new Vector3(1,(mask&4)!=0?8:15,4);
            foreach(double clipLevel in new[]{8.0,10.05,11.0,15.0,16.0})
            {
                var expectedClip=ReferenceClip(a,b,c,clipLevel);
                var actualClip=clipper.clipped_polygon(optimizedField,a,b,c,clipLevel);
                require(expectedClip.SequenceEqual(actualClip),
                    "Stack-based liquid clipping changed reference triangle at mask "+mask+" level "+clipLevel);
            }
        }
        Vector3[] ReferenceClip(Vector3 a,Vector3 b,Vector3 c,double level)
        {
            var polygon=new[]{a,b,c};var clipped=new List<Vector3>(6);
            for(int index=0;index<3;index++)
            {
                var p=polygon[index];var q=polygon[(index+1)%3];bool pInside=p.Y<level-.05,qInside=q.Y<level-.05;
                if(pInside)clipped.Add(new Vector3(p.X,(float)level,p.Z));
                if(pInside==qInside)continue;var inside=pInside?p:q;var outside=pInside?q:p;
                for(int iteration=0;iteration<12;iteration++)
                {
                    var mid=(inside+outside)*.5f;
                    if(optimizedField._get_height(mid.X,mid.Z)<level-.05)inside=mid;
                    else outside=mid;
                }
                clipped.Add(new Vector3(inside.X,(float)level,inside.Z));
            }
            return clipped.ToArray();
        }
    }
}
