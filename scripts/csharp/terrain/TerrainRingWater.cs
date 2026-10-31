using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;

namespace PredatorIsle.Terrain;

/// <summary>Retained local water follows the actual masked triangle layout; it never supplies walking collision.</summary>
public static class TerrainRingWater
{
    public static A Build(TerrainRingMeshGeometry.Data data,double waterLevel,bool beachesEnabled,bool waterEnabled)
    {
        var result=new A();if(!waterEnabled)return result;var arrays=data.Arrays;var terrain=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();var source=arrays[(int)Mesh.ArrayType.Index].AsInt32Array();var uv=arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();var controls=arrays[(int)Mesh.ArrayType.Custom3].AsFloat32Array();var mountain=arrays[(int)Mesh.ArrayType.Custom0].AsFloat32Array();var coast=arrays[(int)Mesh.ArrayType.Custom1].AsFloat32Array();var tropical=arrays[(int)Mesh.ArrayType.Custom2].AsFloat32Array();var terrainColors=arrays[(int)Mesh.ArrayType.Color].AsColorArray();int count=terrain.Length;var vertices=new Vector3[count];var normals=new Vector3[count];var colors=new Color[count];var uvs=new Vector2[count];var classes=new Vector2[count];var wet=new byte[count];var marine=new byte[count];
        for(int i=0;i<count;i++)
        {
            int at=i*4;double weight=Math.Floor(controls[at]/65536.0)/255;if(controls[at]<0)weight=terrainColors[i].A;double tw=tropical[at]<0?(((long)(-(double)tropical[at]-1)>>16)&255)/255.0:0;double mw=mountain[at]<0?Math.Floor(mountain[at+1]/65536.0)/255:0,cw=coast[at+2]<0?(((long)(-(double)coast[at+2]-1)>>8)&255)/255.0:0;
            if(data.HasMountain&&mountain[at+3]<0)tw+=((long)uv[i].Y&255)/255.0;if(data.ExtensionMask!=0&&data.ExtensionData.Length>0)tw+=ExtensionWeight(data,terrain[i]);double sediment=((long)controls[at+1]&255)/255.0,organic=((long)controls[at+3]>>8&255)/255.0,basin=((long)controls[at+1]>>16&255)/255.0;
            mw*=1-cw;tw*=1-cw;if(cw>.01&&uv[i].X<=waterLevel+.2){cw=mw=weight=tw=0;if(beachesEnabled)marine[i]=1;}if(mw>0){sediment=sediment+((((long)mountain[at+1]>>8)&255)/255.0-sediment)*mw;organic*=1-mw;}if(tw>0){sediment=sediment+(.45-sediment)*tw;organic*=1-tw;}if(cw>0){weight*=1-cw;sediment=sediment+((((long)coast[at+3]>>16)&255)/255.0-sediment)*cw;organic*=1-cw;}
            vertices[i]=new Vector3(terrain[i].X,uv[i].X,terrain[i].Z);normals[i]=Vector3.Up;colors[i]=new Color((float)sediment,(float)organic,(float)weight,(float)basin);uvs[i]=new Vector2(terrain[i].Y,uv[i].X);var classification=new Vector2((float)(((long)controls[at+1]>>8&255)/255.0),(float)(((long)controls[at+3]>>16&255)/255.0));if(mw+cw+tw>0)classification.Y=(float)-Math.Max(Math.Max(mw,cw),tw);if(cw>0)classification.X=(float)-cw;classes[i]=classification;if(weight+mw+cw+tw>.01&&uv[i].X+weight>terrain[i].Y)wet[i]=1;
        }
        var indices=new List<int>();for(int i=0;i<source.Length;i+=3){int a=source[i],b=source[i+1],c=source[i+2];if(wet[a]+wet[b]+wet[c]>0&&marine[a]+marine[b]+marine[c]==0){indices.Add(a);indices.Add(b);indices.Add(c);}}if(indices.Count==0)return result;result.Resize((int)Mesh.ArrayType.Max);result[(int)Mesh.ArrayType.Vertex]=vertices;result[(int)Mesh.ArrayType.Normal]=normals;result[(int)Mesh.ArrayType.Color]=colors;result[(int)Mesh.ArrayType.TexUV]=uvs;result[(int)Mesh.ArrayType.TexUV2]=classes;result[(int)Mesh.ArrayType.Index]=indices.ToArray();return result;
    }
    private static double ExtensionWeight(TerrainRingMeshGeometry.Data data,Vector3 vertex)
    {
        int row=data.ExtensionRows;if(row<2)return 0;int width=data.ExtensionData.Length/(row*4);double x=Math.Clamp(vertex.X/data.Patch.Size*(row-1),0,row-1),z=Math.Clamp(vertex.Z/data.Patch.Size*(row-1),0,row-1);int ix=Math.Min((int)x,row-2),iz=Math.Min((int)z,row-2);double tx=x-ix,tz=z-iz,total=0;
        for(int family=0;family<8;family++)if((data.ExtensionMask&(1<<family))!=0){double Value(int px,int pz)=>data.ExtensionData[(pz*width+family*row+px)*4]/255.0;double a=Value(ix,iz)+(Value(ix+1,iz)-Value(ix,iz))*tx,b=Value(ix,iz+1)+(Value(ix+1,iz+1)-Value(ix,iz+1))*tx;total+=a+(b-a)*tz;}return total;
    }
}
