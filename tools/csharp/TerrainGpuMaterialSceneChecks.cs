using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PredatorIsle.Terrain;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>The complete production spatial shader, shared GPU grid and packed
/// controls for every surface family, with synthetic art to bound fixture cost.</summary>
internal static class TerrainGpuMaterialSceneChecks
{
    private static readonly string[] Owners={"grass","forest","savanna","swamp","jungle",
        "mountain","tropical","badlands","quarry","wise_mountains","volcanic","spore_forest",
        "radiation_wasteland","crystal_wastes","insect_colony","alien_infected","rocky_coast","beach"};
    private static readonly string[] ColorBanks={"palette_color","biological_colors","mountain_colors",
        "savanna_colors","jungle_colors","forest_colors","swamp_colors","beach_colors"};
    private static readonly string[] NormalBanks={"palette_normal","cliff_ambient_normals","mountain_normals",
        "savanna_normals","jungle_normals","forest_normals","swamp_normals","beach_normals"};

    internal static async Task<D> Run(Node host,Texture2DArray colors,Texture2DArray normals,
        Action<bool,string> require)
    {
        const int output=32;const float span=1;
        string source=FileAccess.GetFileAsString("res://shaders/terrain_biomes.gdshader");
        require(source.Length>0,"The production terrain spatial shader is missing");
        bool legacyInterpolation=RenderingServer.GetCurrentRenderingMethod()=="gl_compatibility";
        require(System.Text.RegularExpressions.Regex.Matches(source,@"(?m)^varying ").Count==16,
            "The production surface interface must leave one varying location for cave controls");
        var topology=new TerrainRingTopology().Get(1,false,TerrainRingLayout.Mask.None);
        var grids=new TerrainGpuGrids();var template=grids.Template(topology);
        using var map=Image.CreateEmpty(4,4,false,Image.Format.Rgba8);
        for(int z=0;z<4;z++)for(int x=0;x<4;x++)
            map.SetPixel(x,z,new Color(.2f+x*.16f,.25f+z*.13f,.2f+(x+z)*.07f,1));
        using var mask=ImageTexture.CreateFromImage(map);
        using var empty=Image.CreateEmpty(1,1,false,Image.Format.Rgbaf);empty.Fill(Colors.Transparent);
        using var emptyTexture=ImageTexture.CreateFromImage(empty);
        using var environment=new Godot.Environment{BackgroundMode=Godot.Environment.BGMode.Color,
            BackgroundColor=Colors.Black,TonemapMode=Godot.Environment.ToneMapper.Linear};
        var references=new Dictionary<(int Owner,int View,int Debug),byte[]>();
        var maximums=new int[Owners.Length];var visible=new int[Owners.Length];var albedoColors=new int[Owners.Length];
        int maximum=0,pixels=0;
        double previousTimeScale=Engine.TimeScale;Engine.TimeScale=0;
        try
        {
            // Shader TIME drives beach swash and tissue pulses. Freeze the
            // same input for both sweeps; rendering/process frames continue.
            for(int frame=0;frame<2;frame++)await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
            // Full spatial programs are large on software Vulkan. Keep only
            // one live program, material and viewport; CPU reference images
            // occupy less than one MiB and survive disposal of the old shader.
            for(int variant=0;variant<2;variant++)
            {
                GD.Print("Production material sweep starting: "+(variant==0?"reference":"optimized"));
                var shader=new Shader{Code=variant==1?source:
                    legacyInterpolation?OriginalVaryings(source):OriginalPackedReference(source)};
                var material=new ShaderMaterial{Shader=shader};
                var viewport=new SubViewport{Size=new Vector2I(output,output),OwnWorld3D=true,
                    TransparentBg=false,Msaa3D=Viewport.Msaa.Disabled,UseDebanding=false,
                    RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled};
                try
                {
                    foreach(string name in ColorBanks)material.SetShaderParameter(name,colors);
                    foreach(string name in NormalBanks)material.SetShaderParameter(name,normals);
                    foreach(string name in new[]{"grass_macro","meso_mask"})material.SetShaderParameter(name,mask);
                    foreach(string name in new[]{"cavity_portals","alien_tissue_flow"})material.SetShaderParameter(name,emptyTexture);
                    material.SetShaderParameter("terrain_material_sample_pruning",variant==1);
                    material.SetShaderParameter("terrain_grid_enabled",true);
                    material.SetShaderParameter("terrain_grid_rows",2);
                    material.SetShaderParameter("terrain_grid_scale",span/topology.Denominator);
                    material.SetShaderParameter("chunk_size_metres",span);
                    material.SetShaderParameter("extension_normals",new float[]{.8f,.8f,.8f,.8f,.8f,.8f,.8f,.8f});
                    material.SetShaderParameter("extension_emission",new float[8]);
                    host.AddChild(viewport);
                    viewport.AddChild(new WorldEnvironment{Environment=environment});
                    var instance=new MeshInstance3D{Mesh=template,MaterialOverride=material,
                        CastShadow=GeometryInstance3D.ShadowCastingSetting.Off};
                    viewport.AddChild(instance);
                    var camera=new Camera3D{Projection=Camera3D.ProjectionType.Orthogonal,
                        Near=.01f,Far=30,Current=true};
                    viewport.AddChild(camera);viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Always;
                    for(int owner=0;owner<Owners.Length;owner++)
                    {
                        var page=Page(owner,span);
                        using var pageImage=Image.CreateFromData(page.Rows,page.Rows*page.Bands,false,
                            Image.Format.Rgbaf,page.Bytes);
                        using var pageTexture=ImageTexture.CreateFromImage(pageImage);
                        using var extensionImage=Image.CreateEmpty(8,1,false,Image.Format.Rgba8);
                        extensionImage.Fill(Colors.Transparent);bool extension=owner is >=8 and <16;
                        if(extension)extensionImage.SetPixel(owner-8,0,new Color(1,.4f,.7f,.5f));
                        using var extensionTexture=ImageTexture.CreateFromImage(extensionImage);
                        material.SetShaderParameter("terrain_grid_payload",pageTexture);
                        material.SetShaderParameter("terrain_grid_control_mask",page.ControlMask);
                        material.SetShaderParameter("terrain_grid_color_is_constant",page.HasConstantColor);
                        material.SetShaderParameter("terrain_grid_constant_color",page.ConstantColor);
                        material.SetShaderParameter("extension_payload",extensionTexture);
                        material.SetShaderParameter("extension_payload_enabled",extension);
                        material.SetShaderParameter("extension_active_mask",extension?1<<(owner-8):0);
                        RenderingServer.InstanceSetCustomAabb(instance.GetInstance(),page.Bounds.Grow(.1f));
                        for(int scenario=0;scenario<3;scenario++)
                        {
                            Vector3 origin=scenario switch{1=>new Vector3(700000,230,-900000),2=>new Vector3(-180000,37,260000),_=>Vector3.Zero};
                            var basis=scenario==0?Basis.Identity:Basis.FromEuler(new Vector3(.13f,scenario==1?.61f:-.47f,.09f)).Scaled(new Vector3(1.2f,.8f,1.1f));
                            var target=origin+basis*new Vector3(span*.5f,2.1f,span*.5f);
                            instance.Transform=new Transform3D(basis,origin);
                            camera.Size=scenario==0?1.25f:1.8f;
                            camera.Position=target+(scenario==0?new Vector3(0,8,0):new Vector3(2.5f,6,scenario==1?3.1f:-3.1f));
                            camera.LookAt(target,scenario==0?Vector3.Back:Vector3.Up);
                            foreach(int debug in new[]{3,4,8})
                            {
                                material.SetShaderParameter("debug_view",debug);
                                for(int frame=0;frame<5;frame++)
                                    await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                                using var image=viewport.GetTexture().GetImage();
                                require(image is not null&&!image.IsEmpty(),"Production material shader returned no image for "+Owners[owner]);
                                if(image!.GetFormat()!=Image.Format.Rgba8)image.Convert(Image.Format.Rgba8);
                                var bytes=image.GetData();
                                require(bytes.Length==output*output*4,"Production material image dimensions changed");
                                if(owner==0&&scenario==0&&debug==3)
                                    GD.Print("Production material first draw: "+(variant==0?"reference":"optimized"));
                                var key=(owner,scenario,debug);
                                if(variant==0)
                                {
                                    references[key]=bytes;int signal=0;
                                    var distinct=new HashSet<uint>();
                                    for(int i=0;i<bytes.Length;i+=4)
                                    {
                                        for(int c=0;c<3;c++)if(bytes[i+c]>8)signal++;
                                        if(bytes[i]>8||bytes[i+1]>8||bytes[i+2]>8)
                                            distinct.Add((uint)(bytes[i]|bytes[i+1]<<8|bytes[i+2]<<16));
                                    }
                                    require(signal>output*4,"Production "+Owners[owner]+" failed to draw visible output "+debug);
                                    if(debug==3)
                                    {
                                        require(distinct.Count>4,"Production "+Owners[owner]+" albedo did not sample varying art");
                                        albedoColors[owner]=Math.Max(albedoColors[owner],distinct.Count);
                                    }
                                    visible[owner]+=signal;
                                }
                                else
                                {
                                    var expected=references[key];int difference=0;
                                    for(int i=0;i<bytes.Length;i++)difference=Math.Max(difference,Math.Abs(expected[i]-bytes[i]));
                                    require(difference<=1,"Production "+Owners[owner]+" view "+scenario+" output "+debug+
                                        " changed by "+difference+" RGBA8 levels");
                                    maximums[owner]=Math.Max(maximums[owner],difference);
                                    maximum=Math.Max(maximum,difference);pixels+=output*output;
                                }
                            }
                        }
                    }
                }
                finally{viewport.Free();material.Dispose();shader.Dispose();}
                for(int frame=0;frame<4;frame++)await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
                GD.Print("Production material sweep complete: "+(variant==0?"reference":"optimized"));
            }
        }
        finally{Engine.TimeScale=previousTimeScale;grids.Clear();template.Dispose();}
        var records=new Godot.Collections.Array();
        for(int owner=0;owner<Owners.Length;owner++)
        {
            var page=Page(owner,span);
            records.Add(new D{["owner"]=Owners[owner],["maximum_byte_difference"]=maximums[owner],
                ["visible_channels"]=visible[owner],["distinct_albedo_colors"]=albedoColors[owner],
                ["gpu_control_mask"]=page.ControlMask,["gpu_bands"]=page.Bands});
        }
        return new D{["owners"]=records,["pixels_compared"]=pixels,["maximum_byte_difference"]=maximum,
            ["compared_original_varying_layout"]=legacyInterpolation,["compared_original_normal_path"]=true,
            ["compared_original_coast_precision"]=true,["explicit_varying_locations"]=16,
            ["original_explicit_varying_locations"]=23,["view_scenarios"]=3,
            ["animation_time_frozen"]=true,
            ["scope"]="Complete terrain_biomes spatial shader on shared GPU grids: all 16 owners plus coast/beach, synthetic bound art, albedo, geometric and mapped normals; rotated cameras, nonuniform model scales, varying vertex normals and translated origins. Not original texture art or whole-world traversal."};
    }

