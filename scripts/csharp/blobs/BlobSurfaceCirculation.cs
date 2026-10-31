using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

namespace PredatorIsle.Blobs;

/// <summary>Injective Cartesian tissue maps, compliant ground support and bounded secondary motion.</summary>
public partial class BlobSurfaceCirculation : RefCounted
{
    public Godot.Collections.Array<string> MODES {get;}=new(new[]{"roll","vine","limb","contractile","peristaltic","hybrid","drag","pulse","multicontact","undulate"});
    public D dna {get;set;}=new();
    public D rig {get;set;}=new();
    public double circulation {get;set;}
    public double phase {get;set;}
    public double current_speed {get;set;}
    public double acceleration {get;set;}
    public double compression {get;set;}
    public double compression_velocity {get;set;}
    public double height {get;set;}=1;
    public double spread {get;set;}=1;
    public double motion_mix {get;set;}
    public float[] ground {get;set;}=new float[9];
    public Vector2 footprint {get;set;}=Vector2.One;
    public double heading {get;set;}
    public Basis pose_frame {get;set;}=Basis.Identity;
    public Vector3 strain {get;set;}
    public bool idle_enabled {get;set;}=true;
    public bool contact_enabled {get;set;}=true;
    public bool secondary_enabled {get;set;}=true;
    public bool circulation_enabled {get;set;}=true;
    public Godot.Collections.Array<D> support_samples {get;set;}=new();
    public int contact_count {get;set;}
    public double volume_scale {get;set;}=1;
    public Godot.Collections.Array<D> group_states {get;set;}=new();
    public Vector4[] pulse_cells {get;set;}=System.Array.Empty<Vector4>();
    public float[] pulse_values {get;set;}=System.Array.Empty<float>();
    public Godot.Collections.Array<D> _pulse_states {get;set;}=new();
    public RandomNumberGenerator _rng {get;}=new();
    public double _height_velocity {get;set;}
    public Vector3 idle_shear {get;set;}
    public Vector3 _idle_velocity {get;set;}
    public Vector3 _idle_target {get;set;}=new(.002f,-.003f,.002f);
    public double _idle_timer {get;set;}
    public bool roll_safe {get;set;}
    public bool use_leg_support {get;set;}
    public double track_length {get;set;}=1;
    private static Variant Get(D d,string key,Variant fallback)=>d.TryGetValue(key,out var value)?value:fallback;
    private static double N(D d,string key)=>d[key].AsDouble();
    private static double L(double a,double b,double t)=>a+(b-a)*t;
    private static double S(double a,double b,double v){double t=Math.Clamp((v-a)/(b-a),0,1);return t*t*(3-2*t);}
    private Vector3 Radii=>dna["core_radii"].AsVector3();
    public BlobSurfaceCirculation(){MODES.MakeReadOnly();}
    public void configure(D value)=>configure(value,new D(),new D());
    public void configure(D value,D bindingRig)=>configure(value,bindingRig,new D());
    public void configure(D value,D bindingRig,D bodyMesh)
    {
        dna=value;rig=bindingRig;_rng.Seed=unchecked((ulong)(dna["seed"].AsInt64()*7919+11));var r=Radii;footprint=Vector2.One*Math.Max(r.X,r.Z)*2;track_length=Math.Tau*r.Z;roll_safe=Get(rig,"roll_safe",false).AsBool();use_leg_support=dna["locomotion"].AsString()=="limb";
        var cells=new List<Vector4>(pulse_cells);var values=new List<float>(pulse_values);
        foreach(var item in Get(rig,"material_groups",new A()).AsGodotArray())
        {
            var group=item.AsGodotDictionary();group_states.Add(new D{["squash"]=1.0});if(group["tissue"].AsString()!="sac"||cells.Count>=8)continue;var c=group["center"].AsVector3();
            cells.Add(new Vector4(c.X,c.Y,c.Z,(float)Math.Max(group["radii"].AsVector3().Length()*1.25,.15)));values.Add(0);
            _pulse_states.Add(new D{["value"]=0.0,["velocity"]=0.0,["target"]=_rng.RandfRange(.04f,.13f),["timer"]=_rng.RandfRange(0,2),["interval"]=_rng.RandfRange(2.5f,5)});
        }
        pulse_cells=cells.ToArray();pulse_values=values.ToArray();
        if(bodyMesh.Count>0)
        {
            var bins=new Dictionary<Vector2I,D>();foreach(var p in bodyMesh["vertices"].AsVector3Array())
            {
                double theta=Math.Atan2(p.Z/(double)r.Z,p.Y/(double)r.Y)/Math.Tau;theta-=Math.Floor(theta);
                var key=new Vector2I(Math.Clamp((int)((p.X/(double)r.X*.5+.5)*6),0,5),Math.Min((int)(theta*32),31));double radial=new Vector2((float)(p.Y/(double)r.Y),(float)(p.Z/(double)r.Z)).LengthSquared();
                if(!bins.TryGetValue(key,out var previous)||radial>N(previous,"radial"))bins[key]=new D{["p"]=p,["radial"]=radial,["group"]=-1,["weight"]=0.0};
            }
            foreach(var sample in bins.Values)support_samples.Add(sample);
        }
        compression=_target_compression();_solve_support(0,true);
    }
    public double _target_compression()
    {if(!contact_enabled)return 0;var c=dna["controls"].AsGodotDictionary();return Math.Clamp(N(c,"softness")*N(c,"gravity")*(.13+Math.Min(Get(dna,"estimated_mass",5).AsDouble()/80,.13))*(1-N(c,"stiffness")*.5),0,.18);}
    public void step(double delta,double requestedSpeed,string mode)
    {
        motion_mix=mode=="roll"?1:mode=="hybrid"?.4:0;double dt=Math.Clamp(delta,0,.04),previous=current_speed;current_speed=L(current_speed,requestedSpeed,1-Math.Exp(-dt*5));acceleration=(current_speed-previous)/Math.Max(dt,.00001);phase+=dt;
        compression_velocity+=((_target_compression()-compression)*45-compression_velocity*13)*dt;compression=Math.Clamp(compression+compression_velocity*dt,0,.2);
        double dx=((double)ground[5]-ground[3])/(footprint.X*2.0),dz=((double)ground[7]-ground[1])/(footprint.Y*2.0);var normal=new Vector3((float)-dx,1,(float)-dz).Normalized();pose_frame=pose_frame.Slerp(new Basis(new Quaternion(Vector3.Up,normal))*new Basis(Vector3.Up,(float)heading),(float)(1-Math.Exp(-dt*7)));
        _idle_timer+=dt;if(_idle_timer>2.7){_idle_timer=0;_idle_target=new Vector3(_rng.RandfRange(-.006f,.006f),_rng.RandfRange(-.006f,.006f),_rng.RandfRange(-.004f,.004f));}
        var target=idle_enabled?_idle_target:Vector3.Zero;_idle_velocity+=((target-idle_shear)*4-_idle_velocity*4)*(float)dt;idle_shear+=_idle_velocity*(float)dt;
        for(int i=0;i<_pulse_states.Count;i++)
        {
            var state=_pulse_states[i];double timer=N(state,"timer")+dt;state["timer"]=timer;if(timer>N(state,"interval")){state["timer"]=0;state["target"]=_rng.RandfRange(-.035f,.13f);}
            double desired=idle_enabled?N(state,"target"):0,velocity=N(state,"velocity")+((desired-N(state,"value"))*7-N(state,"velocity")*5)*dt;state["velocity"]=velocity;
            double value=Math.Clamp(N(state,"value")+velocity*dt,-.035,.14);state["value"]=value;pulse_values[i]=(float)value;
        }
        _solve_support(dt,false);
    }
    public void advance_distance(double distance){if(roll_safe&&circulation_enabled)circulation+=distance/Math.Max(Radii.Z,.2)*N(dna["controls"].AsGodotDictionary(),"circulation")*motion_mix;}
    // Retained extension hooks: the current injective maps have no independent rigid groups or global rescale.
    public void _update_groups(double dt) { }
    public void _update_volume() { }
    public Vector3 map_base(Vector3 rest)=>map_base(rest,1);
    public Vector3 map_base(Vector3 rest,double gain)
    {
        var p=rest;for(int i=0;i<pulse_cells.Length;i++){var cell=pulse_cells[i];var d=p-new Vector3(cell.X,cell.Y,cell.Z);p+=d*(float)(pulse_values[i]*Math.Exp(-2*d.LengthSquared()/((double)cell.W*cell.W)));}
        var r=Radii;double angle=roll_safe?-circulation:0,co=Math.Cos(angle),si=Math.Sin(angle),y=p.Y/(double)r.Y,z=p.Z/(double)r.Z;p.Y=(float)((co*y-si*z)*r.Y);p.Z=(float)((si*y+co*z)*r.Z);
        for(int i=0;i<3;i++)
        {
            double w=r.Z*.6,center=(i-1)*r.Z*.5,th=Math.Tanh((p.Z-center)/w),a=Math.Clamp(strain[i],-.1,.22),derivative=1-a*(1-th*th);p.Z=(float)(p.Z-a*w*th);p.X=(float)(p.X/Math.Sqrt(derivative));p.Y=(float)(p.Y/Math.Sqrt(derivative));
        }
        p.X=(float)(p.X+r.X*(double)idle_shear.X*Math.Exp(-Math.Pow(p.Y/(double)r.Y,2)-Math.Pow(p.Z/(double)r.Z,2)));
        p.Z=(float)(p.Z+r.Z*(double)idle_shear.Z*Math.Exp(-Math.Pow(p.X/(double)r.X,2)-Math.Pow(p.Y/(double)r.Y,2)));
        p.Y=(float)(p.Y+r.Y*(double)idle_shear.Y*Math.Exp(-Math.Pow(p.X/(double)r.X,2)-Math.Pow(p.Z/(double)r.Z,2)));
        double width=r.Y*.9,v=(p.Y+(double)r.Y)/width,dv=1-2*compression*r.Y*v/width*Math.Exp(-v*v);p.Y=(float)(p.Y+compression*r.Y*Math.Exp(-v*v));p.X=(float)(p.X/Math.Sqrt(dv));p.Z=(float)(p.Z/Math.Sqrt(dv));return pose_frame*p;
    }
    public Vector3 map_point(Vector3 rest)=>map_base(rest);
    public Vector3 map_bound(Vector3 rest,int group,double weight)=>map_base(rest);
    public Vector3 map_normal(Vector3 rest,Vector3 normal)
    {double e=Math.Max(.0003,N(dna,"size")*.0005);var p=map_point(rest);var jacobian=new Basis((map_point(rest+Vector3.Right*(float)e)-p)/(float)e,(map_point(rest+Vector3.Up*(float)e)-p)/(float)e,(map_point(rest+Vector3.Back*(float)e)-p)/(float)e);return (jacobian.Inverse().Transposed()*normal).Normalized();}
    public void _solve_support(double dt,bool initial)
    {
        double required=0;contact_count=0;foreach(var sample in support_samples){var p=map_point(sample["p"].AsVector3());required=Math.Max(required,ground_at(p.X,p.Z)-p.Y);}
        if(use_leg_support)foreach(var item in Get(rig,"chains",new A()).AsGodotArray()){var chain=item.AsGodotDictionary();if(chain["kind"].AsString()!="leg")continue;var rest=chain["rest"].AsVector3Array();var tip=map_point(rest[^1]);required=Math.Max(required,ground_at(tip.X,tip.Z)-tip.Y);}
        double desired=required+.006;if(initial)height=desired;else{_height_velocity+=((desired-height)*70-_height_velocity*17)*dt;height=Math.Max(height+_height_velocity*dt,required-.008);}
        foreach(var sample in support_samples){var p=map_point(sample["p"].AsVector3());if(Math.Abs(p.Y+height-ground_at(p.X,p.Z))<.06)contact_count++;}
    }
    public double ground_at(double x,double z)
    {double u=Math.Clamp(x/footprint.X+1,0,2),v=Math.Clamp(z/footprint.Y+1,0,2);int ix=Math.Min((int)u,1),iz=Math.Min((int)v,1),i=iz*3+ix;return L(L(ground[i],ground[i+1],u-ix),L(ground[i+3],ground[i+4],u-ix),v-iz);}
    public D uniforms()
    {var cells=new Vector4[8];var values=new float[8];System.Array.Copy(pulse_cells,cells,Math.Min(8,pulse_cells.Length));System.Array.Copy(pulse_values,values,Math.Min(8,pulse_values.Length));return new D{["body_radii"]=Radii,["circulation"]=roll_safe?circulation:0.0,["compression"]=compression,["pose_frame"]=pose_frame,["strain"]=strain,["idle_shear"]=idle_shear,["pulse_count"]=pulse_cells.Length,["pulse_cells"]=cells,["pulse_values"]=values,["body_height"]=height};}
}
