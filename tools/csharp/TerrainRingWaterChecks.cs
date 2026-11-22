using Godot;
using System;
using System.Linq;
using PredatorIsle.Terrain;
using A=Godot.Collections.Array;

namespace PredatorIsle.Checks;

/// <summary>Water consumes the same compact extension atlas as the GPU.
/// Exercise every ownership mask, nonuniform values and inserted third knots.</summary>
internal static class TerrainRingWaterChecks
{
    internal static void Run(Action<bool,string> require)
    {
        const int atlasRows=3;
        var patch=new TerrainRingLayout.Patch(new Vector3I(-1,2,2),144,
            new TerrainRingLayout.Mask(1,1,2,2));
        var grid=new TerrainRingTopology().Get(2,true,patch.Hole);
        int count=grid.VertexCount,row=grid.Axis.Length;
        var vertices=new Vector3[count];var normals=new Vector3[count];
        var uv=new Vector2[count];
        for(int i=0;i<count;i++)
        {
            vertices[i]=new Vector3((float)(patch.Size*grid.Axis.Span[i%row]/grid.Denominator),-2,
                (float)(patch.Size*grid.Axis.Span[i/row]/grid.Denominator));
            normals[i]=Vector3.Up;uv[i]=new Vector2(2,0);
        }
        var products=new TerrainVertexProducts(vertices,normals,new Color[count],uv,
            new Vector2[count],new float[count*4],new float[count*4],
            new float[count*4],new float[count*4]);
        for(int mask=1;mask<=255;mask++)
        foreach(bool palette in new[]{false,true})
        {
            // This fixture builds its atlas independently of the production
            // layout helper, so a shared offset bug cannot make the check pass.
            int families=System.Numerics.BitOperations.PopCount((uint)mask);
            int strips=families+2+(palette?1:0),width=strips*atlasRows;
            var bytes=new byte[atlasRows*width*4];int slot=0;
            for(int family=0;family<8;family++)
            {
                if((mask&(1<<family))==0)continue;
                for(int z=0;z<atlasRows;z++)for(int x=0;x<atlasRows;x++)
                {
                    byte weight=Weight(family,x,z);
                    bytes[(z*width+slot*atlasRows+x)*4]=weight;
                    bytes[(z*width+(families+family/4)*atlasRows+x)*4+family%4]=weight;
                }
                slot++;
            }
            if(palette)
                for(int z=0;z<atlasRows;z++)for(int x=0;x<atlasRows;x++)
                    bytes[(z*width+(strips-1)*atlasRows+x)*4]=255;
            var data=new TerrainRingMeshGeometry.Data(patch,grid,null!,bytes,atlasRows,
                mask,palette?strips-1:-1,Array.Empty<byte>(),0){Products=products};
            var result=TerrainRingWater.Build(data,0,false,true);
            require(result.Count>0,"Compact atlas lost extension water for mask "+mask);
            require(result[(int)Mesh.ArrayType.Index].AsInt32Array().SequenceEqual(grid.Indices.ToArray()),
                "Extension water changed the masked triangle footprint for mask "+mask);
            var classes=result[(int)Mesh.ArrayType.TexUV2].AsVector2Array();
            for(int i=0;i<count;i++)
            {
                double x=vertices[i].X/patch.Size*2,z=vertices[i].Z/patch.Size*2;
                int ix=Math.Min((int)x,1),iz=Math.Min((int)z,1);
                double tx=x-ix,tz=z-iz,expected=0;
                for(int family=0;family<8;family++)
                {
                    if((mask&(1<<family))==0)continue;
                    double a=Weight(family,ix,iz)/255.0,b=Weight(family,ix+1,iz)/255.0,
                        c=Weight(family,ix,iz+1)/255.0,d=Weight(family,ix+1,iz+1)/255.0;
                    double top=a+(b-a)*tx,bottom=c+(d-c)*tx;
                    expected+=top+(bottom-top)*tz;
                }
                require(classes[i].Y==-(float)expected,
                    "Compact extension water sampled the wrong family or palette at mask "+mask);
            }
        }
        // Badlands ownership is encoded independently of mountain ownership.
        // A pure badlands pond must not disappear merely because no mountain
        // vertices occur in the same patch.
        var badlands=products with{Uv=(Vector2[])uv.Clone(),C0=new float[count*4]};
        for(int i=0;i<count;i++){badlands.C0[i*4+3]=-1;badlands.Uv[i].Y=255+127*65536;}
        var pond=new TerrainRingMeshGeometry.Data(patch,grid,null!,Array.Empty<byte>(),0,0,
            -1,Array.Empty<byte>(),0){Products=badlands,HasMountain=false};
        var water=TerrainRingWater.Build(pond,0,false,true);
        require(water.Count>0&&water[(int)Mesh.ArrayType.TexUV2].AsVector2Array().All(v=>v.Y==-1),
            "Pure badlands lost its local water without a mountain material bank");
        require(TerrainRingWater.Build(pond,0,false,false).Count==0,
            "Disabled water still emitted extension or badlands triangles");
    }
    private static byte Weight(int family,int x,int z)=>(byte)((family+1)*3+x*2+z*3);
}
