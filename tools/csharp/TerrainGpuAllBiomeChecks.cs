using Godot;
using System;
using System.Runtime.InteropServices;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Checks the universal GPU visual payload for every surface biome.
/// Numerical GPU baking is a separate, currently grassland-specific backend.
/// GPU grid rendering must preserve all biome controls and physics positions.</summary>
internal static class TerrainGpuAllBiomeChecks
{
    private static readonly string[] Names =
    [
        "grass", "forest", "savanna", "swamp", "jungle", "mountain",
        "tropical", "badlands", "quarry", "wise_mountains", "volcanic",
        "spore_forest", "radiation_wasteland", "crystal_wastes",
        "insect_colony", "alien_infected"
    ];

    internal static void Run(Action<bool,string> require)
    {
        var topology=new TerrainRingTopology();
        var geometry=new TerrainRingMeshGeometry(topology,false)
            {GenerateShapeRefinement=false};
        var patch=new TerrainRingLayout.Patch(new Vector3I(-1,2,0),16,TerrainRingLayout.Mask.None);
        var templates=new TerrainGpuGrids();
        ArrayMesh? first=null;
        int completed=0;
        try
        {
            foreach(string biome in Names)
            {
                using var settings=TerrainGpuPipelineChecks.GrassSettings();
                if(biome!="grass")
                {
                    settings.Set("grass_coverage",0.0);
                    settings.Set(biome+"_coverage",100.0);
                }
                using var builder=TerrainGpuPipelineChecks.Builder(settings);
                var product=geometry.Build(builder,patch,16);
                var samples=product.Products;
                require(samples is not null,"GPU visual pipeline lost "+biome+" terrain products");
                var control=samples!;
                int count=product.Topology.VertexCount,rows=product.Topology.Axis.Length;
                var page=TerrainGpuGridPage.Create(control,rows);
                var floats=MemoryMarshal.Cast<byte,float>(page.Bytes.AsSpan());
                require(rows*rows==count&&page.Bytes.Length==count*7*4*sizeof(float),
                    "GPU "+biome+" payload dimensions or byte count changed");
                var surface=product.AuthoritativeGround[(int)Mesh.ArrayType.Vertex].AsVector3Array();
                require(surface.Length==count,"GPU "+biome+" mode changed authoritative near-collision grid");
                var shared=templates.Template(product.Topology);
                first??=shared;
                require(ReferenceEquals(first,shared),"GPU "+biome+" mesh failed to share grid topology");

                for(int i=0;i<count;i++)
                {
                    int pixel=i*4;
                    require(float.IsFinite(control.Vertices[i].Y)&&
                        control.Vertices[i].Y==surface[i].Y&&
                        floats[pixel+3]==control.Vertices[i].Y,
                        "GPU "+biome+" displacement and collision mismatch at "+i);
                    require(floats[pixel]==control.Normals[i].X&&
                        floats[pixel+1]==control.Normals[i].Y&&
                        floats[pixel+2]==control.Normals[i].Z,
                        "GPU "+biome+" per-vertex normal mismatch at "+i);
                    require(floats[(2*count+i)*4]==control.Uv[i].X&&
                        floats[(2*count+i)*4+1]==control.Uv[i].Y&&
                        floats[(2*count+i)*4+2]==control.Surface[i].X&&
                        floats[(2*count+i)*4+3]==control.Surface[i].Y,
                        "GPU "+biome+" material UV mismatch at "+i);
                }
                for(int band=0;band<4;band++)
                {
                    float[] expected=band switch
                        {0=>control.C0,1=>control.C1,2=>control.C2,_=>control.C3};
                    require(expected.Length==count*4,
                        "GPU "+biome+" control bank length changed");
                    for(int i=0;i<expected.Length;i++)
                        require(floats[(band+3)*count*4+i]==expected[i],
                            "GPU "+biome+" lost material control bank "+band+" at "+i);
                }
                completed++;
            }
            require(completed==Names.Length,
                "All surface biome GPU payload cases were not checked");
        }
        finally{templates.Clear();}
    }
}
