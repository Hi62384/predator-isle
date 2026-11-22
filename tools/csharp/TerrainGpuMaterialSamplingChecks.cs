using Godot;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Renders the actual material projection procedures against their
/// original two-endpoint path. Synthetic nonuniform texture arrays expose bad
/// layer, UV, mip, roughness and normal reads without loading large art banks.</summary>
internal static class TerrainGpuMaterialSamplingChecks
{
    internal static D Measurements{get;private set;}=new();
    private static readonly string[] Families={"jungle","forest","savanna","swamp",
        "mountain","tropical","badlands","beach","snow","biological","alien_flow"};
    private static readonly int[] Roles={7,9,11,7,9,8,6,4,4,4,1};

    internal static async Task Run(Node host,Action<bool,string> require)
    {
        require(DisplayServer.GetName()!="headless",
            "Material sampling parity requires an actual graphics device");
        using var shader=new Shader{Code=Program()};
        using var colors=Texture(false);
        using var normals=Texture(true);
        const int size=48;
        var viewports=new List<SubViewport>();
        var materials=new List<ShaderMaterial>();
        int cases=0,pixels=0,maximum=0,negativeDifferences=0;
        var records=new Godot.Collections.Array();
        try
        {
            // The shifted reference is a negative control: a missing draw or a
            // constant/fallback output must fail even if both parity images agree.
            for(int variant=0;variant<3;variant++)
            {
                var material=new ShaderMaterial{Shader=shader};
                material.SetShaderParameter("terrain_material_sample_pruning",variant==1);
                material.SetShaderParameter("test_shift",variant==2?.173f:0f);
                foreach(string family in Families)
                {
                    material.SetShaderParameter(family+"_colors",colors);
                    material.SetShaderParameter(family+"_normals",normals);
                }
                material.SetShaderParameter("palette_color",colors);
                material.SetShaderParameter("palette_normal",normals);
                var viewport=new SubViewport
                {
                    Name="MaterialSampleParity",Size=new Vector2I(size,size),
                    Disable3D=true,TransparentBg=true,UseHdr2D=false,
                    UseDebanding=false,Msaa2D=Viewport.Msaa.Disabled,
                    GuiDisableInput=true,RenderTargetClearMode=SubViewport.ClearMode.Always,
                    RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled
                };
                host.AddChild(viewport);
                viewport.AddChild(new ColorRect{Color=Colors.White,Size=new Vector2(size,size),
                    Material=material,MouseFilter=Control.MouseFilterEnum.Ignore});
                viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Always;
                viewports.Add(viewport);materials.Add(material);
            }
            for(int family=0;family<Families.Length;family++)
            {
                int familyMax=0,familyNegative=0;
                // Every image covers zero, partial and full blends, all source
                // role IDs, detailed normals and the existing normals-off path.
                for(int output=0;output<(family<9?2:1);output++)
                {
                    foreach(var material in materials)
                    {
                        material.SetShaderParameter("test_family",family);
                        material.SetShaderParameter("test_output",output);
                        material.SetShaderParameter("test_roles",Roles[family]);
                    }
                    for(int frame=0;frame<4;frame++)
                        await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                    var images=new List<Image>();
                    try
                    {
                        foreach(var viewport in viewports)
                        {
                            var image=viewport.GetTexture().GetImage();
                            require(image is not null&&!image.IsEmpty(),
                                "Material sampling shader did not produce a valid readback");
                            if(image!.GetFormat()!=Image.Format.Rgba8)image.Convert(Image.Format.Rgba8);
                            images.Add(image);
                        }
                        var reference=images[0].GetData();var actual=images[1].GetData();
                        var negative=images[2].GetData();
                        require(reference.Length==size*size*4&&actual.Length==reference.Length&&
                            negative.Length==reference.Length,"Material readback dimensions changed");
                        int changed=0;
                        for(int i=0;i<reference.Length;i++)
                        {
                            familyMax=Math.Max(familyMax,Math.Abs(reference[i]-actual[i]));
                            if(Math.Abs(reference[i]-negative[i])>2)changed++;
                        }
                        familyNegative+=changed;pixels+=size*size;cases++;
                        require(changed>size,"Material fixture did not detect shifted "+Families[family]+
                            (output==0?" color/roughness":" normal")+" samples");
                    }
                    finally{foreach(var image in images)image.Dispose();}
                }
                require(familyMax<=1,"Exact endpoint pruning changed "+Families[family]+
                    " material sampling by "+familyMax+" RGBA8 levels");
                maximum=Math.Max(maximum,familyMax);negativeDifferences+=familyNegative;
                records.Add(new D{["family"]=Families[family],["maximum_byte_difference"]=familyMax,
                    ["negative_control_different_channels"]=familyNegative});
            }
        }
        finally
        {
            foreach(var viewport in viewports)viewport.Free();
            foreach(var material in materials)material.Dispose();
        }
        Measurements=new D
        {
            ["renderer"]=RenderingServer.GetCurrentRenderingMethod(),
            ["adapter"]=RenderingServer.GetVideoAdapterName(),["cases"]=cases,
            ["pixels_compared"]=pixels,["maximum_rgba8_difference"]=maximum,
            ["negative_control_different_channels"]=negativeDifferences,["materials"]=records,
            ["scope"]="Actual primary/coastal/snow projection procedures; all eight extension families use the tested badlands helper. Numerical terrain generation and full-world frame rate are separate checks."
        };
    }

