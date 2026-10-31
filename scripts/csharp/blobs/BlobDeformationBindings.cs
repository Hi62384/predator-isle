using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Shared endpoint skinning with bounded, protected anatomical material islands.</summary>
public partial class BlobDeformationBindings : RefCounted
{
    public const int MAX_GROUPS=32,MAX_CHAINS=16,JOINTS=8;
    private readonly BlobCurveFrames Frames=new();
    private readonly OrganicCurveGeometry Curves=new();
    private static string Text(D d,string key)=>d[key].AsString();
    private static bool Flag(D d,string key)=>d.TryGetValue(key,out var v)&&v.AsBool();
    private static bool Is(string value,params string[] choices)=>Array.IndexOf(choices,value)>=0;
    public D finalize(D data)
    {
        var groups=new A();var groupIds=new D();var chains=new A();var chainIds=new D();
        var features=data["features"].AsGodotArray();var dna=data["dna"].AsGodotDictionary();var rig=data["rig"].AsGodotDictionary();double size=dna["size"].AsDouble();
        for(int pass=0;pass<2;pass++)foreach(var value in features)
        {
            var f=value.AsGodotDictionary();string kind=Text(f,"feature_type"),tissue=Text(f,"tissue");
            bool protect=Is(kind,"embedded_face","sensory_stalk","sensory_sprout","muscular_limb","jointed_limb","major_vine");
            if(protect!=(pass==0)||(!protect&&!Is(kind,"inflated_sac","satellite_sac","growth_nodule","porous_mantle","cartilage_plate","bruise_patch"))||groups.Count>=MAX_GROUPS)continue;
            var radii=f["radii"].AsVector3();var direction=f["direction"].AsVector3();
            if(f.ContainsKey("points")){var points=f["points"].AsGodotArray();radii=Vector3.One*(float)Math.Max((double)radii.X*3,size*.22);direction=(points[1].AsVector3()-points[0].AsVector3()).Normalized();}
            double stiffness=tissue switch{"face"=>.94,"cartilage"=>.9,"sponge"=>.8,"sac"=>.35,_=>.65};
            groupIds[f["id"]]=groups.Count;
            groups.Add(new D{["feature_id"]=f["id"],["center"]=f["center"],["radii"]=radii,["direction"]=direction,["stiffness"]=stiffness,["protected"]=protect,["minimum_scale"]=stiffness>.8?.91:.74,["circulation_gain"]=protect?0.0:1.0,["tissue"]=tissue});
        }
        foreach(string kind in new[]{"muscular_limb","jointed_limb","major_vine","sensory_stalk","sensory_sprout","membrane_support"})foreach(var value in features)
        {
            var f=value.AsGodotDictionary();if(Text(f,"feature_type")!=kind||chains.Count>=MAX_CHAINS||Flag(f,"omitted"))continue;
            var points=new A();foreach(var p in f["points"].AsGodotArray()){var v=p.AsVector3();points.Add(new A{v.X,v.Y,v.Z});}
            var curve=Curves.sample(new D{["points"]=points,["radii"]=f["radii_profile"]},8,true);
            var rest=f.TryGetValue("binding_curve",out var existing)?existing.AsVector3Array():resample(curve["points"].AsVector3Array(),JOINTS);
            if(rest.Length!=JOINTS)throw new ArgumentException("An anatomical binding must contain eight joints.");
            f["binding_curve"]=rest;var lengths=new float[JOINTS-1];double length=0;
            for(int i=0;i<lengths.Length;i++){lengths[i]=rest[i].DistanceTo(rest[i+1]);length+=lengths[i];}
            chainIds[f["id"]]=chains.Count;double phase=f["id"].AsDouble()*.61803398875;phase-=Math.Floor(phase);
            chains.Add(new D{["feature_id"]=f["id"],["kind"]=kind=="major_vine"?"vine":Is(kind,"sensory_stalk","sensory_sprout","membrane_support")?"passive":"leg",["rest"]=rest,["lengths"]=lengths,["length"]=length,["radius"]=f["radii"].AsVector3().X,["phase"]=phase,["stiffness"]=Is(kind,"muscular_limb","jointed_limb")?.85:.4,["group"]=groupIds.TryGetValue(f["id"],out var group)?group.AsInt32():-1});
        }
        rig["material_groups"]=groups;rig["chains"]=chains;rig["chain_ids"]=chainIds;rig["group_ids"]=groupIds;
        BindMesh(data["body"].AsGodotDictionary(),features,groupIds,chains,chainIds,-1);
        foreach(var value in data["appendages"].AsGodotArray()){var item=value.AsGodotDictionary();BindMesh(item["mesh"].AsGodotDictionary(),features,groupIds,chains,chainIds,item["feature"].AsGodotDictionary()["id"].AsInt32());}
        bool face=features.Any(v=>Text(v.AsGodotDictionary(),"feature_type")=="embedded_face"),legs=chains.Any(v=>Text(v.AsGodotDictionary(),"kind")=="leg"),vines=chains.Any(v=>Text(v.AsGodotDictionary(),"kind")=="vine");
        var core=dna["core_radii"].AsVector3();bool safe=chains.Count==0&&!face&&Math.Max((double)core.Y/core.Z,(double)core.Z/core.Y)<1.4;
        rig["binding_version"]=4;rig["roll_safe"]=safe;dna["requested_locomotion"]=dna["locomotion"];
        if(!safe&&Is(Text(dna,"locomotion"),"roll","hybrid"))dna["locomotion"]=legs?"limb":vines?"vine":"contractile";
        dna["protected_anatomy"]=groups.Any(v=>Flag(v.AsGodotDictionary(),"protected"));dna["roll_compatibility"]=face?.28:legs?.5:1.0;
        return new D{["groups"]=groups.Count,["chains"]=chains.Count,["maximum_groups"]=MAX_GROUPS,["maximum_chains"]=MAX_CHAINS,["joint_count"]=chains.Count*JOINTS};
    }
    private void BindMesh(D mesh,A features,D groups,A chains,D chainIds,int featureId)
    {
        var vertices=mesh["vertices"].AsVector3Array();var owners=mesh["feature_ids"].AsInt32Array();var anchors=mesh["anchors"].AsFloat32Array();
        var binds=new float[vertices.Length*4];var chainBinds=new float[vertices.Length*4];
        var parameters=mesh.TryGetValue("sheet_params",out var sheetParameters)?sheetParameters.AsVector2Array():Array.Empty<Vector2>();
        var rests=chains.Select(v=>v.AsGodotDictionary()["rest"].AsVector3Array()).ToArray();var normals=rests.Select(r=>Frames.normals(r)).ToArray();
        for(int i=0;i<vertices.Length;i++)
        {
            int owner=featureId>=0?featureId:owners[i],at=i*4;var f=features[owner].AsGodotDictionary();binds[at]=ancestor(owner,features,groups)+1;binds[at+2]=.4f;
            int chain=featureId>=0?ancestor(owner,features,chainIds):-1;
            if(Flag(f,"sheet"))
            {
                var ids=f["support_ids"].AsGodotArray();int a=chainIds.TryGetValue(ids[0],out var av)?av.AsInt32():-1,b=chainIds.TryGetValue(ids[1],out var bv)?bv.AsInt32():-1;
                int rows=f["sheet_rows"].AsInt32(),columns=f["sheet_columns"].AsInt32(),surface=(rows+1)*(columns+1),row=(i%surface)/(columns+1);
                chainBinds[at]=a+1;chainBinds[at+1]=parameters[i].X;chainBinds[at+2]=b+1;chainBinds[at+3]=parameters[i].Y;binds[at+2]=-1;
                anchors[at]=(float)(f["thickness"].AsDouble()*(i<surface?1:-1));anchors[at+1]=(float)((f.TryGetValue("sag",out var sag)?sag.AsDouble():.01)*Math.Sin((double)row/rows*Math.PI));
            }
            else if(chain>=0)
            {
                double t=1;
                if(chainIds.ContainsKey(owner)){var curve=mesh.TryGetValue("centerline",out var cv)?cv.AsVector3Array():Array.Empty<Vector3>();int sides=mesh.TryGetValue("sides",out var sv)?sv.AsInt32():8;t=i<curve.Length*sides?(double)(i/sides)/(curve.Length-1):i==curve.Length*sides?0:1;}
                else if(f.TryGetValue("parent_along",out var along))t=along.AsDouble();
                else if(!Is(Text(f,"feature_type"),"gripping_digit","sensory_bulb"))t=closest_parameter(f["center"].AsVector3(),rests[chain]);
                var offset=Frames.frame(rests[chain],normals[chain],t).Transposed()*(vertices[i]-Frames.point(rests[chain],t));anchors[at]=offset.X;anchors[at+1]=offset.Y;anchors[at+2]=offset.Z;chainBinds[at]=chain+1;chainBinds[at+1]=(float)t;
            }
        }
        mesh["binds"]=binds;mesh["chain_binds"]=chainBinds;mesh["anchors"]=anchors;
    }
    public int ancestor(int id,A features,D table)
    {
        int current=id;for(int steps=0;current>=0;steps++)
        {
            if(current>=features.Count||steps>=features.Count)throw new ArgumentException("Anatomical parent references must form a valid acyclic hierarchy.");
            if(table.TryGetValue(current,out var value))return value.AsInt32();current=features[current].AsGodotDictionary()["parent"].AsInt32();
        }
        return -1;
    }
    public Vector3[] resample(Vector3[] points,int count)
    {
        if(points.Length<2||count<1)throw new ArgumentException("Curve resampling needs at least two source points and one output point.");
        var distances=new float[points.Length];for(int i=1;i<points.Length;i++)distances[i]=(float)((double)distances[i-1]+points[i].DistanceTo(points[i-1]));
        var result=new Vector3[count];for(int i=0;i<count;i++){double desired=(double)i/Math.Max(count-1,1)*distances[^1];int segment=0;while(segment<points.Length-2&&distances[segment+1]<desired)segment++;double t=(desired-distances[segment])/Math.Max((double)distances[segment+1]-distances[segment],.0001);result[i]=points[segment].Lerp(points[segment+1],(float)t);}return result;
    }
    public double closest_parameter(Vector3 point,Vector3[] joints)
    {
        double best=double.PositiveInfinity,result=0;for(int i=0;i<joints.Length-1;i++){var line=joints[i+1]-joints[i];double t=Math.Clamp((double)(point-joints[i]).Dot(line)/Math.Max(line.LengthSquared(),.000001),0,1);double distance=point.DistanceSquaredTo(joints[i]+line*(float)t);if(distance<best){best=distance;result=(i+t)/(joints.Length-1);}}return result;
    }
}
