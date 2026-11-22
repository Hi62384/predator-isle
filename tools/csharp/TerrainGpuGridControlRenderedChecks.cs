using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using D=Godot.Collections.Dictionary;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Tests actual nearest RGBA32F reads from the same masked control-bank
/// include used by the shared terrain shader, on Compatibility and Vulkan.</summary>
internal static class TerrainGpuGridControlRenderedChecks
{
    internal static D Measurements {get;private set;}=new();

    internal static async Task Run(Node host,Action<bool,string> require)
    {
        require(DisplayServer.GetName()!="headless",
            "GPU control-bank read validation requires a rendered display");
        var shader=GD.Load<Shader>("res://shaders/terrain_grid_control_validation.gdshader");
        require(shader is not null,"GPU control-bank test shader is missing");
        const int output=24;
        int cases=0,activeCases=0;
        foreach(int expectedMask in new[]{0,1,2,4,8,5,10,15})
        {
            var components=new float[4][];
            for(int bank=0;bank<4;bank++)
            {
                components[bank]=new float[16];
                if((expectedMask&(1<<bank))!=0)
                    components[bank][0]=.2f+bank*.18f;
            }
            var grid=new TerrainVertexProducts(
                new Vector3[4],new Vector3[]{Vector3.Up,Vector3.Up,Vector3.Up,Vector3.Up},
                new Color[4],new Vector2[4],new Vector2[4],
                components[0],components[1],components[2],components[3]);
            var page=TerrainGpuGridPage.Create(grid,2);
            require(page.ControlMask==expectedMask,
                "Packed control-mask bits do not represent the exact numerical vertex products");
            var viewports=new List<SubViewport>();
            var materials=new List<ShaderMaterial>();
            using var image=Image.CreateFromData(2,14,false,Image.Format.Rgbaf,page.Bytes);
            using var texture=ImageTexture.CreateFromImage(image);
            try
            {
                foreach(int mask in new[]{15,page.ControlMask})
                {
                    var material=new ShaderMaterial{Shader=shader};
                    material.SetShaderParameter("terrain_grid_payload",texture);
                    material.SetShaderParameter("terrain_grid_rows",2);
                    material.SetShaderParameter("terrain_grid_control_mask",mask);
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
                require(maximum<=1,
                    "Mask "+expectedMask+" changed shader control data on the real GPU");
                if(expectedMask!=0)
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
            ["maximum_rgba8_pixel_difference"]=1,
            ["scope"]="Shared production control-bank fetches, compared in an actual RGBA32F GPU texture"
        };
    }
}
