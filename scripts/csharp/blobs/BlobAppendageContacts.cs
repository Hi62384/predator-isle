using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Persistent terrain grips, two-bone legs, constrained vines and bounded passive bends.</summary>
public partial class BlobAppendageContacts : RefCounted
{
    public const int JOINTS=8,MAX_CHAINS=16;
    public Node3D? actor{get;set;}
    public A chains{get;set;}=new();
    public Vector4[] rests{get;set;}=Array.Empty<Vector4>();
    public Vector4[] poses{get;set;}=Array.Empty<Vector4>();
    public Vector4[] rest_normals{get;set;}=Array.Empty<Vector4>();
    public Vector4[] pose_normals{get;set;}=Array.Empty<Vector4>();
    public int planted_count{get;set;}
    public int active_count{get;set;}
    public double maximum_lock_error{get;set;}
    public double maximum_length_error{get;set;}
    public FastNoiseLite noise{get;set;}=new();
    public double elapsed{get;set;}
    public bool gait_enabled{get;set;}=true;
    public bool secondary_enabled{get;set;}=true;
    public bool force_release{get;set;}
    public int corrected_poses{get;set;}
    public int rejected_poses{get;set;}
    public int collision_corrections{get;set;}
    public bool collision_enabled{get;set;}=true;
    public int full_guard_checks{get;set;}
    private readonly BlobCurveFrames Frames=new();
    private readonly BlobCurveGuard Guard=new();
    private BlobSurfaceCirculation Solver= null!;
    private D Anatomy=new();
    private static double N(D d,string key)=>d[key].AsDouble();
    private static string S(D d,string key)=>d[key].AsString();
    private static Vector3 V(D d,string key)=>d[key].AsVector3();
    private static bool B(D d,string key)=>d.TryGetValue(key,out var v)&&v.AsBool();
    private Vector3 Origin=>actor!.GlobalPosition+Vector3.Up*(float)Solver.height;
    private Vector3 Root(D c)=>Origin+Solver.map_bound(c["rest"].AsVector3Array()[0],c["group"].AsInt32(),1);
    public Vector3 _root(D c)=>Root(c);
    public Vector3 _terrain_target(Vector3 p)=>TerrainTarget(p);
    public void configure(Node3D ownerActor,A definitions)
    {
        if(definitions.Count>MAX_CHAINS)throw new ArgumentException("An organism cannot exceed sixteen anatomical chains.");
        actor=ownerActor;Anatomy=actor.Get("anatomy").AsGodotDictionary();Solver=actor.Get("solver").AsGodotObject() as BlobSurfaceCirculation??throw new ArgumentException("Contacts require the native circulation solver.");
        noise.Seed=(int)Anatomy["dna"].AsGodotDictionary()["seed"].AsInt64();noise.Frequency=.4f;
        foreach(var value in definitions)
        {
            var c=value.AsGodotDictionary().Duplicate(true);var rest=c["rest"].AsVector3Array();if(rest.Length!=JOINTS)throw new ArgumentException("Contact chains require eight joints.");
            var points=new Vector3[JOINTS];for(int j=0;j<JOINTS;j++)points[j]=Origin+Solver.map_bound(rest[j],c["group"].AsInt32(),1);
            c["frame_seed"]=Solver.pose_frame*Frames.normals(rest)[0];
            var feature=Anatomy["features"].AsGodotArray()[c["feature_id"].AsInt32()].AsGodotDictionary();if(S(feature,"feature_type")=="membrane_support")c["kind"]="web";
            c["bend"]=Vector3.Zero;c["bend_velocity"]=Vector3.Zero;c["points"]=points;c["previous"]=(Vector3[])points.Clone();c["target"]=TerrainTarget(points[^1]);c["from"]=points[^1];c["goal"]=c["target"];c["state"]="stance";c["timer"]=N(c,"phase")*.75;c["duration"]=.5;c["active"]=false;c["plant_root"]=points[0];c["pull_distance"]=N(c,"length")*.28;c["pull_duration"]=.8;c["cycles"]=0;c["motion_phase"]="plant";c["planted_reference"]=c["target"];
            foreach(var itemValue in Anatomy["appendages"].AsGodotArray()){var item=itemValue.AsGodotDictionary();if(item["feature"].AsGodotDictionary()["id"].Equals(c["feature_id"])){Guard.prepare(c,item["mesh"].AsGodotDictionary());break;}}
            chains.Add(c);
        }
        foreach(string kind in new[]{"vine","leg"})
        {
            var candidates=new List<D>();foreach(var value in chains){var c=value.AsGodotDictionary();if(S(c,"kind")==kind)c["motor"]=false;else if(!c.ContainsKey("motor"))c["motor"]=false;if(S(c,"kind")!=kind)continue;var root=Root(c);if(root.Y-TerrainTarget(root).Y<N(c,"length")*(kind=="vine"?.82:.94))candidates.Add(c);}
            var heading=actor.Get("direction").AsVector3();
            foreach(var c in candidates.OrderBy(c=>{var root=Root(c);return root.Y-(root-actor.GlobalPosition).Dot(heading)*.5;}).Take(kind=="vine"?3:4))c["motor"]=true;
            foreach(var value in chains){var c=value.AsGodotDictionary();if(S(c,"kind")==kind)Anatomy["features"].AsGodotArray()[c["feature_id"].AsInt32()].AsGodotDictionary()["animation_role"]=B(c,"motor")?"locomotor":"secondary";}
        }
        Upload();
    }
    private Vector3 TerrainTarget(Vector3 p)
    {
        var terrain=actor!.Get("terrain").AsGodotObject();p.Y=IsInstanceValid(terrain)?(float)terrain.Call("get_height_at",p).AsDouble():actor.GlobalPosition.Y;return p;
    }
    private bool Active(D c,string mode)
    {
        string kind=S(c,"kind");if(!gait_enabled||(kind!="vine"&&kind!="leg")||!B(c,"motor"))return false;var root=Root(c);if(root.Y-TerrainTarget(root).Y>N(c,"length")*(kind=="vine"?.82:.94))return false;
        return kind=="leg"?mode is "limb" or "hybrid" or "multicontact":mode is "vine" or "hybrid" or "drag" or "multicontact";
    }
    public double traction(string mode)
    {
        int active=0,planted=0;foreach(var value in chains){var c=value.AsGodotDictionary();if(!Active(c,mode))continue;active++;if(S(c,"state")=="stance")planted++;}return active==0?0:Math.Clamp(planted/Math.Max(active*.45,1),0,1);
    }
    public void step(double delta,string mode,Vector3 movement,double speed)
    {
        double dt=Math.Clamp(delta,0,.033334);elapsed+=dt;active_count=0;planted_count=0;maximum_lock_error=0;maximum_length_error=0;
        foreach(var value in chains){var c=value.AsGodotDictionary();bool active=Active(c,mode);c["active"]=active;if(active){active_count++;if(S(c,"state")=="stance")planted_count++;}}
        var travel=movement.Normalized()*(speed>=0?1:-1);
        for(int i=0;i<chains.Count;i++)
        {
            var c=chains[i].AsGodotDictionary();var root=Root(c);var previous=c["points"].AsVector3Array();
            if(B(c,"active"))
            {
                double reach=N(c,"length")*.96;bool moving=Math.Abs(speed)>.025;
                if(S(c,"state")=="stance")
                {
                    if(moving)c["timer"]=N(c,"timer")+dt;
                    bool overdue=N(c,"timer")>N(c,"pull_duration");c["motion_phase"]=N(c,"timer")<.06?"plant":"pull";
                    if(force_release||root.DistanceTo(V(c,"target"))>reach||(overdue&&(active_count==1||planted_count>Math.Max(1,active_count/2)))){BeginReach(c,root,travel,speed);planted_count--;}
                }
                if(S(c,"state")=="reach")
                {
                    c["timer"]=N(c,"timer")+dt;double t=Math.Clamp(N(c,"timer")/N(c,"duration"),0,1);c["motion_phase"]=t<.18?"release":t<.65?"recover":"reach";
                    double smooth=t*t*t*(10+t*(-15+t*6)),lift=16*t*t*(1-t)*(1-t)*Math.Min(N(c,"length")*.22,.42);c["target"]=V(c,"from").Lerp(V(c,"goal"),(float)smooth)+Vector3.Up*(float)lift;
                    if(t>=1){c["state"]="stance";c["timer"]=0.0;c["target"]=c["goal"];c["planted_reference"]=c["goal"];planted_count++;c["plant_root"]=root;c["pull_distance"]=Math.Min(N(c,"length")*.32,Math.Max(.1,(V(c,"target")-root).Dot(travel)*.85));c["pull_duration"]=Math.Clamp(N(c,"pull_distance")/Math.Max(Math.Abs(speed),.2),.35,1.3);c["cycles"]=c["cycles"].AsInt32()+1;c["motion_phase"]="plant";}
                }
                if(S(c,"kind")=="leg")SolveLeg(c,root,V(c,"target"));else SolveVine(c,root,V(c,"target"));
                if(S(c,"state")=="stance"){double error=c["points"].AsVector3Array()[^1].DistanceTo(V(c,"planted_reference"));if(error>.015)BeginReach(c,root,travel,speed);else maximum_lock_error=Math.Max(maximum_lock_error,error);}
            }
            else if(S(c,"kind")=="web"){var rest=c["rest"].AsVector3Array();var points=new Vector3[JOINTS];for(int j=0;j<JOINTS;j++)points[j]=Origin+Solver.map_point(rest[j]);c["points"]=points;}
            else Passive(c,root,dt,i);
            if(collision_enabled&&B(c,"active"))AvoidObstacles(c);
            var current=c["points"].AsVector3Array();var origin=Origin;var local=current.Select(p=>p-origin).ToArray();var seed=V(c,"frame_seed");bool guarded=B(c,"active");if(guarded)full_guard_checks++;
            if(guarded&&!Guard.valid(c,local,seed))
            {
                corrected_poses++;var rootDelta=root-previous[0];bool accepted=false;
                for(int attempt=0;attempt<4;attempt++)
                {
                    double blend=Math.Pow(.5,attempt+1);for(int j=0;j<JOINTS;j++)local[j]=(previous[j]+rootDelta).Lerp(current[j],(float)blend)-origin;
                    if(!Guard.valid(c,local,seed))continue;for(int j=0;j<JOINTS;j++)current[j]=local[j]+origin;accepted=true;break;
                }
                if(!accepted){rejected_poses++;for(int j=0;j<JOINTS;j++)current[j]=previous[j]+rootDelta;}
                c["points"]=current;c["previous"]=(Vector3[])current.Clone();if(B(c,"active"))BeginReach(c,root,travel,speed);
            }
            if(B(c,"active")&&S(c,"state")=="stance"){double error=current[^1].DistanceTo(V(c,"planted_reference"));if(error>.015)BeginReach(c,root,travel,speed);else maximum_lock_error=Math.Max(maximum_lock_error,error);}
            var lengths=c["lengths"].AsFloat32Array();for(int j=0;j<JOINTS-1;j++)maximum_length_error=Math.Max(maximum_length_error,Math.Abs(current[j].DistanceTo(current[j+1])-(double)lengths[j]));
        }
        planted_count=chains.Count(v=>{var c=v.AsGodotDictionary();return B(c,"active")&&S(c,"state")=="stance";});force_release=false;Upload();
    }
    private void BeginReach(D c,Vector3 root,Vector3 direction,double speed)
    {
        c["state"]="reach";c["motion_phase"]="recover";c["timer"]=0.0;c["duration"]=Math.Clamp(N(c,"length")*.22/Math.Max(Math.Abs(speed),.3),.24,.7);c["from"]=c["points"].AsVector3Array()[^1];
        double height=root.Y-TerrainTarget(root).Y,horizontal=Math.Sqrt(Math.Max(N(c,"length")*N(c,"length")*.78-height*height,.02));var rest=c["rest"].AsVector3Array();var outward=new Vector3(rest[0].X,0,rest[0].Z).Normalized();
        var goal=TerrainTarget(root+direction*(float)horizontal*.78f+outward*(float)horizontal*.22f);if(goal.DistanceTo(root)>N(c,"length")*.92)goal=TerrainTarget(root+(goal-root).Normalized()*(float)N(c,"length")*.92f);c["goal"]=goal;
    }
    private void SolveVine(D c,Vector3 root,Vector3 target)
    {
        var points=c["points"].AsVector3Array();var lengths=c["lengths"].AsFloat32Array();var goal=target;if(root.DistanceTo(goal)>N(c,"length")*.999)goal=root+(goal-root).Normalized()*(float)N(c,"length")*.999f;
        for(int iteration=0;iteration<32;iteration++)
        {
            points[^1]=goal;for(int j=JOINTS-2;j>=0;j--){var direction=(points[j]-points[j+1]).Normalized();if(direction.LengthSquared()<.1)direction=Vector3.Up;points[j]=points[j+1]+direction*lengths[j];}
            points[0]=root;for(int j=0;j<JOINTS-1;j++){var direction=(points[j+1]-points[j]).Normalized();if(direction.LengthSquared()<.1)direction=Vector3.Down;points[j+1]=points[j]+direction*lengths[j];}LimitBends(c,points,lengths);
        }
        LimitBends(c,points,lengths);c["points"]=points;
    }
    private void SolveLeg(D c,Vector3 root,Vector3 target)
    {
        var lengths=c["lengths"].AsFloat32Array();double upper=0,lower=0;for(int j=0;j<JOINTS-1;j++){if(j<3)upper+=lengths[j];else lower+=lengths[j];}
        var delta=target-root;double distance=Math.Clamp(delta.Length(),Math.Abs(upper-lower)+.001,upper+lower-.001);var axis=delta.Normalized();if(axis.LengthSquared()<.1)axis=Vector3.Down;
        var rest=c["rest"].AsVector3Array();var preferred=Solver.pose_frame*(rest[3]-rest[0]);var bend=preferred-axis*preferred.Dot(axis);if(bend.LengthSquared()<.001)bend=axis.Cross(Vector3.Right);if(bend.LengthSquared()<.001)bend=axis.Cross(Vector3.Forward);bend=bend.Normalized();
        double along=(upper*upper+distance*distance-lower*lower)/(2*distance);var knee=root+axis*(float)along+bend*(float)Math.Sqrt(Math.Max(upper*upper-along*along,0));var goal=root+axis*(float)distance;var points=new Vector3[JOINTS];points[0]=root;double accumulated=0;
        for(int j=1;j<JOINTS;j++){if(j<=3){accumulated+=lengths[j-1];points[j]=root.Lerp(knee,(float)(accumulated/Math.Max(upper,.001)));}else{if(j==4)accumulated=0;accumulated+=lengths[j-1];points[j]=knee.Lerp(goal,(float)(accumulated/Math.Max(lower,.001)));}}c["points"]=points;SolveVine(c,root,target);
    }
    private void Passive(D c,Vector3 root,double dt,int index)
    {
        var target=new Vector3(noise.GetNoise2D((float)(elapsed*.7),index*19),-.25f,noise.GetNoise2D(index*31,(float)(elapsed*.6)))*.035f;if(!secondary_enabled)target=Vector3.Zero;target.Z-=(float)Math.Clamp(Solver.acceleration*.004,-.015,.015);
        var velocity=V(c,"bend_velocity")+((target-V(c,"bend"))*12-V(c,"bend_velocity")*7)*(float)dt;var bend=(V(c,"bend")+velocity*(float)dt).LimitLength(.05f);c["bend_velocity"]=velocity;c["bend"]=bend;
        var rest=c["rest"].AsVector3Array();var points=new Vector3[JOINTS];for(int j=0;j<JOINTS;j++){double t=(double)j/(JOINTS-1);points[j]=root+Solver.pose_frame*(rest[j]-rest[0])+bend*(float)N(c,"length")*(float)t*(float)t;}
        if(S(c,"kind")=="leg"){double clearance=0;for(int j=1;j<JOINTS;j++)clearance=Math.Max(clearance,TerrainTarget(points[j]).Y+.012-points[j].Y);for(int j=1;j<JOINTS;j++)points[j].Y+=(float)(clearance*Math.Pow((double)j/(JOINTS-1),1.5));}
        c["points"]=points;c["previous"]=(Vector3[])points.Clone();
    }
    private void Upload()
    {
        var restBuffer=new Vector4[MAX_CHAINS*JOINTS];var poseBuffer=new Vector4[MAX_CHAINS*JOINTS];var restAxesBuffer=new Vector4[MAX_CHAINS*JOINTS];var axesBuffer=new Vector4[MAX_CHAINS*JOINTS];int offset=0;var origin=Origin;
        foreach(var value in chains)
        {
            var c=value.AsGodotDictionary();var rest=c["rest"].AsVector3Array();var points=c["points"].AsVector3Array();var restAxes=Frames.normals(rest);var local=points.Select(p=>p-origin).ToArray();var axes=Frames.normals(local,V(c,"frame_seed"));c["frame_seed"]=axes[0];
            for(int j=0;j<JOINTS;j++){restBuffer[offset]=new Vector4(rest[j].X,rest[j].Y,rest[j].Z,0);poseBuffer[offset]=new Vector4(local[j].X,local[j].Y,local[j].Z,0);restAxesBuffer[offset]=new Vector4(restAxes[j].X,restAxes[j].Y,restAxes[j].Z,0);axesBuffer[offset]=new Vector4(axes[j].X,axes[j].Y,axes[j].Z,0);offset++;}
        }
        rests=restBuffer;poses=poseBuffer;rest_normals=restAxesBuffer;pose_normals=axesBuffer;
    }
    public D uniforms()=>new(){["chain_count"]=chains.Count,["chain_rest"]=rests,["chain_pose"]=poses,["chain_rest_normal"]=rest_normals,["chain_pose_normal"]=pose_normals};
    public Vector3 pull_displacement(double delta,Vector3 direction,double speed,string mode)
    {
        var result=Vector3.Zero;int count=0;var heading=direction.Normalized()*(speed>=0?1:-1);
        foreach(var value in chains){var c=value.AsGodotDictionary();if(!Active(c,mode)||S(c,"state")!="stance")continue;double t=Math.Clamp((N(c,"timer")+delta)/N(c,"pull_duration"),0,1),progress=t*t*(3-2*t);var desired=V(c,"plant_root")+heading*(float)N(c,"pull_distance")*(float)progress;var correction=desired-Root(c);correction.Y=0;result+=correction;count++;}
        if(count==0)return Vector3.Zero;double forward=Math.Max(0,(result/count).Dot(heading));return heading*(float)Math.Min(forward,Math.Abs(speed)*delta*1.5);
    }
    private static void LimitBends(D c,Vector3[] points,float[] lengths)
    {
        double limit=S(c,"kind")=="vine"?.45:.4;for(int j=1;j<JOINTS-1;j++){var incoming=(points[j]-points[j-1]).Normalized();var outgoing=(points[j+1]-points[j]).Normalized();double angle=incoming.AngleTo(outgoing);if(angle>limit)outgoing=incoming.Slerp(outgoing,(float)(limit/angle)).Normalized();points[j+1]=points[j]+outgoing*lengths[j];}
    }
    private void AvoidObstacles(D c)
    {
        var points=c["points"].AsVector3Array();var rest=c["rest"].AsVector3Array();var rig=Anatomy["rig"].AsGodotDictionary();var volumes=rig.TryGetValue("obstacle_volumes",out var v)?v.AsGodotArray():new A();
        for(int j=3;j<JOINTS;j++)
        {
            foreach(var value in volumes)
            {
                var volume=value.AsGodotDictionary();var basis=volume["basis"].AsBasis();var radii=V(volume,"radii");var center=V(volume,"center");if((j<4||S(c,"kind")=="leg")&&((basis.Transposed()*(rest[0]-center))/radii).Length()<1.35)continue;
                center=Origin+Solver.map_point(center);basis=Solver.pose_frame*basis;radii=radii*.92f+Vector3.One*(float)N(c,"radius")*.65f;var q=(basis.Transposed()*(points[j]-center))/radii;
                if(q.LengthSquared()<1&&q.LengthSquared()>.0001){var outside=center+basis*(q.Normalized()*radii);points[j]+=(outside-points[j]).LimitLength((float)(N(c,"length")*.12));collision_corrections++;}
            }
            foreach(var value in chains)
            {
                var other=value.AsGodotDictionary();if(other["feature_id"].Equals(c["feature_id"]))continue;var otherPoints=other["points"].AsVector3Array();for(int k=2;k<JOINTS;k++){var delta=points[j]-otherPoints[k];double radius=(N(c,"radius")+N(other,"radius"))*.7;if(delta.LengthSquared()<radius*radius&&delta.LengthSquared()>.000001){points[j]+=delta.Normalized()*(float)(radius-delta.Length())*.6f;collision_corrections++;}}
            }
        }
        c["points"]=points;
    }
}