    private static Texture2DArray Texture(bool normal)
    {
        const int size=32,layers=16;
        var images=new Godot.Collections.Array<Image>();
        try
        {
            for(int layer=0;layer<layers;layer++)
            {
                var bytes=new byte[size*size*4];
                for(int y=0;y<size;y++)for(int x=0;x<size;x++)
                {
                    int at=(y*size+x)*4;
                    bytes[at]=(byte)(normal?72+(x*7+y*3+layer*5)%112:20+(x*19+y*11+layer*31)%216);
                    bytes[at+1]=(byte)(normal?72+(x*3+y*13+layer*7)%112:18+(x*7+y*23+layer*17)%220);
                    bytes[at+2]=(byte)(20+(x*11+y*5+layer*13)%216);
                    bytes[at+3]=(byte)(40+(x*3+y*17+layer*23)%192);
                }
                var image=Image.CreateFromData(size,size,false,Image.Format.Rgba8,bytes);
                image.GenerateMipmaps();images.Add(image);
            }
            var texture=new Texture2DArray();
            if(texture.CreateFromImages(images)!=Error.Ok)
            {texture.Dispose();throw new InvalidOperationException("Could not create material fixture textures");}
            return texture;
        }
        finally{foreach(var image in images)image.Dispose();}
    }

