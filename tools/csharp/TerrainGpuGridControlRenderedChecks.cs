using Godot;
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using D=Godot.Collections.Dictionary;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Tests actual nearest RGBA32F reads from the same masked control-bank
/// include used by the shared terrain shader, on Compatibility and Vulkan.</summary>
internal static class TerrainGpuGridControlRenderedChecks
{
    internal static D Measurements {get;private set;}=new();

    // Keep byref-like spans in a synchronous method: the check itself awaits
    // GPU render frames and targets a non-preview C# language version.
    private static byte[] ExpandCanonicalSevenBandPage(TerrainGpuGridPage page,float[][] controls)
    {
        int vertices=checked(page.Rows*page.Rows);
        var bytes=new byte[checked(vertices*7*16)];
        page.Bytes.AsSpan(0,vertices*16).CopyTo(bytes);
        page.Bytes.AsSpan((page.BaseBands-1)*vertices*16,vertices*16)
            .CopyTo(bytes.AsSpan(vertices*2*16));
        var floats=MemoryMarshal.Cast<byte,float>(bytes.AsSpan());
        if(page.HasConstantColor)
        {
            for(int i=0;i<vertices;i++)for(int channel=0;channel<4;channel++)
                floats[(vertices+i)*4+channel]=page.ConstantColor[channel];
        }
        else page.Bytes.AsSpan(vertices*16,vertices*16).CopyTo(bytes.AsSpan(vertices*16));
        for(int bank=0;bank<4;bank++)
            controls[bank].AsSpan().CopyTo(floats.Slice((bank+3)*vertices*4,vertices*4));
        return bytes;
    }

