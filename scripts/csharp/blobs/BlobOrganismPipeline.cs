using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Staged biological composition, extraction, topology guards and shared deformation bindings.</summary>
public partial class BlobOrganismPipeline : RefCounted
{
    public RandomNumberGenerator rng{get;set;}=new();
    public D dna{get;set;}=new();
    public A features{get;set;}=new();
    public A stages{get;set;}=new();
    public RefCounted? controls{get;set;}
    public double extraction_offset{get;set;}
    private readonly BlobBlueprint Blueprint=new();
    private readonly BlobCurveFrames Frames=new();
    private readonly OrganicCurveGeometry Curves=new();
    private readonly BlobMeshIntegrity Integrity=new();
    private readonly BlobDeformationBindings Bindings=new();
    private readonly BlobAnatomicalGrowth Growth;
    public BlobOrganismPipeline(){Growth=new BlobAnatomicalGrowth(this);}
    private static readonly string[] PassNames={"Biological blueprint","Mass composition","Weight-bearing anatomy","Primary biology","Organic integration","Regional geometry","Connected anatomy","Tissue materials"};
    private static readonly string[] Tissues={"flesh","sac","sponge","root","face","membrane","belly","leg","cavity","cartilage","vein"};
    private bool Cancelled()=>controls is BlobBuildControls job?job.is_cancelled():controls is not null&&controls.Call("is_cancelled").AsBool();
    private void Progress(double progress,string message){if(controls is BlobBuildControls job)job.set_progress(progress,message);else controls?.Call("set_progress",progress,message);}
    private void Snapshot(int pass)=>stages.Add(new D{["pass"]=pass,["label"]=PassNames[pass],["feature_count"]=features.Count,["features"]=features.Duplicate(true)});
    private static A PointArrays(A points){var result=new A();foreach(var point in points){var p=point.AsVector3();result.Add(new A{p.X,p.Y,p.Z});}return result;}
    public D build(long seed)=>build(seed,1,"auto",7,null,new D());
    public D build(long seed,int quality)=>build(seed,quality,"auto",7,null,new D());
    public D build(long seed,int quality,string mode)=>build(seed,quality,mode,7,null,new D());
    public D build(long seed,int quality,string mode,int lastPass)=>build(seed,quality,mode,lastPass,null,new D());
    public D build(long seed,int quality,string mode,int lastPass,RefCounted? job)=>build(seed,quality,mode,lastPass,job,new D());
    public D build(long seed,int quality,string mode,int lastPass,RefCounted? job,D options)
    {
        controls=job;extraction_offset=0;features.Clear();stages.Clear();lastPass=Math.Clamp(lastPass,1,7);quality=Math.Clamp(quality,0,2);dna=Blueprint.plan(seed,mode,options);rng.Seed=("blob_anatomy_v2:"+seed.ToString(System.Globalization.CultureInfo.InvariantCulture)).Hash();dna["quality"]=quality;Snapshot(0);
        Growth.Blockout();Snapshot(1);if(lastPass>=2){Growth.Development();Snapshot(2);}FitEnvelope();if(lastPass>=3){Growth.Primary();Snapshot(3);}if(lastPass>=4){Growth.Integrate();Snapshot(4);}if(lastPass>=5){if(N(Controls,"detail")>.001)Growth.Detail();Snapshot(5);}if(lastPass>=6){Growth.Additional();Snapshot(6);}if(Cancelled())return new D{["cancelled"]=true};Growth.PrepareIntegrated();Progress(.2,"Extracting composed anatomy");var mesh=Extract(quality);if(Failed(mesh))return mesh;Progress(.65,"Blending anatomical tissue fields");var integrity=Integrity.clean(mesh,true);
        bool Closed(D report)=>report["boundary_edges"].AsInt32()==0&&report["nonmanifold_edges"].AsInt32()==0&&report["inconsistent_edges"].AsInt32()==0;
        for(int attempt=0;attempt<2&&!Closed(integrity);attempt++){extraction_offset=(attempt+1)*.173;mesh=Extract(quality);if(Failed(mesh))return mesh;integrity=Integrity.clean(mesh,true);}if(!Closed(integrity))return new D{["error"]="Body topology could not be repaired safely",["integrity"]=integrity};Attribute(mesh,lastPass>=7);if(Cancelled())return new D{["cancelled"]=true};
        using var surface=new BlobSurfaceAttachments();surface.configure(mesh,Size);var attachmentReport=surface.finalize(features,Size);if(attachmentReport["failures"].AsGodotArray().Count>0)return new D{["error"]="Attachment validation failed",["attachment_report"]=attachmentReport};
        foreach(var value in features){var f=value.AsGodotDictionary();if(f.ContainsKey("points")&&!f.ContainsKey("root_color")){var seat=surface.nearest(f["points"].AsGodotArray()[0].AsVector3());if(seat.Count>0){f["root_color"]=seat["color"];f["root_tissue"]=seat["tissue"];}}}
        var appendages=new A();foreach(var value in features)
        {
            var f=value.AsGodotDictionary();if(!f.ContainsKey("points")||B(f,"fused_path")||B(f,"omitted"))continue;if(Cancelled())return new D{["cancelled"]=true};var points=f["points"].AsGodotArray();int parent=f["parent"].AsInt32();
            if(f.ContainsKey("parent_along")&&features[parent].AsGodotDictionary().TryGetValue("binding_curve",out var pc)){var parentCurve=pc.AsVector3Array();double t=Bindings.closest_parameter(points[0].AsVector3(),parentCurve);var root=Frames.point(parentCurve,t);var delta=root-points[0].AsVector3();for(int i=0;i<points.Count;i++)points[i]=points[i].AsVector3()+delta;f["center"]=root;f["parent_along"]=t;}
            D detail;
            if(B(f,"bulb"))detail=Bulb(f,lastPass>=7);else if(B(f,"sheet"))detail=Sheet(f,lastPass>=7);else
            {
                var curve=Curves.sample(new D{["points"]=PointArrays(points),["radii"]=f["radii_profile"],["shape"]=new D{["swelling"]=.08,["twist"]=0.0}},quality==0?5:7,true);
                if(Is(S(f,"feature_type"),"major_vine","muscular_limb","jointed_limb","sensory_stalk","sensory_sprout","membrane_support"))
                {
                    var source=new Vector3[40];var start=points[0].AsVector3();var end=points[^1].AsVector3();var middle=points[points.Count>3?1:points.Count/2].AsVector3();for(int i=0;i<source.Length;i++){double t=i/39.0;source[i]=start*(float)(1-t)*(float)(1-t)+middle*(float)(2*t*(1-t))+end*(float)t*(float)t;}var rest=Bindings.resample(source,8);f["binding_curve"]=rest;var samples=new Vector3[50];var radii=new float[50];var profile=f["radii_profile"].AsGodotArray();for(int row=0;row<50;row++){double t=row/49.0;samples[row]=Frames.point(rest,t);double u=t*(profile.Count-1);int index=Math.Min((int)u,profile.Count-2);radii[row]=(float)(profile[index].AsDouble()+(profile[index+1].AsDouble()-profile[index].AsDouble())*(u-index));}
                    for(int row=0;row<50;row++){double t=row/49.0;var before=Frames.tangent(rest,Math.Max(0,t-.01));var after=Frames.tangent(rest,Math.Min(1,t+.01));double distance=Frames.point(rest,Math.Min(1,t+.01)).DistanceTo(Frames.point(rest,Math.Max(0,t-.01))),curvature=before.DistanceTo(after)/Math.Max(distance,.00001);radii[row]=(float)Math.Min(radii[row],.42/Math.Max(curvature,.01));}curve["points"]=samples;curve["radii"]=radii;
                }
                detail=Tube(curve,f,lastPass>=7);
            }
            var vertices=detail["vertices"].AsVector3Array();if(vertices.Length==0)continue;AlignWinding(detail);var report=Integrity.clean(detail);f["mesh_integrity"]=report;if(detail["indices"].AsInt32Array().Length==0||!Closed(report)){f["omitted"]=true;f["omission_reason"]="Appendage failed closed-manifold validation";continue;}vertices=detail["vertices"].AsVector3Array();var bounds=new Aabb(vertices[0],Vector3.Zero);foreach(var point in vertices)bounds=bounds.Expand(point);f["bounds"]=bounds;appendages.Add(new D{["feature"]=f,["mesh"]=detail});
        }
        if(lastPass>=7)Snapshot(7);var moment=Vector3.Zero;double totalMass=0;var rig=new D{["rolling_axis"]=Vector3.Right,["contact_zones"]=new A(),["active_legs"]=new A(),["passive_trailing"]=new A(),["roll_coupled"]=new A(),["secondary_motion_groups"]=new A(),["squish_regions"]=new A(),["collision_proxies"]=new A(),["cage"]=dna["envelope"],["bone_positions"]=new A()};
        foreach(var value in features)
        {
            var f=value.AsGodotDictionary();string kind=S(f,"feature_type"),tissue=S(f,"tissue");void Add(string name)=>rig[name].AsGodotArray().Add(f["id"]);if(kind=="belly_contact")Add("contact_zones");if(Is(kind,"muscular_limb","jointed_limb"))Add("active_legs");if(S(f,"roll_coupling")=="drag")Add("passive_trailing");if(S(f,"roll_coupling")=="coupled")Add("roll_coupled");if(tissue=="sac")Add("secondary_motion_groups");if(B(f,"subtract")||f.ContainsKey("points"))continue;var r=V(f,"radii");double mass=(double)r.X*r.Y*r.Z;moment+=V(f,"center")*(float)mass;totalMass+=mass;Add("squish_regions");if(f["pass_created"].AsInt32()<=2&&kind!="belly_contact"){rig["collision_proxies"].AsGodotArray().Add(new D{["center"]=f["center"],["radii"]=r*.83f});rig["bone_positions"].AsGodotArray().Add(f["center"]);}
        }
        dna["center_of_mass"]=moment/(float)Math.Max(totalMass,.001);rig["center_of_mass"]=dna["center_of_mass"];dna["estimated_mass"]=totalMass*4*Math.PI/3;var result=new D{["dna"]=dna.Duplicate(true),["features"]=features.Duplicate(true),["stages"]=stages.Duplicate(true),["body"]=mesh,["appendages"]=appendages,["rig"]=rig,["descriptor"]=Blueprint.descriptor(dna)};var obstacles=new A();rig["obstacle_volumes"]=obstacles;
        foreach(var value in features){var f=value.AsGodotDictionary();var r=V(f,"radii");if(f.ContainsKey("points")||B(f,"subtract")||r[(int)r.MaxAxisIndex()]<Size*.18)continue;obstacles.Add(new D{["center"]=f["center"],["radii"]=r,["basis"]=(f.TryGetValue("inverse_basis",out var basis)?basis.AsBasis():Basis.Identity).Transposed(),["feature_id"]=f["id"]});}rig["attachment_validation"]=attachmentReport;result["finalization"]=Bindings.finalize(result);result["mesh_integrity"]=integrity;Progress(.94,"Validating connected anatomy");if(Cancelled())return new D{["cancelled"]=true};result["statistics"]=Statistics(result);Progress(1,"Anatomy and deformation bindings ready");return result;
    }
    private static bool Failed(D result)=>result.ContainsKey("error")||B(result,"cancelled");
    private D Statistics(D result)
    {
        var body=result["body"].AsGodotDictionary();int triangles=body["indices"].AsInt32Array().Length/3,vertices=body["vertices"].AsVector3Array().Length;var types=new D();foreach(var value in features){string type=S(value.AsGodotDictionary(),"feature_type");types[type]=(types.TryGetValue(type,out var count)?count.AsInt32():0)+1;}foreach(var value in result["appendages"].AsGodotArray()){var mesh=value.AsGodotDictionary()["mesh"].AsGodotDictionary();triangles+=mesh["indices"].AsInt32Array().Length/3;vertices+=mesh["vertices"].AsVector3Array().Length;}return new D{["triangles"]=triangles,["vertices"]=vertices,["features"]=features.Count,["feature_types"]=types,["packed_bytes"]=GD.VarToBytes(body).Length+GD.VarToBytes(result["appendages"]).Length};
    }
    public A build_collection(A seeds)=>build_collection(seeds,0,new D(),.07);
    public A build_collection(A seeds,int quality)=>build_collection(seeds,quality,new D(),.07);
    public A build_collection(A seeds,int quality,D options)=>build_collection(seeds,quality,options,.07);
    public A build_collection(A seeds,int quality,D options,double minimumDistance)
    {
        var result=new A();var descriptors=new System.Collections.Generic.List<float[]>();foreach(var value in seeds){long seed=value.AsInt64(),accepted=seed;bool unique=false;int attempts=0;for(int attempt=0;attempt<12;attempt++){attempts=attempt+1;accepted=checked(seed+attempt*104729L);var candidate=Blueprint.plan(accepted,"auto",options);var descriptor=candidate["descriptor"].AsFloat32Array();unique=descriptors.All(previous=>Blueprint.distance(descriptor,previous)>=minimumDistance);if(unique)break;}if(!unique)continue;var item=build(accepted,quality,"auto",7,null,options);item["requested_seed"]=seed;item["diversity_attempts"]=attempts;result.Add(item);if(!Failed(item))descriptors.Add(item["descriptor"].AsFloat32Array());}return result;
    }
}
