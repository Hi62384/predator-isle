using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    // Ready finest meshes can be displayed while the wider collision/LOD transaction
    // is still assembling. The shared mask clips only their footprints from coarse ground.
    private sealed class FlightTile(MeshInstance3D node,TerrainRingMeshGeometry.Data source)
    {
        public MeshInstance3D Node {get;}=node;
        public TerrainRingMeshGeometry.Data Source {get;}=source;
        public Vector3[] DrawVertices {get;set;}=Array.Empty<Vector3>();
        public TerrainRingMeshGeometry.Data?[] Neighbors {get;}=new TerrainRingMeshGeometry.Data?[4];
    }
    private readonly Dictionary<Vector2I,FlightTile> flightNodes=new();
    private Dictionary<Vector3I,TerrainRingMeshGeometry.Data> committedRender=new();
    private Image? flightMask;
    private ImageTexture? flightTexture;
    private long flightRevision=-1;
    private void InitializeFlightMask()
    {
        if(flightMask!=null)return;
        flightMask=Image.CreateEmpty(8,8,false,Image.Format.Rgbaf);
        flightMask.Fill(Colors.Transparent);
        middleMask=Image.CreateEmpty(64,64,false,Image.Format.Rgbaf);
        middleMask.Fill(Colors.Transparent);middleTexture=ImageTexture.CreateFromImage(middleMask);
        flightTexture=ImageTexture.CreateFromImage(flightMask);
        if(_swamp_water_material is not null)
        {
            _swamp_water_material.SetShaderParameter("flight_cell_size",chunk_size);
            _swamp_water_material.SetShaderParameter("flight_coverage",flightTexture);
            _swamp_water_material.SetShaderParameter("middle_coverage",middleTexture);
        }
    }
    internal bool HasVisibleFineCell(Vector2I cell)
    {
        if(_active_chunks.TryGetValue(new Vector3I(cell.X,cell.Y,0),out var value))
        {
            var owner=value.As<MeshInstance3D>();
            var draw=owner.GetNodeOrNull<MeshInstance3D>("TerrainGrid");
            if(draw?.Mesh!=null && draw.IsVisibleInTree() || owner.Layers!=0 && owner.Mesh!=null && owner.IsVisibleInTree())return true;
        }
        return flightNodes.TryGetValue(cell,out var tile)&&tile.Node.Mesh!=null&&tile.Node.IsVisibleInTree();
    }
    private void UpdateFlightSurface(Vector3 point)
    {
        if(flightMask is null || ringStream is null)return;
        var center=world_to_chunk(point);
        var caves=CaveStreams().ToArray();
        bool changed=false;
        foreach(var cell in flightNodes.Keys.ToArray())
        {
            var key=new Vector3I(cell.X,cell.Y,0);
            if(flightRevision==ringSourceRevision && !_teleport_pending && !_active_chunks.ContainsKey(key) &&
               (Math.Max(Math.Abs(cell.X-center.X),Math.Abs(cell.Y-center.Y))<=1 ||
                Math.Max(Math.Abs(cell.X-center.X),Math.Abs(cell.Y-center.Y))<=3 && !CommittedCell(cell.X,cell.Y)) &&
               !caves.Any(c=>c.needs_fine_surface(key)))continue;
            var node=flightNodes[cell].Node;node.Hide();node.QueueFree();flightNodes.Remove(cell);
            SetFlightCell(cell,false);changed=true;
        }
        flightRevision=ringSourceRevision;
        if(!_teleport_pending)
        {
            // A single new draw per frame, always closest first.
            for(int radius=0;radius<=1;radius++)
            {
                bool added=false;
                for(int dz=-radius;dz<=radius&&!added;dz++)
                for(int dx=-radius;dx<=radius&&!added;dx++)
                {
                    if(Math.Max(Math.Abs(dx),Math.Abs(dz))!=radius)continue;
                    var cell=center+new Vector2I(dx,dz);var key=new Vector3I(cell.X,cell.Y,0);
                    if(flightNodes.ContainsKey(cell)||_active_chunks.ContainsKey(key))continue;
                    var data=ringStream.ReadyFine(cell);
                    if(data is null||caves.Any(c=>c.needs_fine_surface(key)))continue;
                    var node=new MeshInstance3D{Position=new Vector3((float)data.Patch.OriginX,0,(float)data.Patch.OriginZ)};
                    AddChild(node);AddFlightWater(node,data);flightNodes.Add(cell,new FlightTile(node,data));SetFlightCell(cell,true);
                    added=changed=true;
                }
                if(added)break;
            }
        }
        bool middleChanged=UpdateMiddleSurface(center);
        foreach(var pair in flightNodes)
        {
            var cell=pair.Key;
            var tile=pair.Value;
            var node=tile.Node;
            var data=tile.Source;
            var p=data.Patch;
            bool rebuild=node.Mesh is null;
            for(int side=0;side<4;side++)
            {
                var neighbor=cell+FlightSides[side];
                // Use the surface actually drawn on this side. At a coarse tile
                // corner each edge can have a different neighbor.
                var ground=flightNodes.ContainsKey(neighbor)?null:SurfaceAt(neighbor)?.Data;
                if(!ReferenceEquals(tile.Neighbors[side],ground))rebuild=true;
                tile.Neighbors[side]=ground;
            }
            if(!rebuild)continue;
            var arrays=data.Arrays.Duplicate();
            for(int side=0;side<4;side++)
                if(tile.Neighbors[side] is {} ground)MatchFlightEdges(arrays,data,ground,1<<side);
            if(node.Mesh is null)
            {
                var result=RingUploadPayload(data,arrays,groundOnly:true);
                node.Mesh=Upload(result,p.Key,out _,data);
            }
            else
            {
                // The biome textures are immutable. An exposed edge changing height
                // only requires a replacement vertex buffer and the existing material.
                var mesh=new ArrayMesh();
                mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays,flags:TerrainGpuGrids.ControlFlags);
                mesh.SurfaceSetMaterial(0,node.Mesh.SurfaceGetMaterial(0));
                node.Mesh=mesh;
            }
            tile.DrawVertices=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            changed=true;

        }
        if(changed)flightTexture!.Update(flightMask);
        if(changed || middleChanged)UpdatePreviewSeams();
    }
    private Image? middleMask;
    private ImageTexture? middleTexture;
    private readonly Dictionary<Vector3I,MeshInstance3D> middleNodes=new();
    internal readonly HashSet<Vector3I> VisibleMiddle=new();
    private (Vector2I Cell,long Revision,object Render,bool Teleport)? middleState;

    private TerrainRingMeshGeometry.Data? CommittedSurface(Vector2I cell)
    {
        double baseSize=ringLayout!.BaseSize;
        double x=(cell.X+.5)*baseSize,z=(cell.Y+.5)*baseSize,span=baseSize;
        for(int level=0;level<=ringLayout.OuterRings;level++,span*=3)
        {
            var key=new Vector3I((int)Math.Floor(x/span),(int)Math.Floor(z/span),level);
            if(committedRender.TryGetValue(key,out var data)&&data.Patch.Contains(x,z))return data;
        }
        return null;
    }
    private bool CommittedCell(int x,int z)
    {
        return CommittedSurface(new Vector2I(x,z)) is not null;
    }
    private bool NeedsMiddleFallback(Vector3I key,int span)
    {
        for(int z=0;z<span;z++)
        for(int x=0;x<span;x++)
            if(!CommittedCell(key.X*span+x,key.Y*span+z))return true;
        return false;
    }

    private bool UpdateMiddleSurface(Vector2I center)
    {
        var state=(center,ringSourceRevision,(object)committedRender,_teleport_pending);
        bool changed=middleState!=state;
        if(changed)foreach(var (key,node) in middleNodes.ToArray())
        {
            int factor=key.Z==1?3:9;
            var pivot=(Vector2I)(((Vector2)center)/factor).Floor();
            if(!_teleport_pending && middleState?.Revision==ringSourceRevision &&
               Math.Max(Math.Abs(key.X-pivot.X),Math.Abs(key.Y-pivot.Y))<=2 &&
               (Math.Abs(key.X-pivot.X)<=1 && Math.Abs(key.Y-pivot.Y)<=1 || NeedsMiddleFallback(key,factor)))continue;
            node.Hide();node.QueueFree();middleNodes.Remove(key);middleSources.Remove(key);middleDraw.Remove(key);middleNeighbors.Remove(key);changed=true;
        }
        bool added=false;
        for(int radius=0;radius<=1&&!added&&!_teleport_pending;radius++)
        for(int level=1;level<=Math.Min(2,ringLayout!.OuterRings)&&!added;level++)
        {
            var pivot=(Vector2I)(((Vector2)center)/(level==1?3:9)).Floor();
            for(int z=-radius;z<=radius&&!added;z++)
            for(int x=-radius;x<=radius&&!added;x++)
            {
                if(Math.Max(Math.Abs(x),Math.Abs(z))!=radius)continue;
                var key=new Vector3I(pivot.X+x,pivot.Y+z,level);
                if(middleNodes.ContainsKey(key) || committedRender.TryGetValue(key,out var existing)&&existing.Patch.Hole.Empty)continue;
                var data=ringStream!.ReadyFlight(key);
                if(data is null)continue;
                var mesh=Upload(RingUploadPayload(data,data.Arrays,true),key,out _,data);
                var material=(ShaderMaterial)mesh.SurfaceGetMaterial(0).Duplicate();
                material.SetShaderParameter("middle_preview",true);
                mesh.SurfaceSetMaterial(0,material);
                var node=new MeshInstance3D{Position=new Vector3((float)data.Patch.OriginX,0,(float)data.Patch.OriginZ),Mesh=mesh};
                AddChild(node);AddFlightWater(node,data);middleNodes.Add(key,node);middleSources.Add(key,data);added=changed=true;
            }
        }
        if(!changed)return false;
        middleState=state;middleMask!.Fill(Colors.Transparent);VisibleMiddle.Clear();
        // Each base cell belongs to the finest available draw. Canonical terrain wins ties.
        foreach(var key in middleNodes.Keys.OrderByDescending(k=>k.Z))
        {
            int span=key.Z==1?3:9;
            for(int dz=0;dz<span;dz++)
            for(int dx=0;dx<span;dx++)
            {
                int x=key.X*span+dx,z=key.Y*span+dz;
                var owner=CommittedSurface(new Vector2I(x,z))?.Patch;
                if(owner.HasValue && owner.Value.Key.Z<=key.Z)continue;
                middleMask.SetPixel(x&63,z&63,new Color(x,z,key.Z,1));
            }
        }
        foreach(var (key,node) in middleNodes)
        {
            int span=key.Z==1?3:9;
            bool visible=false;
            for(int dz=0;dz<span&&!visible;dz++)
            for(int dx=0;dx<span&&!visible;dx++)
            {
                int x=key.X*span+dx,z=key.Y*span+dz;
                var pixel=middleMask.GetPixel(x&63,z&63);
                visible=pixel.A>0 && pixel.R==x && pixel.G==z && pixel.B==key.Z;
            }
            node.Visible=visible;if(visible)VisibleMiddle.Add(key);
        }
        foreach(var key in VisibleMiddle.OrderByDescending(k=>k.Z))
            FitMiddleEdges(key);
        middleTexture!.Update(middleMask);
        return true;
    }
    private readonly Dictionary<Vector3I,TerrainRingMeshGeometry.Data> middleDraw=new();
    private readonly Dictionary<Vector3I,TerrainRingMeshGeometry.Data?[]> middleNeighbors=new();
    private void FitMiddleEdges(Vector3I key)
    {
        var source=middleSources[key];
        int span=key.Z==1?3:9;
        var neighbors=new TerrainRingMeshGeometry.Data?[span*4];
        for(int side=0;side<4;side++)
        for(int part=0;part<span;part++)
        {
            int x=side<2?(side==0?-1:span):part;
            int z=side>=2?(side==2?-1:span):part;
            var surface=SurfaceAt(new Vector2I(key.X*span+x,key.Y*span+z));
            if(surface is {} other && (other.Data.Patch.Key.Z>key.Z ||
                other.Data.Patch.Key.Z==key.Z && !other.Preview))
                neighbors[side*span+part]=other.Data;
        }
        if(middleNeighbors.TryGetValue(key,out var old) && old.SequenceEqual(neighbors))return;
        middleNeighbors[key]=neighbors;
        var arrays=source.Arrays.Duplicate();
        for(int i=0;i<neighbors.Length;i++)
            if(neighbors[i] is {} ground)
                MatchFlightEdges(arrays,source,ground,1<<(i/span),i%span,span);
        var mesh=new ArrayMesh();
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays,flags:TerrainGpuGrids.ControlFlags);
        var node=middleNodes[key];
        mesh.SurfaceSetMaterial(0,node.Mesh.SurfaceGetMaterial(0));
        node.Mesh=mesh;
        middleDraw[key]=source with{Arrays=arrays,Products=source.Products! with{
            Vertices=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(),
            Normals=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array()}};
    }
    private static readonly Vector2I[] FlightSides={Vector2I.Left,Vector2I.Right,Vector2I.Up,Vector2I.Down};
    private void SetFlightCell(Vector2I cell,bool covered)
    {
        flightMask!.SetPixel(cell.X&7,cell.Y&7,covered?new Color(cell.X,cell.Y,1):Colors.Transparent);
    }
    private static void MatchFlightEdges(A arrays,TerrainRingMeshGeometry.Data fine,TerrainRingMeshGeometry.Data coarse,int borders,int part=0,int parts=1)
    {
        var verts=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var normals=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
        var coarseNormals=coarse.Products?.Normals??coarse.Arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
        var surface=coarse.Products?.Vertices??coarse.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var axis=coarse.Topology.Axis.Span;int row=fine.Topology.Axis.Length,n=axis.Length;
        for(int z=0;z<row;z++)
        for(int x=0;x<row;x++)
        {
            if(!((x==0&&(borders&1)!=0)||(x==row-1&&(borders&2)!=0)||(z==0&&(borders&4)!=0)||(z==row-1&&(borders&8)!=0)))continue;
            ref var v=ref verts[z*row+x];
            double along=(borders&3)!=0?v.Z:v.X;
            if(along<fine.Patch.Size*part/parts || along>fine.Patch.Size*(part+1)/parts)continue;
            double scale=coarse.Topology.Denominator/coarse.Patch.Size;
            double u=(fine.Patch.OriginX+v.X-coarse.Patch.OriginX)*scale,w=(fine.Patch.OriginZ+v.Z-coarse.Patch.OriginZ)*scale;
            int i=Segment(axis,u),j=Segment(axis,w),a=j*n+i;
            double fx=(u-axis[i])/(axis[i+1]-axis[i]),fz=(w-axis[j])/(axis[j+1]-axis[j]);
            bool lower=fx+fz<=1;
            int first=lower?a:a+n+1;
            float w0=(float)(lower?1-fx-fz:fx+fz-1);
            float wx=(float)(lower?fx:1-fz), wz=(float)(lower?fz:1-fx);
            v.Y=surface[first].Y*w0+surface[a+1].Y*wx+surface[a+n].Y*wz;
            normals[z*row+x]=(coarseNormals[first]*w0+coarseNormals[a+1]*wx+coarseNormals[a+n]*wz).Normalized();
        }
        arrays[(int)Mesh.ArrayType.Normal]=normals;
        arrays[(int)Mesh.ArrayType.Vertex]=verts;
    }
    private static int Segment(ReadOnlySpan<int> axis,double coordinate)
    {
        int i=axis.BinarySearch((int)Math.Floor(coordinate));
        return Math.Clamp(i<0?~i-1:i,0,axis.Length-2);
    }
}