    private static string Program()
    {
        var source=new StringBuilder("shader_type canvas_item;render_mode unshaded,blend_disabled;\n");
        source.AppendLine("#include \"res://shaders/terrain_material_sampling.gdshaderinc\"");
        source.AppendLine("uniform int test_family=0;uniform int test_output=0;uniform int test_roles=7;uniform float test_shift=0.0;uniform bool alien_tissue_variation_enabled=true;");
        foreach(string family in Families)
        {
            source.AppendLine($"uniform sampler2DArray {family}_colors:source_color,filter_linear_mipmap,repeat_enable;");
            source.AppendLine($"uniform sampler2DArray {family}_normals:filter_linear_mipmap,repeat_enable;");
        }
        source.AppendLine("uniform sampler2DArray palette_color:source_color,filter_linear_mipmap,repeat_enable;");
        source.AppendLine("uniform sampler2DArray palette_normal:filter_linear_mipmap,repeat_enable;");
        string terrain=FileAccess.GetFileAsString("res://shaders/terrain_biomes.gdshader");
        source.AppendLine(Function(terrain,"field"));source.AppendLine(Function(terrain,"unpack_normal"));
        // Force endpoints and interior values within each render, while keeping
        // a fourth strip's natural smoothstep result. Both reference and fast
        // materials run the same production procedure and the same input.
        source.AppendLine("float test_blend(float value,vec2 uv){int strip=int(mod(floor(uv.y*4.0),4.0));return strip==0?0.0:(strip==1?1.0:(strip==2?.37:value));}");
        foreach(string family in Families)
        {
            if(family is "biological" or "alien_flow")continue;
            string material=FileAccess.GetFileAsString($"res://shaders/{family}_material.gdshaderinc");
            foreach(string helper in new[]{family+"_shared_id",family+"_local_id",family+"_savanna_id",
                family+"_layer",family+"_texel",family+"_normal_texel"})
                if(material.Contains(helper+"(",StringComparison.Ordinal))source.AppendLine(Function(material,helper));
            string procedure=Function(material,family=="beach"?"beach_plane":family+"_projected");
            int coordinate=procedure.IndexOf("// Exact endpoints",StringComparison.Ordinal);
            if(coordinate<0)throw new InvalidOperationException("Material projection coordinates changed: "+family);
            procedure=procedure.Insert(coordinate,"blend=test_blend(blend,uv);\n ");
            source.AppendLine(procedure);
        }
        string biological=FileAccess.GetFileAsString("res://shaders/biological_sampling.gdshaderinc");
        source.AppendLine(Function(biological,"biological_quarter_turn"));
        source.AppendLine(Function(biological,"biological_lookup"));
        source.AppendLine(WithBlendTest(Function(biological,"biological_projected")));
        string flow=FileAccess.GetFileAsString("res://shaders/alien_tissue_flow.gdshaderinc");
        source.AppendLine(Function(flow,"alien_flow_mirrored"));
        source.AppendLine(WithBlendTest(Function(flow,"alien_flow_varied")));
        source.AppendLine("void fragment(){vec2 uv=UV*4.0+vec2(test_shift);vec2 world_uv=uv*11.0+vec2(-137,291);");
        source.AppendLine("float footprint=mix(.003,.18,UV.y);vec2 dx=vec2(footprint,0),dy=vec2(0,footprint*1.3);float fine=fract(UV.x*2.0)<.5?0.0:1.0;int id=int(floor(UV.x*float(test_roles)));vec4 s;vec3 t;");
        for(int family=0;family<Families.Length;family++)
        {
            string name=Families[family];
            if(name is "biological" or "alien_flow")
            {
                string call=name=="biological"?"biological_projected(id,uv,dx,dy,world_uv)":"alien_flow_varied(uv,dx,dy)";
                source.AppendLine($"else if(test_family=={family}){{s=vec4({call},1);t=vec3(0);}}");
                continue;
            }
            string arguments=name is "jungle" or "snow"?"id,uv,dx,dy,fine,s,t":"id,uv,world_uv,dx,dy,fine,s,t";
            source.AppendLine((family==0?"if":"else if")+$"(test_family=={family}){(name=="beach"?"beach_plane":name+"_projected")}({arguments});");
        }
        source.AppendLine("else{s=vec4(1,0,1,1);t=vec3(0);}COLOR=test_output==0?s:vec4(t.xy*.15+.5,t.z*.5,1);}");
        return source.ToString();
    }

    private static string WithBlendTest(string procedure)
    {
        int marker=procedure.IndexOf("// Exact endpoints",StringComparison.Ordinal);
        if(marker<0)throw new InvalidOperationException("Production sampling endpoint marker is missing");
        return procedure.Insert(marker,"blend=test_blend(blend,uv);\n ");
    }

    private static string Function(string source,string name)
    {
        int token=source.IndexOf(name+"(",StringComparison.Ordinal);
        if(token<0)throw new InvalidOperationException("Missing production shader function "+name);
        int begin=source.LastIndexOf('\n',token)+1,brace=source.IndexOf('{',token),depth=1,end=brace+1;
        if(brace<0)throw new InvalidOperationException("Missing shader function body "+name);
        while(end<source.Length&&depth>0){if(source[end]=='{')depth++;else if(source[end]=='}')depth--;end++;}
        if(depth!=0)throw new InvalidOperationException("Unterminated shader function "+name);
        return source[begin..end];
    }
}
