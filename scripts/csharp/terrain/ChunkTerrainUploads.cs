using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private static ImageTexture Texture(int width,int height,Image.Format format,byte[] bytes)
    {using var image=Image.CreateFromData(width,height,false,format,bytes);return ImageTexture.CreateFromImage(image);}
    private ArrayMesh Upload(D result,Vector3I key,out ulong surfaceEnd)
    {
        var arrays=result["arrays"].AsGodotArray();var mesh=new ArrayMesh();int vertices=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array().Length;
        ulong flags=(ulong)(arrays[(int)Mesh.ArrayType.Custom0].AsFloat32Array().Length==vertices*4?Mesh.ArrayCustomFormat.RgbaFloat:Mesh.ArrayCustomFormat.RgbFloat)<<(int)Mesh.ArrayFormat.FormatCustom0Shift;
        var shifts=new[]{Mesh.ArrayFormat.FormatCustom1Shift,Mesh.ArrayFormat.FormatCustom2Shift,Mesh.ArrayFormat.FormatCustom3Shift};
        for(int i=0;i<3;i++)if(arrays[(int)Mesh.ArrayType.Custom1+i].VariantType!=Variant.Type.Nil)flags|=(ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)shifts[i];
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays,null,null,(Mesh.ArrayFormat)flags);mesh.SetMeta("collision_data",result["collision_data"]);mesh.SetMeta("edge_profiles",result["edge_profiles"]);
        if(_cave_streamer is not null&&key.Z<=1)mesh.SetMeta("terrain_cpu_arrays",arrays);
        surfaceEnd=Time.GetTicksUsec();
        var material=_tile_material(key);var bytes=result["extension_data"].AsByteArray();
        if(bytes.Length>0)
        {
            material=(ShaderMaterial)material.Duplicate();int rows=result["extension_rows"].AsInt32();material.SetShaderParameter("extension_payload",Texture(bytes.Length/(rows*4),rows,Image.Format.Rgba8,bytes));material.SetShaderParameter("extension_payload_enabled",true);material.SetShaderParameter("extension_active_mask",result["extension_mask"]);
        }
        if(result["badlands_palette_slot"].AsInt32()>=0){material.SetShaderParameter("badlands_palette_slot",result["badlands_palette_slot"]);material.SetShaderParameter("badlands_palette_enabled",true);}
        bytes=result["alien_flow"].AsByteArray();
        if(bytes.Length>0)
        {
            int rows=result["alien_flow_rows"].AsInt32();var texture=Texture(rows,rows,Image.Format.Rgbaf,bytes);material.SetShaderParameter("alien_tissue_flow",texture);material.SetShaderParameter("alien_tissue_flow_enabled",true);material.SetShaderParameter("alien_tissue_flow_span",Vector2.One*(float)TileSpan(key.Z));mesh.SetMeta("alien_tissue_flow",texture);
        }
        var features=result["features"].AsGodotDictionary();
        if(features.Count>0)
        {
            if(features.TryGetValue("ground_collision",out var faces))mesh.SetMeta("cavity_ground_faces",faces);
            var openings=features["openings"].AsVector4Array();
            if(openings.Length>0)
            {
                if(result["extension_data"].AsByteArray().Length==0)material=(ShaderMaterial)material.Duplicate();var values=new float[openings.Length*4];
                for(int i=0;i<openings.Length;i++){values[i*4]=openings[i].X;values[i*4+1]=openings[i].Y;values[i*4+2]=openings[i].Z;values[i*4+3]=openings[i].W;}
                var data=new byte[values.Length*sizeof(float)];Buffer.BlockCopy(values,0,data,0,data.Length);material.SetShaderParameter("cavity_portals",Texture(openings.Length,1,Image.Format.Rgbaf,data));material.SetShaderParameter("cavity_portal_count",openings.Length);mesh.SetMeta("cavity_portals",openings);
            }
            var featureMesh=new ArrayMesh();var surfaces=features["surfaces"].AsGodotArray();
            for(int i=0;i<4;i++){var a=surfaces[i].AsGodotArray();if(a.Count==0)continue;featureMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,a);featureMesh.SurfaceSetMaterial(featureMesh.GetSurfaceCount()-1,_feature_materials[i]);}
            if(featureMesh.GetSurfaceCount()>0)mesh.SetMeta("terrain_features",featureMesh);else featureMesh.Dispose();
        }
        mesh.SurfaceSetMaterial(0,material);var structures=result["structures"].AsGodotArray();
        if(structures.Count>0)
        {
            var structureMesh=new ArrayMesh();var flow=result["structure_flow"].AsGodotDictionary();ImageTexture? texture=null;
            if(flow.Count>0){texture=Texture(flow["columns"].AsInt32(),flow["rows"].AsInt32(),Image.Format.Rgbaf,flow["data"].AsByteArray());structureMesh.SetMeta("alien_tissue_flow",texture);structureMesh.SetMeta("alien_tissue_flow_span",flow["span"]);structureMesh.SetMeta("alien_tissue_flow_offset",flow["offset"]);}
            for(int i=0;i<3;i++)
            {
                if(structures[i].VariantType==Variant.Type.Nil)continue;var m=_extension_materials[i];
                if(i==2&&texture is not null){m=(ShaderMaterial)m.Duplicate();m.SetShaderParameter("alien_tissue_flow",texture);m.SetShaderParameter("alien_tissue_flow_enabled",true);m.SetShaderParameter("alien_tissue_flow_span",flow["span"]);m.SetShaderParameter("alien_tissue_flow_offset",flow["offset"]);}
                structureMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,structures[i].AsGodotArray());structureMesh.SurfaceSetMaterial(structureMesh.GetSurfaceCount()-1,m);
            }
            if(structureMesh.GetSurfaceCount()>0)mesh.SetMeta("extension_structures",structureMesh);else structureMesh.Dispose();
        }
        var localWater=result["swamp_water"].AsGodotArray();if(localWater.Count>0){var waterMesh=new ArrayMesh();waterMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,localWater);waterMesh.SurfaceSetMaterial(0,_swamp_water_material);mesh.SetMeta("swamp_water_mesh",waterMesh);}
        return mesh;
    }
    public void _collect_jobs()
    {
        ulong start=Time.GetTicksUsec();int installed=0;
        foreach(var key in Keys(_jobs))
        {
            var job=_jobs[key].AsGodotDictionary();long task=job["task"].AsInt64();if(!WorkerThreadPool.IsTaskCompleted(task))continue;WorkerThreadPool.WaitForTaskCompletion(task);_idle_builders.Add(Obj<TerrainMeshBuilder>(job["builder"]));_jobs.Remove(key);
            string error=_workerOutcomes.TryGetValue(key.AsVector3I(),out var outcome)?outcome.Error:"";_workerOutcomes.Remove(key.AsVector3I());
            if(error.Length>0){last_error=error;foreach(var k in job["batch"].AsGodotArray()){var item=k.AsVector4I();_inflight.Remove(new Vector3I(item.X,item.Y,item.Z));}GD.PushError("Terrain worker failed: "+last_error);continue;}
            foreach(var result in job["result"].AsGodotArray())_ready_chunks.Add(result);
        }
        while(_ready_chunks.Count>0)
        {
            var result=Pop(_ready_chunks,0).AsGodotDictionary();var key=result["key"].AsVector3I();_inflight.Remove(key);if(!_wanted.ContainsKey(key))continue;
            int resolution=result["resolution"].AsInt32();if(resolution!=_tile_resolution(key)){_pending_chunks.Insert(0,key);continue;}
            ulong commit=Time.GetTicksUsec();var mesh=Upload(result,key,out ulong surfaceEnd);ulong resources=Time.GetTicksUsec();_stage_chunk(key,resolution,mesh);
            if(profile_streaming)
            {
                long begin=result["begin"].AsInt64();streaming_records.Add(new D{["lod"]=key.Z,["resolution"]=resolution,["worker_ms"]=(result["end"].AsInt64()-begin)/1000.0,["queue_ms"]=(begin-(_queued_at.TryGetValue(key,out var queued)?queued.AsInt64():begin))/1000.0,["commit_ms"]=(Time.GetTicksUsec()-commit)/1000.0,["surface_upload_ms"]=(surfaceEnd-commit)/1000.0,["supplementary_resources_ms"]=(resources-surfaceEnd)/1000.0,["node_and_collision_stage_ms"]=(Time.GetTicksUsec()-resources)/1000.0,["collision_stage"]=Obj<MeshInstance3D>(_staged[key]).GetMeta("collision_stage_profile",new D())});
                if(streaming_records.Count>4096)streaming_records.RemoveAt(0);
            }
            _queued_at.Remove(key);installed++;if(installed>=chunks_created_per_frame||Time.GetTicksUsec()-start>=upload_budget_ms*1000)break;
        }
        _commit_partition();
    }
    public void _stage_chunk(Vector3I key,int resolution,ArrayMesh mesh)
    {
        MeshInstance3D node;if(_chunk_pool.Count==0){node=new MeshInstance3D{Visible=false};AddChild(node);}else node=Pop(_chunk_pool,_chunk_pool.Count-1);
        double size=TileSpan(key.Z);node.Position=new Vector3((float)(key.X*size),0,(float)(key.Y*size));node.Mesh=mesh;node.Visible=false;
        if(mesh.HasMeta("terrain_owned_regions"))node.SetMeta("terrain_owned_regions",mesh.GetMeta("terrain_owned_regions"));else if(node.HasMeta("terrain_owned_regions"))node.RemoveMeta("terrain_owned_regions");
        Child("TerrainFeatures","terrain_features",GeometryInstance3D.ShadowCastingSetting.On);
        Child("BiomeStructures","extension_structures",key.Z<=1&&terrain_shadows?GeometryInstance3D.ShadowCastingSetting.On:GeometryInstance3D.ShadowCastingSetting.Off);
        Child("SwampWater","swamp_water_mesh",GeometryInstance3D.ShadowCastingSetting.Off);
        node.CastShadow=terrain_shadows&&key.Z<=1?GeometryInstance3D.ShadowCastingSetting.On:GeometryInstance3D.ShadowCastingSetting.Off;
        node.SetMeta("resolution",resolution);node.SetMeta("tile",key);node.SetMeta("published_usec",0);node.SetMeta("edge_profiles",mesh.GetMeta("edge_profiles",new D()));node.SetMeta("profile_collision",profile_streaming);_update_near_collision(node,true);_staged[key]=node;_staging_revision++;
        void Child(string name,string metadata,GeometryInstance3D.ShadowCastingSetting shadow)
        {var child=node.GetNodeOrNull<MeshInstance3D>(name);if(mesh.HasMeta(metadata)){if(child is null){child=new MeshInstance3D{Name=name};node.AddChild(child);}child.Mesh=Obj<Mesh>(mesh.GetMeta(metadata));child.CastShadow=shadow;}else if(child is not null)child.Mesh=null;}
    }
    public void _update_near_collision(MeshInstance3D node)=>_update_near_collision(node,false,false);
    public void _update_near_collision(MeshInstance3D node,bool force)=>_update_near_collision(node,force,false);
    public void _update_near_collision(MeshInstance3D node,bool force,bool activePosition)
    {
        var key=node.GetMeta("tile").AsVector3I();bool nearTerrain=terrain_collision_enabled&&key.Z<=1,nearStructures=false;var local=Valid(target)?(authority_only?NearestCollisionActor(node.Position+new Vector3((float)TileSpan(key.Z)*.5f,0,(float)TileSpan(key.Z)*.5f)):_teleport_pending&&!activePosition?_teleport_destination:target!.GlobalPosition)-node.Position:Vector3.Inf;
        if(terrain_collision_enabled&&Valid(target))
        {
            foreach(string name in new[]{"extension_structures","cavity_collision"})if(node.Mesh.HasMeta(name))nearStructures|=Obj<Mesh>(node.Mesh.GetMeta(name)).GetAabb().Grow(600).HasPoint(local);
            if(node.Mesh.HasMeta("collision_data")){var data=node.Mesh.GetMeta("collision_data").AsGodotDictionary();if(data["cavity_faces"].AsVector3Array().Length>0)nearStructures|=data["cavity_bounds"].AsAabb().Grow(600).HasPoint(local);}
        }
        var state=new Vector2I(nearTerrain?1:0,nearStructures?1:0);
        if(force||node.GetMeta("collision_state",new Vector2I(-1,-1)).AsVector2I()!=state)
        {_collision.stage(node,TileSpan(key.Z),node.GetMeta("resolution").AsInt32(),nearTerrain,nearStructures,spatial_structure_collision?local:Vector3.Inf);node.SetMeta("collision_state",state);if(_active_chunks.TryGetValue(key,out var active)&&Obj<MeshInstance3D>(active)==node)_collision.activate(node,terrain_collision_enabled);}
        else if(spatial_structure_collision&&(nearTerrain||nearStructures))_collision.refresh_structure_subset(node,local);
        foreach(var stream in CaveStreams())stream.apply_parent(node);
        ApplyAuthorityGroundCuts(node);
    }
    public void _release_node(MeshInstance3D node)
    {
        foreach(var stream in CaveStreams())stream.release_parent(node);_collision.release(node);var key=node.GetMeta("tile").AsVector3I();
        if(!nested_rings&&cached_mesh_limit>0){_mesh_cache[new Vector4I(key.X,key.Y,key.Z,node.GetMeta("resolution").AsInt32())]=node.Mesh;while(_mesh_cache.Count>cached_mesh_limit)_mesh_cache.Remove(_mesh_cache.Keys.First());}
        node.Visible=false;node.Mesh=null;foreach(string name in new[]{"TerrainFeatures","BiomeStructures","SwampWater"}){var child=node.GetNodeOrNull<MeshInstance3D>(name);if(child is not null)child.Mesh=null;}
        if(_chunk_pool.Count<128)_chunk_pool.Add(node);else node.QueueFree();
    }
}
