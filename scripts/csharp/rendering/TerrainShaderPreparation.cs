using Godot;
using System;
using System.Threading.Tasks;
using GArray = Godot.Collections.Array;

namespace PredatorIsle.Rendering;

public static class TerrainShaderPreparation
{
    public static async Task<Shader> Prepare(SceneTree tree, Resource settings)
    {
        using var variants = new TerrainShaderVariants();
        var shader = variants.select(GD.Load<Shader>("res://shaders/terrain_biomes.gdshader"), settings)!;
        if (DisplayServer.GetName() == "headless") return shader;
        ulong start = Time.GetTicksUsec();
        var material = new ShaderMaterial { Shader = shader };
        var pixel = Image.CreateEmpty(1, 1, false, Image.Format.Rgba8);
        pixel.Fill(new Color(.5f, .5f, .5f, 1));
        var layers = new Godot.Collections.Array<Image>();
        for (int i = 0; i < 9; i++) layers.Add(pixel);
        var bank = new Texture2DArray();
        if (bank.CreateFromImages(layers) != Error.Ok) throw new InvalidOperationException("Terrain preparation texture creation failed");
        foreach (string name in new[] { "palette_color", "palette_normal", "cliff_ambient_normals", "biological_colors", "mountain_colors", "mountain_normals", "savanna_colors", "savanna_normals", "jungle_colors", "jungle_normals", "forest_colors", "forest_normals", "swamp_colors", "swamp_normals", "beach_colors", "beach_normals" })
            material.SetShaderParameter(name, bank);
        var payload = Image.CreateEmpty(8, 1, false, Image.Format.Rgba8);
        for (int i = 0; i < 8; i++) payload.SetPixel(i, 0, new Color(.125f, .04f, .06f, .03f));
        material.SetShaderParameter("extension_payload", ImageTexture.CreateFromImage(payload));
        material.SetShaderParameter("extension_payload_enabled", true);
        material.SetShaderParameter("extension_active_mask", variants.configured_mask(settings) >> 8);
        material.SetShaderParameter("extension_normals", new float[] { 1, 1, 1, 1, 1, 1, 1, 1 });
        material.SetShaderParameter("extension_emission", new float[8]);
        var arrays = new GArray(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = new Vector3[] { Vector3.Zero, new(0, 0, 256), new(256, 0, 256), new(256, 0, 0) };
        arrays[(int)Mesh.ArrayType.Normal] = new[] { Vector3.Up, Vector3.Up, Vector3.Up, Vector3.Up };
        arrays[(int)Mesh.ArrayType.Color] = new[] { new Color(1, 0, 0, 0), new Color(1, 0, 0, 0), new Color(1, 0, 0, 0), new Color(1, 0, 0, 0) };
        arrays[(int)Mesh.ArrayType.TexUV] = new Vector2[4]; arrays[(int)Mesh.ArrayType.TexUV2] = new Vector2[4];
        arrays[(int)Mesh.ArrayType.Index] = new int[] { 0, 1, 2, 0, 2, 3 };
        Mesh.ArrayFormat flags = 0;
        int[] shifts = { (int)Mesh.ArrayFormat.FormatCustom0Shift, (int)Mesh.ArrayFormat.FormatCustom1Shift, (int)Mesh.ArrayFormat.FormatCustom2Shift, (int)Mesh.ArrayFormat.FormatCustom3Shift };
        for (int i = 0; i < 4; i++)
        {
            arrays[(int)Mesh.ArrayType.Custom0 + i] = new float[16];
            flags |= (Mesh.ArrayFormat)((ulong)Mesh.ArrayCustomFormat.RgbaFloat << shifts[i]);
        }
        var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays, flags: flags); mesh.SurfaceSetMaterial(0, material);
        var viewport = new SubViewport { Size = new Vector2I(32, 32), OwnWorld3D = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
        tree.Root.AddChild(viewport);
        try
        {
            viewport.AddChild(new MeshInstance3D { Mesh = mesh });
            viewport.AddChild(new DirectionalLight3D
            {
                Transform = new Transform3D(new Vector3(.88294756f, .36994863f, -.2890356f), new Vector3(0, .6156615f, .7880107f), new Vector3(.46947157f, -.6957722f, .5435968f), Vector3.Zero),
                LightColor = new Color(1, .94f, .82f), LightEnergy = 1.15f, ShadowEnabled = true, DirectionalShadowMaxDistance = 500
            });
            viewport.AddChild(new WorldEnvironment { Environment = new Godot.Environment
            {
                AmbientLightSource = Godot.Environment.AmbientSource.Color, AmbientLightColor = new Color(.72f, .8f, .9f), AmbientLightEnergy = .45f,
                TonemapMode = Godot.Environment.ToneMapper.Filmic, FogEnabled = true, FogLightColor = new Color(.66f, .74f, .81f), FogDensity = .000035f
            }});
            var camera = new Camera3D { Position = new Vector3(128, 100, 300) }; viewport.AddChild(camera);
            camera.LookAt(new Vector3(128, 0, 128)); camera.Current = true;
            for (int i = 0; i < 8; i++) await tree.ToSignal(tree, SceneTree.SignalName.ProcessFrame);
            await tree.ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            tree.Root.SetMeta("terrain_shader_preparation", new Godot.Collections.Dictionary
            {
                ["shader"] = shader, ["configured_mask"] = variants.configured_mask(settings),
                ["seconds"] = (Time.GetTicksUsec() - start) / 1000000.0,
                ["large_image_banks_loaded_before_preparation"] = ResourceLoader.HasCached("res://materials/terrain.tres")
            });
        }
        finally { viewport.QueueFree(); }
        await tree.ToSignal(tree, SceneTree.SignalName.ProcessFrame);
        await tree.ToSignal(tree, SceneTree.SignalName.ProcessFrame);
        return shader;
    }
}
