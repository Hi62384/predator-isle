using Godot;
using System;
using System.Linq;
using System.Threading.Tasks;
using PredatorIsle.Caves;
using PredatorIsle.Terrain;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Real GPU candidate lattice and exact mesh/frontier comparisons
/// for every cave cross-section style, including portal and floor fallback.</summary>
internal static class CaveGpuLatticeChecks
{
    internal static async Task<D> Run(Node host,Action<bool,string> require)
    {
        var gpu=new TerrainBiomeNoiseGpu{ShaderPath=CaveGpuLattice.ShaderPath,TopologyShaderPath=CaveGpuLattice.TopologyShaderPath,RequestTimeoutSeconds=120};
        host.AddChild(gpu);
        try
        {
            require(gpu.TopologyAvailable,"Cave lattice or topology shader unavailable");
            require(CaveGpuLattice.PackCases(0)==0&&CaveGpuLattice.PackCases(255)==0xffffff,
                "Uniform GPU topology cases changed");
            for(int mask=0;mask<256;mask++)
            {
                int packed=CaveGpuLattice.PackCases(mask);
                require((packed^CaveGpuLattice.PackCases(mask^255))==0xffffff,
                    "Complementary tetrahedron case table changed");
            }
            var cases=new A();
            for(int scenario=0;scenario<12;scenario++)
            {
                int style=scenario==11?7:scenario>=8?3:scenario;
                var key=scenario>=10?new Vector3I(-1744,-16,3334):new Vector3I(-2,-1,1);var origin=(Vector3)key*64;
                using var field=new PortalCaveField{maximum_depth=scenario>=10?1200:400,include_surface_air=style==7,opening_rock_cover=style==7?0:6};
                field.height=Callable.From<double,double,double>((x,z)=>100);
                field.top_height=Callable.From<double,double,double>((x,z)=>origin.Y+57);
                if(style==7)field.surface_columns[new Vector2I(key.X,key.Z)]=true;
                var center=origin+new Vector3(32,18,32);
                require(scenario==8?field.append_feature(center,center+new Vector3(11,0,6),new Vector2(17,26),4,style):field.append_feature(center,center,new Vector2(23,27),2,style),
                    "Cave GPU fixture rejected its chamber");
                require(field.append_feature(origin+new Vector3(2,12,9),origin+new Vector3(61,20,45),new Vector2(7,15),1,style),
                    "Cave GPU fixture rejected its route");
                if(scenario==9)require(field.append_feature(center-Vector3.Up*14,center+Vector3.Up*24,new Vector2(5,6),5,style),"GPU fissure rejected");
                if(style==5)field.floor_relief["fixture"]=1.0;
                if(style==6)field.precise_shores.Add(new D{["center"]=center,["radius"]=24.0});
                using var cpu=new PortalCaveMesher{capture_boundary_values=true};
                using var candidate=new PortalCaveMesher{capture_boundary_values=true,GpuLattice=gpu};
                double step=style==7?2:4;
                var original=cpu.build(field,key,step);
                var actual=await Task.Run(()=>candidate.build(field,key,step));
                int cells=(int)(64/step);
                require(candidate.GpuTopologyCubes==cells*cells*cells,
                    "Cave topology GPU stage was not consumed for style "+style+": "+gpu.LastFailure);
                require(candidate.GpuLatticeSamples>0&&candidate.GpuLatticeExactSamples<candidate.GpuLatticeSamples,
                    "Cave GPU style "+style+" fell back or did not save any field samples: "+gpu.LastFailure);
                require(original.Count>0&&GD.VarToBytes(original).SequenceEqual(GD.VarToBytes(actual)),
                    "Cave GPU screening changed exact mesh topology, crossings or normals for style "+style);
                require(GD.VarToBytes(cpu.boundary_values).SequenceEqual(GD.VarToBytes(candidate.boundary_values)),
                    "Cave GPU screening changed exact chunk frontier for style "+style);
                cases.Add(new D{["style"]=style,["warped_room"]=scenario==8,["vertical_fissure"]=scenario==9,["distant_world"]=scenario>=10,["gpu_samples"]=candidate.GpuLatticeSamples,
                    ["cpu_exact_samples"]=candidate.GpuLatticeExactSamples,["gpu_topology_cubes"]=candidate.GpuTopologyCubes});
            }
            return new D{["styles"]=cases,["gpu_topology_scalars"]=gpu.CompletedScalars};
        }
        finally{gpu.Shutdown();gpu.Free();}
    }
}
