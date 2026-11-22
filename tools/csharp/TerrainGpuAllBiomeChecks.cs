using Godot;
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Checks the universal GPU visual payload for every surface biome.
/// Numerical GPU baking is a separate, currently grassland-specific backend.
/// GPU grid rendering must preserve all biome controls and physics positions.</summary>
internal static class TerrainGpuAllBiomeChecks
{
    internal static D Measurements {get;private set;}=new();
    private static readonly string[] Names =
    [
        "grass", "forest", "savanna", "swamp", "jungle", "mountain",
        "tropical", "badlands", "quarry", "wise_mountains", "volcanic",
        "spore_forest", "radiation_wasteland", "crystal_wastes",
        "insect_colony", "alien_infected"
    ];

    internal static void Run(Action<bool,string> require,string? onlyBiome=null)
    {
        if(onlyBiome is not null&&Array.IndexOf(Names,onlyBiome)<0)
            throw new ArgumentException("Unknown canonical biome "+onlyBiome,nameof(onlyBiome));
        using var resources=new TerrainBenchmarkResources();
        var topology=new TerrainRingTopology();
        var geometry=new TerrainRingMeshGeometry(topology,false)
            {GenerateShapeRefinement=false};
        var patch=new TerrainRingLayout.Patch(new Vector3I(-1,2,0),16,TerrainRingLayout.Mask.None);
        var templates=new TerrainGpuGrids();
        ArrayMesh? first=null;
        int completed=0;
        var perBiome=new A();
        try
        {
            foreach(string biome in Names)
            {
                if(onlyBiome is not null&&biome!=onlyBiome)continue;
                GD.Print("GPU visual and collision parity for biome: "+biome);
                using var settings=TerrainGpuPipelineChecks.GrassSettings();
                if(biome!="grass")
                {
                    settings.Set("grass_coverage",0.0);
                    settings.Set(biome+"_coverage",100.0);
                }
                resources.Retain(settings);
                using var builder=new TerrainMeshBuilder{settings=settings,world_seed=73921};
                builder._configure_noise();
                long beforeAlloc=GC.GetAllocatedBytesForCurrentThread();
                long start=Stopwatch.GetTimestamp();
                var product=geometry.Build(builder,patch,16);
                double buildMs=(Stopwatch.GetTimestamp()-start)*1000.0/Stopwatch.Frequency;
                long bytes=GC.GetAllocatedBytesForCurrentThread()-beforeAlloc;
                var samples=product.Products;
                require(samples is not null,"GPU visual pipeline lost "+biome+" terrain products");
                var control=samples!;
                int count=product.Topology.VertexCount,rows=product.Topology.Axis.Length;
                var page=TerrainGpuGridPage.Create(control,rows);
                var floats=MemoryMarshal.Cast<byte,float>(page.Bytes.AsSpan());
                require(rows*rows==count&&page.Bytes.Length==count*7*4*sizeof(float),
                    "GPU "+biome+" payload dimensions or byte count changed");
                // Extension control bytes retain their original eight strips.
                // Two packed weight strips must match every family at every
                // atlas coordinate, including zero and mixed ownership.
                if(product.ExtensionMask!=0)
                {
                    require(product.ExtensionRows>0,"GPU "+biome+" active extension lacks atlas rows");
                    int width=product.ExtensionData.Length/(product.ExtensionRows*4),
                        stripCount=width/product.ExtensionRows;
                    require(stripCount==10||stripCount==11,
                        "GPU "+biome+" extension atlas is missing packed weights");
                    require(product.BadlandsSlot==(stripCount==11?10:-1),
                        "GPU "+biome+" badlands palette overlaps packed weights");
                    for(int z=0;z<product.ExtensionRows;z++)
                    for(int x=0;x<product.ExtensionRows;x++)
                    for(int family=0;family<8;family++)
                    {
                        int original=(z*width+family*product.ExtensionRows+x)*4;
                        int packed=(z*width+(8+family/4)*product.ExtensionRows+x)*4+family%4;
                        require(product.ExtensionData[original]==product.ExtensionData[packed],
                            "GPU "+biome+" extension weight encoding mismatch at "+x+","+z+"/"+family);
                    }
                }
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
                perBiome.Add(new D
                {
                    ["biome"]=biome,["build_ms"]=buildMs,
                    ["managed_allocated_bytes"]=bytes,
                    ["canonical_evaluations"]=builder._native_height.CanonicalEvaluations,
                    ["vertex_count"]=count
                });
                require(ReferenceEquals(templates.Template(product.Topology),shared),
                    "GPU "+biome+" shared topology changed between repeated requests");
            }
            require(completed==(onlyBiome is null?Names.Length:1),
                "Requested surface biome GPU payload cases were not checked");
            Measurements=new D
            {
                ["biome_scope"]=onlyBiome??"all",
                ["records"]=perBiome,
                ["scope"]="Cold canonical terrain+feature+collision products for one 16m patch, after builder configuration and JIT startup; not GPU time, FPS or renderer readback"
            };
        }
        finally{templates.Clear();}
    }
}
