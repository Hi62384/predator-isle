using Godot;
using System;
using PredatorIsle.Blobs;
using D=Godot.Collections.Dictionary;
namespace PredatorIsle.Checks;
internal static class BlobRuntimeChecks
{
    internal static void Run(Node owner,Action<bool,string> require)
    {
        using var pipeline=new BlobOrganismPipeline();
        var result=pipeline.build(22,0,"auto",7,null,new D());
        require(!result.ContainsKey("error"),"Default blob generation failed: "+result);
        var integrity=result["mesh_integrity"].AsGodotDictionary();
        foreach(string name in new[]{"boundary_edges","nonmanifold_edges","inconsistent_edges"})require(integrity[name].AsInt32()==0,"Blob body failed closed topology: "+name);
        var vertices=result["body"].AsGodotDictionary()["vertices"].AsVector3Array();require(vertices.Length>100,"Blob body mesh is empty");foreach(var v in vertices)require(v.IsFinite(),"Blob body has nonfinite geometry");
        var actor=new BlobOrganism{simulation_enabled=false,travel_enabled=false};owner.AddChild(actor);
        try
        {
            actor.configure(result);require(actor.render_instances.Count>0&&actor.skeleton.GetBoneCount()>0,"Blob rendering or skeleton did not initialize");
            foreach(string mode in new[]{"roll","vine","limb","contractile","peristaltic","drag","pulse","multicontact"})
            {
                actor.set_locomotion(mode);for(int frame=0;frame<12;frame++)actor.simulate(1.0/60);
                require(actor.GlobalTransform.IsFinite()&&double.IsFinite(actor.solver.height),"Blob pose became invalid: "+mode);
                foreach(var v in vertices.AsSpan(0,Math.Min(32,vertices.Length)))require(actor.solver.map_point(v).IsFinite(),"Blob deformation became invalid: "+mode);
            }
        }
        finally{actor.Free();}
    }
}
