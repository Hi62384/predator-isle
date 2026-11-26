using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private readonly Dictionary<Vector3I,TerrainRingMeshGeometry.Data> middleSources=new();
    private MeshInstance3D? previewSeams;
    private StandardMaterial3D? seamMaterial;
    private readonly record struct DrawSurface(TerrainRingMeshGeometry.Data Data,Vector3[] Vertices,bool Preview);

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
                if((side.X<0 || side.Y<0) && cells.Contains(neighbor))continue;
                if(Read(neighbor) is not {} b || ReferenceEquals(a.Data,b.Data) || !a.Preview&&!b.Preview)continue;
                double size=ringLayout!.BaseSize;
                bool alongZ=side.X!=0;
                double line=alongZ?Math.Max(cell.X,neighbor.X)*size:Math.Max(cell.Y,neighbor.Y)*size;
                double start=(alongZ?cell.Y:cell.X)*size;
                AddSeam(vertices,a,b,alongZ,line,start,start+size);
            }
        }
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

    // The clipping shader can cut through a triangle interior. Include both
    // meshes' diagonal crossings as well as their grid lines in the shared edge.
    private static void AddSeam(List<Vector3> output,DrawSurface a,DrawSurface b,bool alongZ,double line,double start,double end)
    {
        var knots=new SortedSet<double>{start,end};
        void AddKnots(DrawSurface surface)
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
        AddKnots(a);AddKnots(b);
        Vector3 At(DrawSurface surface,double coordinate)
        {
            var data=surface.Data;double x=alongZ?line:coordinate,z=alongZ?coordinate:line;
            var axis=data.Topology.Axis.Span;double scale=data.Topology.Denominator/data.Patch.Size;
            double u=(x-data.Patch.OriginX)*scale,v=(z-data.Patch.OriginZ)*scale;
            int i=Segment(axis,u),j=Segment(axis,v),n=axis.Length,k=j*n+i;
            double fx=(u-axis[i])/(axis[i+1]-axis[i]),fz=(v-axis[j])/(axis[j+1]-axis[j]);
            var p=surface.Vertices;
            double h=fx+fz<=1?p[k].Y*(1-fx-fz)+p[k+1].Y*fx+p[k+n].Y*fz:
                p[k+n+1].Y*(fx+fz-1)+p[k+1].Y*(1-fz)+p[k+n].Y*(1-fx);
            return new((float)x,(float)h,(float)z);
        }
        Vector3 prevA=At(a,start),prevB=At(b,start);
        foreach(double t in knots)
        {
            if(t==start)continue;
            Vector3 nextA=At(a,t),nextB=At(b,t);
            if(prevA.Y!=prevB.Y || nextA.Y!=nextB.Y)
            {
                output.Add(prevA);output.Add(prevB);output.Add(nextA);
                output.Add(nextA);output.Add(prevB);output.Add(nextB);
            }
            prevA=nextA;prevB=nextB;
        }
    }
}
