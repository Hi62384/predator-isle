using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class SporeForestSampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Mycelium lowlands","Colony mounds","Pale crustlands","Decomposition basins","Rocky fungal highlands","Dry spore residue"};
    private Vector2 _ecologyPoint=Vector2.Inf;
    private D _ecology=new();
    private static readonly double[] Heights={18,45,35,18,240,16},Details={1,2,1,1,7,1};
    public override void configure(Resource config,long seed_id,RefCounted host,long family_id)
    {_ecologyPoint=Vector2.Inf;_ecology.Clear();base.configure(config,seed_id,host,family_id);}
    public D ecology(Vector2 p)
    {
        if(p==_ecologyPoint)return _ecology;double span=1800*P("feature_scale");var cell=new Vector2I((int)Math.Floor(p.X/span),(int)Math.Floor(p.Y/span));double uncovered=1,mound=0,luminous=0,weightedAge=0,sum=0;
        for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++)
        {
            var owner=cell+new Vector2I(dx,dz);var d=descriptor(owner,span);var q=local(p,d)/(float)d["radius"].AsDouble();double age=d["age"].AsDouble(),elongation=.55+age*.45;
            double edge=new Vector2(q.X,(float)(q.Y*elongation)).Length()+noise(p)*.2+.09*Math.Sin((float)Math.Atan2(q.Y,q.X)*3.0+d["angle"].AsDouble());double cover=1-Smooth(.35+age*.16,1.1+age*.3,edge),link=0;
            foreach(var direction in new[]{Vector2I.Right,Vector2I.Down})
            {
                if(random(owner.X,owner.Y,801+direction.X*7)>.48)continue;var other=descriptor(owner+direction,span);var position=d["position"].AsVector2();var otherPosition=other["position"].AsVector2();var axis=otherPosition-position;var bend=(position+otherPosition)*.5f+new Vector2(-axis.Y,axis.X)*(float)((age-.5)*.3);
                double distance=Math.Min(segment(p,position,bend).X,segment(p,bend,otherPosition).X),width=Lerp(40,100,age)*P("feature_scale");link=Math.Max(link,(1-Smooth(width*.3,width*2.2,distance))*.72);
            }
            cover=Math.Max(cover,link);uncovered*=1-cover;weightedAge+=cover*age;sum+=cover;mound=Math.Max(mound,Math.Pow(Math.Max(cover,0),1.7)*(.35+age*.75));if(d["chance"].AsDouble()<P("luminous_frequency"))luminous=Math.Max(luminous,cover*(.75+age*.25));
        }
        _ecologyPoint=p;_ecology=new D {["coverage"]=(1-uncovered)*P("mycelium"),["age"]=weightedAge/Math.Max(sum,.001),["mound"]=mound,["luminous"]=luminous*P("mycelium")};return _ecology;
    }
    public override double[] evaluate(Vector2 p,int id)
    {
        var d=nearby(p,1800*P("feature_scale"));var q=local(p,d);double distance=new Vector2(q.X,(float)((double)q.Y*.65)).Length()/d["radius"].AsDouble()+noise(p)*.22;var field=ecology(p);double colony=field["coverage"].AsDouble(),h=40+macro(p)*Heights[id]+noise(p)*Details[id];
        if(id==1)h+=field["mound"].AsDouble()*P("mound_height");if(id==2)h+=colony*6;if(id==3)h-=colony*22;if(id==4)h+=Math.Pow(1-Math.Abs(macro(p*.7f)),3)*120;
        double wet=Math.Clamp(.35+colony*.4+(id==3?.2:0)-(id==5?.3:0),0,1),water=0;if(id==3&&d["chance"].AsDouble()<P("water_frequency")){water=27*(1-Smooth(.65,1.2,distance));h=Lerp(h,19+noise(p),1-Smooth(.5,.8,distance));}
        return new[]{h,water,wet,0,.5*colony+.5*field["luminous"].AsDouble()};
    }
    public override D describe(Vector2 p)
    {
        var result=base.describe(p);var d=nearby(p,1800*P("feature_scale"));var field=ecology(p);result["colony_id"]=d["id"];result["colony_age"]=field["age"];result["colony_coverage"]=field["coverage"];result["luminous_potential"]=field["luminous"];result["luminous"]=field["luminous"].AsDouble()>.5;result["spore_dose_calibrated"]=false;return result;
    }
}
