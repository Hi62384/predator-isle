using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Biomes;

public partial class DesertSampler
{
    public double _asymmetric(double phase)
    {
        double t=Mod(phase,1);if(t<duneCrest){double u=t/duneCrest;return u*u*(3-2*u);}double v=(1-t)/(1-duneCrest);return L(v*v*(3-2*v),v,settings.slip_face_sharpness);
    }
    private Vector4[] DuneSites(Vector2I cell)
    {
        if(duneCache.TryGetValue(cell,out var result))return result;var sites=new List<Vector4>();for(int z=-1;z<2;z++)for(int x=-1;x<2;x++){var c=cell+new Vector2I(x,z);double random=_hash(c.X,c.Y,103);if(random>.8)continue;sites.Add(new Vector4((float)(c.X+.22+_hash(c.X,c.Y,107)*.56),(float)(c.Y+.22+_hash(c.X,c.Y,109)*.56),(float)(.62+random*.55),(float)_hash(c.X,c.Y,113)));}if(duneCache.Count>=512)duneCache.Clear();result=sites.ToArray();duneCache[cell]=result;return result;
    }
    private Vector4[] NearDuneSites(Vector2 q,double pitch,double width,int family)
    {
        double span=pitch/8;var subcell=Cell(q,span);var key=new Vector3I(subcell.X,subcell.Y,family);if(duneSubsets.TryGetValue(key,out var result))return result;var bounds=new Rect2(Point(subcell)*(float)span,Vector2.One*(float)span).Grow(.1f);var sites=new List<Vector4>();foreach(var site in DuneSites(Cell(q,pitch))){var extent=new Vector2(1.2f,family==3?.85f:.8f)*(float)width*site.Z;if(new Rect2(new Vector2(site.X,site.Y)*(float)pitch-extent,extent*2).Intersects(bounds,true))sites.Add(site);}if(duneSubsets.Count>=1024)duneSubsets.Clear();result=sites.ToArray();duneSubsets[key]=result;return result;
    }
    public double _isolated_dunes(Vector2 q,double width,int family)
    {
        double pitch=width*duneSpacing*1.65,height=0,crossLimit=family==3?.85:.8;foreach(var site in NearDuneSites(q,pitch,width,family))
        {
            var p=(q-new Vector2(site.X,site.Y)*(float)pitch)/(float)(width*site.Z);if(Math.Abs(p.X)>1.2||Math.Abs(p.Y)>crossLimit)continue;double profile=0;
            if(family==3){double radius=p.Length();if(radius>.85)continue;for(int arm=0;arm<3;arm++){var a=Rotate(p,arm*Math.Tau/3+site.W);double longitudinal=1-Smooth(0,.85,Math.Abs(a.X)),face=a.Y<0?Smooth(-.36,0,a.Y):1-Smooth(0,.18,a.Y);profile=Math.Max(profile,face*longitudinal);}profile*=1-Smooth(.65,.85,radius);}
            else{double cross=Math.Abs(p.Y)/.64;if(cross>=1)continue;double bow=cross*cross*.52;if(family==4)bow=-bow;double distance=p.X-bow,stoss=.66,lee=.23;if(distance< -stoss||distance>lee)continue;profile=distance<0?Smooth(-stoss,0,distance):1-distance/lee;profile*=Smooth(0,.85,1-cross);}
            double amplitude=Math.Min(settings.dune_max_height*site.Z*.72,width*site.Z*.07);height=Math.Max(height,profile*amplitude);
        }
        return height;
    }
    public double _dunes(Vector2 q,double x,double z,double supply,double style)
    {
        if(supply<.001||settings.dune_frequency<=0||settings.dune_max_height<=0){last_family=0;last_crest=0;last_family_weights=Vector4.Zero;last_irregular_weight=0;return 0;}double family=Noise(_macro,x*.32+38173,z*.32-12913)*.5+.5,first=Smooth(.37,.41,family),transverse=1-first,second=Smooth(.53,.57,family),longitudinal=first*(1-second),barchan=second*(1-Smooth(.65,.69,family)),star=Smooth(.74,.79,family),irregular=Math.Max(0,1-transverse-longitudinal-barchan-star);last_family_weights=new Vector4((float)transverse,(float)longitudinal,(float)barchan,(float)star);last_irregular_weight=irregular;last_family=0;double strongest=transverse;var familyWeights=new Vector4((float)longitudinal,(float)barchan,(float)star,(float)irregular);if(familyWeights.X>strongest){strongest=familyWeights.X;last_family=1;}if(familyWeights.Y>strongest){strongest=familyWeights.Y;last_family=2;}if(familyWeights.Z>strongest){strongest=familyWeights.Z;last_family=3;}if(familyWeights.W>strongest)last_family=4;double warp=Noise(_meso,x*.20,z*.20),height=0,amplitude=Math.Min(settings.dune_max_height*L(.35,.7,style),duneCap);
        if(transverse>.001){double phase=q.X/(duneWidth*duneSpacing)+warp*.30,bend=Noise(_meso,q.X*.15+9103,q.Y*.18)*.26,primary=_asymmetric(phase+bend),secondary=_asymmetric(phase*secondaryRatio+q.Y/(duneWidth*4))*(.18/secondaryRatio),continuity=Smooth(-.25,-.12,bend),relief=L(.72,1,Smooth(-.12,.20,bend));height+=(primary+secondary)*amplitude*transverse*continuity*relief;}
        if(longitudinal>.001){double phase=q.Y/(duneWidth*.65*duneSpacing)+warp*.28,bifurcate=Noise(_meso,q.X*.22,q.Y*.16),ridge=_asymmetric(phase+bifurcate*.5),shoulder=_asymmetric(phase*secondaryRatio+bifurcate*.7)*Smooth(.05,.45,bifurcate)*(.18/secondaryRatio),continuity=Smooth(-.58,-.24,bifurcate),relief=L(.72,1,Smooth(-.24,.45,bifurcate));height+=(ridge+shoulder)*amplitude*.75*longitudinal*continuity*relief;}
        if(barchan>.001)height+=_isolated_dunes(q,duneWidth,2)*barchan;if(star>.001)height+=_isolated_dunes(q,duneWidth*1.45,3)*star;if(irregular>.001)height+=_isolated_dunes(q,duneWidth*.8,4)*irregular;double mega=q.X/megaWidth+Noise(_macro,x*.20,z*.20)*.45;height+=_asymmetric(mega)*settings.dune_max_height*.5*L(.55,1,Smooth(.15,.85,family));last_crest=Math.Clamp(height/Math.Max(amplitude,1),0,1);return height*supply*settings.dune_frequency;
    }
    public double _strata_phase(double uniformBed)=>uniformBed+Math.Sin(uniformBed*.73+bedding.W*.41)*.18+Math.Sin(uniformBed*1.17-bedding.W*.29)*.07;
    public double _strata_hardness(double bed)=>.5+Math.Sin(bed*.91+bedding.W*.23)*.5;
    public double _uniform_bed_coordinate(double height,double x,double z)
    {
        double offset=x*bedding.X+z*bedding.Y;offset+=Math.Sin(x/7300+z/9100+bedding.W)*7;return (height+offset)/bedding.Z;
    }
    private void PackDetail()
    {
        static long Q(double x)=>(long)Math.Round(Math.Clamp(x,0,1)*255,MidpointRounding.AwayFromZero);long a=Q(last_family_weights.X),b=Q(last_family_weights.Y),c=Q(last_family_weights.Z),d=Q(last_family_weights.W),e=Q(last_irregular_weight),f=Q(last_crest);control_detail=new Vector4((float)last_bedding_coordinate,a+b*256+c*65536,d+e*256+f*65536,(float)last_obstacle_shelter);
    }
    public double _sedimentary_relief(double height,double x,double z,double exposure)=>_sedimentary_relief(height,x,z,exposure,double.PositiveInfinity);
    public double _sedimentary_relief(double height,double x,double z,double exposure,double uniformBed)
    {
        double bed=_strata_phase(double.IsInfinity(uniformBed)?_uniform_bed_coordinate(height,x,z):uniformBed),terraced=Math.Floor(bed)+Smooth(0,.78,Mod(bed,1)),strength=Math.Clamp(settings.ruggedness,0,1)*.22*exposure;strength*=L(.55,1,_strata_hardness(bed));return height+(terraced-bed)*bedding.Z*strength;
    }
}
