using Godot;
using System;
using System.Linq;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Numerical GPU-pipeline plumbing. The separate rendered suite tests the shader itself.</summary>
internal static class TerrainGpuPipelineChecks
{
    internal static Godot.Collections.Dictionary Measurements { get; private set; } = new();
    internal static void Run(Node host, Action<bool, string> require)
    {
        using var resources = FixtureResources();
        var policy=new TerrainGpuAdaptivePolicy();
        var policyKey=new TerrainGpuAdaptivePolicy.Key(1,2,16,128);
        using(var baseline=policy.Begin(policyKey)){require(!baseline.UseGpu,"Automatic policy skipped CPU baseline");baseline.Complete(10);}
        using(var cancelled=policy.Begin(policyKey))
        {
            require(cancelled.UseGpu,"Automatic policy never tried GPU");
            using var concurrent=policy.Begin(policyKey);require(!concurrent.UseGpu,"Concurrent calibration started duplicate GPU probes");
        }
        using(var trial=policy.Begin(policyKey)){require(trial.UseGpu,"Cancelled calibration blocked GPU retry");trial.Complete(20);}
        for(int i=0;i<24;i++)using(var slower=policy.Begin(policyKey)){require(!slower.UseGpu,"Automatic policy chose slower GPU");slower.Complete(10);}
        using(var retry=policy.Begin(policyKey)){require(retry.UseGpu,"Automatic policy failed to re-test GPU");retry.Complete(.1);}
        var fastKey=policyKey with{Families=256};
        using(var baseline=policy.Begin(fastKey)){require(!baseline.UseGpu,"Different biome reused timing");baseline.Complete(20);}
        using(var trial=policy.Begin(fastKey)){require(trial.UseGpu,"Missing GPU calibration");trial.Complete(5);}
        using(var faster=policy.Begin(fastKey)){require(faster.UseGpu,"Automatic policy ignored faster GPU");faster.Complete(5);}
        using(var revised=policy.Begin(fastKey with{Revision=2}))require(!revised.UseGpu,"Source revision reused old calibration");
        // Worker-side compact strips and main-thread shader uniforms must
        // share one mapping for every possible eight-family ownership mask.
        for(int mask=0;mask<256;mask++)
        {
            var layout=TerrainExtensionAtlasLayout.FromMask(mask);
            int families=System.Numerics.BitOperations.PopCount((uint)mask);
            require(layout.Mask==mask&&layout.FamilyCount==families&&
                layout.ExtensionStrips==(mask==0?0:families+2)&&
                layout.PaletteSlot==(mask==0?0:families+2),
                "Compact extension atlas dimensions changed for mask "+mask);
            for(int family=0;family<8;family++)
            {
                int expected=(mask&(1<<family))==0?-1:
                    System.Numerics.BitOperations.PopCount((uint)(mask&((1<<family)-1)));
                require(layout.FamilySlots[family]==expected&&
                    layout.PackedWeightSlot(family)==families+family/4,
                    "Compact extension atlas slots diverged from the canonical family mask");
            }
        }
        // The optional shader must use the same numerical field implementation
        // as the fragment shader. The stage-specific encoding appears afterward.
        string fragment=Godot.FileAccess.GetFileAsString("res://shaders/grassland_gpu.gdshader");
        string vertex=Godot.FileAccess.GetFileAsString("res://shaders/grassland_gpu_vertex.gdshader");
        const string stageStart="vec4 encode_scalar(float value)";
        int prefix=fragment.IndexOf(stageStart,StringComparison.Ordinal);
        require(prefix>0&&vertex.StartsWith(fragment[..prefix],StringComparison.Ordinal),
            "Experimental GPU vertex shader diverged from the reference terrain algorithm");

        // Decode sample-major 1x9 strips without involving the graphics device.
        const int columns=16,rows=2,count=21;
        var numericalPixels=new byte[columns*rows*9*4];
        for(int sample=0;sample<count;sample++)
        for(int band=0;band<9;band++)
        {
            float value=sample*13.125f+band*.0625f+1;
            int pixel=(sample/columns*9+band)*columns+sample%columns;
            System.Buffers.Binary.BinaryPrimitives.WriteInt32LittleEndian(
                numericalPixels.AsSpan(pixel*4,4),BitConverter.SingleToInt32Bits(value));
        }
        var decoded=TerrainGpuSampler.Decode(numericalPixels,count,columns,rows,true);
        for(int sample=0;sample<count;sample++)
        for(int band=0;band<9;band++)
            require(decoded[sample*9+band]==sample*13.125f+band*.0625f+1,
                "Vertex-bake readback decoded the wrong sample or scalar band");
        using (var quads=new TerrainGpuVertexQuads())
        {
            var mesh=quads.Get(1300);
            require(ReferenceEquals(mesh,quads.Get(1300))&&quads.CachedTemplates==1,
                "GPU numerical quad topology was unnecessarily rebuilt");
        }
        require(TerrainGpuSampler.SoftwareVulkanVertexUnsupported("forward_plus","llvmpipe (LLVM 20)")&&
                TerrainGpuSampler.SoftwareVulkanVertexUnsupported("mobile","lavapipe")&&
                !TerrainGpuSampler.SoftwareVulkanVertexUnsupported("gl_compatibility","llvmpipe (LLVM 20)")&&
                !TerrainGpuSampler.SoftwareVulkanVertexUnsupported("forward_plus","NVIDIA RTX 3060"),
                "Renderer-specific vertex bake guard incorrectly selected a graphics device");
        foreach (int backend in new[] { 0, 1, 2 })
        {
            require(!ChunkTerrain.UseGpuGeneration(backend, true, "X11", "NVIDIA GeForce RTX 3060"), "Authority selected GPU generation");
            require(!ChunkTerrain.UseGpuGeneration(backend, false, "headless", "NVIDIA GeForce RTX 3060"), "Headless generation awaited a GPU draw");
        }
        require(!ChunkTerrain.UseGpuGeneration(0, false, "X11", "NVIDIA GeForce RTX 3060"), "Explicit CPU generation was overridden");
        require(ChunkTerrain.UseGpuGeneration(1, false, "X11", "llvmpipe"), "Explicit rendered GPU validation was disabled");
        require(ChunkTerrain.UseGpuGeneration(2, false, "X11", "NVIDIA GeForce RTX 3060"), "Hardware Compatibility renderer was excluded");
        foreach (string adapter in new[] { "llvmpipe (LLVM)", "lavapipe", "softpipe", "Google SwiftShader", "Microsoft Basic Render Driver" })
            require(!ChunkTerrain.UseGpuGeneration(2, false, "X11", adapter), "Automatic generation selected a software renderer");

        var settings = resources.Retain(GrassSettings());
        // The GPU's int noise seed can wrap, while the CPU's river and lake
        // planning retains the original long seed. Never share cached raw
        // samples across distinct high-bit world seeds.
        var otherSettings = resources.Retain(GrassSettings());
        using (var seedA=Builder(otherSettings))
        using (var seedB=new TerrainMeshBuilder{settings=otherSettings,world_seed=seedA.world_seed+(1L<<32)})
        {
            seedB._configure_noise();
            var a=GrasslandGpuParameters.Capture(seedA._native_grass);
            var b=GrasslandGpuParameters.Capture(seedB._native_grass);
            require(a is not null&&b is not null&&!a.Equivalent(b),"GPU cache aliased different 64-bit world seeds");
        }
        using var cpu = Builder(settings);
        using var baked = Builder(settings);
        var topology = new TerrainRingTopology();
        var forestOnly = resources.Retain(GrassSettings());
        {
            forestOnly.Set("grass_coverage",0.0);
            forestOnly.Set("forest_coverage",100.0);
            using var noGrass=Builder(forestOnly);
            var skipped=TerrainGpuSamplePlan.Create(noGrass,topology,
                new TerrainRingLayout.Patch(new Vector3I(0,0,2),144,TerrainRingLayout.Mask.None),
                16,true,CancellationToken.None);
            require(skipped.Length==0,
                "GPU planner queued grassland samples for a forest-only world");
        }
        var geometry = new TerrainRingMeshGeometry(topology);
        var patch = new TerrainRingLayout.Patch(new Vector3I(-1, 2, 0), 16, TerrainRingLayout.Mask.None);
        // GPU planning must not bake samples for disabled middle-ring
        // refinement; all required surface and physics points must remain.
        var middle=new TerrainRingLayout.Patch(new Vector3I(0,0,2),144,TerrainRingLayout.Mask.None);
        var enabled=TerrainGpuSamplePlan.Create(baked,topology,middle,16,false,
            CancellationToken.None,true);
        var disabled=TerrainGpuSamplePlan.Create(baked,topology,middle,16,false,
            CancellationToken.None,false);
        require(enabled.Length>disabled.Length&&disabled.All(enabled.Contains),
            "Disabled refinement wasted GPU samples or removed essential coverage");
        var positions = TerrainGpuSamplePlan.Create(baked, topology, patch, 16, true, CancellationToken.None);
        require(positions.Length > 0 && positions.Length <= TerrainGpuSamplePlan.MaximumPoints, "GPU plan was empty or unbounded");
        require(positions.Distinct().Count() == positions.Length, "GPU plan contained duplicate sample positions");
        require(positions.SequenceEqual(TerrainGpuSamplePlan.Create(baked, topology, patch, 16, true, CancellationToken.None)), "GPU plan order changed for the same inputs");
        foreach (var point in positions)
            require(point.IsFinite() && Math.Abs(point.X) <= TerrainGpuSampler.MaximumCoordinate && Math.Abs(point.Y) <= TerrainGpuSampler.MaximumCoordinate, "GPU plan admitted unsupported coordinates");

        // Supply exact CPU field outputs in the same eight-scalar contract as readback.
        // This isolates planning/cache/collision plumbing from shader numerical parity.
        var values = Samples(baked._native_grass, positions);
        var reference = geometry.Build(cpu, patch, 16);
        baked._native_grass.InstallGpuSamples(positions, values);
        baked._native_height.ClearSampleCaches();
        var generated = geometry.Build(baked, patch, 16);
        require(baked._native_grass.GpuSampleHits > 0, "Generated terrain did not consume installed numerical samples");
        require(GD.VarToBytes(reference.Arrays).SequenceEqual(GD.VarToBytes(generated.Arrays)), "Numerical sample installation changed visual terrain products");
        require(GD.VarToBytes(reference.AuthoritativeGround).SequenceEqual(GD.VarToBytes(generated.AuthoritativeGround)), "Numerical sample installation changed authoritative collision ground");
        var vertices = generated.Products!.Vertices;
        var ground = generated.AuthoritativeGround[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var indices = generated.AuthoritativeGround[(int)Mesh.ArrayType.Index].AsInt32Array();
        var faces = generated.Collision["ground_faces"].AsVector3Array();
        require(vertices.SequenceEqual(ground), "One-metre visual and collision vertices used different height samples");
        require(faces.Length == indices.Length, "Collision lost generated ground triangles");
        for (int i = 0; i < faces.Length; i++) require(faces[i] == ground[indices[i]], "Collision triangle differs from its generated ground vertex");
        require(TerrainGpuSamplePlan.Create(baked, topology, patch, 16, true, CancellationToken.None).Length == 0, "Cached numerical samples were unnecessarily resubmitted");

        var grids = new TerrainGpuGrids();
        try
        {
            require(ReferenceEquals(grids.Template(generated.Topology), grids.Template(reference.Topology)), "Generated chunks did not share topology meshes");
        }
        finally { grids.Clear(); }

        var distant = patch with { Key = new Vector3I(1000000, 1000000, 0) };
        require(TerrainGpuSamplePlan.Create(baked, topology, distant, 16, true, CancellationToken.None).Length == 0, "Unsupported world magnitudes were rounded into GPU samples");
        using (var cancelled = new CancellationTokenSource())
        {
            cancelled.Cancel();
            bool rejected = false;
            try { TerrainGpuSamplePlan.Create(baked, topology, patch, 16, true, cancelled.Token); }
            catch (OperationCanceledException) { rejected = true; }
            require(rejected, "Cancelled GPU sample planning continued");
        }

        var field = baked._native_grass;
        var retained = field.sample(positions[0].X, positions[0].Y);
        var invalid = (float[])values.Clone(); invalid[0] += 100; invalid[^1] = float.NaN;
        bool invalidRejected = false;
        try { field.InstallGpuSamples(positions, invalid); }
        catch (ArgumentException) { invalidRejected = true; }
        require(invalidRejected && field.sample(positions[0].X, positions[0].Y) == retained, "Invalid readback partially mutated the numerical cache");
        long hits = field.GpuSampleHits;
        double unsupportedX = positions[0].X + 1.0 / 3.0;
        var arbitrary = field.sample(unsupportedX, positions[0].Y);
        require(field.GpuSampleHits == hits && arbitrary == cpu._native_grass.sample(unsupportedX, positions[0].Y), "An arbitrary authority query was rounded to a nearby GPU sample");

        var full = new Vector2[GrasslandField.GpuSampleCapacity + 1];
        for (int i = 0; i < full.Length; i++) full[i] = new Vector2(5000 + i, -5000);
        field.InstallGpuSamples(full, new float[full.Length * 8]);
        require(!field.HasGpuSample(full[0]) && field.HasGpuSample(full[^1]), "GPU sample cache failed its FIFO bound");
        baked._configure_noise();
        require(!field.HasGpuSample(full[^1]) && field.GpuSampleHits == 0, "Worker reconfiguration retained GPU samples from a previous source");

        if (DisplayServer.GetName() == "headless")
        {
            var sampler = new TerrainGpuSampler(); host.AddChild(sampler);
            try
            {
                require(!sampler.Available, "Headless GPU service became available");
                var request = sampler.SampleAsync(field, new[] { Vector2.Zero });
                require(request.IsCompletedSuccessfully && request.Result is null, "Headless fallback waited for a rendered frame");
                sampler.Shutdown();
            }
            finally { sampler.Free(); }
        }
    }

    internal static async Task RunQueues(Node host, Action<bool, string> require)
    {
        require(DisplayServer.GetName() != "headless", "GPU queue checks require a rendered display");
        using var resources = FixtureResources();
        var settings = resources.Retain(GrassSettings());
        using var builder = Builder(settings);
        var sampler = new TerrainGpuSampler { MaximumQueuedRequests = 2 };
        host.AddChild(sampler); sampler.SetProcess(false);
        try
        {
            require(sampler.Available, "Rendered GPU service was unavailable");
            using var cancellation = new CancellationTokenSource();
            var cancelled = sampler.SampleAsync(builder._native_grass, new[] { Vector2.Zero }, cancellation.Token);
            require(sampler.QueuedRequests == 1 && !cancelled.IsCompleted, "GPU request did not enter the bounded queue");
            cancellation.Cancel();
            require(await cancelled is null, "Cancelled GPU request did not finish without a draw");
            sampler.Shutdown();
            require(sampler.QueuedRequests == 0 && !sampler.Available, "Shutdown retained pending requests");
        }
        finally { sampler.Free(); }

        // Simulate a device that never produces a frame. The request must
        // timeout and unblock the waiting worker without requiring Shutdown().
        sampler = new TerrainGpuSampler { RequestTimeoutSeconds = 1 };
        host.AddChild(sampler); sampler.SetProcess(false);
        try
        {
            var timedOut=sampler.SampleAsync(builder._native_grass,new[]{Vector2.Zero});
            var finished=await Task.WhenAny(timedOut,Task.Delay(4000));
            require(ReferenceEquals(finished,timedOut)&&await timedOut is null,
                "GPU request timeout did not unblock a suspended terrain worker");
        }
        finally { sampler.Shutdown(); sampler.Free(); }

        sampler = new TerrainGpuSampler { MaximumQueuedRequests = 2 };
        host.AddChild(sampler); sampler.SetProcess(false);
        try
        {
            var first = sampler.SampleAsync(builder._native_grass, new[] { Vector2.Zero });
            var second = sampler.SampleAsync(builder._native_grass, new[] { new Vector2(4, 4) });
            var overflow = sampler.SampleAsync(builder._native_grass, new[] { new Vector2(8, 8) });
            require(sampler.QueuedRequests == 2 && !first.IsCompleted && !second.IsCompleted, "GPU queue did not retain exactly its capacity");
            require(overflow.IsCompletedSuccessfully && await overflow is null, "Overflowing GPU queue did not return CPU fallback");
            sampler.Shutdown();
            require(await first is null && await second is null && sampler.QueuedRequests == 0, "Shutdown stranded a numerical generation request");
            require(sampler.Readbacks == 0, "Queue-only checks unexpectedly dispatched graphics work");
        }
        finally { sampler.Free(); }

        sampler = new TerrainGpuSampler(); host.AddChild(sampler); sampler.SetProcess(false);
        var topology = new TerrainRingTopology();
        using var stream = new TerrainRingStream(topology)
        {
            MaximumWorkers = 1,
            ShareSamples = false,
            GpuPreparation = new TerrainGpuPreparation(sampler, topology, false)
        };
        try
        {
            var plan = new TerrainRingLayout(16, 0).Select(Vector2.Zero);
            stream.Request(plan, 16, 1);
            stream.Tick(1, () => Builder(settings));
            var wait = Stopwatch.StartNew();
            while (sampler.QueuedRequests == 0 && wait.Elapsed.TotalSeconds < 5)
                await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
            require(sampler.QueuedRequests > 0 && stream.RunningJobs == 1, "Terrain worker did not suspend on its GPU request");
            var dispose = Stopwatch.StartNew(); stream.Dispose();
            require(dispose.Elapsed.TotalSeconds < 2 && stream.RunningJobs == 0, "Stream disposal waited for a future render instead of cancelling GPU work");
            require(stream.LastError.Length == 0, "Cancelled GPU terrain worker was reported as a generation failure");
            sampler.Shutdown();
            require(sampler.QueuedRequests == 0, "GPU queue retained a disposed stream's request");
        }
        finally { sampler.Shutdown(); sampler.Free(); }
    }

    internal static async Task RunRendered(Node host, Action<bool, string> require)
    {
        require(DisplayServer.GetName() != "headless", "GPU terrain readback checks require a rendered display");
        using var resources = FixtureResources();
        var settings = resources.Retain(GrassSettings());
        using var builder = Builder(settings);
        using var referenceBuilder = Builder(settings);
        var sampler = new TerrainGpuSampler { RequestTimeoutSeconds = 120 };
        host.AddChild(sampler);
        MeshInstance3D? node = null;
        try
        {
            var topology = new TerrainRingTopology();
            var patch = new TerrainRingLayout.Patch(new Vector3I(-1, 2, 0), 16, TerrainRingLayout.Mask.None);
            var preparation = new TerrainGpuPreparation(sampler, topology, false);
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(150));
            var watch = Stopwatch.StartNew();
            var prepared = await preparation.PrepareAsync(builder, patch, 16, timeout.Token);
            double preparationMs = watch.Elapsed.TotalMilliseconds;
            require(prepared.Samples > 0 && !prepared.Rejected, "Actual GPU terrain bake was not accepted: " + sampler.LastFailure);
            var geometry = new TerrainRingMeshGeometry(topology);
            var data = geometry.Build(builder, patch, 16);
            require(builder._native_grass.GpuSampleHits > 0 && sampler.Readbacks > 0, "Terrain did not use actual GPU readback data");
            var ground = data.AuthoritativeGround[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            require(data.Products!.Vertices.SequenceEqual(ground), "GPU visual and collision grids used different heights at the same coordinates");
            var indices = data.AuthoritativeGround[(int)Mesh.ArrayType.Index].AsInt32Array();
            var faces = data.Collision["ground_faces"].AsVector3Array();
            require(faces.Length == indices.Length, "GPU-generated collision lost triangles");
            for (int i = 0; i < faces.Length; i++) require(faces[i] == ground[indices[i]], "GPU collision triangle does not use its heightmap vertex");

            var reference = geometry.Build(referenceBuilder, patch, 16);
            double maximumCpuDifference = 0;
            for (int i = 0; i < ground.Length; i++) maximumCpuDifference = Math.Max(maximumCpuDifference, Math.Abs(ground[i].Y - reference.Products!.Vertices[i].Y));
            require(maximumCpuDifference <= .01, "GPU patch exceeded the CPU authority height budget");

            using var carrier = new ArrayMesh();
            var arrays = new Godot.Collections.Array(); arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = new[] { ground[0], ground[^1], ground[0] };
            carrier.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
            carrier.SetMeta("collision_data", data.Collision);
            node = new MeshInstance3D { Mesh = carrier, Position = new Vector3((float)patch.OriginX, 0, (float)patch.OriginZ) };
            host.AddChild(node);
            using var collision = new TerrainCollision();
            collision.stage(node, patch.Size, 16, true);
            collision.activate(node, true);
            await host.ToSignal(host.GetTree(), SceneTree.SignalName.PhysicsFrame);
            await host.ToSignal(host.GetTree(), SceneTree.SignalName.PhysicsFrame);
            await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
            var local = ground[8 * 17 + 8]; var world = node.ToGlobal(local);
            using var ray = PhysicsRayQueryParameters3D.Create(world + Vector3.Up * 50, world + Vector3.Down * 50, 1);
            var hit = node.GetWorld3D().DirectSpaceState.IntersectRay(ray);
            require(hit.Count > 0, "Jolt did not collide with the GPU-generated heightmap");
            double rayError = hit.Count > 0 ? Math.Abs(hit["position"].AsVector3().Y - world.Y) : double.PositiveInfinity;
            require(rayError <= .01, "Installed physics ground differs from its GPU visual vertex");
            Measurements = new()
            {
                ["samples"] = prepared.Samples,
                ["gpu_sample_hits"] = builder._native_grass.GpuSampleHits,
                ["readbacks"] = sampler.Readbacks,
                ["readback_bytes"] = sampler.ReadbackBytes,
                ["readback_ms"] = sampler.ReadbackMilliseconds,
                ["preparation_ms_including_compile_and_frames"] = preparationMs,
                ["visual_collision_vertices_exact"] = true,
                ["maximum_cpu_height_difference_m"] = maximumCpuDifference,
                ["physics_ray_height_error_m"] = rayError
            };
        }
        finally { node?.Free(); sampler.Shutdown(); sampler.Free(); }
    }

    internal static TerrainBenchmarkResources FixtureResources()
    {
        var resources = new TerrainBenchmarkResources();
        // Builders initially load the saved configuration before a fixture assigns
        // its own settings. Keep both complete resource graphs natively referenced
        // until the last builder and queued worker have been disposed. Otherwise a
        // collection between builders can finalize C# child-resource handles while
        // ResourceLoader is reusing the saved graph.
        resources.Retain(GD.Load<Resource>("res://config/world/terrain_settings.tres"));
        return resources;
    }

    internal static TerrainConfiguration GrassSettings()
    {
        // A self-contained fixture owns its C# resource and all default child settings.
        var settings = new TerrainConfiguration();
        foreach (string biome in new[] { "grass", "forest", "savanna", "swamp", "jungle", "mountain", "tropical", "badlands", "quarry", "wise_mountains", "volcanic", "spore_forest", "radiation_wasteland", "crystal_wastes", "insect_colony", "alien_infected" })
            settings.Set(biome + "_coverage", biome == "grass" ? 100.0 : 0.0);
        settings.alien_infected.Set("overlay_strength", 0.0);
        settings.beaches_enabled = settings.rocky_coast_enabled = false;
        settings.island_size = 100400;
        settings.island_position_jitter = settings.island_size_variation = settings.island_coast_irregularity = 0;
        settings.terrain_shape_scale = 1;
        return settings;
    }

    internal static TerrainMeshBuilder Builder(Resource settings)
    {
        var builder = new TerrainMeshBuilder { settings = settings, world_seed = 73921 };
        builder._configure_noise(); return builder;
    }

    internal static float[] Samples(GrasslandField field, Vector2[] positions)
    {
        var values = new float[positions.Length * 8];
        for (int i = 0; i < positions.Length; i++)
        {
            var value = field.CpuReference(positions[i]); int at = i * 8;
            values[at] = value.Value.X; values[at + 1] = value.Value.Y; values[at + 2] = value.Value.Z;
            values[at + 3] = value.Surface.X; values[at + 4] = value.Surface.Y;
            values[at + 5] = value.Geology.X; values[at + 6] = value.Geology.Y; values[at + 7] = value.Geology.Z;
        }
        return values;
    }
}
