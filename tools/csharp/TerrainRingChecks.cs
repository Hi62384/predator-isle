using Godot;
using System;
using System.Linq;
using PredatorIsle.Terrain;
using A=Godot.Collections.Array;

namespace PredatorIsle.Checks;

internal static class TerrainRingChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var topology=new TerrainRingTopology();var layout=new TerrainRingLayout(16,6);
        foreach(var focus in new[]{Vector2.Zero,new Vector2(-.01f,-.01f),new Vector2(15.99f,47.99f),new Vector2(16,48),new Vector2(-49,-145),new Vector2(16384,-32768)})
        {
            var plan=layout.Select(focus);Check(plan);
            Check(TerrainRingRefinement.Apply(plan,new[]{new Rect2(focus-Vector2.One*24,Vector2.One*64)}));
        }
        void Check(TerrainRingLayout.Plan plan)
        {
            var regions=plan.Patches.SelectMany(p=>p.OwnedRegions().Select(r=>new Rect2(r.Position+new Vector2((float)p.OriginX,(float)p.OriginZ),r.Size))).ToArray();
            double area=regions.Sum(r=>(double)r.Size.X*r.Size.Y);require(Math.Abs(area-(double)plan.Bounds.Size.X*plan.Bounds.Size.Y)<.01,"Ring cut does not cover its complete bounds");
            for(int i=0;i<regions.Length;i++)for(int j=i+1;j<regions.Length;j++)require(!regions[i].Intersects(regions[j]),"Ring ownership overlaps");
            var source=plan.Patches.Select(p=>Surface(p,topology)).ToArray();
            foreach(var data in source)
            {
                var vertices=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();var indices=data.Topology.Indices.Span;double triangleArea=0;
                for(int i=0;i<indices.Length;i+=3){var a=vertices[indices[i]];var b=vertices[indices[i+1]];var c=vertices[indices[i+2]];var center=(a+b+c)/3;require(data.Patch.Contains(data.Patch.OriginX+center.X,data.Patch.OriginZ+center.Z),"Triangle crosses finer terrain ownership");triangleArea+=Math.Abs((double)(b.X-a.X)*(c.Z-a.Z)-(double)(b.Z-a.Z)*(c.X-a.X))*.5;}
                require(Math.Abs(triangleArea-data.Patch.OwnedRegions().Sum(r=>(double)r.Size.X*r.Size.Y))<.01,"Masked topology area differs from ownership");
                var water=TerrainRingWater.Build(data,0,true,true);require(water.Count>0&&water[(int)Mesh.ArrayType.Index].AsInt32Array().SequenceEqual(indices.ToArray()),"Water escaped or lost its masked ownership");
            }
            var cut=TerrainRingTransitions.Stitch(plan,source);require(cut.Meshes.Length==source.Length&&cut.StitchedVertices>0,"Complete cut failed to stitch");
            foreach(var data in cut.Meshes)
            {
                int row=data.Topology.Axis.Length;var vertices=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
                for(int i=0;i<row;i++){Edge(i,0,-.001);Edge((row-1)*row+i,0,.001);Edge(i*row,-.001,0);Edge(i*row+row-1,.001,0);}
                void Edge(int index,double dx,double dz)
                {
                    var v=vertices[index];double x=data.Patch.OriginX+v.X,z=data.Patch.OriginZ+v.Z;double px=dx==0?Math.Clamp(x,data.Patch.OriginX+.001,data.Patch.OriginX+data.Patch.Size-.001):x+dx,pz=dz==0?Math.Clamp(z,data.Patch.OriginZ+.001,data.Patch.OriginZ+data.Patch.Size-.001):z+dz;var owner=plan.Owner(px,pz);if(owner is null||owner.Value.Key.Z<=data.Patch.Key.Z)return;
                    var other=cut.Meshes.Single(m=>m.Patch.Key==owner.Value.Key);var grid=other.Topology;var points=other.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();double lx=x-other.Patch.OriginX,lz=z-other.Patch.OriginZ;double expected=double.NaN;var axis=grid.Axis.Span;
                    for(int iz=0;iz<axis.Length-1;iz++)for(int ix=0;ix<axis.Length-1;ix++)
                    {
                        double x0=other.Patch.Size*axis[ix]/grid.Denominator,x1=other.Patch.Size*axis[ix+1]/grid.Denominator,z0=other.Patch.Size*axis[iz]/grid.Denominator,z1=other.Patch.Size*axis[iz+1]/grid.Denominator;
                        if(lx<x0-1e-6||lx>x1+1e-6||lz<z0-1e-6||lz>z1+1e-6)continue;int a=iz*axis.Length+ix;double tx=(lx-x0)/(x1-x0),tz=(lz-z0)/(z1-z0);expected=points[a].Y*(1-tx)*(1-tz)+points[a+1].Y*tx*(1-tz)+points[a+axis.Length].Y*(1-tx)*tz+points[a+axis.Length+1].Y*tx*tz;
                    }
                    require(double.IsFinite(expected)&&Math.Abs(v.Y-expected)<.0001,"Stitched fine edge differs from emitted coarse edge");
                }
            }
        }
        using var settings=new TerrainRingSettings();foreach(int profile in Enumerable.Range(0,4)){settings.apply_profile(profile);require(settings.validation_errors().Count==0,"Invalid built-in terrain quality profile");require(settings.nearby_vertex_metres==(profile==0?2:profile==3?.5:1),"Profile spacing differs from its label");}
        var changes=new TerrainHeightChanges();changes.Configure(new[]{new Vector4(0,0,8,4)});require(changes.Offset(0,0)==4&&changes.Offset(8,0)==0&&changes.Offset(100,100)==0,"Canonical terrain changes have incorrect support");
    }
    private static TerrainRingMeshGeometry.Data Surface(TerrainRingLayout.Patch patch,TerrainRingTopology topology)
    {
        var grid=topology.Get(16,patch.Key.Z>0,patch.Hole);int row=grid.Axis.Length,count=grid.VertexCount;var vertices=new Vector3[count];var normals=new Vector3[count];var colors=new Color[count];var uv=new Vector2[count];var controls=new float[count*4];var axis=grid.Axis.Span;
        for(int z=0;z<row;z++)for(int x=0;x<row;x++){double lx=patch.Size*axis[x]/grid.Denominator,lz=patch.Size*axis[z]/grid.Denominator;int i=z*row+x;vertices[i]=new Vector3((float)lx,(float)(Math.Sin((patch.OriginX+lx)*.003)*3+Math.Cos((patch.OriginZ+lz)*.002)),(float)lz);normals[i]=Vector3.Up;colors[i]=new Color(0,0,0,1);uv[i]=new Vector2(1000,0);controls[i*4]=255*65536;}
        var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices;arrays[(int)Mesh.ArrayType.Normal]=normals;arrays[(int)Mesh.ArrayType.Color]=colors;arrays[(int)Mesh.ArrayType.TexUV]=uv;for(int i=0;i<3;i++)arrays[(int)Mesh.ArrayType.Custom0+i]=new float[count*4];arrays[(int)Mesh.ArrayType.Custom3]=controls;arrays[(int)Mesh.ArrayType.Index]=grid.Indices.ToArray();return new(patch,grid,arrays,Array.Empty<byte>(),0,0,-1,Array.Empty<byte>(),0);
    }
}
