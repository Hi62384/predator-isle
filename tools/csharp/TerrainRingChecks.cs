using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using PredatorIsle.Terrain;
using A=Godot.Collections.Array;

namespace PredatorIsle.Checks;

internal static class TerrainRingChecks
{
    internal static void Run(Action<bool,string> require)
    {
        TerrainSharedSampleChecks.Run(require);
        // In-flight and cancelled keys must never prevent later runnable work.
        var pending=new List<int>{1,2,3,4};var wanted=new HashSet<int>{1,2,3};var busy=new HashSet<int>{1,3};
        require(TerrainRingStream.TryDequeueAvailable(pending,wanted.Contains,busy.Contains,out int next)&&next==2&&
                pending.SequenceEqual(new[]{3,4,1}),"A busy terrain job starved runnable patches behind it");
        require(!TerrainRingStream.TryDequeueAvailable(pending,wanted.Contains,busy.Contains,out _)&&
                pending.SequenceEqual(new[]{3,1}),"A fully blocked terrain queue did not terminate safely");
        foreach(var point in new[]{new Vector2(-.001f,-16.01f),new Vector2(2,3),new Vector2(16384,-32768)})
        foreach(var velocity in new[]{Vector2.Zero,new Vector2(25,0),new Vector2(-100,80)})
        {
            var predicted=TerrainPrefetch.Select(point,velocity,.2,16);var again=TerrainPrefetch.Select(point,velocity,.2,16);
            require(predicted.Length<=24&&predicted.Length>=16&&predicted.SequenceEqual(again)&&predicted.Distinct().Count()==predicted.Length,"Prefetch rows are unbounded or unstable");
            foreach(var p in predicted)require(p.Key.Z==0&&Math.Abs(p.Key.X-(int)Math.Floor(point.X/16))<=4&&Math.Abs(p.Key.Y-(int)Math.Floor(point.Y/16))<=4,"Prefetch escaped its bounded local neighborhood");
        }
        var topology=new TerrainRingTopology();var layout=new TerrainRingLayout(16,6);
        {
            var raw=Surface(new TerrainRingLayout.Patch(new Vector3I(-1,2,0),16,TerrainRingLayout.Mask.None),topology);var data=raw with{GpuPage=TerrainGpuGridPage.Create(raw.Arrays,raw.Topology.Axis.Length)};
            var grids=new TerrainGpuGrids();require(ReferenceEquals(grids.Template(data.Topology),grids.Template(data.Topology)),"Grid instances did not share the actual mesh resource");
            using var shader=new Shader{Code="shader_type spatial;uniform bool terrain_grid_enabled=false;uniform sampler2D terrain_grid_payload;uniform int terrain_grid_rows=17;"};using var material=new ShaderMaterial{Shader=shader};
            using var carrier=new ArrayMesh();var a=new A();a.Resize((int)Mesh.ArrayType.Max);a[(int)Mesh.ArrayType.Vertex]=new[]{data.GpuPage.Bounds.Position,data.GpuPage.Bounds.End,data.GpuPage.Bounds.Position};carrier.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,a);carrier.SurfaceSetMaterial(0,material);carrier.SetMeta("collision_data",new Godot.Collections.Dictionary{["proof"]=7});grids.AttachPayload(carrier,data);
            var node=new MeshInstance3D{Mesh=carrier};TerrainGpuGrids.Stage(node);var child=node.GetNode<MeshInstance3D>("TerrainGrid");require(child.Mesh==grids.Template(data.Topology)&&((ShaderMaterial)child.MaterialOverride).GetShaderParameter("terrain_grid_enabled").AsBool(),"Shared grid payload was not installed on its render instance");
            require(node.Mesh.GetAabb().Size.IsEqualApprox(data.GpuPage.Bounds.Size),"Carrier bounds lost displaced terrain extent");
            TerrainGpuGrids.EnsureCpuSurface(node);require(node.Mesh!=carrier&&child.Mesh is null&&node.Mesh.GetMeta("collision_data").AsGodotDictionary()["proof"].AsInt32()==7,"Cave CPU fallback lost original collision or left the grid drawing");
            require(((ArrayMesh)node.Mesh).SurfaceGetArrays(0)[(int)Mesh.ArrayType.Vertex].AsVector3Array().SequenceEqual(data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array()),"Cave fallback changed emitted terrain positions");node.Free();grids.Clear();
        }
        foreach(var focus in new[]{new Vector2(1,1),new Vector2(-31,-31),new Vector2(16385,-32735)})
        foreach(var move in new[]{new Vector2(16,0),new Vector2(16,16)})
        {
            var old=layout.Select(focus);var next=layout.Select(focus+move);
            var available=next.Patches.Where(p=>p.Key.Z<=1||old.Patches.Contains(p)).ToHashSet();
            var local=TerrainLocalPublication.Select(old.Patches,next.Patches,available);
            require(local is not null,"Ready nearby replacement waited for unrelated distant patches");
            var plan=old with{Patches=local!,Camera=next.Camera};Check(plan);
            require(plan.Patches.Any(p=>p.Key.Z==6&&old.Patches.Contains(p)),"Local publication lost distant published coverage");
            var fineOnly=next.Patches.Where(p=>p.Key.Z==0||old.Patches.Contains(p)).ToHashSet();
            var partial=TerrainLocalPublication.Select(old.Patches,next.Patches,fineOnly);
            // A diagonal move can entirely fill a previously partial coarse cell;
            // that complete fine-only closure is safe without a replacement parent.
            if(partial is not null){require(partial.All(p=>fineOnly.Contains(p)||old.Patches.Contains(p)),"Unready owner entered a local cut");Check(old with{Patches=partial,Camera=next.Camera});}
            require(TerrainLocalPublication.Select(next.Patches,next.Patches,next.Patches.ToHashSet()) is null,"Unchanged owners triggered another transaction");
        }
        var parent=new TerrainRingLayout.Patch(new Vector3I(0,0,1),48,TerrainRingLayout.Mask.None);
        var children=Enumerable.Range(0,9).Select(i=>new TerrainRingLayout.Patch(new Vector3I(i%3,i/3,0),16,TerrainRingLayout.Mask.None)).ToArray();
        require(TerrainLocalPublication.Select(new[]{parent},children,children.Skip(1).ToHashSet()) is null,"Eight ready children exposed the ninth child's hole");
        require(TerrainLocalPublication.Select(new[]{parent},children,children.ToHashSet())?.Length==9,"A complete nine-child closure waited for unrelated data");
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
                var page=TerrainGpuGridPage.Create(data.Arrays,data.Topology.Axis.Length);var points=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
                require(page.Bytes.Length==points.Length*112,"GPU page size differs from its declared layout");
                for(int band=0;band<4;band++)
                {
                    var controls=data.Arrays[(int)Mesh.ArrayType.Custom0+band].AsFloat32Array();
                    for(int i=0;i<Math.Min(controls.Length,12);i++)
                        require(BitConverter.ToSingle(page.Bytes,((band+3)*points.Length*4+i)*sizeof(float))==controls[i],
                            "Direct GPU upload changed a terrain material control");
                }
                for(int i=0;i<points.Length;i++)
                {
                    float scale=(float)(data.Patch.Size/data.Topology.Denominator);var axis=data.Topology.Axis.Span;
                    var reconstructed=new Vector3(axis[i%page.Rows]*scale,BitConverter.ToSingle(page.Bytes,(i*4+3)*sizeof(float)),axis[i/page.Rows]*scale);
                    require(reconstructed==points[i],"GPU page reconstruction changed emitted canonical or stitched vertices");
                }
            }
            foreach(var data in source)
            {
                var vertices=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();var indices=data.Topology.Indices.Span;double triangleArea=0;
                for(int i=0;i<indices.Length;i+=3){var a=vertices[indices[i]];var b=vertices[indices[i+1]];var c=vertices[indices[i+2]];var center=(a+b+c)/3;require(data.Patch.Contains(data.Patch.OriginX+center.X,data.Patch.OriginZ+center.Z),"Triangle crosses finer terrain ownership");triangleArea+=Math.Abs((double)(b.X-a.X)*(c.Z-a.Z)-(double)(b.Z-a.Z)*(c.X-a.X))*.5;}
                require(Math.Abs(triangleArea-data.Patch.OwnedRegions().Sum(r=>(double)r.Size.X*r.Size.Y))<.01,"Masked topology area differs from ownership");
                var water=TerrainRingWater.Build(data,0,true,true);require(water.Count>0&&water[(int)Mesh.ArrayType.Index].AsInt32Array().SequenceEqual(indices.ToArray()),"Water escaped or lost its masked ownership");
            }
            var cut=TerrainRingTransitions.Stitch(plan,source);require(cut.Meshes.Length==source.Length&&cut.StitchedVertices>0,"Complete cut failed to stitch");
            var memo=new TerrainRingTransitions.Cache();var first=TerrainRingTransitions.Stitch(plan,source,cache:memo);var second=TerrainRingTransitions.Stitch(plan,source,cache:memo);
            require(memo.Hits==source.Length&&first.Meshes.Zip(second.Meshes).All(pair=>ReferenceEquals(pair.First,pair.Second)),"Unchanged cut copied or rebuilt its products");
            require(first.Meshes.Zip(cut.Meshes).All(pair=>pair.First.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array().SequenceEqual(pair.Second.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array())),"Dependency cache changed stitched geometry");
            var changed=source.ToArray();changed[0]=changed[0] with{ProductRevision=TerrainRingMeshGeometry.Data.NewRevision(),WaterEnabled=!changed[0].WaterEnabled};var third=TerrainRingTransitions.Stitch(plan,changed,cache:memo);
            require(first.Meshes[0].GeometryFingerprint!=third.Meshes[0].GeometryFingerprint,"A non-position product revision failed to invalidate publication");
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