    private static TerrainGpuGridPage Page(int owner,float span)
    {
        var p=new Vector3[4];var n=new Vector3[4];var color=new Color[4];
        var uv=new Vector2[4];var surface=new Vector2[4];
        var controls=new float[4][];
        for(int bank=0;bank<4;bank++)controls[bank]=new float[16];
        for(int i=0;i<4;i++)
        {
            float x=i%2*span,z=i/2*span;
            p[i]=new Vector3(x,2+x*.15f+z*.05f,z);
            n[i]=new Vector3(-.15f+x*.35f,1,-.05f+z*.4f).Normalized();
            color[i]=owner==0?new Color(1,0,0,0):new Color(0,0,0,0);
            uv[i]=new Vector2(0,.02f);surface[i]=new Vector2(.3f+x*.2f,.5f+z*.3f);
            int at=i*4;
            controls[0][at]=.25f;controls[0][at+1]=.5f;controls[0][at+2]=.15f;
            switch(owner)
            {
                case 1:controls[1][at]=Pack(.55+x*.25,.3+z*.3,1);controls[1][at+1]=Pack(.1+x*.3,.05+z*.15,.1+x*.2);controls[1][at+2]=.6f;break;
                case 2:controls[2][at]=Pack(.4+x*.2,.2+z*.2,1);controls[2][at+1]=Pack(.1+x*.1,.1+z*.3,.1+x*.2);controls[2][at+2]=Pack(x*.2,z*.3,x*.1);controls[2][at+3]=Pack(.1+x*.1,.1+z*.2,.2+x*.2);break;
                case 3:controls[3][at]=Pack(.85,.6,1);controls[3][at+1]=Pack(.2,.3,.4);controls[3][at+2]=Pack(.3,.2,.4);break;
                case 4:controls[0][at+3]=Pack(.75+x*.2,.4+z*.4,1);break;
                case 5:
                    controls[0][at]=-Pack(.25,.5,.15)-1;controls[0][at+1]=Pack(.6,.4,1);
                    controls[0][at+2]=Pack(.4,.6,.2);surface[i]=new Vector2(Pack(.1+x*.2,.2+z*.3,.1+x*.3),Pack(.1+z*.1,.1+x*.2,.2+z*.2));break;
                case 6:
                    controls[2][at]=-Pack(0,0,1)-1;controls[3][at]=-Pack(0,0,.3+x*.4)-1;
                    controls[1][at]=-Pack(0,0,.1+z*.3)-1;break;
                case 7:controls[0][at+3]=-1;uv[i].Y=Pack(1,.4+x*.35,.5);break;
                case 16:controls[1][at+2]=-Pack(0,1,.4+x*.25)-1;controls[1][at+3]=Pack(0,.6+z*.2,.4+x*.25);break;
                case 17:controls[1][at+2]=-Pack(0,1,.4)-1;controls[1][at+3]=-Pack(0,1,.3+x*.5)-1;break;
            }
        }
        return TerrainGpuGridPage.Create(new TerrainVertexProducts(p,n,color,uv,surface,
            controls[0],controls[1],controls[2],controls[3]),2);
    }
    private static float Pack(double x,double y,double z)=>(float)(
        Math.Round(x*255,MidpointRounding.AwayFromZero)+Math.Round(y*255,MidpointRounding.AwayFromZero)*256+
        Math.Round(z*255,MidpointRounding.AwayFromZero)*65536);

