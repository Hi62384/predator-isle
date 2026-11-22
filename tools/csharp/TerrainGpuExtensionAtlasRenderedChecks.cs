using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Real renderer parity for the shared extension weight lookup in
/// 8/10-strip atlases and 9/11-strip badlands/extension atlas combinations.</summary>
internal static class TerrainGpuExtensionAtlasRenderedChecks
{
    internal static D Measurements {get;private set;}=new();

    internal static async Task Run(Node host,Action<bool,string> require)
    {
        require(DisplayServer.GetName()!="headless","GPU extension atlas parity requires a rendered display");
        var shader=GD.Load<Shader>("res://shaders/extension_atlas_validation.gdshader");
        require(shader is not null,"GPU extension atlas validation shader was not imported");
        var cases=new Godot.Collections.Array();
        for(int extra=0;extra<2;extra++)
        {
            const int row=9, output=64;
            bool withPalette=extra!=0;
            var legacy=Atlas(row,withPalette,false);
            var packed=Atlas(row,withPalette,true);
            var viewports=new List<SubViewport>();
            var textures=new List<ImageTexture>();
            var materials=new List<ShaderMaterial>();
            try
            {
                foreach(var bytes in new[]{legacy,packed})
                {
                    int width=bytes.Length/(row*4);
                    using var image=Image.CreateFromData(width,row,false,Image.Format.Rgba8,bytes);
                    var texture=ImageTexture.CreateFromImage(image);
                    var material=new ShaderMaterial{Shader=shader};
                    material.SetShaderParameter("extension_payload",texture);
                    material.SetShaderParameter("extension_active_mask",255);
                    var viewport=new SubViewport
                    {
                        Name="ExtensionAtlasParity",Size=new Vector2I(output,output),
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
                    viewports.Add(viewport);textures.Add(texture);materials.Add(material);
                }
                // Allow both render targets to draw after first-use shader compilation.
                for(int frame=0;frame<6;frame++)
                    await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                using var first=viewports[0].GetTexture().GetImage();
                using var second=viewports[1].GetTexture().GetImage();
                require(first is not null&&!first.IsEmpty()&&second is not null&&!second.IsEmpty(),
                    "Extension atlas shader returned an empty render target");
                if(first!.GetFormat()!=Image.Format.Rgba8)first.Convert(Image.Format.Rgba8);
                if(second!.GetFormat()!=Image.Format.Rgba8)second.Convert(Image.Format.Rgba8);
                var a=first.GetData();var b=second.GetData();
                require(a.Length==output*output*4&&b.Length==a.Length,
                    "Extension atlas shader produced an unexpected readback layout");
                int maximum=0,active=0,varied=0;
                for(int i=0;i<a.Length;i++)
                {
                    maximum=Math.Max(maximum,Math.Abs(a[i]-b[i]));
                    if(i%4!=3&&a[i]>2)active++;
                    if(i%4!=3&&a[i]>20&&a[i]<235)varied++;
                }
                require(active>output&&varied>output,
                    "Extension atlas shader did not produce varying weight channels");
                require(maximum<=1,
                    "Packed extension atlas changes GPU-filtered weights: maximum RGBA8 error "+maximum);
                cases.Add(new D
                {
                    ["badlands_palette"]=withPalette,
                    ["legacy_atlas_strips"]=withPalette?9:8,
                    ["packed_atlas_strips"]=withPalette?11:10,
                    ["pixels_checked"]=output*output,
                    ["maximum_byte_difference"]=maximum,
                    ["nonzero_weight_channels"]=active
                });
            }
            finally
            {
                foreach(var viewport in viewports)viewport.Free();
                foreach(var material in materials)material.Dispose();
                foreach(var texture in textures)texture.Dispose();
            }
        }
        Measurements=new D
        {
            ["scope"]="Rendered shared GPU shader extension weights on legacy and packed atlases",
            ["renderer"]=RenderingServer.GetCurrentRenderingMethod(),
            ["adapter"]=RenderingServer.GetVideoAdapterName(),
            ["cases"]=cases
        };
    }

    private static byte[] Atlas(int rows,bool palette,bool packed)
    {
        int strips=(packed?10:8)+(palette?1:0);
        var bytes=new byte[rows*rows*strips*4];
        for(int z=0;z<rows;z++)
        for(int x=0;x<rows;x++)
        {
            for(int family=0;family<8;family++)
            {
                byte weight=(byte)(8+(family*23+x*11+z*17)%230);
                int at=(z*rows*strips+family*rows+x)*4;
                bytes[at]=weight;bytes[at+1]=(byte)(weight/2);
                bytes[at+2]=(byte)(weight/3);bytes[at+3]=(byte)(weight/4);
                if(packed)
                    bytes[(z*rows*strips+(8+family/4)*rows+x)*4+family%4]=weight;
            }
            if(palette)
            {
                int at=(z*rows*strips+(strips-1)*rows+x)*4;
                bytes[at]=11;bytes[at+1]=78;bytes[at+2]=134;bytes[at+3]=255;
            }
        }
        return bytes;
    }
}
