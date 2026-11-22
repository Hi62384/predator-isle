using Godot;
using System;
using System.Runtime.InteropServices;
using A=Godot.Collections.Array;

namespace PredatorIsle.Terrain;

/// <summary>Exact vertex products as nearest RGBA32F texels. Packed categorical controls are never filtered.</summary>
public sealed record TerrainGpuGridPage(int Rows,byte[] Bytes,Aabb Bounds)
{
    // A control bank containing only +0.0 is a zero-valued constant in the
    // vertex shader. Keep other banks (including -0.0) bit-exact.
    public int ControlMask{get;init;}=15;
    // Quantized biome ownership is constant across most pure-biome patches.
    // Send that value once as a uniform instead of repeating it in a texture
    // and fetching it for every vertex (including shadow/depth passes).
    public bool HasConstantColor{get;init;}
    public Vector4 ConstantColor{get;init;}
    public int BaseBands=>HasConstantColor?2:3;
    // The first three bands are always normals/height, UNORM8 colors and
    // UV/surface. Only occupied RGBA32F material banks are transferred.
    // The legacy seven-band layout is still readable with default mask 15.
    public int Bands{get;init;}=7;
    public static int ControlOffset(int mask,int bank,bool constantColor=false)
    {
        if(bank<0||bank>3)throw new ArgumentOutOfRangeException(nameof(bank));
        if((mask & (1<<bank))==0)return -1;
        int offset=constantColor?2:3;
        for(int prior=0;prior<bank;prior++)if((mask&(1<<prior))!=0)offset++;
        return offset;
    }
    public static TerrainGpuGridPage Create(A arrays,int rows)
    {
        int count=checked(rows*rows);var position=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var normal=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();var color=arrays[(int)Mesh.ArrayType.Color].AsColorArray();
        var uv=arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();var uv2=arrays[(int)Mesh.ArrayType.TexUV2].VariantType==Variant.Type.Nil?new Vector2[count]:arrays[(int)Mesh.ArrayType.TexUV2].AsVector2Array();
        return Create(new TerrainVertexProducts(position,normal,color,uv,uv2,arrays[(int)Mesh.ArrayType.Custom0].AsFloat32Array(),arrays[(int)Mesh.ArrayType.Custom1].AsFloat32Array(),arrays[(int)Mesh.ArrayType.Custom2].AsFloat32Array(),arrays[(int)Mesh.ArrayType.Custom3].AsFloat32Array()),rows);
    }
    public static TerrainGpuGridPage Create(TerrainVertexProducts products,int rows)
    {
        if(rows<1)throw new ArgumentOutOfRangeException(nameof(rows));
        int count=checked(rows*rows);var position=products.Vertices;var normal=products.Normals;var color=products.Colors;var uv=products.Uv;var uv2=products.Surface;
        if(position.Length!=count||normal.Length!=count||color.Length!=count||uv.Length!=count||uv2.Length!=count)throw new ArgumentException("Grid page products have different dimensions");
        // First inspect the four categorical banks, then allocate only the
        // occupied strips. Never quantize floats or drop signed-zero lanes.
        int mask=0;
        for(int bank=0;bank<4;bank++)
        {
            var data=bank switch{0=>products.C0,1=>products.C1,2=>products.C2,_=>products.C3};
            if(data.Length!=count*4)throw new ArgumentException("Grid pages require four float controls per vertex");
            for(int i=0;i<data.Length;i++)
                if(BitConverter.SingleToInt32Bits(data[i])!=0){mask|=1<<bank;break;}
        }
        static float Byte(float x)=>MathF.Round(Math.Clamp(x,0,1)*255)/255;
        static Vector4 Quantized(Color c)=>new(Byte(c.R),Byte(c.G),Byte(c.B),Byte(c.A));
        Vector4 firstColor=Quantized(color[0]);bool constantColor=true;
        for(int i=1;i<count;i++)
            if(Quantized(color[i])!=firstColor){constantColor=false;break;}
        int baseBands=constantColor?2:3,bands=baseBands;
        for(int bank=0;bank<4;bank++)if((mask&(1<<bank))!=0)bands++;
        // Write directly into the final upload buffer: no second full atlas
        // and no runtime GPU copies for empty biome-control families.
        var bytes=new byte[checked(count*bands*4*sizeof(float))];var values=MemoryMarshal.Cast<byte,float>(bytes.AsSpan());var bounds=new Aabb(position[0],Vector3.Zero);
        for(int i=0;i<count;i++)
        {
            bounds=bounds.Expand(position[i]);Put(values,count,0,i,new Vector4(normal[i].X,normal[i].Y,normal[i].Z,position[i].Y));
            // ArrayMesh stores vertex colors as UNORM8; keep the same input to biome decoding.
            if(!constantColor)Put(values,count,1,i,Quantized(color[i]));
            Put(values,count,baseBands-1,i,new Vector4(uv[i].X,uv[i].Y,uv2[i].X,uv2[i].Y));
        }
        for(int band=0;band<4;band++)
        {
            int offset=ControlOffset(mask,band,constantColor);
            if(offset<0)continue;
            var input=band switch{0=>products.C0,1=>products.C1,2=>products.C2,_=>products.C3};
            input.AsSpan().CopyTo(values.Slice(offset*count*4,count*4));
        }
        return new(rows,bytes,bounds){ControlMask=mask,Bands=bands,
            HasConstantColor=constantColor,ConstantColor=firstColor};
        static void Put(Span<float> values,int count,int band,int index,Vector4 v)
        {int at=(band*count+index)*4;values[at]=v.X;values[at+1]=v.Y;values[at+2]=v.Z;values[at+3]=v.W;}
    }
}
