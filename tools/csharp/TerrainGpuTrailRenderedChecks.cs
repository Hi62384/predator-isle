using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Actually renders the production curved-trail function with and
/// without its conservative AABB gate on Compatibility and both Vulkan methods.
/// The two materials use one compiled shader and differ in one uniform only.</summary>
internal static class TerrainGpuTrailRenderedChecks
{
    internal static D Measurements{get;private set;}=new();

    internal static async Task Run(Node host,Action<bool,string> require)
    {
        require(DisplayServer.GetName()!="headless",
            "GPU trail parity requires a real rendering backend");
        string terrain=GD.Load<Shader>("res://shaders/terrain_biomes.gdshader").Code;
        int begin=terrain.IndexOf("float path_hash(vec2 p)",StringComparison.Ordinal);
        int end=terrain.IndexOf("// BC5 stores",begin,StringComparison.Ordinal);
        require(begin>=0&&end>begin,"Terrain trail shader segment changed unexpectedly");
        string procedures=terrain[begin..end];
        require(procedures.Contains("if(terrain_trail_bounds)",StringComparison.Ordinal),
            "Trail shader no longer contains its conservative GPU fast path");
        string program=
            "shader_type canvas_item;render_mode unshaded;\n"+
            "uniform bool terrain_trail_bounds=true;\n"+
            "uniform float path_wander_strength=.82;\n"+
            "uniform float path_edge_noise_strength=.48;\n"+
            "uniform float path_edge_noise_metres=7.0;\n"+
            "uniform vec2 test_origin=vec2(0.0);\n"+
            "uniform float test_size=450.0;\n"+
            "uniform float test_width=8.0;\n"+
            procedures+"\n"+
            "void fragment(){vec2 p=test_origin+UV*640.0;\n"+
            "vec2 trail=ground_trail(p,test_size,test_width,4.0,1.5);\n"+
            "COLOR=vec4(clamp(trail,vec2(0.0),vec2(1.0)),0.0,1.0);}\n";
        using var shader=new Shader{Code=program};
        var cases=new (Vector2 Origin,float Size,float Width)[]
        {
            (Vector2.Zero,450f,8f),
            (new Vector2(-2048f,4096f),900f,7f),
            (new Vector2(19200f,-9600f),480f,10f)
        };
        int compared=0,nonzero=0,maximum=0;
        foreach(var entry in cases)
        {
            const int resolution=48;
            var viewports=new List<SubViewport>();
            var materials=new List<ShaderMaterial>();
            try
            {
                foreach(bool optimized in new[]{false,true})
                {
                    var material=new ShaderMaterial{Shader=shader};
                    material.SetShaderParameter("terrain_trail_bounds",optimized);
                    material.SetShaderParameter("test_origin",entry.Origin);
                    material.SetShaderParameter("test_size",entry.Size);
                    material.SetShaderParameter("test_width",entry.Width);
                    var viewport=new SubViewport
                    {
                        Size=new Vector2I(resolution,resolution),Disable3D=true,
                        TransparentBg=false,UseHdr2D=false,UseDebanding=false,
                        Msaa2D=Viewport.Msaa.Disabled,GuiDisableInput=true,
                        RenderTargetClearMode=SubViewport.ClearMode.Always,
                        RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled
                    };
                    host.AddChild(viewport);
                    viewport.AddChild(new ColorRect
                    {
                        Color=Colors.White,Size=new Vector2(resolution,resolution),
                        Material=material,MouseFilter=Control.MouseFilterEnum.Ignore
                    });
                    viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Always;
                    viewports.Add(viewport);materials.Add(material);
                }
                for(int frame=0;frame<6;frame++)
                    await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                using var a=viewports[0].GetTexture().GetImage();
                using var b=viewports[1].GetTexture().GetImage();
                require(a is not null&&!a.IsEmpty()&&b is not null&&!b.IsEmpty(),
                    "GPU curved trail shader failed to produce valid render targets");
                if(a!.GetFormat()!=Image.Format.Rgba8)a.Convert(Image.Format.Rgba8);
                if(b!.GetFormat()!=Image.Format.Rgba8)b.Convert(Image.Format.Rgba8);
                var left=a.GetData();var right=b.GetData();
                require(left.Length==resolution*resolution*4&&right.Length==left.Length,
                    "GPU curved trail readback has wrong dimensions");
                for(int i=0;i<left.Length;i++)
                {
                    int error=Math.Abs(left[i]-right[i]);
                    maximum=Math.Max(maximum,error);
                    if(i%4<2&&left[i]>5)nonzero++;
                }
                compared+=resolution*resolution;
            }
            finally
            {
                foreach(var viewport in viewports)viewport.Free();
                foreach(var material in materials)material.Dispose();
            }
        }
        require(nonzero>20,
            "GPU trail parity did not exercise any visible curved trail segments");
        require(maximum<=1,
            "Conservative GPU trail culling altered the original rendered path mask");
        Measurements=new D
        {
            ["renderer"]=RenderingServer.GetCurrentRenderingMethod(),
            ["cases"]=cases.Length,
            ["pixels_compared"]=compared,
            ["nonzero_trail_channels"]=nonzero,
            ["maximum_rgba8_difference"]=maximum
        };
    }
}
