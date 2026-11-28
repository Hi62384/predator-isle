using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private readonly Dictionary<Vector3I,TerrainRingMeshGeometry.Data> middleSources=new();
    private MeshInstance3D? previewSeams;
    private StandardMaterial3D? seamMaterial;
    private readonly record struct DrawSurface(TerrainRingMeshGeometry.Data Data,Vector3[] Vertices,bool Preview);

    internal bool HasVisibleGround(Vector2I cell) => CaveOwnsTerrainCell(cell,requireDraw:true) || flightNodes.ContainsKey(cell) || (middleMask != null && SurfaceAt(cell) != null) || (ringLayout != null && CommittedSurface(cell) != null);
    private DrawSurface? SurfaceAt(Vector2I cell)
    {
        if(flightNodes.TryGetValue(cell,out var fine))
            return new(fine.Source,fine.DrawVertices,true);
        var pixel=middleMask!.GetPixel(cell.X&63,cell.Y&63);
        if(pixel.A>0 && pixel.R==cell.X && pixel.G==cell.Y)
        {
            int level=(int)pixel.B;
            var parent=(Vector2I)(((Vector2)cell)/(level==1?3:9)).Floor();
            var key=new Vector3I(parent.X,parent.Y,level);
            var middle=middleDraw.GetValueOrDefault(key)??middleSources[key];
            return new(middle,middle.Products!.Vertices,true);
        }
        var ground=CommittedSurface(cell);
        if(ground is null)return null;
        return new(ground,ground.Products?.Vertices??ground.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(),false);
    }

    private void UpdatePreviewSeams()
    {
        var cells=new HashSet<Vector2I>(flightNodes.Keys);
        foreach(var key in VisibleMiddle)
        {
            int span=key.Z==1?3:9;
            for(int z=0;z<span;z++)
            for(int x=0;x<span;x++)cells.Add(new(key.X*span+x,key.Y*span+z));
        }
        var vertices=new List<Vector3>();
        var sampled=new Dictionary<Vector2I,DrawSurface?>();
        DrawSurface? Read(Vector2I cell)
        {
            if(!sampled.TryGetValue(cell,out var value))sampled[cell]=value=SurfaceAt(cell);
            return value;
        }
        foreach(var cell in cells)
        {
            if(Read(cell) is not {} a)continue;
            foreach(var side in FlightSides)
            {
                var neighbor=cell+side;
                // The invisible heightfield under a portal cannot contribute
                // its own seam. The fitted cave mesh owns this edge instead.
                if(CaveOwnsTerrainCell(cell) || CaveOwnsTerrainCell(neighbor))continue;
                if((side.X<0 || side.Y<0) && cells.Contains(neighbor))continue;
                if(Read(neighbor) is not {} b || ReferenceEquals(a.Data,b.Data) || !a.Preview&&!b.Preview)continue;
                double size=ringLayout!.BaseSize;
                bool alongZ=side.X!=0;
                double line=alongZ?Math.Max(cell.X,neighbor.X)*size:Math.Max(cell.Y,neighbor.Y)*size;
                double start=(alongZ?cell.Y:cell.X)*size;
                AddSeam(vertices,a,b,alongZ,line,start,start+size);
            }
        }
        AddCaveTerrainSeams(vertices);
        if(vertices.Count==0){previewSeams?.Hide();return;}
        if(previewSeams is null)
        {
            seamMaterial=new StandardMaterial3D{CullMode=BaseMaterial3D.CullModeEnum.Disabled,AlbedoColor=new Color(.43f,.40f,.32f),Roughness=1};
            previewSeams=new MeshInstance3D{MaterialOverride=seamMaterial,CastShadow=GeometryInstance3D.ShadowCastingSetting.Off};
            AddChild(previewSeams);
        }
        var arrays=new Godot.Collections.Array();arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex]=vertices.ToArray();
        var normals=new Vector3[vertices.Count];Array.Fill(normals,Vector3.Up);
        arrays[(int)Mesh.ArrayType.Normal]=normals;
        var mesh=new ArrayMesh();mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays);
        previewSeams.Mesh=mesh;previewSeams.Show();
    }

    private sealed record CaveBorder(MeshInstance3D Node,int Side,bool AlongZ, double Line, Vector2I Neighbor, Vector3 Start, Vector3 End);
    private readonly List<MeshInstance3D> caveBorderNodes = new();
    private readonly HashSet<Vector2I> drawnCaveColumns = new();
    private readonly List<CaveBorder> caveBorders = new();
    private const int CaveBorderSamples = 65;
    private sealed class CaveBorderMesh(ArrayMesh original)
    {
        public ArrayMesh Original { get; } = original;
        public float[] Profile { get; set; } = Array.Empty<float>();
    }
    private readonly Dictionary<MeshInstance3D,CaveBorderMesh> caveBorderMeshes = new();
    internal int CaveBorderSegments => caveBorders.Count;
    internal int UncoveredCaveBorderSegments { get; private set; }
    private void AddCaveTerrainSeams(List<Vector3> vertices)
    {
        UncoveredCaveBorderSegments=0;
        var cut = _cave_streamer?._surface_transaction;
        if (cut is null) { caveBorders.Clear(); caveBorderNodes.Clear(); drawnCaveColumns.Clear(); caveBorderMeshes.Clear(); return; }
        float size = (float)ringLayout!.BaseSize;
        if (size > 64 || 64 % size != 0) return;
        if (cut.patches.Count!=caveBorderNodes.Count || cut.patches.Where((node,i)=>node.As<MeshInstance3D>()!=caveBorderNodes[i]).Any())
        {
            caveBorderNodes.Clear();
            drawnCaveColumns.Clear();
            foreach(var old in caveBorderMeshes.Keys.ToArray())
                if(!GodotObject.IsInstanceValid(old) || !cut.patches.Contains(old))caveBorderMeshes.Remove(old);
            caveBorders.Clear();
            foreach (var raw in cut.patches)
            {
                var node=raw.As<MeshInstance3D>();
                caveBorderNodes.Add(node);
                var key=node.GetMeta("cave_cell").AsVector3I();
                var column=new Vector2I(key.X,key.Z);
                if (!cut.columns.ContainsKey(column)) continue;
                if(!caveBorderMeshes.TryGetValue(node,out var borderMesh))
                    caveBorderMeshes[node]=borderMesh=new CaveBorderMesh((ArrayMesh)node.Mesh);
                var original=borderMesh.Original;
                for(int surface=0;surface<original.GetSurfaceCount();surface++)
                {
                    if (original.SurfaceGetMaterial(surface) is not ShaderMaterial material ||
                        material.GetShaderParameter("cave_surface_payload").VariantType==Variant.Type.Nil) continue;
                    drawnCaveColumns.Add(column);
                    var arrays=original.SurfaceGetArrays(surface);
                    var points=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
                    var indices=arrays[(int)Mesh.ArrayType.Index].AsInt32Array();
                    var normals=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
                    int count=indices.Length==0?points.Length:indices.Length;
                    var borderSides=FlightSides.Where(side=>!cut.columns.ContainsKey(column+side)).ToArray();
                    if(borderSides.Length==0)continue;
                    for(int i=0;i+2<count;i+=3)
                    for(int edge=0;edge<3;edge++)
                    {
                        int a=indices.Length==0?i+edge:indices[i+edge];
                        int b=indices.Length==0?i+(edge+1)%3:indices[i+(edge+1)%3];
                        if(normals.Length>0 && normals[a].Y+normals[b].Y<.4f)continue;
                        foreach(var side in borderSides)
                        {
                            bool alongZ=side.X!=0;
                            float edgeCoordinate=side.X+side.Y>0?64:0;
                            if(Math.Abs((alongZ?points[a].X:points[a].Z)-edgeCoordinate)>.002 ||
                               Math.Abs((alongZ?points[b].X:points[b].Z)-edgeCoordinate)>.002)continue;
                            var p=points[a]+node.GlobalPosition;
                            var q=points[b]+node.GlobalPosition;
                            float from=alongZ?p.Z:p.X,to=alongZ?q.Z:q.X;
                            if(Math.Abs(to-from)<.001)continue;
                            if(to<from)(p,q,from,to)=(q,p,to,from);
                            float line=(alongZ?node.GlobalPosition.X:node.GlobalPosition.Z)+edgeCoordinate;
                            for(int cell=Mathf.FloorToInt(from/size);cell*size<to;cell++)
                            {
                                float left=Math.Max(from,cell*size),right=Math.Min(to,(cell+1)*size);
                                int opposite=Mathf.FloorToInt(line/size)+(side.X+side.Y<0?-1:0);
                                caveBorders.Add(new CaveBorder(node,Array.IndexOf(FlightSides,side),alongZ,line,alongZ?new(opposite,cell):new(cell,opposite),
                                    p.Lerp(q,(left-from)/(to-from)),p.Lerp(q,(right-from)/(to-from))));
                            }
                        }
                    }
                }
            }
        }
        // Sample the actual displayed grid, including its temporary flight
        // edge morph. Reuse the fitted mesh until its border heights change.
        const int samples=CaveBorderSamples;
        var profiles=new Dictionary<MeshInstance3D,float[]>();
        var surfaces=new Dictionary<Vector2I,DrawSurface?>();
        foreach(var edge in caveBorders)
        {
            if(!surfaces.TryGetValue(edge.Neighbor,out var visible))
                surfaces[edge.Neighbor]=visible=SurfaceAt(edge.Neighbor);
            if(visible is not {} terrain)
            {
                UncoveredCaveBorderSegments++;
                continue;
            }
            double start=edge.AlongZ?edge.Start.Z:edge.Start.X,end=edge.AlongZ?edge.End.Z:edge.End.X;
            double origin=edge.AlongZ?edge.Node.GlobalPosition.Z:edge.Node.GlobalPosition.X;
            if(!profiles.TryGetValue(edge.Node,out var profile))
                profiles[edge.Node]=profile=new float[samples*4*4];
            int first=Math.Clamp((int)Math.Ceiling(start-origin-.002),0,64);
            int last=Math.Clamp((int)Math.Floor(end-origin+.002),0,64);
            for(int station=first;station<=last;station++)
            {
                double t=origin+station;
                float target=SurfacePoint(terrain,edge.AlongZ,edge.Line,t).Y-edge.Node.GlobalPosition.Y;
                float original=Mathf.Lerp(edge.Start.Y,edge.End.Y,(float)Math.Clamp((t-start)/(end-start),0,1))-edge.Node.GlobalPosition.Y;
                int index=(edge.Side*samples+station)*4;
                profile[index]=target;
                profile[index+1]=target-original;
                profile[index+2]=1;
            }
        }
        foreach (var edge in caveBorders)
        {
            if (surfaces[edge.Neighbor] is not {} terrain || !profiles.TryGetValue(edge.Node, out var profile))
                continue;
            double start = edge.AlongZ ? edge.Start.Z : edge.Start.X;
            double end = edge.AlongZ ? edge.End.Z : edge.End.X;
            var knots=new SortedSet<double>{start,end};
            AddKnots(knots,terrain,edge.AlongZ,edge.Line,start,end);
            // Use the actual fitted cave line. Assuming it reaches the exact
            // terrain sample leaves slivers at fractional crossings and at corners
            // whose two neighbour profiles have different heights.
            var offset = edge.Node.GlobalPosition;
            var startPoint = edge.Start - offset;
            var endPoint = edge.End - offset;
            FitCaveVertex(ref startPoint, profile);
            FitCaveVertex(ref endPoint, profile);
            startPoint += offset;
            endPoint += offset;
            var previous=startPoint;
            var previousGround=SurfacePoint(terrain,edge.AlongZ,edge.Line,start);
            foreach(double position in knots)
            {
                if(position<=start)continue;
                var next=startPoint.Lerp(endPoint,(float)((position-start)/(end-start)));
                var nextGround=SurfacePoint(terrain,edge.AlongZ,edge.Line,position);
                AppendSeam(vertices,previous,previousGround,next,nextGround);
                previous=next;
                previousGround=nextGround;
            }
        }
        foreach(var (node,border) in caveBorderMeshes)
        {
            if(!profiles.TryGetValue(node,out var profile))
            {
                if(border.Profile.Length==0)continue;
                border.Profile=Array.Empty<float>();
                node.Mesh=border.Original;
                continue;
            }
            if(border.Profile.AsSpan().SequenceEqual(profile))continue;
            border.Profile=profile;
            var fitted=new ArrayMesh();
            for(int surface=0;surface<border.Original.GetSurfaceCount();surface++)
            {
                var material=border.Original.SurfaceGetMaterial(surface);
                var arrays=border.Original.SurfaceGetArrays(surface);
                if(material is ShaderMaterial ground &&
                    ground.GetShaderParameter("cave_surface_payload").VariantType!=Variant.Type.Nil)
                {
                    var points=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
                    var normals=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
                    for(int index=0;index<points.Length;index++)
                    {
                        if(normals[index].Y<=.35f)continue;
                        FitCaveVertex(ref points[index],profile);
                    }
                    arrays[(int)Mesh.ArrayType.Vertex]=points;
                }
                fitted.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays);
                fitted.SurfaceSetMaterial(surface,material);
            }
            node.Mesh=fitted;
        }
    }

    private static void FitCaveVertex(ref Vector3 point,float[] profile)
    {
        float correction=0,weights=0,fade=0;
        for(int side=0;side<4;side++)
        {
            float distance=side switch{0=>point.X,1=>64-point.X,2=>point.Z,_=>64-point.Z};
            if(distance>6)continue;
            float along=Mathf.Clamp(side<2?point.Z:point.X,0,64);
            int station=(int)Math.Floor(along);
            int first=(side*CaveBorderSamples+station)*4;
            int second=station==64?first:first+4;
            float fraction=along-station;
            if(profile[first+2]==0 || profile[second+2]==0)continue;
            float target=Mathf.Lerp(profile[first],profile[second],fraction);
            float delta=Mathf.Lerp(profile[first+1],profile[second+1],fraction);
            if(Math.Abs(point.Y-(target-delta))>3)continue;
            float blend=1-Mathf.SmoothStep(0,6,distance);
            float weight=blend/Math.Max(distance,.04f);
            correction+=weight*Mathf.Lerp(delta,target-point.Y,1-Mathf.SmoothStep(0,1,distance));
            weights+=weight;
            fade=Math.Max(fade,blend);
        }
        if(weights>0)point.Y+=correction/weights*fade;
    }

    // Include the intersections with both meshes' grid lines and diagonals.
    private static void AddKnots(SortedSet<double> knots,DrawSurface surface,bool alongZ,double line,double start,double end)
    {
        var data=surface.Data;var axis=data.Topology.Axis.Span;
        double unit=data.Patch.Size/data.Topology.Denominator;
        double origin=alongZ?data.Patch.OriginZ:data.Patch.OriginX;
        double fixedAxis=(line-(alongZ?data.Patch.OriginX:data.Patch.OriginZ))/unit;
        int k=Segment(axis,fixedAxis);
        double fraction=Math.Clamp((fixedAxis-axis[k])/(axis[k+1]-axis[k]),0,1);
        for(int i=0;i<axis.Length-1;i++)
        {
            double edge=origin+axis[i]*unit,diagonal=edge+(1-fraction)*(axis[i+1]-axis[i])*unit;
            if(edge>start && edge<end)knots.Add(edge);
            if(diagonal>start && diagonal<end)knots.Add(diagonal);
        }
    }

    private static Vector3 SurfacePoint(DrawSurface surface,bool alongZ,double line,double coordinate)
    {
        var data=surface.Data;double x=alongZ?line:coordinate,z=alongZ?coordinate:line;
        var axis=data.Topology.Axis.Span;double scale=data.Topology.Denominator/data.Patch.Size;
        double u=Math.Clamp((x-data.Patch.OriginX)*scale,axis[0],axis[^1]);
        double v=Math.Clamp((z-data.Patch.OriginZ)*scale,axis[0],axis[^1]);
        int i=Segment(axis,u),j=Segment(axis,v),n=axis.Length,k=j*n+i;
        double fx=(u-axis[i])/(axis[i+1]-axis[i]),fz=(v-axis[j])/(axis[j+1]-axis[j]);
        var p=surface.Vertices;
        double h=fx+fz<=1?p[k].Y*(1-fx-fz)+p[k+1].Y*fx+p[k+n].Y*fz:
            p[k+n+1].Y*(fx+fz-1)+p[k+1].Y*(1-fz)+p[k+n].Y*(1-fx);
        return new((float)x,(float)h,(float)z);
    }

    private static void AppendSeam(List<Vector3> output,Vector3 a,Vector3 b,Vector3 nextA,Vector3 nextB)
    {
        if (a.IsEqualApprox(b) && nextA.IsEqualApprox(nextB)) return;
        output.Add(a);output.Add(b);output.Add(nextA);
        output.Add(nextA);output.Add(b);output.Add(nextB);
    }

    private static void AddSeam(List<Vector3> output,DrawSurface a,DrawSurface b,bool alongZ,double line,double start,double end)
    {
        var knots=new SortedSet<double>{start,end};
        AddKnots(knots,a,alongZ,line,start,end);AddKnots(knots,b,alongZ,line,start,end);
        Vector3 At(DrawSurface surface,double t)=>SurfacePoint(surface,alongZ,line,t);
        Vector3 prevA=At(a,start),prevB=At(b,start);
        foreach(double t in knots)
        {
            if(t==start)continue;
            Vector3 nextA=At(a,t),nextB=At(b,t);
            AppendSeam(output,prevA,prevB,nextA,nextB);
            prevA=nextA;prevB=nextB;
        }
    }
}