    // Compatibility can render the complete original 23-location interface.
    // Vulkan reserves 15 of 32 locations; its independent reference restores
    // only the old normal varying, exactly filling the remaining 17 locations.
    internal static string OriginalVaryings(string source)
    {
        source=source.Replace("#define view_distance terrain_world_values.w","varying vec3 world_normal;\n#define view_distance terrain_world_values.w",StringComparison.Ordinal);
        source=source.Replace("varying vec4 terrain_forest_local_values;\n#define forest_local_position terrain_forest_local_values.xyz",
            "varying vec3 forest_local_position;\nvarying flat vec3 forest_origin;",StringComparison.Ordinal);
        foreach(string name in new[]{"swamp_control","swamp_hydro"})
            source=source.Replace($"varying vec4 terrain_{name}_values;\n#define {name} terrain_{name}_values.xyz",
                $"varying vec3 {name};",StringComparison.Ordinal);
        source=source.Replace("#define swamp_ecology vec3(terrain_swamp_control_values.w,0.0,terrain_swamp_hydro_values.w)",
            "varying vec3 swamp_ecology;\n#define swamp_water_level terrain_forest_values.w",StringComparison.Ordinal);
        source=source.Replace("#define coast_control terrain_coast_values.xyz",
            "varying vec4 terrain_surface_values;\n#define terrain_surface terrain_surface_values.xy\nvarying vec4 terrain_coast_values;\n#define coast_control terrain_coast_values.xyz",StringComparison.Ordinal);
        source=source.Replace("#define badlands_control vec2(terrain_forest_values.w,terrain_forest_local_values.w)",
            "#define badlands_control terrain_surface_values.zw",StringComparison.Ordinal);
        source=source.Replace(" vec4 terrain_coast_values;vec2 terrain_surface;float swamp_water_level;\n","",StringComparison.Ordinal);
        source=source.Replace(" world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;",
            " world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;\n world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);",StringComparison.Ordinal);
        source=source.Replace(" terrain_forest_values.w=0.0;terrain_forest_local_values.w=0.0;"," badlands_control=vec2(0);",StringComparison.Ordinal);
        source=source.Replace("terrain_forest_values.w=b.x;terrain_forest_local_values.w=b.y;","badlands_control=b.xy;",StringComparison.Ordinal);
        source=source.Replace(" forest_local_position=VERTEX;"," forest_local_position=VERTEX;\n forest_origin=MODEL_MATRIX[3].xyz;",StringComparison.Ordinal);
        source=source.Replace(" vec3 decoded_swamp_ecology=unpack_control24(grid_control3.w);terrain_swamp_control_values.w=decoded_swamp_ecology.x;terrain_swamp_hydro_values.w=decoded_swamp_ecology.z;",
            " swamp_ecology=unpack_control24(grid_control3.w);",StringComparison.Ordinal);
        source=source.Replace("terrain_forest_values.w/=old_total;","badlands_control.x/=old_total;",StringComparison.Ordinal);
        source=source.Replace(" COLOR=terrain_coast_values;UV2=terrain_surface;\n","",StringComparison.Ordinal);
        source=source.Replace(" vec3 forest_origin=MODEL_MATRIX[3].xyz;\n float swamp_water_level=UV.x;vec2 terrain_surface=UV2;vec4 terrain_coast_values=COLOR;\n","",StringComparison.Ordinal);
        source=source.Replace(" vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);\n if(!FRONT_FACING)n=-n; // Undo the engine's two-sided normal flip, matching the original world-space varying.",
            " vec3 n=normalize(world_normal);",StringComparison.Ordinal);
        foreach(string name in new[]{"jungle_control","forest_control","savanna_control",
            "savanna_geology","savanna_water","savanna_surface"})
            source=source.Replace($"varying vec4 terrain_{name}_values;\n#define {name} terrain_{name}_values.xyz",
                $"varying vec3 {name};",StringComparison.Ordinal);
        source=source.Replace("#define tropical_control vec3(terrain_jungle_control_values.w,terrain_forest_control_values.w,terrain_savanna_control_values.w)",
            "varying vec3 tropical_control;",StringComparison.Ordinal);
        source=source.Replace("#define mountain_shape vec3(terrain_savanna_geology_values.w,terrain_savanna_water_values.w,terrain_savanna_surface_values.w)",
            "varying vec3 mountain_shape;",StringComparison.Ordinal);
        source=source.Replace("terrain_jungle_control_values.w=0.0;terrain_forest_control_values.w=0.0;terrain_savanna_control_values.w=0.0;",
            "tropical_control=vec3(0);",StringComparison.Ordinal);
        source=source.Replace("terrain_jungle_control_values.w=s.z;terrain_forest_control_values.w=w.z;terrain_savanna_control_values.w=f.z;",
            "tropical_control=vec3(s.z,w.z,f.z);",StringComparison.Ordinal);
        source=source.Replace("terrain_savanna_geology_values.w=0.0;terrain_savanna_water_values.w=0.0;terrain_savanna_surface_values.w=0.0;",
            "mountain_shape=vec3(0);",StringComparison.Ordinal);
        source=source.Replace("terrain_savanna_geology_values.w=legacy_ridge.z;terrain_savanna_water_values.w=erosion_wet.x;terrain_savanna_surface_values.w=erosion_wet.y;",
            "mountain_shape=vec3(legacy_ridge.z,erosion_wet.xy);",StringComparison.Ordinal);
        source=source.Replace("terrain_jungle_control_values.w/=old_total;","tropical_control.x/=old_total;",StringComparison.Ordinal);
        foreach(string name in new[]{"jungle_control","forest_control","savanna_control",
            "savanna_geology","savanna_water","savanna_surface"})
            if(source.Contains("terrain_"+name+"_values",StringComparison.Ordinal))
                throw new InvalidOperationException("Original varying reference contains a packed lane: "+name);
        return source;
    }

