using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    public A _material_variants()
    {
        var variants=Values(_lod_materials);
        foreach(var collection in new[]{_active_chunks,_staged})foreach(var item in collection.Values){var mesh=Obj<MeshInstance3D>(item).Mesh;if(mesh is null||mesh.GetSurfaceCount()==0)continue;var m=mesh.SurfaceGetMaterial(0);if(!variants.Contains(m))variants.Add(m);}
        foreach(var item in _mesh_cache.Values){var m=Obj<ArrayMesh>(item).SurfaceGetMaterial(0);if(!variants.Contains(m))variants.Add(m);}
        foreach(var stream in CaveStreams())foreach(var material in stream.surface_materials())if(!variants.Contains(material))variants.Add(material);
        return variants;
    }
    public ShaderMaterial _tile_material(Vector3I key)=>Obj<ShaderMaterial>(_lod_materials[key.Z]);
    public A _structure_material_variants()
    {
        var variants=new A();foreach(var m in _extension_materials)variants.Add(m);var meshes=Values(_mesh_cache);
        foreach(var collection in new[]{_active_chunks,_staged})foreach(var n in collection.Values){var mesh=Obj<MeshInstance3D>(n).Mesh;if(mesh is not null)meshes.Add(mesh);}
        foreach(var item in meshes){var mesh=Obj<Mesh>(item);if(!mesh.HasMeta("extension_structures"))continue;var structures=Obj<ArrayMesh>(mesh.GetMeta("extension_structures"));for(int s=0;s<structures.GetSurfaceCount();s++){var material=structures.SurfaceGetMaterial(s);if(!variants.Contains(material))variants.Add(material);}}
        return variants;
    }
    public void _refresh_cliff_settings()=>_refresh_cliff_settings(false);
    public void _refresh_cliff_settings(bool force)
    {
        if(cliff_normal_settings is null)return;var values=cliff_normal_settings.Call("uniforms").AsGodotDictionary();var signature=cliff_normal_settings.Call("texture_signature").AsGodotArray();
        if(force||!signature.RecursiveEqual(_cliff_texture_cache))
        {
            var rebuilt=cliff_normal_settings.Call("build_texture_array").AsGodotObject() as Texture2DArray;if(rebuilt is null){GD.PushError("Cliff normal texture array rebuild failed; previous settings retained");return;}
            _cliff_array=rebuilt;_cliff_texture_cache=signature;foreach(var m in _material_variants())Obj<ShaderMaterial>(m).SetShaderParameter("cliff_ambient_normals",_cliff_array);
        }
        if(force||!values.RecursiveEqual(_cliff_uniform_cache)){foreach(var m in _material_variants())foreach(var parameter in values.Keys)Obj<ShaderMaterial>(m).SetShaderParameter(parameter.AsStringName(),values[parameter]);_cliff_uniform_cache=values;}
        if(force&&cliff_normal_settings.ResourcePath.Length>0)_cliff_file_time=(long)FileAccess.GetModifiedTime(cliff_normal_settings.ResourcePath);
    }
    public void _refresh_ground_settings()=>_refresh_ground_settings(false);
    public void _refresh_ground_settings(bool force)
    {
        if(ground_material_settings is null)return;string path=ground_material_settings.ResourcePath;
        if(auto_reload_ground_settings&&path.Length>0){long modified=(long)FileAccess.GetModifiedTime(path);if(!force&&modified!=_ground_file_time){var updated=ResourceLoader.Load(path,"",ResourceLoader.CacheMode.Replace);if(updated is PredatorIsle.Rendering.GroundMaterialSettings||(updated is not null&&updated.HasMethod("uniforms")))ground_material_settings=updated;}_ground_file_time=modified;}
        var values=ground_material_settings.Call("uniforms").AsGodotDictionary();if(force||!values.RecursiveEqual(_ground_uniform_cache)){foreach(var m in _material_variants())foreach(var p in values.Keys)Obj<ShaderMaterial>(m).SetShaderParameter(p.AsStringName(),values[p]);_ground_uniform_cache=values;}
    }
    public void cycle_debug_view()=>set_debug_view((terrain_debug_view+1)%154);
    public void set_debug_view(int view)
    {
        terrain_debug_view=Math.Clamp(view,0,153);if(_terrain_material is null)return;int v=terrain_debug_view;
        int shader=v>=99?v+81:v>=61?v+79:v>=47?v+73:v>=36?v+64:v>=28?v+52:v==5||v>=21?0:v;
        if(v>=131)shader=v+89;if(v>=141)shader=v+99;if(v>=149)shader=v+111;
        _terrain_material.SetShaderParameter("debug_view",shader);foreach(var m in _structure_material_variants())Obj<ShaderMaterial>(m).SetShaderParameter("debug_view",shader);
        if(_swamp_water_material is not null){int water=v>=99?v+81:v>=61?v+79:0;if(v>=131)water=v is 137 or 145?172:0;_swamp_water_material.SetShaderParameter("swamp_water_debug",water);}
        foreach(var m in _material_variants())Obj<ShaderMaterial>(m).SetShaderParameter("cliff_normal_debug",v>=21&&v<28?v-21:0);
        GetViewport().DebugDraw=v==5?Viewport.DebugDrawEnum.Wireframe:Viewport.DebugDrawEnum.Disabled;
    }
    public string get_debug_view_name()
    {
        if(terrain_debug_view>=149)return new string[] {"Extension ownership","Extension regional identity","Extension feature intensity","Extension wetness","Extension geometric normals"}[terrain_debug_view-149];
        if(terrain_debug_view>=141)return new string[] {"Badlands region","Badlands influence","Sedimentary coordinate / hardness","Exposure / erosion / deposition","Major / secondary drainage","Sedimentary materials","Badlands normals","Badlands LOD"}[terrain_debug_view-141];
        if(terrain_debug_view>=131)return new string[] {"Tropical region","Tropical influence","Tropical moisture","Tropical elevation","Tropical slope","Tropical exposed rock","Tropical wetness / water / wear","Tropical material mix","Tropical mapped normals","Tropical LOD"}[terrain_debug_view-131];
        if(terrain_debug_view>=119)return new string[] {"Beach region","Sand influence","Sand wetness","Intertidal band","Sand elevation","Dune slope","Regional wind","Sandy water depth","Sand material mix","Sand mapped normals","Sand LOD","Sand chunk bounds"}[terrain_debug_view-119];
        if(terrain_debug_view>=99)return new string[] {"Coast region","Coast influence","Coast normal orientation","Coast wave exposure","Coast steep faces","Coast elevation","Coast low headland potential","Coast sheltered sediment","Coast platform classification","Coast pool depth","Coast geology","Coast bedrock coverage","Coast wetness","Coast intertidal zone","Coast sediment","Coast underwater depth","Coast material mix","Coast mapped normals","Coast LOD","Coast chunk bounds"}[terrain_debug_view-99];
        if(terrain_debug_view>=81)return new string[] {"Mountain region","Mountain elevation","Mountain primary ridges","Mountain secondary ridges","Mountain peaks/saddles","Mountain valleys","Mountain glacial influence","Mountain cliff slopes","Mountain exposed rock","Mountain scree","Mountain geology","Mountain erosion","Mountain drainage/depth","Mountain material mix","Mountain mapped normals","Mountain LOD","Mountain chunk bounds","Mountain macro/meso normals"}[terrain_debug_view-81];
        if(terrain_debug_view>=61)return new string[] {"Swamp region","Swamp height","Swamp local water level","Swamp relative elevation","Swamp depth","Swamp connectivity classes","Swamp basins","Swamp channels","Swamp levees","Swamp saturation","Swamp mud","Swamp peat","Swamp sediment","Swamp shoreline","Swamp islands","Swamp LOD","Swamp chunk bounds","Swamp material mix","Swamp normals","Swamp worn routes"}[terrain_debug_view-61];
        if(terrain_debug_view>=47)return new string[] {"Savanna regions","Savanna height","Savanna slope","Savanna bedrock","Savanna soil","Savanna aridity","Savanna moisture","Savanna drainage","Savanna dry channels","Savanna basins","Savanna material mix","Savanna macro variation","Savanna trails","Savanna mapped normals"}[terrain_debug_view-47];
        if(terrain_debug_view>=36)return new string[] {"Forest regions","Forest conifer litter influence","Forest meadow/clearing","Forest wetness","Forest leaf litter","Forest needle litter","Forest moss","Forest exposed rock","Forest trails","Forest material mixture","Forest mapped normals"}[terrain_debug_view-36];
        if(terrain_debug_view>=28)return new string[] {"Jungle regions","Jungle wetness","Jungle drainage","Jungle rock exposure","Jungle water corridors","Jungle material weights","Jungle mapped normals","Jungle canopy placement potential (no foliage)"}[terrain_debug_view-28];
        if(terrain_debug_view>=21)return new string[] {"Cliff ambient normals: combined","Cliff base normal only / overlays off","Cliff macro normals only","Cliff medium normals only","Cliff coverage: macro red / medium green","Cliff ambient texture IDs","Cliff combined world normal"}[terrain_debug_view-21];
        return new string[] {"Shaded","Material weights","Dominant material ID","Unlit albedo","Geometry normals","Wireframe","Geology: red scree / green drainage / blue cliff","Normal maps OFF","Mapped normals","Quadtree LOD / bounds","Macro grass","Exposed soil","Drainage wetness","Dryness","Cliff coverage","Fracture recess","Scree","Meso controls","Micro detail disabled","Region fields: highland / drainage / exposure","Macro only (meso and micro disabled)"}[terrain_debug_view];
    }
}
