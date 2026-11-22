using Godot;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Runs the actual fragment shader and compares decoded GPU data with the CPU field.</summary>
public static class TerrainGpuSamplerChecks
{
    public static Godot.Collections.Dictionary Measurements {get;private set;}=new();
    public static async Task Run(Node host,Action<bool,string> require)
    {
        // Keep the saved graph and every fixture graph natively referenced until
        // all asynchronous requests and builders have finished. Repeated setup
        // otherwise lets collection finalize shared cached C# resource handles.
        using var resources=TerrainGpuPipelineChecks.FixtureResources();
        require(DisplayServer.GetName()!="headless","GPU sampler checks require a rendered Compatibility viewport.");
        var sampler=new TerrainGpuSampler{RequestTimeoutSeconds=120};host.AddChild(sampler);
        require(sampler.Available,"GPU sampler was not available.");
        var points=new List<Vector2>();
        foreach(var origin in new[]{new Vector2(0,0),new Vector2(-811,721),new Vector2(5100,-8400),new Vector2(27000,17000),new Vector2(16000,-16000),new Vector2(-16000,16000),new Vector2(32744,32744),new Vector2(-32768,-32768)})
            for(int z=0;z<7;z++)for(int x=0;x<7;x++)points.Add(origin+new Vector2(x*3.25f,z*2.5f));
        var random=new Random(7143);
        for(int i=0;i<192;i++)points.Add(new Vector2((float)(random.NextDouble()*65500-32750),(float)(random.NextDouble()*65500-32750)));
        var samples=points.ToArray();
        double maxValueError=0,maxControlError=0,totalCpuMs=0,totalGpuMs=0;
        int compared=0;var gpuTimes=new List<double>();
        try
        {
            foreach(long seed in new long[]{73921,-1789123,2147483711})
            for(int profile=0;profile<2;profile++)
            {
                var settings=resources.Retain(new TerrainConfiguration());
                if(profile==1){settings.grass_field_spacing=2.5;settings.grass_river_frequency=2.25;settings.grass_lake_frequency=1;settings.grass_plateau_frequency=.65;settings.grass_mountain_frequency=.65;settings.grass_mountain_height=750;settings.grass_fractal_strength=18;}

                using var builder=new TerrainMeshBuilder{settings=settings,world_seed=seed};builder._configure_noise();
                var field=builder._native_grass;var expected=new float[samples.Length*8];
                var timer=Stopwatch.StartNew();
                for(int i=0;i<samples.Length;i++)
                {
                    var point=samples[i];var value=field.sample(point.X,point.Y);var surface=field.last_surface;var geology=field.last_geology;
                    expected[i*8]=value.X;expected[i*8+1]=value.Y;expected[i*8+2]=value.Z;
                    expected[i*8+3]=surface.X;expected[i*8+4]=surface.Y;
                    expected[i*8+5]=geology.X;expected[i*8+6]=geology.Y;expected[i*8+7]=geology.Z;
                }
                totalCpuMs+=timer.Elapsed.TotalMilliseconds;
                timer.Restart();
                using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(120));
                var actual=await sampler.SampleAsync(field,samples,timeout.Token);
                totalGpuMs+=timer.Elapsed.TotalMilliseconds;gpuTimes.Add(timer.Elapsed.TotalMilliseconds);
                require(actual is not null,"GPU generation failed: "+sampler.LastFailure);
                require(actual!.Length==expected.Length,"GPU sample count changed.");
                double seedValueError=0,seedControlError=0;
                for(int i=0;i<actual.Length;i++)
                {
                    double error=Math.Abs(actual[i]-expected[i]);
                    if(i%8 is 0 or 2)seedValueError=Math.Max(seedValueError,error);else seedControlError=Math.Max(seedControlError,error);
                    if(error>.01&&(i%8 is 0 or 2))GD.Print($"GPU mismatch seed={seed} profile={profile} point={samples[i/8]} component={i%8} CPU={expected[i]:R} GPU={actual[i]:R} error={error:R}");
                    compared++;
                }
                maxValueError=Math.Max(maxValueError,seedValueError);maxControlError=Math.Max(maxControlError,seedControlError);
                GD.Print($"GPU sampler seed={seed} profile={profile} max value error={seedValueError:R}, control={seedControlError:R}");
            }
            Measurements=new(){["samples"]=samples.Length*6,["scalars_compared"]=compared,["maximum_value_error"]=maxValueError,["maximum_control_error"]=maxControlError,["cpu_sample_ms"]=totalCpuMs,["gpu_request_ms_including_compile_and_frames"]=totalGpuMs,["readback_ms"]=sampler.ReadbackMilliseconds,["readback_bytes"]=sampler.ReadbackBytes,["gpu_request_ms_per_case"]=gpuTimes.ToArray()};
            require(maxValueError<=.01,"GPU grassland heights exceeded the 0.01 m parity budget: "+maxValueError);
            require(maxControlError<=.001,"GPU grassland material controls exceeded the 0.001 parity budget: "+maxControlError);
            using var cancelled=new CancellationTokenSource();cancelled.Cancel();
            var cancellationSettings=resources.Retain(new TerrainConfiguration());using var cancellationBuilder=new TerrainMeshBuilder{settings=cancellationSettings};cancellationBuilder._configure_noise();
            require(await sampler.SampleAsync(cancellationBuilder._native_grass,samples,cancelled.Token) is null,"Cancelled GPU request did not fall back.");
            var fieldForChecks=cancellationBuilder._native_grass;
            long beforeReadbacks=sampler.Readbacks;
            foreach(float coordinate in new[]{100000f,-100000f,1000000f,-1000000f})
                require(await sampler.SampleAsync(fieldForChecks,[new Vector2(coordinate,0)]) is null,"Coordinates outside the validated range did not fall back.");
            require(await sampler.SampleAsync(fieldForChecks,[new Vector2(float.NaN,0)]) is null,"Non-finite coordinate did not fall back.");
            require(sampler.Readbacks==beforeReadbacks,"Unsupported coordinates dispatched graphics work.");
            var fractionalSettings=resources.Retain(new TerrainConfiguration{grass_field_spacing=2.3});
            using var fractionalBuilder=new TerrainMeshBuilder{settings=fractionalSettings};fractionalBuilder._configure_noise();
            require(await sampler.SampleAsync(fractionalBuilder._native_grass,[new Vector2(7.25f,13.5f)]) is null,"Inexact coarse field coordinates did not use the CPU fallback.");
            fieldForChecks.region.NoiseType=FastNoiseLite.NoiseTypeEnum.Perlin;
            require(await sampler.SampleAsync(fieldForChecks,[Vector2.Zero]) is null,"Unsupported noise configuration did not fall back.");
            fieldForChecks.region.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;

            var batchPoints=samples.AsSpan(0,49).ToArray();
            double batchStep=Math.Min(cancellationSettings.grass_field_spacing,Math.Max(1,cancellationSettings.grass_river_width*.25));
            var batchPlan=GrasslandGpuSamplePlan.Create(batchPoints,batchStep)!;
            long previousSamples=sampler.GeneratedRawSamples;beforeReadbacks=sampler.Readbacks;
            var batchTimer=Stopwatch.StartNew();
            // Three ready workers with the same world must share one render and one
            // readback. These submissions happen before yielding to the next frame.
            var batchA=sampler.SampleAsync(fieldForChecks,batchPoints);
            var batchB=sampler.SampleAsync(fieldForChecks,batchPoints);
            var batchC=sampler.SampleAsync(fieldForChecks,batchPoints);
            require(sampler.QueuedRequests==3,"Expected all three requests in the pending batch.");
            var batch=await Task.WhenAll(batchA,batchB,batchC);
            require(batch[0] is not null&&batch[1] is not null&&batch[2] is not null,"Batched GPU request did not complete.");
            require(batch[0]!.AsSpan().SequenceEqual(batch[1])&&batch[0]!.AsSpan().SequenceEqual(batch[2]),"Shared GPU samples changed between workers.");
            require(sampler.Readbacks-beforeReadbacks==1,"Compatible worker requests did not share a single readback.");
            require(sampler.GeneratedRawSamples-previousSamples==batchPlan.RawPositions.Length,"Neighboring requests regenerated duplicate raw samples.");
            // Once decoded, another worker requesting exactly the same raw field
            // must not submit a new draw or readback.
            long cachedReadbacks=sampler.Readbacks;
            var cached=await sampler.SampleAsync(fieldForChecks,batchPoints);
            require(cached is not null&&cached.AsSpan().SequenceEqual(batch[0])&&sampler.Readbacks==cachedReadbacks&&
                    sampler.RawCacheHits>=batchPlan.RawPositions.Length,
                    "Repeated terrain samples bypassed the bounded GPU raw cache.");
            require(sampler.RawCacheEntries<=32768&&sampler.CreatedRenderTargets<=2,
                    "GPU cache or render target count exceeded its configured bound.");
            Measurements["batched_requests"]=3;Measurements["batched_readbacks"]=sampler.Readbacks-beforeReadbacks;
            Measurements["batched_unique_raw_samples"]=sampler.GeneratedRawSamples-previousSamples;
            Measurements["batched_request_ms"]=batchTimer.Elapsed.TotalMilliseconds;
        }
        finally{sampler.Shutdown();sampler.Free();}
    }

    /// <summary>Opt-in real-renderer comparison of numerical vertex and fragment baking.</summary>
    public static async Task RunVertex(Node host,Action<bool,string> require)
    {
        require(DisplayServer.GetName()!="headless","Vertex baking requires a rendered display");
        var renderer=RenderingServer.GetCurrentRenderingMethod();
        var adapter=RenderingServer.GetVideoAdapterName();
        if(TerrainGpuSampler.SoftwareVulkanVertexUnsupported(renderer,adapter))
        {
            var fallback=new TerrainGpuSampler {PreferVertexBake=true};
            host.AddChild(fallback);
            try
            {
                require(fallback.Available&&!fallback.PreferVertexBake&&fallback.VertexBakeFlights==0,
                    "Software Vulkan failed to select its safe fragment-generation fallback");
                Measurements=new()
                {
                    ["renderer"]=renderer,["adapter"]=adapter,
                    ["vertex_bake_skipped_software_vulkan"]=true,
                    ["vertex_bake_flights"]=0
                };
            }
            finally{fallback.Shutdown();fallback.Free();}
            return;
        }
        using var resources=TerrainGpuPipelineChecks.FixtureResources();
        var settings=resources.Retain(new TerrainConfiguration());
        using var builder=TerrainGpuPipelineChecks.Builder(settings);
        var positions=new Vector2[1024];
        for(int i=0;i<positions.Length;i++)
            positions[i]=new Vector2((i%32)*13+.25f,(i/32)*11+.5f);
        var referenceSampler=new TerrainGpuSampler{RequestTimeoutSeconds=120};
        var vertexSampler=new TerrainGpuSampler{RequestTimeoutSeconds=120,PreferVertexBake=true};
        host.AddChild(referenceSampler);host.AddChild(vertexSampler);
        try
        {
            using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(150));
            require(referenceSampler.Available&&vertexSampler.Available&&vertexSampler.PreferVertexBake,
                "The fragment or vertex shader was not available for rendered comparison");
            var reference=await referenceSampler.SampleAsync(builder._native_grass,positions,timeout.Token);
            var accelerated=await vertexSampler.SampleAsync(builder._native_grass,positions,timeout.Token);
            require(reference is not null&&accelerated is not null,
                "Numerical shader stage returned no result: "+vertexSampler.LastFailure);
            require(reference!.Length==accelerated!.Length,"Numerical shader output length changed");
            require(vertexSampler.VertexBakeFlights>0,"Vertex generation shader was not exercised");
            double maximumHeightError=0,maximumControlError=0;
            for(int i=0;i<reference.Length;i++)
            {
                double difference=Math.Abs(reference[i]-accelerated[i]);
                if(i%8 is 0 or 2)maximumHeightError=Math.Max(maximumHeightError,difference);
                else maximumControlError=Math.Max(maximumControlError,difference);
            }
            require(maximumHeightError<=.01&&maximumControlError<=.001,
                $"Vertex and fragment GPU outputs differ: height {maximumHeightError}, controls {maximumControlError}");

            // Match final terrain elevation against independent CPU sampling.
            // The shader's raw profile is not authoritative for physics until
            // this parity gate passes on the actual target GPU.
            using var cpu=TerrainGpuPipelineChecks.Builder(settings);
            double cpuHeightError=0;
            for(int i=0;i<32;i++)
            {
                var v=cpu._native_grass.sample(positions[i].X,positions[i].Y);
                double expected=Math.Max(1,v.X)*(1-v.Y)+v.Z*v.Y;
                int offset=i*8;
                double observed=Math.Max(1,accelerated[offset])*(1-accelerated[offset+1])+
                    accelerated[offset+2]*accelerated[offset+1];
                cpuHeightError=Math.Max(cpuHeightError,Math.Abs(expected-observed));
            }
            require(cpuHeightError<=.01,"Vertex GPU heights exceed CPU reference tolerance: "+cpuHeightError);
            Measurements=new()
            {
                ["samples"]=positions.Length,
                ["vertex_bake_flights"]=vertexSampler.VertexBakeFlights,
                ["fragment_readbacks"]=referenceSampler.Readbacks,
                ["vertex_readbacks"]=vertexSampler.Readbacks,
                ["maximum_gpu_stage_height_error"]=maximumHeightError,
                ["maximum_gpu_stage_control_error"]=maximumControlError,
                ["maximum_cpu_height_error"]=cpuHeightError
            };
        }
        finally
        {
            referenceSampler.Shutdown();vertexSampler.Shutdown();
            referenceSampler.Free();vertexSampler.Free();
        }
    }
}
