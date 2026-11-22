using Godot;
using System;
using System.Text;
using System.Threading.Tasks;
using PredatorIsle.Caves;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Executes the production cave vertex fetches and compares every control lane.</summary>
internal static class CaveGpuPayloadRenderedChecks
{
    internal static D Measurements { get; private set; } = new();
    internal static async Task Run(Node host, Action<bool, string> require)
    {
        require(DisplayServer.GetName() != "headless", "Cave GPU payload check requires an actual rendered display");
        using var payload = new CaveSurfacePayload(); using var source = new CaveSurfaceShader();
        using var legacyShader = new Shader { Code = ShaderSource(source.load_texels(), false) };
        using var packedShader = new Shader { Code = ShaderSource(CaveSurfaceShader.CompactTexels(), true) };
        int cases = 0, maximumDifference = 0;
        foreach (int mask in new[] { 0, 1, 1 << 16, 0x15555, 0xAAAA, (1 << 17) - 1 })
        {
            // Canvas rectangles have four vertices. Vary their source values to
            // cover per-vertex stride addressing as well as every texel/lane.
            var values = CaveGpuPayloadChecks.Values(4, mask);
            var full = payload.atlas(values); var compact = payload.CompactAtlas(values);
            using var fullImage = Image.CreateFromData(CaveSurfacePayload.Width, full["height"].AsInt32(), false, Image.Format.Rgbaf, full["bytes"].AsByteArray());
            using var compactImage = Image.CreateFromData(CaveSurfacePayload.Width, compact["height"].AsInt32(), false, Image.Format.Rgbaf, compact["bytes"].AsByteArray());
            using var fullTexture = ImageTexture.CreateFromImage(fullImage);
            using var compactTexture = ImageTexture.CreateFromImage(compactImage);
            using var fullMaterial = new ShaderMaterial { Shader = legacyShader };
            using var compactMaterial = new ShaderMaterial { Shader = packedShader };
            fullMaterial.SetShaderParameter("cave_surface_payload", fullTexture);
            compactMaterial.SetShaderParameter("cave_surface_payload", compactTexture);
            compactMaterial.SetShaderParameter("cave_surface_texel_mask", mask);
            compactMaterial.SetShaderParameter("cave_surface_texels", compact["texels_per_vertex"]);
            var fullViewport = Viewport(host, fullMaterial); var compactViewport = Viewport(host, compactMaterial);
            try
            {
                for (int warm = 0; warm < 6; warm++) await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
                for (int texel = 0; texel < 17; texel++)
                for (int rotated = 0; rotated < 2; rotated++)
                {
                    fullMaterial.SetShaderParameter("selected_texel", texel); compactMaterial.SetShaderParameter("selected_texel", texel);
                    fullMaterial.SetShaderParameter("rotate_lanes", rotated != 0); compactMaterial.SetShaderParameter("rotate_lanes", rotated != 0);
                    // Rendering-server updates are queued; cross two process
                    // frames before reading both completed render targets.
                    for (int frame = 0; frame < 2; frame++) await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
                    using var expected = fullViewport.GetTexture().GetImage(); using var actual = compactViewport.GetTexture().GetImage();
                    require(expected != null && actual != null && !expected.IsEmpty() && !actual.IsEmpty(), "Cave GPU payload image is empty");
                    if (expected!.GetFormat() != Image.Format.Rgba8) expected.Convert(Image.Format.Rgba8);
                    if (actual!.GetFormat() != Image.Format.Rgba8) actual.Convert(Image.Format.Rgba8);
                    var a = expected.GetData(); var b = actual.GetData();
                    require(a.Length == 24 * 24 * 4 && b.Length == a.Length, "Cave GPU payload render dimensions differ");
                    int signal = 0, difference = 0;
                    for (int i = 0; i < a.Length; i++)
                    {
                        difference = Math.Max(difference, Math.Abs(a[i] - b[i]));
                        if (i % 4 != 3 && a[i] > 2) signal++;
                    }
                    require(difference <= 1, $"Cave GPU compact payload differs: mask {mask}, texel {texel}, lane rotation {rotated}, delta {difference}");
                    require((mask & (1 << texel)) == 0 ? signal == 0 : signal > 24,
                        "Cave GPU comparison did not render the expected active/inactive control bank");
                    maximumDifference = Math.Max(maximumDifference, difference); cases++;
                }
            }
            finally { fullViewport.Free(); compactViewport.Free(); }
        }
        Measurements = new D
        {
            ["renderer"] = RenderingServer.GetCurrentRenderingMethod(), ["adapter"] = RenderingServer.GetVideoAdapterName(),
            ["rendered_cases"] = cases, ["compared_control_lanes"] = 68,
            ["maximum_rgba8_byte_difference"] = maximumDifference,
            ["scope"] = "Actual production cave vertex texel reads; full and compact RGBA32F input, all 68 lanes"
        };
    }
    private static SubViewport Viewport(Node host, ShaderMaterial material)
    {
        var viewport = new SubViewport
        {
            Size = new Vector2I(24, 24), Disable3D = true, TransparentBg = false, UseHdr2D = false,
            UseDebanding = false, Msaa2D = Godot.Viewport.Msaa.Disabled, GuiDisableInput = true,
            RenderTargetClearMode = SubViewport.ClearMode.Always, RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled
        };
        host.AddChild(viewport);
        viewport.AddChild(new ColorRect { Color = Colors.White, Size = new Vector2(24, 24), Material = material, MouseFilter = Control.MouseFilterEnum.Ignore });
        viewport.RenderTargetUpdateMode = SubViewport.UpdateMode.Always;
        return viewport;
    }
    private static string ShaderSource(string fetches, bool compact)
    {
        var code = new StringBuilder("shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\nuniform sampler2D cave_surface_payload:filter_nearest,repeat_disable;\nuniform int selected_texel=0;\nuniform bool rotate_lanes=false;\nvarying vec4 test_controls;\n");
        if (compact) code.Append(CaveSurfaceShader.CompactUniforms);
        code.Append("void vertex(){\n").Append(fetches).Append(" test_controls=surface_p0;\n");
        for (int texel = 1; texel < 17; texel++) code.Append($" if(selected_texel=={texel})test_controls=surface_p{texel};\n");
        return code.Append("}\nvoid fragment(){COLOR=vec4(rotate_lanes?test_controls.yzw:test_controls.xyz,1.0);}\n").ToString();
    }
}
