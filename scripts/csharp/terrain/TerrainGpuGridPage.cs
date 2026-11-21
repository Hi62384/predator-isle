using Godot;
using System;
using A=Godot.Collections.Array;

namespace PredatorIsle.Terrain;

/// <summary>Exact vertex products as nearest RGBA32F texels. Packed categorical controls are never filtered.</summary>
public sealed record TerrainGpuGridPage(int Rows,byte[] Bytes,Aabb Bounds)
{
    public static TerrainGpuGridPage Create(A arrays,int rows)
    {
        int count=checked(rows*rows);var position=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var normal=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();var color=arrays[(int)Mesh.ArrayType.Color].AsColorArray();
        var uv=arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();var uv2=arrays[(int)Mesh.ArrayType.TexUV2].VariantType==Variant.Type.Nil?new Vector2[count]:arrays[(int)Mesh.ArrayType.TexUV2].AsVector2Array();
        return Create(new TerrainVertexProducts(position,normal,color,uv,uv2,arrays[(int)Mesh.ArrayType.Custom0].AsFloat32Array(),arrays[(int)Mesh.ArrayType.Custom1].AsFloat32Array(),arrays[(int)Mesh.ArrayType.Custom2].AsFloat32Array(),arrays[(int)Mesh.ArrayType.Custom3].AsFloat32Array()),rows);
    }
    public static TerrainGpuGridPage Create(TerrainVertexProducts products,int rows)
    {
        int count=checked(rows*rows);var position=products.Vertices;var normal=products.Normals;var color=products.Colors;var uv=products.Uv;var uv2=products.Surface;
        if(position.Length!=count||normal.Length!=count||color.Length!=count||uv.Length!=count||uv2.Length!=count)throw new ArgumentException("Grid page products have different dimensions");
        var values=new float[checked(count*7*4)];var bounds=new Aabb(position[0],Vector3.Zero);
        for(int i=0;i<count;i++)
        {
            bounds=bounds.Expand(position[i]);Put(0,i,new Vector4(normal[i].X,normal[i].Y,normal[i].Z,position[i].Y));
            // ArrayMesh stores vertex colors as UNORM8; keep the same input to biome decoding.
            static float Byte(float x)=>MathF.Round(Math.Clamp(x,0,1)*255)/255;
            var c=color[i];Put(1,i,new Vector4(Byte(c.R),Byte(c.G),Byte(c.B),Byte(c.A)));Put(2,i,new Vector4(uv[i].X,uv[i].Y,uv2[i].X,uv2[i].Y));
        }
        for(int band=0;band<4;band++)
        {
            var input=band switch{0=>products.C0,1=>products.C1,2=>products.C2,_=>products.C3};if(input.Length!=count*4)throw new ArgumentException("Grid pages require four float controls per vertex");
            input.CopyTo(values,(band+3)*count*4);
        }
        var bytes=new byte[values.Length*sizeof(float)];Buffer.BlockCopy(values,0,bytes,0,bytes.Length);return new(rows,bytes,bounds);
        void Put(int band,int index,Vector4 v){int at=(band*count+index)*4;values[at]=v.X;values[at+1]=v.Y;values[at+2]=v.Z;values[at+3]=v.W;}
    }
}
