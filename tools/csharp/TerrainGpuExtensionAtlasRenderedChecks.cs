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
        foreach(int activeMask in new[]{0,1,128,129,255})
        {
            const int row=9, output=64;
            bool withPalette=extra!=0;
            var legacy=Atlas(row,withPalette,false,activeMask,false);
            var packed=Atlas(row,withPalette,true,activeMask,false);
            int occupied=System.Numerics.BitOperations.PopCount((uint)activeMask);
            // A mask-free production patch does not allocate a compact atlas;
            // otherwise the third image exercises the real streaming layout.
            var variants=new List<(byte[] Data,bool Compact,int PaletteSlot)>
            {
                (legacy,false,withPalette?8:-1),
                (packed,false,withPalette?10:-1)
            };
            if(activeMask!=0)
                variants.Add((Atlas(row,withPalette,true,activeMask,true),true,
                    withPalette?occupied+2:-1));
            int[] familySlots=new int[8];int slotIndex=0;
            for(int family=0;family<8;family++)
                familySlots[family]=(activeMask&(1<<family))!=0?slotIndex++:-1;
            var viewports=new List<SubViewport>();
            var textures=new List<ImageTexture>();
            var materials=new List<ShaderMaterial>();
            try
            {
                foreach(var variant in variants)
                {
                    int width=variant.Data.Length/(row*4);
                    using var image=Image.CreateFromData(width,row,false,Image.Format.Rgba8,variant.Data);
                    var texture=ImageTexture.CreateFromImage(image);
                    var material=new ShaderMaterial{Shader=shader};
                    material.SetShaderParameter("extension_payload",texture);
                    material.SetShaderParameter("extension_active_mask",activeMask);
                    material.SetShaderParameter("extension_compact_payload",variant.Compact);
                    material.SetShaderParameter("extension_compact_family_slots",familySlots);
                    material.SetShaderParameter("extension_compact_weight_start",occupied);
                    material.SetShaderParameter("test_palette_slot",variant.PaletteSlot);
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
                for(int frame=0;frame<6;frame++)
                    await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                using var reference=viewports[0].GetTexture().GetImage();
                require(reference is not null&&!reference.IsEmpty(),
                    "Extension atlas shader returned an empty reference image");
                if(reference!.GetFormat()!=Image.Format.Rgba8)
                    reference.Convert(Image.Format.Rgba8);
                var expectedPixels=reference.GetData();
                require(expectedPixels.Length==output*output*4,
                    "Extension atlas reference has an unexpected pixel layout");
                int maximum=0,active=0,varied=0;
                for(int i=0;i<expectedPixels.Length;i++)
                {
                    if(i%4!=3&&expectedPixels[i]>2)active++;
                    if(i%4!=3&&expectedPixels[i]>20&&expectedPixels[i]<235)varied++;
                }
                for(int variantIndex=1;variantIndex<viewports.Count;variantIndex++)
                {
                    using var actual=viewports[variantIndex].GetTexture().GetImage();
                    require(actual is not null&&!actual.IsEmpty(),
                        "Extension atlas shader returned an empty compact image");
                    if(actual!.GetFormat()!=Image.Format.Rgba8)
                        actual.Convert(Image.Format.Rgba8);
                    var pixels=actual.GetData();
                    require(pixels.Length==expectedPixels.Length,
                        "Extension atlas shader changed the pixel dimensions");
                    for(int i=0;i<expectedPixels.Length;i++)
                        maximum=Math.Max(maximum,Math.Abs(expectedPixels[i]-pixels[i]));
                }
                if(activeMask==0&&!withPalette)require(active==0,
                    "Inactive extension atlas emitted nonexistent family controls");
                else require(active>output&&varied>output,
                    "Extension atlas parity did not render varying biome controls");
                require(maximum<=1,
                    "Compact extension atlas changes GPU-filtered weights or material controls: RGBA8 delta "+maximum);
                cases.Add(new D
                {
                    ["badlands_palette"]=withPalette,
                    ["active_family_mask"]=activeMask,
                    ["legacy_atlas_strips"]=withPalette?9:8,
                    ["packed_atlas_strips"]=withPalette?11:10,
                    ["compact_atlas_strips"]=activeMask==0?0:
                        occupied+2+(withPalette?1:0),
                    ["pixels_checked"]=output*output,
                    ["maximum_byte_difference"]=maximum,
                    ["nonzero_channels"]=active
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

    private static byte[] Atlas(int rows,bool palette,bool packed,int activeMask,bool compact)
    {
        int occupied=System.Numerics.BitOperations.PopCount((uint)activeMask);
        int strips=(compact?occupied+2:(packed?10:8))+(palette?1:0);
        var bytes=new byte[rows*rows*strips*4];
        for(int z=0;z<rows;z++)
        for(int x=0;x<rows;x++)
        {
            int rank=0;
            for(int family=0;family<8;family++)
            {
                bool present=(activeMask&(1<<family))!=0;
                byte weight=present?
                    (byte)(8+(family*23+x*11+z*17)%230):(byte)0;
                if(!compact||present)
                {
                    int slot=compact?rank:family;
                    int at=(z*rows*strips+slot*rows+x)*4;
                    bytes[at]=weight;bytes[at+1]=(byte)(weight/2);
                    bytes[at+2]=(byte)(weight/3);bytes[at+3]=(byte)(weight/4);
                }
                if(packed)
                {
                    int weightStrip=(compact?occupied:8)+family/4;
                    bytes[(z*rows*strips+weightStrip*rows+x)*4+family%4]=weight;
                }
                if(present)rank++;
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
