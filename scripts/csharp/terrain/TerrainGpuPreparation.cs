using Godot;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace PredatorIsle.Terrain;

/// <summary>Connects a GPU numerical bake to the existing authoritative terrain products.</summary>
internal sealed class TerrainGpuPreparation
{
    internal readonly record struct Result(int Samples,bool Rejected,double MaximumHeightError);
    private readonly TerrainGpuSampler sampler;
    private readonly TerrainRingTopology topology;
    private readonly bool filterDistant;
    private readonly bool automatic,includeShapeRefinement;
    internal TerrainGpuPreparation(TerrainGpuSampler gpu,TerrainRingTopology sharedTopology,
        bool filteredDistant,bool automaticSelection=false,bool shapeRefinement=true)
    {sampler=gpu;topology=sharedTopology;filterDistant=filteredDistant;automatic=automaticSelection;
        includeShapeRefinement=shapeRefinement;}

    internal async Task<Result> PrepareAsync(TerrainMeshBuilder builder,TerrainRingLayout.Patch patch,int resolution,CancellationToken cancellation)
    {
        if(!sampler.Available)return default;
        // A tiny nearby grid already shares a very small set of cached 4 m field
        // nodes. Avoid adding a render/readback round trip to its physics readiness.
        if(automatic&&patch.Size/resolution<4)return default;
        var positions=TerrainGpuSamplePlan.Create(builder,topology,patch,resolution,filterDistant,
            cancellation,includeShapeRefinement);
        if(positions.Length==0)return default;
        if(automatic&&positions.Length<1024)return default;
        var values=await sampler.SampleAsync(builder._native_grass,positions,cancellation).ConfigureAwait(false);
        cancellation.ThrowIfCancellationRequested();
        if(values is null)return default;
        if(values.Length!=positions.Length*8)return new(0,true,double.PositiveInfinity);

        // Catch format/color-space/driver errors before any generated data is installed.
        // These sentinels complement the full native CPU/GPU differential test suite;
        // they are not a substitute for validating every supported shader operation.
        double multiplier=Math.Max(builder.settings.Get("height_multiplier").AsDouble(),.01),maximumError=0;
        int checks=Math.Min(9,positions.Length);
        for(int check=0;check<checks;check++)
        {
            cancellation.ThrowIfCancellationRequested();
            int index=checks==1?0:(int)((long)check*(positions.Length-1)/(checks-1)),at=index*8;
            var reference=builder._native_grass.CpuReference(positions[index]);
            var value=new Vector3(values[at],values[at+1],values[at+2]);
            double error=Math.Abs(Land(reference.Value)-Land(value))*multiplier;
            maximumError=Math.Max(maximumError,error);
            var surface=new Vector2(values[at+3],values[at+4]);
            var geology=new Vector3(values[at+5],values[at+6],values[at+7]);
            if(!value.IsFinite()||!surface.IsFinite()||!geology.IsFinite()||error>.005||
                surface.DistanceTo(reference.Surface)>.001||geology.DistanceTo(reference.Geology)>.001)
            {
                sampler.RejectNumericalResults();
                return new(0,true,maximumError);
            }
        }
        cancellation.ThrowIfCancellationRequested();
        sampler.AcceptNumericalResults();
        builder._native_grass.InstallGpuSamples(positions,values);
        // Cached final CPU heights must not conceal newly baked input samples. Within
        // this build, the visual mesh and physics grid share this same numerical field.
        builder._native_height.ClearSampleCaches();
        return new(positions.Length,false,maximumError);
    }
    private static double Land(Vector3 sample)=>Math.Max(1,sample.X)+(sample.Z-Math.Max(1,sample.X))*sample.Y;
}
