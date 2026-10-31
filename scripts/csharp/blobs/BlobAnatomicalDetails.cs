using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

internal sealed partial class BlobAnatomicalGrowth
{
    internal void Additional()
    {
        var hosts=g.features.Duplicate();foreach(var value in hosts)
        {
            var host=value.AsGodotDictionary();int parent=host["id"].AsInt32();if(S(host,"feature_type")!="primary_mass"||parent%2!=0)continue;
            if(N(weights,"stalk")>.25){var normal=new Vector3(.35f,.9f,.2f).Normalized();var start=V(host,"center")+normal*V(host,"radii")*.8f;var tip=start+normal*(float)size*.55f;Path("sensory_sprout",parent,new A{start,start.Lerp(tip,.5f)+Vector3.Right*(float)size*.12f,tip},size*.055,"root","drag",6);}
            if(N(weights,"lattice")>.3)for(int plate=0;plate<3;plate++){var normal=Vec((plate-1.0)*.45,.65,.7).Normalized();var center=V(host,"center")+normal*V(host,"radii")*.87f;int id=Feature("cartilage_plate",parent,6,center,Vec(size*.23,size*.08,size*.3),"cartilage");F(id)["direction"]=normal;g._orient(id,normal);}
        }
        foreach(var value in hosts)
        {
            var host=value.AsGodotDictionary();if(!Is(S(host,"feature_type"),"embedded_face","porous_mantle")||rng.Randf()>=Math.Max(N(weights,"tendril"),.25))continue;int count=N(controls,"fibers")>.001?(int)L(2,8,N(controls,"fibers")*N(weights,"tendril")):0;
            for(int j=0;j<count;j++){var r=V(host,"radii");var start=V(host,"center")+V(host,"direction")*r.Z*.75f+Vector3.Right*(float)((double)j/Math.Max(count-1,1)-.5)*r.X*1.7f;var end=start+Vec(R(-.2,.2),-size*R(.5,1.2),.25);end.Y=Math.Max(end.Y,(float)(-V(dna,"core_radii").Y*.95));Path(S(host,"tissue")=="face"?"facial_drape":"root_curtain",host["id"].AsInt32(),new A{start,start.Lerp(end,.5f)+Vector3.Forward*.12f,end},size*R(.018,.035),"root","drag",6);}
        }
        if(N(weights,"membrane")>.25&&!B(dna,"soft_roller"))
        {
            var normal=new Vector3(.25f,.9f,.2f).Normalized();var frame=Frame(normal);var basis=g._surface(normal)*.96f;var supports=new A();foreach(double side in new[]{-1.0,1.0}){var root=basis+frame.X*(float)size*.17f*(float)side;var tip=root+normal*(float)size*.72f+frame.X*(float)size*.12f*(float)side;int support=Path("membrane_support",0,new A{root,root.Lerp(tip,.5f)+frame.Y*(float)size*.08f,tip},size*.045,"cartilage","coupled",6);supports.Add(support);}int id=Feature("supported_membrane",supports[0].AsInt32(),6,basis,Vector3.One*(float)size*.4f,"membrane");F(id)["sheet"]=true;F(id)["points"]=new A{F(supports[0].AsInt32())["points"].AsGodotArray()[0],F(supports[1].AsInt32())["points"].AsGodotArray()[0]};F(id)["support_ids"]=supports;
        }
    }
    private void Face(D host)
    {
        var normal=V(host,"direction");var frame=host["inverse_basis"].AsBasis().Transposed();double r=V(host,"radii").X;var p=V(host,"center")+normal*V(host,"radii").Z*.92f;double eyeSpacing=R(.32,.46),noseLength=R(.4,.64);int parent=host["id"].AsInt32();
        var parts=new System.Collections.Generic.List<(string,Vector3,Vector3)>{("forehead",new Vector3(0,.65f,-.04f),new Vector3(.78f,.72f,.23f)),("nose_bridge",new Vector3(0,.12f,.14f),Vec(.14,noseLength,.22)),("nose_tip",new Vector3(0,-.13f,.29f),new Vector3(.22f,.16f,.2f)),("chin",new Vector3(0,-.95f,-.02f),new Vector3(.5f,.28f,.23f)),("upper_lip",new Vector3(0,-.58f,.1f),new Vector3(.43f,.095f,.14f)),("lower_lip",new Vector3(0,-.72f,.12f),new Vector3(.4f,.095f,.15f))};
        foreach(double side in new[]{-1.0,1.0}){parts.Add(("cheek",Vec(side*.5,-.15,-.02),new Vector3(.35f,.44f,.21f)));parts.Add(("brow",Vec(side*eyeSpacing,.36,.03),new Vector3(.36f,.14f,.18f)));}
        foreach(var part in parts){int id=Feature(part.Item1,parent,4,p+frame*(part.Item2*(float)r),part.Item3*(float)r,"face");g._orient(id,normal);}
        foreach(double side in new[]{-1.0,1.0}){var eye=Vec(side*eyeSpacing,.18,.15);int id=Feature("eye_recess",parent,4,p+frame*(eye*(float)r),new Vector3(.27f,.12f,.16f)*(float)r,"cavity",true);g._orient(id,normal);Path("eyelid",parent,new A{p+frame*((eye+new Vector3(-.24f,0,0))*(float)r),p+frame*((eye+new Vector3(0,-.03f,.08f))*(float)r),p+frame*((eye+new Vector3(.24f,0,0))*(float)r)},r*.035,"face","coupled",4);}
        int mouth=Feature("mouth_slit",parent,4,p+frame*Vec(0,-.65*r,.18*r),new Vector3(.35f,.035f,.12f)*(float)r,"cavity",true);g._orient(mouth,normal);
        foreach(double side in new[]{-1.0,1.0})Path("face_transition",parent,new A{p+frame*Vec(side*r*.7,r*.65,-r*.13),p+frame*Vec(side*r*.92,-r*.3,-r*.1),p+frame*Vec(side*r*.5,-r*1.2,-r*.2)},r*.09,"flesh","coupled",4);host["face_relief"]=true;host["eye_spacing"]=eyeSpacing;host["nose_length"]=noseLength;
    }
    private void Lattice(D host,bool perforate)
    {
        var frame=(host.TryGetValue("inverse_basis",out var basisValue)?basisValue.AsBasis():Basis.Identity).Transposed();var r=V(host,"radii");var center=V(host,"center");int count=Math.Clamp((int)(15*N(controls,"detail")),6,24),parent=host["id"].AsInt32();
        if(perforate)for(int i=0;i<count;i++){double angle=i*2.399963+parent*.37,spread=Math.Sqrt((i+.5)/count)*.84,u=Math.Cos(angle)*spread,v=Math.Sin(angle)*spread,z=Math.Sqrt(Math.Max(.05,1-u*u-v*v));var direction=(frame*Vec(u*.4,v*.4,1)).Normalized();var p=center+frame*Vec(u*r.X,v*r.Y,z*r.Z);double radius=Math.Min(r.X,r.Y)*R(.12,.2);int id=Feature("lattice_opening",parent,5,p,Vec(radius,radius*R(.7,1.25),r.Z*.65),"cavity",true);g._orient(id,direction);}
        for(int i=0;i<7;i++){double a=i*Math.Tau/7,b=(i+1)*Math.Tau/7;var start=center+frame*(Vec(Math.Cos(a)*.8,Math.Sin(a)*.7,.4)*r);var end=center+frame*(Vec(Math.Cos(b)*.8,Math.Sin(b)*.7,.4)*r);var mid=center+frame*(Vec(Math.Cos((a+b)*.5)*.82,Math.Sin((a+b)*.5)*.75,.7)*r);int id=Path("lattice_bridge",parent,new A{start,mid,end},Math.Min(r.X,r.Y)*.1,"sponge","coupled",5);F(id)["fused_path"]=true;}
    }
    internal void PrepareIntegrated()
    {
        foreach(var value in g.features)
        {
            var f=value.AsGodotDictionary();if(!f.ContainsKey("points")||!Is(S(f,"feature_type"),"vascular_trunk","vascular_branch","capillary","anatomical_fold","eyelid","face_transition","lattice_bridge","lattice_arch"))continue;var points=f["points"].AsGodotArray();var radii=f["radii_profile"].AsGodotArray();
            if(!B(f,"fused_path"))
            {
                var host=F(Math.Max(f["parent"].AsInt32(),0));for(int steps=0;host.ContainsKey("points")&&host["parent"].AsInt32()>=0;steps++){if(steps>=g.features.Count)throw new ArgumentException("Anatomical parent hierarchy is cyclic.");host=F(host["parent"].AsInt32());}var outward=V(host,"direction");double epsilon=size*.004;
                for(int i=0;i<points.Count;i++){var original=points[i].AsVector3();double shift=0;for(int iteration=0;iteration<5;iteration++){var point=original+outward*(float)shift;double distance=g._positive_field(point),gradient=(g._positive_field(point+outward*(float)epsilon)-g._positive_field(point-outward*(float)epsilon))/(2*epsilon);if(Math.Abs(gradient)<.15)break;shift=Math.Clamp(shift-distance/gradient,-size*.35,size*.5);}points[i]=original+outward*(float)(shift+radii[i].AsDouble()*.15);}for(int i=0;i<radii.Count;i++)radii[i]=Math.Max(radii[i].AsDouble()*1.6,size*.016);
            }
            f["fused_path"]=true;var bounds=new Aabb(points[0].AsVector3(),Vector3.Zero);foreach(var p in points)bounds=bounds.Expand(p.AsVector3());f["bounds"]=bounds.Grow((float)(radii.Max(v=>v.AsDouble())*1.5));
        }
    }
    private void Stalk()
    {
        var normal=Normal(.6,1.5);var start=g._surface(normal)*.96f;double length=size*R(.8,1.7);var end=start+new Vector3(normal.X*.6f,1,normal.Z*.6f)*(float)length;var middle=start.Lerp(end,.55f)+Vec(R(-.3,.3),.15,.15)*(float)length;double radius=size*R(.055,.095);int id=Path("sensory_stalk",0,new A{start,middle,end},radius,"root","coupled",3);F(id)["radii_profile"]=new A{radius*1.4,radius,radius*.85};Feature("stalk_socket",0,3,start,Vector3.One*(float)radius*2.2f,"flesh");int bulb=Path("sensory_bulb",id,new A{end,end+Vector3.Up*(float)radius*3.5f},radius*3.3,"sponge","coupled",3);F(bulb)["bulb"]=true;F(bulb)["bulb_radii"]=Vec(radius*3.3,radius*3.8,radius*3);F(bulb)["flexibility"]=0.0;
    }
    private void Branches(D host)
    {
        if(S(host,"feature_type")=="sensory_stalk"&&rng.Randf()>.3)return;int count=Math.Max(1,(int)(N(controls,"branches")*rng.RandiRange(2,4)));var points=host["points"].AsGodotArray();for(int i=0;i<count;i++){double t=R(.45,.95);var start=points[1].AsVector3().Lerp(points[^1].AsVector3(),(float)t);double r=V(host,"radii").X*.4;var curl=Vec(R(-.4,.4),R(-.5,.2),R(-.4,.4))*(float)size;Path("vine_branch",host["id"].AsInt32(),new A{start,start+curl*.55f+Vector3.Up*.1f,start+curl,start+curl+new Vector3(curl.Z,.07f,-curl.X)*.4f},r,"root","drag",5);}
    }
    private void Vascular(D host)
    {
        var normal=V(host,"direction");var frame=(host.TryGetValue("inverse_basis",out var basisValue)?basisValue.AsBasis():Basis.Identity).Transposed();var r=V(host,"radii");var center=V(host,"center");var root=center+frame*Vec(0,-r.Y*.7,r.Z*.7);var fork=center+frame*Vec(.05*r.X,.05*r.Y,r.Z*.99);var tip=center+frame*Vec(.12*r.X,r.Y*.8,r.Z*.65);double radius=r.X*.018*N(controls,"veins");int trunk=Path("vascular_trunk",host["id"].AsInt32(),new A{root,fork,tip},radius,"vein","coupled",5);
        foreach(double side in new[]{-1.0,1.0}){var end=center+frame*Vec(side*r.X*.7,r.Y*.48,r.Z*.68);int child=Path("vascular_branch",trunk,new A{fork,fork.Lerp(end,.5f)+normal*r.X*.08f,end},radius*.6,"vein","coupled",5);for(int j=0;j<2;j++){var start=fork.Lerp(end,(float)(.45+j*.25));Path("capillary",child,new A{start,start+frame*Vec(side*r.X*.15,r.Y*.17,-r.Z*.03),start+frame*Vec(side*r.X*.2,r.Y*.26,-r.Z*.09)},radius*.3,"vein","coupled",5);}}
    }
    private void Folds(D host)
    {
        var frame=(host.TryGetValue("inverse_basis",out var basisValue)?basisValue.AsBasis():Frame(V(host,"direction")).Transposed()).Transposed();var r=V(host,"radii");int count=Math.Max(2,(int)(N(weights,"fold")*5));for(int j=0;j<count;j++){double y=((double)j/Math.Max(count-1,1)-.5)*r.Y*1.5;var points=new A();for(int i=0;i<5;i++){double t=i/4.0*Math.PI;var local=Vec(Math.Cos(t)*r.X*.92,y+Math.Sin(t*2)*r.Y*.07,Math.Sin(t)*r.Z*.95);points.Add(V(host,"center")+frame*local);}int id=Path("anatomical_fold",host["id"].AsInt32(),points,r.X*.045,"flesh","coupled",5);F(id)["radii_profile"]=new A{r.X*.025,r.X*.05,r.X*.06,r.X*.05,r.X*.025};}
    }
}
