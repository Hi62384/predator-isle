using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Indexed marching tetrahedra. A lattice edge owns exactly one output vertex.</summary>
public partial class OrganicMeshExtractor : RefCounted
{
    private static readonly int[][] Tetrahedra={new[]{0,5,1,6},new[]{0,1,2,6},new[]{0,2,3,6},new[]{0,3,7,6},new[]{0,7,4,6},new[]{0,4,5,6}};
    protected readonly List<Vector3> Vertices=new(),Normals=new();
    protected readonly List<int> Indices=new();
    public Vector3[] vertices {get=>Vertices.ToArray();set{Vertices.Clear();Vertices.AddRange(value);}}
    public Vector3[] normals {get=>Normals.ToArray();set{Normals.Clear();Normals.AddRange(value);}}
    public int[] indices {get=>Indices.ToArray();set{Indices.Clear();Indices.AddRange(value);}}
    public D edge_vertices {get;set;}=new();
    public float[] field {get;set;}=System.Array.Empty<float>();
    public Vector3I dimensions {get;set;}
    public Vector3 origin {get;set;}
    public double spacing {get;set;}=.1;
    public int sample_count {get;set;}
    public int plane {get;set;}
    public RefCounted? controls {get;set;}
    public RefCounted? edge_refinement {get;set;}
    private string RefinementError=>edge_refinement?.Get("error").AsString()??"";
    private D RefinementFailure()=>new(){["error"]=RefinementError,["edge_refinement204"]=edge_refinement!.Call("snapshot")};
    public D extract(float[] values,Vector3I dims,Vector3 minimum,double cellSize)=>extract(values,dims,minimum,cellSize,null,null);
    public D extract(float[] values,Vector3I dims,Vector3 minimum,double cellSize,RefCounted? job)=>extract(values,dims,minimum,cellSize,job,null);
    public D extract(float[] values,Vector3I dims,Vector3 minimum,double cellSize,RefCounted? job,RefCounted? refinement)
    {
        if(dims.X<2||dims.Y<2||dims.Z<2||(long)dims.X*dims.Y*dims.Z!=values.Length)throw new ArgumentException("The extraction lattice must contain every sample of a three-dimensional grid.");
        edge_refinement=refinement;field=values;dimensions=dims;origin=minimum;spacing=cellSize;controls=job;sample_count=values.Length;plane=checked(dims.X*dims.Y);Vertices.Clear();Normals.Clear();Indices.Clear();edge_vertices.Clear();
        int[] offsets={0,1,dims.X+1,dims.X,plane,plane+1,plane+dims.X+1,plane+dims.X};int active=0;Span<int> inside=stackalloc int[4];Span<int> outside=stackalloc int[4];
        try
        {
            for(int z=0;z<dims.Z-1;z++)
            {
                if(edge_refinement is not null&&RefinementError.Length>0)return RefinementFailure();
                if(job is not null){if(job.Call("is_cancelled").AsBool())return new D{["cancelled"]=true};job.Call("set_progress",.48+.35*z/Math.Max(dims.Z-1,1.0),"Extracting continuous tissue");}
                for(int y=0;y<dims.Y-1;y++)for(int x=0;x<dims.X-1;x++)
                {
                    int start=z*plane+y*dims.X+x,mask=0;for(int c=0;c<8;c++)if(field[start+offsets[c]]<0)mask|=1<<c;if(mask==0||mask==255)continue;active++;
                    foreach(var tet in Tetrahedra)
                    {
                        int n=0,m=0;foreach(int corner in tet){int id=start+offsets[corner];if(field[id]<0)inside[n++]=id;else outside[m++]=id;}if(n==0||m==0)continue;
                        var outward=Vector3.Zero;for(int i=0;i<m;i++)outward+=_point(outside[i])/m;for(int i=0;i<n;i++)outward-=_point(inside[i])/n;
                        if(n==1)_emit(_edge(inside[0],outside[0]),_edge(inside[0],outside[1]),_edge(inside[0],outside[2]),outward);
                        else if(n==3)_emit(_edge(outside[0],inside[0]),_edge(outside[0],inside[1]),_edge(outside[0],inside[2]),outward);
                        else{int a=_edge(inside[0],outside[0]),b=_edge(inside[0],outside[1]),c=_edge(inside[1],outside[0]),d=_edge(inside[1],outside[1]);_emit(a,b,d,outward);_emit(a,d,c,outward);}
                    }
                }
            }
            if(edge_refinement is null)_reconcile_normals();
            else{if(RefinementError.Length>0)return RefinementFailure();_validate_refined_normals();if(RefinementError.Length>0)return _completed_refined_rejection(active);}
            var result=new D{["vertices"]=vertices,["normals"]=normals,["indices"]=indices,["active_cells"]=active};if(edge_refinement is not null)result["edge_refinement204"]=edge_refinement.Call("snapshot");return result;
        }
        finally{edge_vertices.Clear();field=System.Array.Empty<float>();}
    }
    public Vector3 _point(int index){int z=index/plane,remain=index-z*plane,y=remain/dimensions.X,x=remain-y*dimensions.X;return origin+new Vector3(x,y,z)*(float)spacing;}
    public Vector3 _gradient(int index)
    {
        int z=index/plane,remain=index-z*plane,y=remain/dimensions.X,x=remain-y*dimensions.X;
        double dx=(double)field[index+(x+1<dimensions.X?1:0)]-field[index-(x>0?1:0)],dy=(double)field[index+(y+1<dimensions.Y?dimensions.X:0)]-field[index-(y>0?dimensions.X:0)],dz=(double)field[index+(z+1<dimensions.Z?plane:0)]-field[index-(z>0?plane:0)];
        return new Vector3((float)dx,(float)dy,(float)dz);
    }
    public virtual int _edge(int first,int second)
    {
        int low=Math.Min(first,second),high=Math.Max(first,second);long key=(long)low*sample_count+high;if(edge_vertices.TryGetValue(key,out var cached))return cached.AsInt32();
        double a=field[low],b=field[high];Vector3 point,normal;
        if(edge_refinement is not null)
        {
            var refined=edge_refinement.Call("solve",low,high,_point(low),_point(high),a,b).AsGodotDictionary();if(refined.ContainsKey("error"))return -1;point=refined["point"].AsVector3();normal=refined["normal"].AsVector3();
        }
        else{float t=(float)Math.Clamp(a/(a-b),.0001,.9999);point=_point(low).Lerp(_point(high),t);normal=_gradient(low).Lerp(_gradient(high),t).Normalized();if(normal.LengthSquared()<.01)normal=Vector3.Up;}
        int id=Vertices.Count;Vertices.Add(point);Normals.Add(normal);edge_vertices[key]=id;return id;
    }
    public void _emit(int a,int b,int c,Vector3 outward)
    {
        if(edge_refinement is not null&&(a<0||b<0||c<0))return;if(a==b||b==c||c==a)return;var cross=(Vertices[b]-Vertices[a]).Cross(Vertices[c]-Vertices[a]);
        if(cross.LengthSquared()==0){edge_refinement?.Call("reject","204 refined face degenerated; no topology repair.");return;}
        Indices.Add(a);if(cross.Dot(outward)>0){Indices.Add(c);Indices.Add(b);}else{Indices.Add(b);Indices.Add(c);}
    }
    public virtual void _reconcile_normals()
    {
        var geometric=new Vector3[Vertices.Count];for(int i=0;i<Indices.Count;i+=3){int a=Indices[i],b=Indices[i+1],c=Indices[i+2];var n=-(Vertices[b]-Vertices[a]).Cross(Vertices[c]-Vertices[a]);geometric[a]+=n;geometric[b]+=n;geometric[c]+=n;}
        for(int i=0;i<Normals.Count;i++){var normal=geometric[i].Normalized();if(normal.LengthSquared()<.01)continue;Normals[i]=normal.Dot(Normals[i])<.55?normal:normal.Lerp(Normals[i],.72f).Normalized();}
        for(int pass=0;pass<10;pass++)
        {
            int corrected=0;for(int i=0;i<Indices.Count;i+=3)
            {
                int a=Indices[i],b=Indices[i+1],c=Indices[i+2];var outward=-(Vertices[b]-Vertices[a]).Cross(Vertices[c]-Vertices[a]).Normalized();double alignment=(Normals[a]+Normals[b]+Normals[c]).Dot(outward)/3.0;
                if(alignment>=.025)continue;var correction=outward*(float)(.035-alignment)*1.25f;Normals[a]=(Normals[a]+correction).Normalized();Normals[b]=(Normals[b]+correction).Normalized();Normals[c]=(Normals[c]+correction).Normalized();corrected++;
            }
            if(corrected==0)break;
        }
    }
    public void _validate_refined_normals()
    {
        for(int i=0;i<Indices.Count;i+=3){int a=Indices[i],b=Indices[i+1],c=Indices[i+2];var outward=-(Vertices[b]-Vertices[a]).Cross(Vertices[c]-Vertices[a]);if(!outward.IsFinite()||outward.LengthSquared()==0||(Normals[a]+Normals[b]+Normals[c]).Dot(outward)<=0){edge_refinement!.Call("reject","204 refined face/field-normal inconsistency; no normal or topology repair.");return;}}
    }
    public D _completed_refined_rejection(int active)
    {
        var result=new D{["error"]=RefinementError,["edge_refinement204"]=edge_refinement!.Call("snapshot"),["rejected"]=true,["raw_snapshot_complete"]=false};
        if(Vertices.Count==0||Normals.Count!=Vertices.Count||Indices.Count==0||Indices.Count%3!=0)return result;
        foreach(var p in Vertices)if(!p.IsFinite())return result;foreach(var n in Normals)if(!n.IsFinite())return result;foreach(int i in Indices)if(i<0||i>=Vertices.Count)return result;
        result["vertices"]=vertices;result["normals"]=normals;result["indices"]=indices;result["active_cells"]=active;result["raw_snapshot_complete"]=true;result["raw_snapshot_status"]="completed_finite_index_safe_rejected_before_attribution";result["finite_index_safe"]=true;return result;
    }
}
