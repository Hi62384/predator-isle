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
    // Render pages are immutable by product revision. A revisited patch can
    // reference the same native image without another GPU transfer. Page
    // identity also rejects a rebuilt page under an accidentally reused
    // source revision; older materials retain their own native references.
    private sealed record CachedPage(TerrainGpuGridPage Page,ImageTexture Texture,long Bytes);
    private readonly Dictionary<long,CachedPage> pageCache=new();
    private readonly Queue<(long Revision,TerrainGpuGridPage Page)> pageOrder=new();
    private long cachedPageBytes;
    public long PageReuseHits{get;private set;}
    public int CachedPages=>pageCache.Count;
    public long CachedPageBytes=>cachedPageBytes;
    public long PageCacheBudgetBytes{get;set;}=16L*1024*1024;
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
        var texture=PageTexture(data.ProductRevision,page);
        material.SetShaderParameter("terrain_grid_payload",texture);material.SetShaderParameter("terrain_grid_rows",page.Rows);material.SetShaderParameter("terrain_grid_enabled",true);
        material.SetShaderParameter("terrain_grid_scale",data.Patch.Size/data.Topology.Denominator);
        carrier.SetMeta("terrain_gpu_template",Template(data.Topology));carrier.SetMeta("terrain_gpu_material",material);carrier.SetMeta("terrain_render_bounds",page.Bounds);carrier.SetMeta("terrain_cpu_payload",new TerrainCpuSurfacePayload{Data=data});
    }
    private ImageTexture PageTexture(long revision,TerrainGpuGridPage page)
    {
        if(pageCache.TryGetValue(revision,out var cached)&&ReferenceEquals(cached.Page,page))
        {
            PageReuseHits++;
            return cached.Texture;
        }
        // A mismatched page must never inherit a texture just because a caller
        // preserved the revision while replacing the byte payload.
        if(pageCache.Remove(revision,out var stale))
        {
            cachedPageBytes-=stale.Bytes;
            stale.Texture.Dispose();
        }
        using var image=Image.CreateFromData(page.Rows,page.Rows*7,false,Image.Format.Rgbaf,page.Bytes);
        var texture=ImageTexture.CreateFromImage(image);
        PageUploads++;
        PageBytesUploaded+=page.Bytes.LongLength;
        long limit=Math.Max(PageCacheBudgetBytes,0);
        if(page.Bytes.LongLength>limit)return texture;
        // FIFO is bounded by total native texture bytes and entry count.
        // Live ShaderMaterials hold their own references to evicted textures.
        while((pageCache.Count>=128||cachedPageBytes+page.Bytes.LongLength>limit)&&pageOrder.Count>0)
        {
            var oldest=pageOrder.Dequeue();
            if(pageCache.TryGetValue(oldest.Revision,out var retired)&&
                ReferenceEquals(retired.Page,oldest.Page))
            {
                pageCache.Remove(oldest.Revision);
                cachedPageBytes-=retired.Bytes;
                retired.Texture.Dispose();
            }
        }
        pageCache[revision]=new CachedPage(page,texture,page.Bytes.LongLength);
        pageOrder.Enqueue((revision,page));
        cachedPageBytes+=page.Bytes.LongLength;
        return texture;
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
        mesh.SurfaceSetMaterial(0,carrier.SurfaceGetMaterial(0));foreach(var name in carrier.GetMetaList())if(name!="terrain_gpu_template"&&name!="terrain_gpu_material"&&name!="terrain_cpu_payload")mesh.SetMeta(name,carrier.GetMeta(name));mesh.SetMeta("terrain_cpu_arrays",arrays);node.Mesh=mesh;TerrainCollision.RebindEquivalentMesh(node,carrier,mesh);
        Stage(node);
    }
    internal static Mesh.ArrayFormat ControlFlags=>(Mesh.ArrayFormat)(((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom0Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom1Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom2Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom3Shift));
    public void Clear()
    {
        templates.Clear();order.Clear();CachedTemplateBytes=0;
        foreach(var entry in pageCache.Values)entry.Texture.Dispose();
        pageCache.Clear();pageOrder.Clear();cachedPageBytes=0;
    }
}
