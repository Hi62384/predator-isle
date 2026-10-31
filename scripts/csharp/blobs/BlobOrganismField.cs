using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobOrganismPipeline
{
    private static double N(D d,string key)=>d[key].AsDouble();
    private static string S(D d,string key)=>d[key].AsString();
    private static Vector3 V(D d,string key)=>d[key].AsVector3();
    private static bool B(D d,string key)=>d.TryGetValue(key,out var v)&&v.AsBool();
    private static bool Is(string v,params string[] choices)=>Array.IndexOf(choices,v)>=0;
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private double Size=>N(dna,"size");
    private D Controls=>dna["controls"].AsGodotDictionary();
    public int _feature(string kind,int parent,int pass,Vector3 center,Vector3 radii,string tissue)=>_feature(kind,parent,pass,center,radii,tissue,false);
    public int _feature(string kind,int parent,int pass,Vector3 center,Vector3 radii,string tissue,bool subtract)
    {
        int id=features.Count;features.Add(new D{["id"]=id,["parent"]=parent,["pass_created"]=pass,["feature_type"]=kind,["center"]=center,["radii"]=radii,["bounds"]=new Aabb(center-radii,radii*2),["influence"]=new D{["shape"]="ellipsoid",["blend"]=.16*Size},["surface_mapping"]="body_vertex_feature_ids",["material_category"]=tissue,["detail_category"]=tissue,["tissue"]=tissue,["subtract"]=subtract,["direction"]=Vector3.Up,["locomotion_relevance"]=tissue=="belly"?"contact":"passive",["roll_coupling"]="coupled",["slide_coupling"]="deform"});return id;
    }
    private static double Gaussian(Vector2 p,Vector2 width)=>Math.Exp(-(p/width).LengthSquared()*2.0);
    public double _distance(Vector3 p,D f)
    {
        if(B(f,"fused_path"))
        {
            double best=double.PositiveInfinity;var points=f["points"].AsGodotArray();var radii=f["radii_profile"].AsGodotArray();for(int i=0;i<points.Count-1;i++){var a=points[i].AsVector3();var b=points[i+1].AsVector3();var line=b-a;double t=Math.Clamp((double)(p-a).Dot(line)/Math.Max(line.LengthSquared(),.000001),0,1);best=Math.Min(best,p.DistanceTo(a+line*(float)t)-(radii[i].AsDouble()+(radii[i+1].AsDouble()-radii[i].AsDouble())*t));}return best;
        }
        var delta=p-V(f,"center");var radius=V(f,"radii");
        if(B(f,"torus")){var normal=V(f,"direction");double axial=delta.Dot(normal),radial=(delta-normal*(float)axial).Length();return new Vector2((float)(radial-radius.X),(float)axial).Length()-radius.Y;}
        if(f.TryGetValue("inverse_basis",out var basis))delta=basis.AsBasis()*delta;double minimum=Math.Min(radius.X,Math.Min(radius.Y,radius.Z)),distance=(delta/radius).Length()*minimum-minimum;
        if(B(f,"face_relief")&&delta.Z>0)
        {
            var uv=new Vector2(delta.X/radius.X,delta.Y/radius.Y);double relief=0;foreach(double side in new[]{-1.0,1.0}){var eye=new Vector2((float)(side*N(f,"eye_spacing")),.12f);relief-=.15*Gaussian(uv-eye,new Vector2(.25f,.14f));relief+=.11*Gaussian(uv-(eye+new Vector2(0,.16f)),new Vector2(.35f,.12f));relief+=.05*Gaussian(uv-(eye+new Vector2(0,-.05f)),new Vector2(.24f,.055f));relief+=.07*Gaussian(uv-new Vector2((float)(side*.52),-.2f),new Vector2(.3f,.25f));relief-=.055*Gaussian(uv-new Vector2((float)(side*.12),-.18f),new Vector2(.07f,.06f));}
            relief+=.2*Gaussian(uv-new Vector2(0,.03f),new Vector2(.18f,(float)(N(f,"nose_length")*.65)));relief+=.22*Gaussian(uv-new Vector2(0,-.16f),new Vector2(.23f,.14f));relief-=.11*Gaussian(uv-new Vector2(0,-.44f),new Vector2(.4f,.05f));relief+=.10*Gaussian(uv-new Vector2(0,-.51f),new Vector2(.4f,.08f));relief+=.08*Gaussian(uv-new Vector2(0,-.36f),new Vector2(.39f,.07f));double boundary=Math.Pow(Math.Max(0,1-(double)uv.X*uv.X),2)*Math.Pow(Math.Max(0,1-(double)uv.Y*uv.Y),2);distance-=relief*radius.X*boundary*Smooth(0,.65,(double)delta.Z/radius.Z);
        }
        return distance;
    }
    public void _orient(int id,Vector3 normal)
    {
        var side=Vector3.Up.Cross(normal).Normalized();if(side.LengthSquared()<.1)side=Vector3.Right;var frame=new Basis(side,normal.Cross(side).Normalized(),normal);var f=features[id].AsGodotDictionary();var radii=V(f,"radii");f["inverse_basis"]=frame.Transposed();var extent=frame.X.Abs()*radii.X+frame.Y.Abs()*radii.Y+frame.Z.Abs()*radii.Z;f["bounds"]=new Aabb(V(f,"center")-extent,extent*2);
    }
    public Vector3 _surface(Vector3 normal)
    {
        double farthest=0;foreach(var value in features){var f=value.AsGodotDictionary();if(B(f,"subtract")||f.ContainsKey("points")||B(f,"torus"))continue;var frame=f.TryGetValue("inverse_basis",out var basis)?basis.AsBasis():Basis.Identity;var radius=V(f,"radii");var origin=frame*(-V(f,"center"))/radius;var ray=frame*normal/radius;double a=ray.Dot(ray),b=2.0*origin.Dot(ray),c=origin.Dot(origin)-1,discriminant=b*b-4*a*c;if(discriminant<0)continue;farthest=Math.Max(farthest,(-b+Math.Sqrt(discriminant))/(2*a));}return normal*(float)farthest;
    }
    public double _positive_field(Vector3 point)
    {
        double distance=100;foreach(var value in features){var f=value.AsGodotDictionary();if(B(f,"subtract")||(f.ContainsKey("points")&&!B(f,"fused_path")))continue;double d=_distance(point,f),k=Math.Max(.001,Size*.12*N(Controls,"fusion"));var r=V(f,"radii");if(f["pass_created"].AsInt32()>=4)k=Math.Min(k,Math.Min(r.X,Math.Min(r.Y,r.Z))*.6);double h=Math.Max(k-Math.Abs(distance-d),0)/k;distance=Math.Min(distance,d)-h*h*k*.25;}return distance;
    }
    private void FitEnvelope()
    {
        var radii=V(dna,"core_radii");var coefficients=new Vector4[9];for(int slice=0;slice<9;slice++){double x=-radii.X*.98+(radii.X*.98*2)*slice/8.0;var coefficient=Vector4.Zero;for(int ring=0;ring<20;ring++){double angle=Math.Tau*ring/20,low=0,high=2.5;for(int iteration=0;iteration<11;iteration++){double mid=(low+high)*.5;var p=new Vector3((float)x,(float)(Math.Cos(angle)*radii.Y*mid),(float)(Math.Sin(angle)*radii.Z*mid));double distance=double.PositiveInfinity;foreach(var value in features)distance=Math.Min(distance,_distance(p,value.AsGodotDictionary()));if(distance<0)low=mid;else high=mid;}coefficient+=new Vector4((float)low,(float)(2*low*Math.Cos(angle)),(float)(2*low*Math.Sin(angle)),(float)(2*low*Math.Cos(angle*2)))/20;}coefficient.X=Math.Max(coefficient.X,.12f);coefficients[slice]=coefficient;}dna["envelope"]=coefficients;
    }
    private D Extract(int quality)
    {
        var bounds=new Aabb(Vector3.Zero,Vector3.One*.001f);foreach(var value in features){var f=value.AsGodotDictionary();if((!f.ContainsKey("points")||B(f,"fused_path"))&&!B(f,"subtract"))bounds=bounds.Merge(f["bounds"].AsAabb());}bounds=bounds.Grow((float)(Size*.3));double cell=bounds.Size[(int)bounds.Size.MaxAxisIndex()]/new[]{40.0,72,108}[quality];bounds.Position+=new Vector3(.73f,.37f,.91f)*(float)cell*(float)extraction_offset;
        var dims=new Vector3I((int)Math.Ceiling(bounds.Size.X/cell)+1,(int)Math.Ceiling(bounds.Size.Y/cell)+1,(int)Math.Ceiling(bounds.Size.Z/cell)+1);var values=new float[checked(dims.X*dims.Y*dims.Z)];Array.Fill(values,100);
        for(int pass=0;pass<3;pass++)
        {
            bool subtract=pass==1;foreach(var value in features)
            {
                var f=value.AsGodotDictionary();if((f.ContainsKey("points")&&!B(f,"fused_path"))||B(f,"subtract")!=subtract)continue;bool lining=S(f,"feature_type")=="cavity_organ";if((pass==0&&lining)||(pass==2&&!lining))continue;if(Cancelled())return new D{["cancelled"]=true};
                double k=Math.Max(.001,Size*(subtract?.018:B(f,"torus")?.025:.12*N(Controls,"fusion")));var radii=V(f,"radii");if(!subtract&&f["pass_created"].AsInt32()>=4)k=Math.Min(k,Math.Min(radii.X,Math.Min(radii.Y,radii.Z))*.6);var box=f["bounds"].AsAabb().Grow((float)(k+cell*2));
                static Vector3I Truncate(Vector3 v)=>new((int)v.X,(int)v.Y,(int)v.Z);
                var lo=Truncate((box.Position-bounds.Position)/(float)cell).Max(Vector3I.Zero);var hi=(Truncate((box.End-bounds.Position)/(float)cell)+Vector3I.One).Min(dims-Vector3I.One);
                for(int z=lo.Z;z<=hi.Z;z++){if(Cancelled())return new D{["cancelled"]=true};for(int y=lo.Y;y<=hi.Y;y++)for(int x=lo.X;x<=hi.X;x++){var p=bounds.Position+new Vector3(x,y,z)*(float)cell;double d=_distance(p,f);if(S(f,"tissue")=="flesh"&&stages.Count>=6)d+=Math.Sin(p.Y*18.0+Math.Sin(p.X*9.0)*1.8)*.007*N(dna,"irregularity")*N(Controls,"folds");int index=x+dims.X*(y+dims.Y*z);double a=subtract?-values[index]:values[index],h=Math.Max(k-Math.Abs(a-d),0)/k,result=Math.Min(a,d)-h*h*k*.25;values[index]=(float)(subtract?-result:result);}}
            }
        }
        using var extractor=new BlobStableExtractor();return extractor.extract(values,dims,bounds.Position,cell,controls);
    }
    private void Attribute(D mesh,bool materials)
    {
        var vertices=mesh["vertices"].AsVector3Array();var colors=new Color[vertices.Length];var uvs=new Vector2[vertices.Length];var uvs2=new Vector2[vertices.Length];var anchors=new float[vertices.Length*4];var mechanics=new float[vertices.Length*4];var owners=new int[vertices.Length];
        for(int i=0;i<vertices.Length;i++)
        {
            if(i%256==0&&Cancelled())return;var p=vertices[i];double nearest=double.PositiveInfinity,second=double.PositiveInfinity;var owner=features[0].AsGodotDictionary();var other=owner;foreach(var value in features){var f=value.AsGodotDictionary();if(f.ContainsKey("points")&&!B(f,"fused_path"))continue;double distance=Math.Abs(_distance(p,f));if(B(f,"subtract"))distance*=.88;if(distance<nearest){second=nearest;other=owner;nearest=distance;owner=f;}else if(distance<second){second=distance;other=f;}}
            double blend=Math.Clamp(.5-(second-nearest)/Math.Max(Size*.16,.001),0,.5);string tissue=S(owner,"tissue");colors[i]=materials?TissueColor(tissue).Lerp(TissueColor(S(other,"tissue")),(float)blend):new Color(.36f,.32f,.26f);uvs[i]=new Vector2(Array.IndexOf(Tissues,tissue),(float)N(dna,"wetness"));uvs2[i]=new Vector2(Array.IndexOf(Tissues,S(other,"tissue")),(float)blend);owners[i]=owner["id"].AsInt32();var center=V(owner,"center");anchors[i*4]=center.X;anchors[i*4+1]=center.Y;anchors[i*4+2]=center.Z;mechanics[i*4]=(float)Stiffness(tissue);
        }
        mesh["colors"]=colors;mesh["uvs"]=uvs;mesh["uvs2"]=uvs2;mesh["feature_ids"]=owners;mesh["anchors"]=anchors;mesh["mechanics"]=mechanics;
    }
    private Color TissueColor(string tissue)
    {
        var color=new[]{new Color(.24f,.195f,.12f),new Color(.22f,.19f,.155f),new Color(.19f,.195f,.13f),new Color(.24f,.175f,.16f),new Color(.195f,.17f,.18f)}[Math.Clamp(dna["palette"].AsInt32(),0,4)];return tissue switch{"sac"=>color.Lightened(.065f),"sponge"=>color.Lightened(.025f),"root"=>color.Lerp(new Color(.16f,.105f,.075f),.32f),"cavity"=>color.Darkened(.52f),"face"=>color.Lightened(.085f),"membrane"=>color.Lerp(new Color(.26f,.17f,.13f),.22f),"belly"=>color.Darkened(.12f),"leg"=>color.Darkened(.04f),"cartilage"=>color.Lightened(.12f),"vein"=>color.Lerp(new Color(.18f,.1f,.085f),.38f),_=>color};
    }
    private static double Stiffness(string tissue)=>tissue switch{"face"=>.85,"cartilage"=>.9,"sponge"=>.7,"leg"=>.6,"sac"=>.25,"membrane"=>.1,_=>.4};
}
