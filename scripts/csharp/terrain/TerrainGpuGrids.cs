using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;

namespace PredatorIsle.Terrain;

/// <summary>Shared GPU vertex/index buffers with per-patch immutable displacement pages and culling.</summary>
public sealed class TerrainGpuGrids
{
    private readonly Dictionary<TerrainRingTopology.Grid,(ArrayMesh Mesh,long Bytes)> templates=new();
    private readonly Queue<TerrainRingTopology.Grid> order=new();
    public long TemplatesCreated{get;private set;}
    public long PageUploads{get;private set;}
    public long PageBytesUploaded{get;private set;}
    public long CachedTemplateBytes{get;private set;}
    public ArrayMesh Template(TerrainRingTopology.Grid topology)
    {
        if(templates.TryGetValue(topology,out var existing))return existing.Mesh;
        var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);int row=topology.Axis.Length;var vertex=new Vector3[topology.VertexCount];var axis=topology.Axis.Span;
        for(int z=0;z<row;z++)for(int x=0;x<row;x++)vertex[z*row+x]=new Vector3(axis[x],0,axis[z]);
        arrays[(int)Mesh.ArrayType.Vertex]=vertex;arrays[(int)Mesh.ArrayType.Index]=topology.Indices.ToArray();
        var mesh=new ArrayMesh();mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays);long bytes=(long)topology.VertexCount*12+(long)topology.Indices.Length*4+4096;templates[topology]=(mesh,bytes);CachedTemplateBytes+=bytes;order.Enqueue(topology);TemplatesCreated++;
        // Evicted templates remain alive while instances reference them; no shared mesh is mutated.
        while(templates.Count>128||CachedTemplateBytes>16L*1024*1024){var key=order.Dequeue();CachedTemplateBytes-=templates[key].Bytes;templates.Remove(key);}return mesh;
    }
    public void AttachPayload(ArrayMesh carrier,TerrainRingMeshGeometry.Data data)
    {
        var page=data.GpuPage??throw new ArgumentException("Missing worker-built grid page");
        var original=(ShaderMaterial)carrier.SurfaceGetMaterial(0);var material=(ShaderMaterial)original.Duplicate();
        using var image=Image.CreateFromData(page.Rows,page.Rows*7,false,Image.Format.Rgbaf,page.Bytes);var texture=ImageTexture.CreateFromImage(image);
        material.SetShaderParameter("terrain_grid_payload",texture);material.SetShaderParameter("terrain_grid_rows",page.Rows);material.SetShaderParameter("terrain_grid_enabled",true);
        material.SetShaderParameter("terrain_grid_scale",data.Patch.Size/data.Topology.Denominator);
        carrier.SetMeta("terrain_gpu_template",Template(data.Topology));carrier.SetMeta("terrain_gpu_material",material);carrier.SetMeta("terrain_render_bounds",page.Bounds);carrier.SetMeta("terrain_cpu_payload",new TerrainCpuSurfacePayload{Data=data});
        PageUploads++;PageBytesUploaded+=page.Bytes.LongLength;
    }
    public static void Stage(MeshInstance3D parent)
    {
        var child=parent.GetNodeOrNull<MeshInstance3D>("TerrainGrid");var carrier=parent.Mesh!;
        if(!carrier.HasMeta("terrain_gpu_template")){if(parent.HasMeta("terrain_original_layers")){parent.Layers=(uint)parent.GetMeta("terrain_original_layers").AsInt64();parent.RemoveMeta("terrain_original_layers");}if(child is not null){child.Mesh=null;child.MaterialOverride=null;child.Visible=false;}return;}
        if(child is null){child=new MeshInstance3D{Name="TerrainGrid"};parent.AddChild(child);}
        child.Mesh=carrier.GetMeta("terrain_gpu_template").As<Mesh>();child.MaterialOverride=carrier.GetMeta("terrain_gpu_material").As<Material>();child.CastShadow=parent.CastShadow;child.Visible=true;
        if(!parent.HasMeta("terrain_original_layers"))parent.SetMeta("terrain_original_layers",(long)parent.Layers);child.Layers=(uint)parent.GetMeta("terrain_original_layers").AsInt64();parent.Layers=0;
        var bounds=carrier.GetMeta("terrain_render_bounds").AsAabb().Grow(.001f);RenderingServer.InstanceSetCustomAabb(child.GetInstance(),bounds);
    }
    public static void EnsureCpuSurface(MeshInstance3D node)
    {
        var carrier=node.Mesh;if(carrier is null||!carrier.HasMeta("terrain_gpu_template"))return;
        var mesh=new ArrayMesh();var arrays=carrier.GetMeta("terrain_cpu_payload").As<TerrainCpuSurfacePayload>().Data.Arrays;mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays,flags:ControlFlags);
        mesh.SurfaceSetMaterial(0,carrier.SurfaceGetMaterial(0));foreach(var name in carrier.GetMetaList())if(name!="terrain_gpu_template"&&name!="terrain_gpu_material"&&name!="terrain_cpu_payload")mesh.SetMeta(name,carrier.GetMeta(name));mesh.SetMeta("terrain_cpu_arrays",arrays);node.Mesh=mesh;
        Stage(node);
    }
    internal static Mesh.ArrayFormat ControlFlags=>(Mesh.ArrayFormat)(((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom0Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom1Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom2Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom3Shift));
    public void Clear(){templates.Clear();order.Clear();CachedTemplateBytes=0;}
}