    internal static async Task Run(Node host,Action<bool,string> require)
    {
        require(DisplayServer.GetName()!="headless",
            "GPU control-bank read validation requires a rendered display");
        var shader=GD.Load<Shader>("res://shaders/terrain_grid_control_validation.gdshader");
        require(shader is not null,"GPU control-bank test shader is missing");
        const int output=48;
        int cases=0,activeCases=0,maximumDifference=0;
        foreach(int expectedMask in new[]{0,1,2,4,8,5,10,15})
        foreach(bool constantColor in new[]{false,true})
        foreach(int product in new[]{0,1,2})
        {
            var components=new float[4][];
            for(int bank=0;bank<4;bank++)
            {
                components[bank]=new float[16];
                if((expectedMask&(1<<bank))!=0)
                    for(int value=0;value<16;value++)
                        components[bank][value]=.03f+bank*.15f+value*.01f;
            }
            var colors=new Color[4];var uv=new Vector2[4];var surface=new Vector2[4];
            for(int i=0;i<4;i++)
            {
                colors[i]=new Color(.2f+(constantColor?0:i*.1f),.31f,.49f,.72f);
                uv[i]=new Vector2(.13f+i*.1f,.27f+i*.1f);
                surface[i]=new Vector2(.41f+i*.1f,.52f+i*.1f);
            }
            var grid=new TerrainVertexProducts(
                new Vector3[4],new Vector3[]{Vector3.Up,Vector3.Up,Vector3.Up,Vector3.Up},
                colors,uv,surface,
                components[0],components[1],components[2],components[3]);
            var page=TerrainGpuGridPage.Create(grid,2);
            require(page.ControlMask==expectedMask,
                "Packed control-mask bits do not represent the exact numerical vertex products");
            require(page.HasConstantColor==constantColor,
                "GPU page omitted varying ownership or retained constant ownership");
            require(page.Bands==(constantColor?2:3)+System.Numerics.BitOperations.PopCount((uint)expectedMask),
                "GPU page did not compact empty material banks");
            // Expand a separate canonical legacy page. The first viewport
            // decodes the original seven-band atlas (mask 15), while the
            // second decodes the new packed page (only occupied bands).
            // Rendered output must be identical on each actual backend.
            var originalBytes=ExpandCanonicalSevenBandPage(page,components);
            var viewports=new List<SubViewport>();
            var materials=new List<ShaderMaterial>();
            using var originalImage=Image.CreateFromData(2,14,false,Image.Format.Rgbaf,originalBytes);
            using var compactImage=Image.CreateFromData(2,2*page.Bands,false,Image.Format.Rgbaf,page.Bytes);
            using var originalTexture=ImageTexture.CreateFromImage(originalImage);
            using var compactTexture=ImageTexture.CreateFromImage(compactImage);
            try
            {
                foreach(var selected in new[]{
                    (Mask:15,Texture:originalTexture,Constant:false),
                    (Mask:page.ControlMask,Texture:compactTexture,Constant:page.HasConstantColor)})
                {
                    var material=new ShaderMaterial{Shader=shader};
                    material.SetShaderParameter("terrain_grid_payload",selected.Texture);
                    material.SetShaderParameter("terrain_grid_rows",2);
                    material.SetShaderParameter("terrain_grid_control_mask",selected.Mask);
                    material.SetShaderParameter("terrain_grid_color_is_constant",selected.Constant);
                    material.SetShaderParameter("terrain_grid_constant_color",page.ConstantColor);
                    material.SetShaderParameter("validation_product",product);
                    var viewport=new SubViewport
                    {
                        Size=new Vector2I(output,output),
                        Disable3D=true,TransparentBg=false,UseHdr2D=false,
                        UseDebanding=false,Msaa2D=Viewport.Msaa.Disabled,
                        GuiDisableInput=true,
                        RenderTargetClearMode=SubViewport.ClearMode.Always,
                        RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled
                    };
                    host.AddChild(viewport);
                    viewport.AddChild(new ColorRect
                    {
                        Color=Colors.White,Size=new Vector2(output,output),
                        Material=material,MouseFilter=Control.MouseFilterEnum.Ignore
                    });
                    viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Always;
                    viewports.Add(viewport);materials.Add(material);
                }
                for(int frame=0;frame<6;frame++)
                    await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                using var first=viewports[0].GetTexture().GetImage();
                using var second=viewports[1].GetTexture().GetImage();
                require(first is not null&&!first.IsEmpty()&&second is not null&&!second.IsEmpty(),
                    "GPU masked control texture renderer returned an empty image");
                if(first!.GetFormat()!=Image.Format.Rgba8)first.Convert(Image.Format.Rgba8);
                if(second!.GetFormat()!=Image.Format.Rgba8)second.Convert(Image.Format.Rgba8);
                var a=first.GetData();var b=second.GetData();
                require(a.Length==output*output*4&&b.Length==a.Length,
                    "GPU masked control readback has unexpected pixel dimensions");
                int maximum=0,signal=0;
                for(int i=0;i<a.Length;i++)
                {
                    maximum=Math.Max(maximum,Math.Abs(a[i]-b[i]));
                    if(i%4!=3&&a[i]>10)signal++;
                }
                maximumDifference=Math.Max(maximumDifference,maximum);
                require(maximum<=1,
                    "Mask "+expectedMask+" changed GPU product "+product+" with constant color="+constantColor);
                if(expectedMask!=0||product!=0)
                {
                    require(signal>=output,
                        "GPU control shader unexpectedly rendered an empty active control bank");
                    activeCases++;
                }
                else require(signal==0,"All-zero controls produced nonzero GPU output");
                cases++;
            }
            finally
            {
                foreach(var viewport in viewports)viewport.Free();
                foreach(var material in materials)material.Dispose();
            }
        }
        Measurements=new D
        {
            ["renderer"]=RenderingServer.GetCurrentRenderingMethod(),
            ["adapter"]=RenderingServer.GetVideoAdapterName(),
            ["control_bank_combinations"]=cases,
            ["active_control_cases"]=activeCases,
            ["maximum_rgba8_pixel_difference"]=maximumDifference,
            ["products"]="control banks, uniform/varying ownership, UV and surface",
            ["scope"]="Shared production control-bank fetches, compared in an actual RGBA32F GPU texture"
        };
    }
}
