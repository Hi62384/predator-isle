using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;
using PredatorIsle.Rendering;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private static readonly string[] Natural={"grass","jungle","forest","savanna","swamp","mountain","coast","beach","tropical","badlands"};
    private bool Preview(string key)=>Get(key+"_preview").AsBool();
    private void Preset(string key,Variant value)=>_settings_snapshot.Set(key,value);
    private void DisablePrevious(string[] keys,bool clearCoast=false)
    {
        foreach(string key in keys){Set(key+"_preview",false);if(key is not ("grass" or "coast" or "beach"))Set("_"+key+"_feature_active",false);}
        if(clearCoast)_coast_feature_active=false;
    }
    private void Manifest(string biome,string feature,string? path=null)
    {
        if(feature.Length==0)return;
        var parsed=Json.ParseString(FileAccess.GetFileAsString(path??"res://data/"+biome+"_previews.json"));
        if(parsed.VariantType==Variant.Type.Dictionary)
        {
            var manifest=parsed.AsGodotDictionary();var features=Get(manifest,"features",new D()).AsGodotDictionary();
            if(features.TryGetValue(feature,out var value))
            {
                var item=value.AsGodotDictionary();string field=biome=="beach"?"coast":biome;
                Set("_"+field+"_feature_position",new Vector2((float)item["x"].AsDouble(),(float)item["z"].AsDouble()));Set("_"+field+"_feature_active",true);
                if(field=="coast")_coast_outward=new Vector2((float)item["outward_x"].AsDouble(),(float)item["outward_z"].AsDouble());world_seed=manifest["seed"].AsInt64();return;
            }
        }
        GD.PushWarning("Unknown "+biome+" preview feature: "+feature);
    }
    private void ConfigurePreviews()
    {
        _settings_snapshot=settings.DuplicateDeep(Resource.DeepDuplicateMode.All);var args=OS.GetCmdlineUserArgs();
        if(grass_preview||jungle_preview||forest_preview||args.Contains("grass-preview")||args.Contains("jungle-preview")||args.Contains("forest-preview"))Preset("savanna_coverage",0);
        grass_preview|=args.Contains("grass-preview");if(grass_preview){Preset("grass_coverage",100);Preset("jungle_coverage",0);Preset("forest_coverage",0);}
        foreach(string biome in new[]{"jungle","forest","savanna","swamp","mountain","coast","beach","tropical","badlands"})
        {
            bool enabled=Preview(biome)||args.Contains(biome+"-preview");string feature=Get(biome+"_preview_feature").AsString();
            if(biome is "jungle" or "forest" or "savanna" or "swamp" or "mountain" or "coast")if(feature=="Disabled")feature="";
            foreach(string arg in args)if(arg.StartsWith(biome+"-feature=",StringComparison.Ordinal)){feature=arg[(biome.Length+9)..];enabled=true;}
            Set(biome+"_preview",enabled);Set(biome+"_preview_feature",feature);
            int position=System.Array.IndexOf(Natural,biome);
            if(biome=="swamp"&&Natural.Take(4).Any(Preview))Preset("swamp_coverage",0);
            if(biome=="mountain"&&Natural.Take(5).Any(Preview))Preset("mountain_coverage",0);
            if(biome=="coast"&&Natural.Take(6).Any(Preview)){Preset("rocky_coast_enabled",false);Preset("beaches_enabled",false);}
            if(biome=="tropical"&&Natural.Take(8).Any(Preview))Preset("tropical_coverage",0);
            if(biome=="badlands"&&Natural.Take(9).Any(Preview))Preset("badlands_coverage",0);
            if(!enabled)continue;
            if(biome=="beach")
            {
                if(feature is "Disabled" or ""){feature="wide_beach";beach_preview_feature=feature;}
                DisablePrevious(Natural.Take(7).ToArray());Preset("rocky_coast_enabled",true);Preset("beaches_enabled",true);R("rocky_coast").Set("coverage",1);R("beach").Set("coverage",1);
                foreach(string prior in Natural.Take(6))Preset(prior+"_coverage",feature==prior+"_beach_transition"||(prior=="grass"&&!feature.EndsWith("_transition",StringComparison.Ordinal))?100:0);
            }
            else if(biome=="coast")
            {
                DisablePrevious(Natural.Take(6).ToArray());Preset("beaches_enabled",false);Preset("rocky_coast_enabled",true);R("rocky_coast").Set("coverage",1);string underlying="grass";
                foreach(string prior in Natural.Take(6)){Preset(prior+"_coverage",0);if(feature==prior+"_coast_transition")underlying=prior;}Preset(underlying+"_coverage",100);
            }
            else
            {
                DisablePrevious(Natural.Take(position).ToArray(),biome is "tropical" or "badlands");
                foreach(string prior in Natural.Take(position).Where(x=>x is not ("coast" or "beach")))Preset(prior+"_coverage",0);
                Preset(biome+"_coverage",100);
                if(biome=="jungle"){Preset("savanna_coverage",0);Preset("forest_coverage",0);Preset("temperature_enabled",false);}
                if(biome=="forest")Preset("savanna_coverage",0);
                if(biome is "tropical" or "badlands"){Preset("rocky_coast_enabled",false);Preset("beaches_enabled",false);}
                if(biome=="tropical"){foreach(string key in TerrainBiomeCatalog.ExtensionKeys)Preset(key+"_coverage",0);R("alien_infected").Set("overlay_strength",0);}
                string[] others=biome=="tropical"?new[]{"grass","forest","jungle","savanna","swamp","mountain","volcanic"}:Natural.Take(position).Where(x=>x is not ("coast" or "beach")).ToArray();
                foreach(string prior in others)
                {
                    bool transition=feature==prior+"_"+biome+"_transition"||(biome=="forest"&&feature=="forest_jungle_transition"&&prior=="jungle");if(!transition)continue;
                    Preset(prior+"_coverage",50);Preset(biome+"_coverage",50);
                    if(prior=="grass"&&biome=="forest")Preset("grass_region_size",8000);
                    if(prior=="grass"&&biome=="savanna")Preset("grass_region_size",10000);
                    if(biome is "swamp" or "mountain" or "tropical" or "badlands")Preset(prior+"_region_size",biome=="swamp"?9000:biome=="mountain"?16000:14000);
                    if(biome=="tropical"&&prior=="volcanic")Preset("tropical_region_size",14000);
                }
                // The Forest/Jungle transition names its current biome first.
                if(biome=="forest"&&feature=="forest_jungle_transition"){Preset("jungle_coverage",50);Preset("forest_coverage",50);}
                if(biome=="tropical"&&(feature is "beach_tropical_transition" or "coast_tropical_transition" or "river_mouth")){Preset("rocky_coast_enabled",true);Preset("beaches_enabled",feature=="beach_tropical_transition");}
            }
            Manifest(biome,feature,biome=="coast"?"res://data/rocky_coast_previews.json":null);
        }
        RenderingServer.SetDebugGenerateWireframes(true);if(extension_preview=="Disabled")extension_preview="";
        foreach(string arg in args)
        {
            if(arg.StartsWith("biome=",StringComparison.Ordinal))extension_preview=arg[6..];
            if(arg.StartsWith("biome-position=",StringComparison.Ordinal)){var pair=arg[15..].Split(',');if(pair.Length==2)extension_preview_position=new Vector2(pair[0].ToFloat(),pair[1].ToFloat());}
            if(arg=="all-biomes")foreach(string key in TerrainBiomeCatalog.ExtensionKeys)Preset(key+"_coverage",20);
        }
        if(extension_preview.Length>0&&TerrainBiomeCatalog.ExtensionKeys.Contains(extension_preview))
        {
            foreach(string key in Natural)Set(key+"_preview",false);
            foreach(string key in new[]{"grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"}.Concat(TerrainBiomeCatalog.ExtensionKeys))Preset(key+"_coverage",0);
            Preset(extension_preview+"_coverage",100);Preset("beaches_enabled",false);Preset("rocky_coast_enabled",false);Preset("island_size",100400);Preset("island_spacing",585);
        }
    }
    private static void BindUniforms(ShaderMaterial material,Resource config){var uniforms=config.Call("uniforms").AsGodotDictionary();foreach(var key in uniforms.Keys)material.SetShaderParameter(key.AsStringName(),uniforms[key]);}
    private static void BindBank(ShaderMaterial material,string name)
    {material.SetShaderParameter(name+"_colors",GD.Load<Resource>("res://materials/"+name+"_colors.tres"));material.SetShaderParameter(name+"_normals",GD.Load<Resource>("res://materials/"+name+"_normals.tres"));}
    private void SetupMaterials()
    {
        _terrain_material=(ShaderMaterial)GD.Load<ShaderMaterial>("res://materials/terrain.tres").Duplicate();using var variants=new TerrainShaderVariants();_terrain_material.Shader=variants.select(_terrain_material.Shader,_settings_snapshot,specialize_terrain_shader);
        foreach(var entry in new[]{("palette_color","palette_color_roughness.tres"),("palette_normal","palette_normals.tres"),("cliff_ambient_normals","cliff_ambient_normals.tres"),("grass_macro","grass_macro.res"),("meso_mask","meso_macro.res")})_terrain_material.SetShaderParameter(entry.Item1,GD.Load<Resource>("res://materials/"+entry.Item2));
        if(_terrain_material.GetShaderParameter("palette_color").As<Texture2DArray>().GetLayers()!=9||_terrain_material.GetShaderParameter("palette_normal").As<Texture2DArray>().GetLayers()!=9)throw new InvalidOperationException("Terrain palette must contain nine layers.");
        _terrain_material.SetShaderParameter("cliff_world_seed",(double)world_seed);_terrain_material.SetShaderParameter("water_level",water_level);_apply_material_settings();
        bool extended=P("mountain_coverage")>0||B("rocky_coast_enabled")||B("beaches_enabled")||P("tropical_coverage")>0||P("badlands_coverage")>0;
        if(extended){BindBank(_terrain_material,"mountain");BindUniforms(_terrain_material,R("mountain"));if(P("swamp_coverage")<=0)_swamp_water_material=new ShaderMaterial{Shader=GD.Load<Shader>("res://shaders/swamp_water.gdshader")};}
        if(B("rocky_coast_enabled")||B("beaches_enabled"))BindUniforms(_terrain_material,R("rocky_coast"));
        if(B("beaches_enabled")){BindBank(_terrain_material,"beach");BindUniforms(_terrain_material,R("beach"));}
        if(P("tropical_coverage")>0)BindUniforms(_terrain_material,R("tropical"));
        if(P("badlands_coverage")>0){_terrain_material.SetShaderParameter("badlands_height_multiplier",Math.Max(P("height_multiplier"),.01));BindUniforms(_terrain_material,R("badlands"));BindBank(_terrain_material,"swamp");}
        if(P("swamp_coverage")>0)
        {
            BindBank(_terrain_material,"swamp");var c=R("swamp");BindUniforms(_terrain_material,c);_terrain_material.SetShaderParameter("swamp_flood_stage",c.Get("flood_stage"));
            _swamp_water_material=new ShaderMaterial{Shader=GD.Load<Shader>("res://shaders/swamp_water.gdshader")};
            _swamp_water_material.SetShaderParameter("swamp_water_opacity",c.Get("water_opacity"));_swamp_water_material.SetShaderParameter("swamp_ripple",c.Get("ripple_strength"));_swamp_water_material.SetShaderParameter("swamp_flood_stage",c.Get("flood_stage"));
        }
        if(P("savanna_coverage")>0||extended){BindBank(_terrain_material,"savanna");BindUniforms(_terrain_material,R("savanna"));}
        if(P("forest_coverage")>0){BindBank(_terrain_material,"forest");BindUniforms(_terrain_material,R("forest"));}
        if(P("jungle_coverage")>0||P("forest_coverage")>0||P("swamp_coverage")>0||extended){BindBank(_terrain_material,"jungle");BindUniforms(_terrain_material,R("jungle"));}
        bool enabled=false;var normals=new float[8];var emissions=new float[8];
        for(int i=0;i<8;i++){string key=TerrainBiomeCatalog.ExtensionKeys[i];var c=R(key);normals[i]=(float)Number(c,"normal_strength");emissions[i]=(float)Number(c,"emission_strength");enabled|=P(key+"_coverage")>0||(i==7&&Number(c,"overlay_strength")>0);}
        if(enabled){foreach(string bank in new[]{"mountain","savanna","jungle"})BindBank(_terrain_material,bank);_terrain_material.SetShaderParameter("extension_normals",normals);_terrain_material.SetShaderParameter("extension_emission",emissions);_swamp_water_material??=new ShaderMaterial{Shader=GD.Load<Shader>("res://shaders/swamp_water.gdshader")};}
        bool biology=P("spore_forest_coverage")>0||P("alien_infected_coverage")>0||Number(R("alien_infected"),"overlay_strength")>0;
        if(biology){_terrain_material.SetShaderParameter("biological_colors",GD.Load<Resource>("res://materials/biological_colors_v3.tres"));_terrain_material.SetShaderParameter("alien_tissue_variation_enabled",R("alien_infected").Get("nerve_material_variation"));}
        _extension_materials.Clear();_feature_materials.Clear();
        for(int i=0;i<4;i++){var m=new ShaderMaterial{Shader=GD.Load<Shader>("res://shaders/terrain_features.gdshader")};m.SetShaderParameter("kind",i);_feature_materials.Add(m);}
        for(int i=0;i<3;i++)
        {
            var m=new ShaderMaterial{Shader=GD.Load<Shader>("res://shaders/biome_structures.gdshader")};m.SetShaderParameter("family",5+i);
            if(i==0)m.Shader=GD.Load<Shader>(R("crystal_wastes").Get("crystal_bulk_material").AsBool()?"res://shaders/crystal_bulk.gdshader":"res://shaders/crystal_transmission.gdshader");
            if(i==1){if(R("insect_colony").Get("nest_earth_material").AsBool())m.Shader=GD.Load<Shader>("res://shaders/insect_earth.gdshader");m.SetShaderParameter("structure_colors",GD.Load<Resource>("res://materials/savanna_colors.tres"));m.SetShaderParameter("structure_normals",GD.Load<Resource>("res://materials/savanna_normals.tres"));}
            if(i==2&&biology){m.SetShaderParameter("biological_colors",GD.Load<Resource>("res://materials/biological_colors_v3.tres"));m.SetShaderParameter("alien_tissue_variation_enabled",R("alien_infected").Get("nerve_material_variation"));}
            if(i>0)m.SetShaderParameter("normal_strength",R(TerrainBiomeCatalog.ExtensionKeys[i+5]).Get("normal_strength"));_extension_materials.Add(m);
        }
        if(nested_rings){double quality=ring_settings.shader_detail_quality==0?.7:ring_settings.shader_detail_quality==1?1:ring_settings.shader_detail_quality==2?1.5:2;_terrain_material.SetShaderParameter("detail_distance",Math.Max(32,P("detail_distance")*quality));_terrain_material.SetShaderParameter("terrain_shader_quality",ring_settings.shader_detail_quality);}
        _terrain_material.SetShaderParameter("chunk_size_metres",chunk_size);_lod_materials[0]=_terrain_material;
        for(int level=1;level<=maximum_lod;level++){var m=(ShaderMaterial)_terrain_material.Duplicate();m.SetShaderParameter("chunk_lod",(double)level);m.SetShaderParameter("chunk_size_metres",TileSpan(level));_lod_materials[level]=m;}
    }
    public void _apply_material_settings()
    {
        var v=_settings_snapshot.Get("texture_tile_metres").AsVector4();_terrain_material.SetShaderParameter("tile_metres",new Vector4(Math.Max(v.X,.1f),Math.Max(v.Y,.1f),Math.Max(v.Z,.1f),Math.Max(v.W,.1f)));
        foreach(string p in new[]{"sand_tint","normal_strength","detail_distance","texture_blend_sharpness","shore_width","shore_strength","slope_rock_start","slope_rock_end","grass_roughness_floor","grass_specular","grass_normal_scale"})_terrain_material.SetShaderParameter(p,_settings_snapshot.Get(p));
    }
    public void _create_water()
    {
        if(authority_only)return;
        if(!B("water_enabled"))return;double span=TileSpan(maximum_lod)*5;
        var material=new ShaderMaterial{Shader=GD.Load<Shader>(B("rocky_coast_enabled")||B("beaches_enabled")?"res://shaders/coastal_ocean.gdshader":"res://shaders/ocean.gdshader")};
        foreach(string p in new[]{"wave_height","wave_speed","water_roughness","shallow_color","deep_color"})material.SetShaderParameter(p,_settings_snapshot.Get(p));
        _water=new MeshInstance3D{Name="InfiniteWater",CastShadow=GeometryInstance3D.ShadowCastingSetting.Off,Mesh=new PlaneMesh{Size=new Vector2((float)span,(float)span),SubdivideWidth=96,SubdivideDepth=96,Material=material}};AddChild(_water);
    }
    public void _update_water_position(){if(_water is null||_teleport_pending)return;_water.Position=new Vector3((float)((_target_chunk.X+.5)*chunk_size),(float)water_level,(float)((_target_chunk.Y+.5)*chunk_size));}
}
