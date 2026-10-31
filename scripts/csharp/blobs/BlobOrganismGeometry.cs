using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobOrganismPipeline
{
    private sealed class MeshBuffer
    {
        public readonly List<Vector3> Vertices=new(),Normals=new();
        public readonly List<int> Indices=new(),Owners=new();
        public readonly List<Color> Colors=new();
        public readonly List<Vector2> Uvs=new(),Uvs2=new(),SheetParameters=new();
        public readonly List<float> Anchors=new(),Mechanics=new();
        public D Finish()=>new(){["vertices"]=Vertices.ToArray(),["normals"]=Normals.ToArray(),["indices"]=Indices.ToArray(),["colors"]=Colors.ToArray(),["uvs"]=Uvs.ToArray(),["uvs2"]=Uvs2.ToArray(),["anchors"]=Anchors.ToArray(),["mechanics"]=Mechanics.ToArray(),["feature_ids"]=Owners.ToArray()};
        public void Tri(params int[] indices)=>Indices.AddRange(indices);
    }
    private void AppendVertex(MeshBuffer mesh,Vector3 p,Vector3 normal,D f,double t,bool materials)
    {
        string tissue=S(f,"tissue");var color=TissueColor(tissue);var root=f.TryGetValue("root_color",out var rootColor)?rootColor.AsColor():color;double blend=1-Smooth(0,.32,t);mesh.Vertices.Add(p);mesh.Normals.Add(normal);mesh.Colors.Add(materials?root.Lerp(color,(float)(1-blend)):new Color(.36f,.32f,.26f));int tissueId=Array.IndexOf(Tissues,tissue);mesh.Uvs.Add(new Vector2(tissueId,(float)N(dna,"wetness")));mesh.Uvs2.Add(new Vector2(f.TryGetValue("root_tissue",out var rt)?(float)rt.AsDouble():tissueId,(float)blend));mesh.Owners.Add(f["id"].AsInt32());var center=V(f,"center");double freedom=(f.TryGetValue("flexibility",out var flex)?flex.AsDouble():0)*Smooth(0,.8,t);mesh.Anchors.AddRange(new[]{center.X,center.Y,center.Z,(float)freedom});mesh.Mechanics.AddRange(new[]{(float)Stiffness(tissue),S(f,"slide_coupling")=="active"?1f:0,(float)((f["id"].AsInt32()%2)*Math.PI),(float)t});
    }
    private D Sheet(D f,bool materials)
    {
        var mesh=new MeshBuffer();var ids=f["support_ids"].AsGodotArray();var left=features[ids[0].AsInt32()].AsGodotDictionary();var right=features[ids[1].AsInt32()].AsGodotDictionary();var aCurve=left["binding_curve"].AsVector3Array();var bCurve=right["binding_curve"].AsVector3Array();int rows=10,columns=8;f["sheet_rows"]=rows;f["sheet_columns"]=columns;f["t_min"]=.15;f["t_max"]=.55;f["thickness"]=Size*.008;f["sag"]=Size*.025;var reference=Vector3.Zero;
        for(int row=0;row<=rows;row++){double t=.15+(.55-.15)*row/rows;var a=Frames.point(aCurve,t);var b=Frames.point(bCurve,t);var normal=(b-a).Cross(Frames.tangent(aCurve,t)+Frames.tangent(bCurve,t)).Normalized();if(row==0)reference=normal;if(a.DistanceTo(b)>Size*1.1||a.DistanceTo(b)<Size*.06||normal.Dot(reference)<.5){f["omitted"]=true;f["omission_reason"]="Incompatible web supports";var empty=mesh.Finish();empty["sheet_params"]=Array.Empty<Vector2>();return empty;}}
        for(int layer=0;layer<2;layer++)for(int row=0;row<=rows;row++){double v=(double)row/rows;for(int column=0;column<=columns;column++){double u=(double)column/columns,t=.15+(.55-.15)*v-.13*v*4*u*(1-u);var a=Frames.point(aCurve,t);var b=Frames.point(bCurve,t);var normal=(b-a).Cross(Frames.tangent(aCurve,t)+Frames.tangent(bCurve,t)).Normalized();mesh.SheetParameters.Add(new Vector2((float)t,(float)u));var p=a.Lerp(b,(float)u)+normal*(float)(N(f,"thickness")*(layer==0?1:-1)-N(f,"sag")*Math.Sin(v*Math.PI)*4*u*(1-u));AppendVertex(mesh,p,normal*(layer==0?1:-1),f,t,materials);}}
        int offset=(rows+1)*(columns+1);for(int row=0;row<rows;row++)for(int column=0;column<columns;column++){int a=row*(columns+1)+column,b=a+1,c=a+columns+1,d=c+1;mesh.Tri(a,c,b,b,c,d,a+offset,b+offset,c+offset,b+offset,d+offset,c+offset);}for(int row=0;row<rows;row++)foreach(int col in new[]{0,columns}){int a=row*(columns+1)+col,b=a+columns+1;mesh.Tri(a,b,a+offset,b,b+offset,a+offset);}for(int col=0;col<columns;col++)foreach(int row in new[]{0,rows}){int a=row*(columns+1)+col,b=a+1;mesh.Tri(a,b,a+offset,b,b+offset,a+offset);}var result=mesh.Finish();result["sheet_params"]=mesh.SheetParameters.ToArray();return result;
    }
    private static Basis Frame(Vector3 normal){var side=Vector3.Up.Cross(normal).Normalized();if(side.LengthSquared()<.1)side=Vector3.Right;return new Basis(side,normal.Cross(side).Normalized(),normal);}
    private D Bulb(D f,bool materials)
    {
        var mesh=new MeshBuffer();int rows=12,sides=24;var parent=features[f["parent"].AsInt32()].AsGodotDictionary();var parentPoints=parent["points"].AsGodotArray();var axis=(parentPoints[^1].AsVector3()-parentPoints[^2].AsVector3()).Normalized();var frame=Frame(axis);double baseRadius=parent["radii_profile"].AsGodotArray()[^1].AsDouble(),height=V(f,"bulb_radii").Y*1.8;int variety=f["id"].AsInt32()%3;f["root_tissue"]=Array.IndexOf(Tissues,S(parent,"tissue"));f["root_color"]=TissueColor(S(parent,"tissue"));
        for(int layer=0;layer<2;layer++)for(int row=0;row<=rows;row++){double t=(double)row/rows,swelling=Math.Sin(t*Math.PI*.9)*(variety==0?.7:1),radius=baseRadius*(1+swelling*2.8);if(layer==1)radius=Math.Max(baseRadius*.45,radius-baseRadius*.3);for(int side=0;side<sides;side++){double angle=(double)side/sides*Math.Tau,ribs=1+.08*t*Math.Sin(angle*5+t*3)+.035*t*Math.Sin(angle*9-t*4);var n=frame.X*(float)Math.Cos(angle)+frame.Y*(float)Math.Sin(angle);var center=V(f,"center")+axis*(float)height*(float)t+frame.X*(float)height*(float)t*(float)t*.15f;AppendVertex(mesh,center+n*(float)radius*(float)ribs,n*(layer==0?1:-1),f,t,materials);}}
        int offset=(rows+1)*sides;for(int row=0;row<rows;row++)for(int side=0;side<sides;side++){int a=row*sides+side,b=row*sides+(side+1)%sides,c=a+sides,d=b+sides;mesh.Tri(a,b,c,b,d,c,a+offset,c+offset,b+offset,b+offset,c+offset,d+offset);}foreach(int row in new[]{0,rows})for(int side=0;side<sides;side++){int a=row*sides+side,b=row*sides+(side+1)%sides;mesh.Tri(a,a+offset,b,b,a+offset,b+offset);}return mesh.Finish();
    }
    private D Tube(D curve,D f,bool materials)
    {
        var mesh=new MeshBuffer();var points=curve["points"].AsVector3Array();var radii=curve["radii"].AsFloat32Array();string kind=S(f,"feature_type");
        if(Is(kind,"vascular_trunk","vascular_branch","capillary","anatomical_fold"))
        {
            var parent=features[f["parent"].AsInt32()].AsGodotDictionary();for(int steps=0;parent.ContainsKey("points")&&parent["parent"].AsInt32()>=0;steps++){if(steps>=features.Count)throw new ArgumentException("Anatomical parent hierarchy is cyclic.");parent=features[parent["parent"].AsInt32()].AsGodotDictionary();}var outward=V(parent,"direction");double epsilon=Size*.006;
            for(int i=0;i<points.Length;i++){var original=points[i];double shift=0;for(int iteration=0;iteration<5;iteration++){var point=original+outward*(float)shift;double distance=_positive_field(point),gradient=(_positive_field(point+outward*(float)epsilon)-_positive_field(point-outward*(float)epsilon))/(epsilon*2);if(Math.Abs(gradient)<.15)break;shift=Math.Clamp(shift-distance/gradient,-Size*.25,Size*.45);}points[i]=original+outward*(float)(shift+(double)radii[i]*.35+.008);}
        }
        int sides=dna["quality"].AsInt32()==0?8:10;var previousAxis=Vector3.Zero;var bound=f.TryGetValue("binding_curve",out var binding)?binding.AsVector3Array():Array.Empty<Vector3>();var axes=bound.Length>0?Frames.normals(bound):Array.Empty<Vector3>();
        for(int i=0;i<points.Length;i++)
        {
            var tangent=(points[Math.Min(i+1,points.Length-1)]-points[Math.Max(i-1,0)]).Normalized();var axis=previousAxis-tangent*previousAxis.Dot(tangent);if(axis.LengthSquared()<.01){axis=tangent.Cross(Vector3.Up);if(axis.LengthSquared()<.01)axis=tangent.Cross(Vector3.Right);}axis=axis.Normalized();previousAxis=axis;double t=(double)i/Math.Max(points.Length-1,1);if(bound.Length>0){var frame=Frames.frame(bound,axes,t);axis=frame.X;tangent=frame.Z;}
            for(int j=0;j<sides;j++){double angle=j*Math.Tau/sides;var normal=axis.Rotated(tangent,(float)angle);double radius=radii[i];if(Is(kind,"major_vine","vine_branch","root_curtain","facial_drape"))radius*=1-.8*Smooth(.78,1,t);double organic=1+.055*Math.Sin(angle*3+t*8+N(f,"id"))*Math.Sin(t*Math.PI)+.035*Math.Sin(t*23+N(f,"id"))*Math.Sin(t*Math.PI);var radial=normal*(float)radius*(float)organic;if(B(f,"ribbon"))radial=axis*(float)Math.Cos(angle)*radii[i]*2.2f+tangent.Cross(axis)*(float)Math.Sin(angle)*radii[i]*.3f;AppendVertex(mesh,points[i]+radial,normal,f,t,materials);if(i<points.Length-1){int a=i*sides+j,b=i*sides+(j+1)%sides;mesh.Tri(a,b,a+sides,b,b+sides,a+sides);}}
        }
        for(int end=0;end<2;end++){int ring=end==0?0:points.Length-1,center=mesh.Vertices.Count;var tangent=end==0?(points[1]-points[0]).Normalized():(points[^1]-points[^2]).Normalized();AppendVertex(mesh,points[ring],end==0?-tangent:tangent,f,end,materials);for(int j=0;j<sides;j++){int a=ring*sides+j,b=ring*sides+(j+1)%sides;if(end==0)mesh.Tri(center,b,a);else mesh.Tri(center,a,b);}}
        var result=mesh.Finish();result["centerline"]=(Vector3[])points.Clone();result["sides"]=sides;return result;
    }
    private static void AlignWinding(D mesh)
    {
        var indices=mesh["indices"].AsInt32Array();var vertices=mesh["vertices"].AsVector3Array();var normals=mesh["normals"].AsVector3Array();for(int i=0;i<indices.Length;i+=3){int a=indices[i],b=indices[i+1],c=indices[i+2];var cross=(vertices[b]-vertices[a]).Cross(vertices[c]-vertices[a]);var normal=normals[a]+normals[b]+normals[c];if(cross.Dot(normal)>0){indices[i+1]=c;indices[i+2]=b;}}mesh["indices"]=indices;
    }
}
