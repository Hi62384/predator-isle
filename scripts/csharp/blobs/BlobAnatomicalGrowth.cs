using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Blueprint-compatible growth operators; random draws retain their authored stage order.</summary>
internal sealed partial class BlobAnatomicalGrowth
{
    private readonly BlobOrganismPipeline g;
    internal BlobAnatomicalGrowth(BlobOrganismPipeline owner){g=owner;}
    private D dna=>g.dna;
    private D controls=>dna["controls"].AsGodotDictionary();
    private D weights=>dna["weights"].AsGodotDictionary();
    private double size=>N(dna,"size");
    private RandomNumberGenerator rng=>g.rng;
    private double R(double a,double b)=>rng.RandfRange((float)a,(float)b);
    private static double N(D d,string key)=>d[key].AsDouble();
    private static Vector3 V(D d,string key)=>d[key].AsVector3();
    private static string S(D d,string key)=>d[key].AsString();
    private static bool B(D d,string key)=>d.TryGetValue(key,out var v)&&v.AsBool();
    private static bool Is(string value,params string[] choices)=>Array.IndexOf(choices,value)>=0;
    private D F(int id)=>g.features[id].AsGodotDictionary();
    private int Feature(string kind,int parent,int pass,Vector3 p,Vector3 r,string tissue,bool subtract=false)=>g._feature(kind,parent,pass,p,r,tissue,subtract);
    private static Vector3 Vec(double x,double y,double z)=>new((float)x,(float)y,(float)z);
    private static double L(double a,double b,double t)=>a+(b-a)*t;
    private static Basis Frame(Vector3 n){var side=Vector3.Up.Cross(n).Normalized();if(side.LengthSquared()<.1)side=Vector3.Right;return new Basis(side,n.Cross(side).Normalized(),n);}
    private Vector3 Normal(double low,double high){double angle=rng.Randf()*Math.Tau;return Vec(Math.Cos(angle),R(low,high),Math.Sin(angle)).Normalized();}
    private int Count(string family,int maximum){double weight=N(weights,family);if(weight<.16)return 0;return Math.Clamp((int)Math.Round(weight*maximum*R(.55,1.1),MidpointRounding.AwayFromZero),0,maximum*2);}
    internal void Blockout()
    {
        var r=V(dna,"core_radii");int count=dna["mass_count"].AsInt32();string plan=S(dna,"body_plan");var central=plan=="compact"?new Vector3(.94f,.94f,.94f):plan=="cluster"?new Vector3(.6f,.65f,.65f):new Vector3(.72f,.72f,.72f);Feature("core",-1,1,Vector3.Zero,r*central,"flesh");
        for(int i=1;i<count;i++)
        {
            double t=(double)i/Math.Max(count-1,1),angle=rng.Randf()*Math.Tau;var p=Vector3.Zero;var proportions=Vector3.One*(float)R(.48,.78);
            switch(plan){case "compact":p=Vec(Math.Cos(angle),R(-.3,.4),Math.Sin(angle))*r*.3f;break;case "flattened":p=Vec(Math.Cos(angle),-.12,Math.Sin(angle))*r*.6f;proportions.Y=(float)R(.6,.9);break;case "tower":p=Vec(Math.Sin(t*4)*.25,t*1.1-.25,Math.Cos(t*5)*.24)*r;proportions.Y=(float)R(.45,.7);break;case "elongated":p=Vec(Math.Sin(t*5)*.4,-.06,t*1.7-.8)*r;proportions.Z=(float)R(.42,.62);break;case "lopsided":p=Vec(t*.92,t*.45-.2,Math.Sin(t*4)*.3)*r;proportions*=(float)L(.8,1.05,t);break;case "sagging":p=Vec(Math.Cos(angle)*.6,-Math.Abs(Math.Sin(angle))*.36,Math.Sin(angle)*.7)*r;proportions.Y=(float)R(.4,.7);break;case "muscular":p=Vec(Math.Cos(angle)*.55,-.18,Math.Sin(angle)*.5)*r;proportions.Y=.8f;break;default:p=Vec(Math.Cos(angle)*.65,R(-.22,.65),Math.Sin(angle)*.65)*r;break;}
            p.X+=(float)(Math.Sin(t*9)*r.X*N(dna,"asymmetry")*.18);double variance=L(1,R(.7,1.2),N(controls,"mass_variation")*.6);Feature("primary_mass",0,1,p,r*proportions*(float)variance,"flesh");
        }
        var bounds=F(0)["bounds"].AsAabb();foreach(var value in g.features)bounds=bounds.Merge(value.AsGodotDictionary()["bounds"].AsAabb());var offset=bounds.GetCenter();foreach(var value in g.features){var f=value.AsGodotDictionary();f["center"]=V(f,"center")-offset;var b=f["bounds"].AsAabb();b.Position-=offset;f["bounds"]=b;}dna["core_radii"]=bounds.Size*.5f;dna["ground_contact"]=new Vector3(0,-V(dna,"core_radii").Y,0);
    }
    internal void Development()
    {
        var r=V(dna,"core_radii");string plan=S(dna,"body_plan");int contacts=Is(plan,"elongated","sagging")?3:1;for(int i=0;i<contacts;i++){double z=contacts>1?((double)i/Math.Max(contacts-1,1)-.5)*r.Z*1.1:0;Feature("belly_contact",0,2,Vec(0,-r.Y*.72,z),Vec(r.X*.68,r.Y*.28,r.Z*(contacts>1?.35:.68)),"belly");}if(Is(plan,"tower","muscular"))foreach(double side in new[]{-1.0,1.0})Feature("weight_buttress",0,2,Vec(r.X*.55*side,-r.Y*.5,0),Vec(r.X*.48,r.Y*.6,r.Z*.65),"leg");
    }
    internal void Primary()
    {
        for(int i=0,n=Count("sac",9);i<n;i++){var normal=Normal(0,.9);var site=g._surface(normal);double radius=size*R(.3,.58);var shape=Vec(radius*R(.7,1.2),radius*R(.7,1.8),radius*R(.65,1));int id=Feature("inflated_sac",0,3,site+normal*(float)radius*.08f,shape,"sac");F(id)["direction"]=normal;F(id)["exposure"]=R(.4,.95);g._orient(id,normal);}
        for(int i=0,n=Count("nodule",10);i<n;i++){var normal=Normal(-.3,.8);var site=g._surface(normal);double radius=size*R(.12,.3);int id=Feature("growth_nodule",0,3,site-normal*(float)radius*.5f,Vec(radius,radius*R(.7,1.5),radius),rng.Randf()<.6?"sac":"cartilage");F(id)["direction"]=normal;}
        int faces=Count("face",3);if(N(weights,"face")>.75)faces=Math.Max(faces,1);for(int i=0;i<faces;i++){double angle=new[]{.65,2.45,1.55}[i%3]+R(-.14,.14);var normal=Vec(Math.Cos(angle)*.7,R(-.1,.45),Math.Sin(angle)).Normalized();var site=g._surface(normal);double radius=size*R(.32,.56);int id=Feature("embedded_face",0,3,site-normal*(float)radius*.18f,Vec(radius*.76,radius*R(1.2,1.65),radius*.9),"face");F(id)["direction"]=normal;F(id)["exposure"]=R(.45,.9);g._orient(id,normal);}
        for(int i=0,n=Count("lattice",4);i<n;i++){var normal=Normal(.2,1.5);var site=g._surface(normal);double radius=size*R(.45,.75);int id=Feature("porous_mantle",0,3,site-normal*(float)radius*.62f,Vec(radius,radius*.8,radius*.75),"sponge");F(id)["direction"]=normal;g._orient(id,normal);}
        for(int i=0,n=Count("cavity",3);i<n;i++){var normal=Normal(-.05,.9);var site=g._surface(normal);double radius=size*R(.2,.42);int id=Feature("recess",0,3,site-normal*(float)radius*.1f,Vec(radius*R(.65,1.5),radius*R(.6,1.3),radius*.75),"cavity",true);F(id)["direction"]=normal;g._orient(id,normal);}
        bool soft=S(dna,"locomotion")=="roll"&&Is(S(dna,"profile"),"swollen","porous","clustered","hollow")&&Is(S(dna,"body_plan"),"compact","multilobe","cluster");dna["soft_roller"]=soft;int limbs=soft?0:Count("limb",6);if(S(dna,"locomotion")=="limb")limbs=Math.Max(2,limbs);
        for(int i=0;i<limbs;i++)
        {
            double angle=Math.Tau*i/limbs+R(-.2,.2);var normal=Vec(Math.Cos(angle),-.6,Math.Sin(angle)).Normalized();var start=g._surface(normal)*.92f;bool thick=S(dna,"profile")=="muscular"||rng.Randf()<.4;double radius=size*(thick?R(.17,.27):R(.055,.1));var end=Vec(start.X+normal.X*size*.65,-V(dna,"core_radii").Y*.97,start.Z+normal.Z*size*.7);var joint=start.Lerp(end,.5f)+Vector3.Up*(float)size*.25f+normal*(float)size*.18f;int limb=Path(thick?"muscular_limb":"jointed_limb",0,new A{start,joint,end},radius,"leg","active",3);F(limb)["radii_profile"]=new A{radius,radius*.7,radius*.38};Feature("limb_socket",0,3,start,Vector3.One*(float)radius*1.65f,"leg");if(thick)Feature("muscle_shoulder",0,3,start-normal*(float)radius*.3f,Vec(radius*1.7,radius*1.3,radius*1.5),"leg");for(int digit=0;digit<(thick?3:2);digit++){var tip=end+Vec((digit-1.0)*radius*.7,-.02,-radius*1.3);Path("gripping_digit",limb,new A{end,end.Lerp(tip,.5f)+Vector3.Up*(float)radius*.15f,tip},radius*.32,"leg","active",3);}
        }
        for(int i=0,n=soft?0:Count("stalk",5);i<n;i++)Stalk();
        for(int i=0,n=soft?0:Count("tendril",7);i<n;i++){var normal=Normal(-.3,.8);var start=g._surface(normal)*.94f;double radius=size*R(.06,.18);var end=start+normal*(float)size*(float)R(.5,1.1)+Vector3.Down*(float)size*(float)R(.5,1.1);end.Y=Math.Max(end.Y,(float)(-V(dna,"core_radii").Y*.9));var middle=start.Lerp(end,.55f)+Vector3.Up*(float)size*.35f;int id=Path("major_vine",0,new A{start,middle,end,end+new Vector3(-normal.Z,.2f,normal.X)*(float)size*.25f},radius,"root","drag",3);Feature("vine_socket",0,3,start,Vector3.One*(float)radius*1.8f,"root");F(id)["ribbon"]=rng.Randf()<.18;}
    }
    internal int Path(string kind,int parent,A points,double radius,string tissue,string coupling,int pass)
    {
        var start=points[0].AsVector3();int id=Feature(kind,parent,pass,start,Vector3.One*(float)radius,tissue);var f=F(id);f["points"]=points;var radii=new A();for(int i=0;i<points.Count;i++)radii.Add(radius*L(1,.22,(double)i/Math.Max(points.Count-1,1)));f["radii_profile"]=radii;f["flexibility"]=coupling=="drag"?.8:0.0;f["roll_coupling"]=coupling=="drag"?"drag":"coupled";f["slide_coupling"]=coupling;f["locomotion_relevance"]=coupling=="active"?"locomotor":"passive";f["influence"]=new D{["shape"]="anatomical_sweep",["radius"]=radius};var bounds=new Aabb(start,Vector3.Zero);foreach(var point in points)bounds=bounds.Expand(point.AsVector3());f["bounds"]=bounds.Grow((float)radius);return id;
    }
    internal void Integrate()
    {
        foreach(var value in g.features.Duplicate()){var host=value.AsGodotDictionary();string kind=S(host,"feature_type");if(kind=="embedded_face")Face(host);if(kind=="inflated_sac"&&rng.Randf()<.5){int count=rng.RandiRange(1,3);for(int j=0;j<count;j++){double r=V(host,"radii").X*R(.2,.4);var p=V(host,"center")+Normal(-.3,.7)*V(host,"radii")*.8f;Feature("satellite_sac",host["id"].AsInt32(),4,p,Vector3.One*(float)r,"sac");}}if(Is(kind,"muscular_limb","jointed_limb")){var p=host["points"].AsGodotArray()[0].AsVector3();double r=V(host,"radii").X;Path("attachment_fiber",host["id"].AsInt32(),new A{p+Vector3.Right*(float)r,p+Vector3.Up*(float)r*1.2f,p-Vector3.Right*(float)r},r*.18,"root","coupled",4);}}
    }
    internal void Detail()
    {
        foreach(var value in g.features.Duplicate()){var host=value.AsGodotDictionary();string kind=S(host,"feature_type"),tissue=S(host,"tissue");if(kind=="porous_mantle")Lattice(host,true);if(Is(kind,"inflated_sac","embedded_face","weight_buttress")){if(Is(tissue,"sac","root")&&N(controls,"veins")>.05)Vascular(host);if(Is(tissue,"sac","face","leg")&&rng.Randf()<N(weights,"fold"))Folds(host);if(Is(tissue,"sac","sponge","stalk")&&N(weights,"lattice")>.4&&rng.Randf()<N(controls,"combinations")*.5)Lattice(host,false);}if(kind=="recess"){double r=V(host,"radii").X;Feature("cavity_organ",host["parent"].AsInt32(),5,V(host,"center")-V(host,"direction")*(float)r*.65f,Vector3.One*(float)r*.27f,"sac");}if(Is(kind,"major_vine","sensory_stalk"))Branches(host);}
    }
}