    private static string OriginalNormal(string source)
    {
        source=source.Replace("#define view_distance terrain_world_values.w","varying vec3 world_normal;\n#define view_distance terrain_world_values.w",StringComparison.Ordinal);
        source=source.Replace(" world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;",
            " world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;\n world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);",StringComparison.Ordinal);
        return source.Replace(" vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);\n if(!FRONT_FACING)n=-n; // Undo the engine's two-sided normal flip, matching the original world-space varying.",
            " vec3 n=normalize(world_normal);",StringComparison.Ordinal);
    }

    private static string OriginalCoast(string source)
    {
        source=source.Replace("#define coast_control terrain_coast_values.xyz",
            "varying vec4 terrain_coast_values;\n#define coast_control terrain_coast_values.xyz",StringComparison.Ordinal);
        source=source.Replace(" vec4 terrain_coast_values;vec2 terrain_surface;float swamp_water_level;",
            " vec2 terrain_surface;float swamp_water_level;",StringComparison.Ordinal);
        source=source.Replace("vec4 terrain_coast_values=COLOR;","",StringComparison.Ordinal);
        return source.Replace("COLOR=terrain_coast_values;UV2=terrain_surface;","UV2=terrain_surface;",StringComparison.Ordinal);
    }

    private static string OriginalPackedReference(string source)
    {
        source=OriginalCoast(OriginalNormal(source));
        string[] carriers={"swamp_land","mountain_control","mountain_geology"};
        foreach(string name in carriers)
            source=source.Replace("varying vec3 "+name+";","varying vec4 terrain_reference_"+name+
                ";\n#define "+name+" terrain_reference_"+name+".xyz",StringComparison.Ordinal);
        source=source.Replace("varying vec3 world_normal;",
            "#define world_normal vec3(terrain_reference_swamp_land.w,terrain_reference_mountain_control.w,terrain_reference_mountain_geology.w)",StringComparison.Ordinal);
        return source.Replace(" world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);",
            " vec3 terrain_reference_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);"+
            "terrain_reference_swamp_land.w=terrain_reference_normal.x;"+
            "terrain_reference_mountain_control.w=terrain_reference_normal.y;"+
            "terrain_reference_mountain_geology.w=terrain_reference_normal.z;",StringComparison.Ordinal);
    }
}
