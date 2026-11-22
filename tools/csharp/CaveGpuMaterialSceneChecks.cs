using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Draws the complete maximum-composition entrance shader, including
/// its real vertex interface, cave materials and both projection adapters.</summary>
internal static class CaveGpuMaterialSceneChecks
{
    private static readonly string[] ColorBanks = { "palette_color", "biological_colors", "mountain_colors",
        "savanna_colors", "jungle_colors", "forest_colors", "swamp_colors", "beach_colors", "cave_entry_colors", "cave_frozen_colors" };
    private static readonly string[] NormalBanks = { "palette_normal", "cliff_ambient_normals", "mountain_normals",
        "savanna_normals", "jungle_normals", "forest_normals", "swamp_normals", "beach_normals", "cave_entry_normals", "cave_frozen_normals" };

    internal static async Task<D> Run(Node host, Action<bool, string> require, int selectedCase)
    {
        // Sequential image snapshots must use the same animated material
        // inputs. Rendering/process frames continue while shader TIME is held.
        double previous = Engine.TimeScale;
        try { Engine.TimeScale = 0; return await RunFrozen(host, require, selectedCase); }
        finally { Engine.TimeScale = previous; }
    }
    private static async Task<D> RunFrozen(Node host, Action<bool, string> require, int selectedCase)
    {
        require(DisplayServer.GetName() != "headless", "Complete cave shader checks require an actual rendered display");
        require(selectedCase is >= 0 and < 8, "Unknown complete cave shader case");
        const int output = 32;
        const float span = 8;
        var original = GD.Load<Shader>("res://shaders/terrain_biomes.gdshader");
        var registry = GD.Load<Resource>("res://config/caves/cave_biome_regions.tres");
        bool compareLegacy = RenderingServer.GetCurrentRenderingMethod() == "gl_compatibility";
        using var legacyTerrain = compareLegacy ? new Shader { Code = TerrainGpuMaterialSceneChecks.OriginalVaryings(original.Code) } : null;
        using var colors = TerrainGpuMaterialSamplingChecks.Texture(false);
        using var normals = TerrainGpuMaterialSamplingChecks.Texture(true);
        using var mesh = Mesh(span, true); using var noCaves = Mesh(span, false);
        using var payload = new CaveSurfacePayload();
        var controls = Controls(); var atlas = payload.CompactAtlas(controls);
        using var image = Image.CreateFromData(1024, atlas["height"].AsInt32(), false, Image.Format.Rgbaf, atlas["bytes"].AsByteArray());
        using var texture = ImageTexture.CreateFromImage(image);
        for (int vertex = 0; vertex < 4; vertex++) controls[vertex * 68 + 67] = 0;
        var noEntryAtlas = payload.CompactAtlas(controls);
        using var noEntryImage = Image.CreateFromData(1024, noEntryAtlas["height"].AsInt32(), false, Image.Format.Rgbaf, noEntryAtlas["bytes"].AsByteArray());
        using var noEntryTexture = ImageTexture.CreateFromImage(noEntryImage);
        using var map = Image.CreateEmpty(4, 4, false, Image.Format.Rgba8);
        for (int z = 0; z < 4; z++) for (int x = 0; x < 4; x++)
            map.SetPixel(x, z, new Color(.2f + x * .16f, .25f + z * .13f, .2f + (x + z) * .07f, 1));
        using var mask = ImageTexture.CreateFromImage(map);
        using var empty = Image.CreateEmpty(1, 1, false, Image.Format.Rgbaf);
        empty.Fill(Colors.Transparent);
        using var emptyTexture = ImageTexture.CreateFromImage(empty);
        using var extension = Image.CreateEmpty(8, 1, false, Image.Format.Rgba8);
        extension.Fill(Colors.Transparent); extension.SetPixel(7, 0, new Color(1, .4f, .7f, .5f));
        using var extensionTexture = ImageTexture.CreateFromImage(extension);
        using var environment = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Color, BackgroundColor = Colors.Black,
            AmbientLightSource = Godot.Environment.AmbientSource.Color, AmbientLightColor = Colors.White,
            AmbientLightEnergy = 1, TonemapMode = Godot.Environment.ToneMapper.Linear
        };
        var records = new A(); int maximum = 0, pixels = 0, caseIndex = 0;
        foreach (var ids in new[] { new A(), new A { "frozen", "crystal", "magma" } })
        foreach (bool hive in new[] { false, true })
        foreach (bool common in new[] { false, true })
        {
            if (caseIndex++ != selectedCase) continue;
            string label = (ids.Count == 0 ? "default/" : "triple-mix/") + (hive ? "hive" : "ordinary")
                + (common ? "/shared-projection" : "/standard-projection");
            using var renderer = new CaveSurfaceRenderer(); using var biomes = new CaveBiomeMaterials();
            var retainedShaders = new HashSet<Shader>();
            var baseShader = renderer.shader(original, hive, common);
            if (baseShader is not null) retainedShaders.Add(baseShader);
            var packed = baseShader is null ? null : biomes.shader(baseShader, ids, registry, true);
            require(packed is not null, "Full cave shader composition failed: " + label);
            retainedShaders.Add(packed!);
            Shader reference = packed!;
            if (legacyTerrain is not null)
            {
                var legacyBase = renderer.shader(legacyTerrain, hive, common);
                if (legacyBase is not null) retainedShaders.Add(legacyBase);
                var legacy = legacyBase is null ? null : biomes.shader(legacyBase, ids, registry, true);
                require(legacy is not null, "Original cave varying reference failed: " + label);
                reference = legacy!; retainedShaders.Add(reference);
            }
            try
            {
                // Compile/draw one full spatial program at a time. Readback
                // arrays survive after its viewport and material are released.
                var a = await Draw(reference, mesh, atlas, texture, hive, label);
                if (reference != packed)
                {
                    retainedShaders.Remove(reference); reference.Dispose();
                }
                var b = await Draw(packed!, mesh, atlas, texture, hive, label);
                var negative = await Draw(packed!, noCaves, noEntryAtlas, noEntryTexture, hive, label);
                require(a.Length == output * output * 4 && b.Length == a.Length && negative.Length == a.Length,
                    "Full cave render dimensions changed: " + label);
                int difference = 0, changed = 0, visible = 0; var distinct = new HashSet<uint>();
                for (int i = 0; i < a.Length; i++)
                {
                    difference = Math.Max(difference, Math.Abs(a[i] - b[i]));
                    if (i % 4 != 3 && b[i] > 8) visible++;
                    if (Math.Abs(b[i] - negative[i]) > 2) changed++;
                }
                for (int i = 0; i < b.Length; i += 4)
                    if (b[i] > 8 || b[i + 1] > 8 || b[i + 2] > 8) distinct.Add((uint)(b[i] | b[i + 1] << 8 | b[i + 2] << 16));
                require(visible > output * 4 && distinct.Count > 8, "Complete cave shader did not draw varying visible material: " + label);
                require(changed > output, "Cave shader negative control did not detect the entrance material: " + label);
                require(difference <= 1, "Packed cave varying interpolation changed full spatial output by " + difference + ": " + label);
                maximum = Math.Max(maximum, difference); pixels += output * output;
                records.Add(new D { ["entrance"] = label, ["maximum_byte_difference"] = difference,
                    ["visible_channels"] = visible, ["distinct_colors"] = distinct.Count, ["negative_control_different_channels"] = changed });
                GD.Print("Complete cave spatial shader checked: " + label);
            }
            finally { foreach (var shader in retainedShaders) shader.Dispose(); }
        }
        async Task<byte[]> Draw(Shader shader, ArrayMesh geometry, D activeAtlas, ImageTexture activeTexture, bool hive, string label)
        {
            using var material = new ShaderMaterial { Shader = shader };
            foreach (string name in ColorBanks) material.SetShaderParameter(name, colors);
            foreach (string name in NormalBanks) material.SetShaderParameter(name, normals);
            foreach (string name in new[] { "grass_macro", "meso_mask", "alien_tissue_flow" }) material.SetShaderParameter(name, mask);
            material.SetShaderParameter("cavity_portals", emptyTexture);
            material.SetShaderParameter("terrain_grid_enabled", false);
            material.SetShaderParameter("cave_surface_payload", activeTexture);
            material.SetShaderParameter("cave_surface_texel_mask", activeAtlas["texel_mask"]);
            material.SetShaderParameter("cave_surface_texels", activeAtlas["texels_per_vertex"]);
            material.SetShaderParameter("chunk_size_metres", span);
            material.SetShaderParameter("extension_payload", extensionTexture);
            material.SetShaderParameter("extension_payload_enabled", hive);
            material.SetShaderParameter("extension_active_mask", hive ? 128 : 0);
            material.SetShaderParameter("extension_normals", new float[] { .8f, .8f, .8f, .8f, .8f, .8f, .8f, .8f });
            material.SetShaderParameter("extension_emission", new float[8]);
            material.SetShaderParameter("cave_frozen_texture_metres", 3.1f);
            material.SetShaderParameter("cave_frozen_water_sources", new[] { new Vector4(4, 0, 4, 32), Vector4.Zero,
                Vector4.Zero, Vector4.Zero, Vector4.Zero, Vector4.Zero, Vector4.Zero, Vector4.Zero });
            material.SetShaderParameter("cave_frozen_water_source_count", 1);
            material.SetShaderParameter("debug_view", 0);
            var viewport = new SubViewport
            {
                Size = new Vector2I(output, output), OwnWorld3D = true, TransparentBg = false,
                Msaa3D = Viewport.Msaa.Disabled, UseDebanding = false,
                RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled
            };
            host.AddChild(viewport);
            try
            {
                viewport.AddChild(new WorldEnvironment { Environment = environment });
                viewport.AddChild(new MeshInstance3D { Mesh = geometry, MaterialOverride = material,
                    CastShadow = GeometryInstance3D.ShadowCastingSetting.Off });
                viewport.AddChild(new Camera3D { Projection = Camera3D.ProjectionType.Orthogonal,
                    Size = span * 1.25f, Near = .01f, Far = 80, Position = new Vector3(span * .5f, 20, span * .5f),
                    RotationDegrees = new Vector3(-90, 0, 0), Current = true });
                viewport.AddChild(new DirectionalLight3D { RotationDegrees = new Vector3(-65, -30, 0),
                    LightEnergy = 1, ShadowEnabled = false });
                viewport.RenderTargetUpdateMode = SubViewport.UpdateMode.Always;
                for (int frame = 0; frame < 6; frame++) await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
                using var rendered = viewport.GetTexture().GetImage();
                require(rendered is not null && !rendered.IsEmpty(), "Complete cave shader produced no readback: " + label);
                if (rendered!.GetFormat() != Image.Format.Rgba8) rendered.Convert(Image.Format.Rgba8);
                return rendered.GetData();
            }
            finally { viewport.Free(); }
        }
        GC.KeepAlive(original); GC.KeepAlive(registry);
        require(records.Count == 1, "Selected cave shader case did not produce a complete comparison");
        return new D { ["renderer"] = RenderingServer.GetCurrentRenderingMethod(), ["adapter"] = RenderingServer.GetVideoAdapterName(),
            ["case_index"] = selectedCase, ["entrances"] = records, ["pixels_compared"] = pixels, ["maximum_byte_difference"] = maximum,
            ["compared_original_varying_layout"] = compareLegacy,
            ["scope"] = "One selected complete production spatial shader from the eight-case default/triple-mix, ordinary/hive, standard/shared-projection matrix. Varying vertex weights/depth, synthetic art and a no-cave-influence negative control. Each scene has its own unchanged process time/memory bound." };
    }

    private static ArrayMesh Mesh(float span, bool caveWeights)
    {
        var arrays = new A(); arrays.Resize((int)Godot.Mesh.ArrayType.Max);
        arrays[(int)Godot.Mesh.ArrayType.Vertex] = new[] { Vector3.Zero, new Vector3(span, span * .15f, 0),
            new Vector3(0, span * .05f, span), new Vector3(span, span * .20f, span) };
        arrays[(int)Godot.Mesh.ArrayType.Normal] = Enumerable.Repeat(new Vector3(-.15f, 1, -.05f).Normalized(), 4).ToArray();
        arrays[(int)Godot.Mesh.ArrayType.Color] = Enumerable.Repeat(Colors.White, 4).ToArray();
        arrays[(int)Godot.Mesh.ArrayType.TexUV] = caveWeights ? new[] { new Vector2(.25f, .2f), new Vector2(.4f, .15f),
            new Vector2(.3f, .25f), new Vector2(.35f, .2f) } : new Vector2[4];
        arrays[(int)Godot.Mesh.ArrayType.TexUV2] = caveWeights ? new[] { new Vector2(.15f, 0), new Vector2(.2f, 0),
            new Vector2(.1f, 0), new Vector2(.25f, 0) } : new Vector2[4];
        arrays[(int)Godot.Mesh.ArrayType.Index] = new[] { 0, 1, 2, 1, 3, 2 };
        var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Godot.Mesh.PrimitiveType.Triangles, arrays); return mesh;
    }
    private static float[] Controls()
    {
        var result = new float[68 * 4];
        for (int vertex = 0; vertex < 4; vertex++)
        {
            int at = vertex * 68; float x = vertex % 2, z = vertex / 2;
            result[at] = .25f + x * .15f; result[at + 1] = .5f; result[at + 2] = .15f + z * .1f;
            for (int lane = 26; lane < 38; lane++) result[at + lane] = .2f + ((lane + vertex * 3) % 7) * .08f;
            result[at + 28] = .15f;
            for (int lane = 38; lane < 50; lane++) result[at + lane] = .2f + ((lane + vertex * 5) % 7) * .08f;
            result[at + 40] = .15f;
            result[at + 63] = .7f; result[at + 67] = 2 + x * 3 + z * 4;
        }
        return result;
    }
}
