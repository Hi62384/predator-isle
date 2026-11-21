using Godot;
using A=Godot.Collections.Array;
namespace PredatorIsle.Terrain;

/// <summary>Owned numerical buffers. Godot packed arrays are materialized only at a CPU upload/cave boundary.</summary>
public sealed record TerrainVertexProducts(Vector3[] Vertices,Vector3[] Normals,Color[] Colors,Vector2[] Uv,Vector2[] Surface,float[] C0,float[] C1,float[] C2,float[] C3)
{
    public A ToArrays(TerrainRingTopology.Grid grid)
    {
        var a=new A();a.Resize((int)Mesh.ArrayType.Max);a[(int)Mesh.ArrayType.Vertex]=Vertices;a[(int)Mesh.ArrayType.Normal]=Normals;a[(int)Mesh.ArrayType.Color]=Colors;a[(int)Mesh.ArrayType.TexUV]=Uv;a[(int)Mesh.ArrayType.TexUV2]=Surface;
        a[(int)Mesh.ArrayType.Custom0]=C0;a[(int)Mesh.ArrayType.Custom1]=C1;a[(int)Mesh.ArrayType.Custom2]=C2;a[(int)Mesh.ArrayType.Custom3]=C3;a[(int)Mesh.ArrayType.Index]=grid.Indices.ToArray();return a;
    }
}
