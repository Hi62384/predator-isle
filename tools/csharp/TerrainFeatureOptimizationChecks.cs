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
    }
}
