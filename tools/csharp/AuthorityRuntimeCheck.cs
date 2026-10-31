using Godot;
using System;
using System.Diagnostics;
using System.Threading.Tasks;
using PredatorIsle.Terrain;
namespace PredatorIsle.Checks;
public partial class AuthorityRuntimeCheck:Node
{
    private int checks;
    private void Require(bool ok,string message){checks++;if(!ok)throw new InvalidOperationException(message);}
    public override async void _Ready()
    {
        ChunkTerrain? terrain=null;
        try
        {
            terrain=GD.Load<PackedScene>("res://scenes/terrain_server.tscn").Instantiate<ChunkTerrain>();
            terrain.cave_settings=terrain.cave_settings.DuplicateDeep(Resource.DeepDuplicateMode.All);terrain.cave_settings.Set("enabled",false);terrain.authority_radius_metres=32;AddChild(terrain);
            var actors=new Node3D[17];for(int i=0;i<actors.Length;i++){actors[i]=new Node3D{Position=new Vector3(-714+i%2*16,100,-548)};AddChild(actors[i]);}
            Require(terrain.register_collision_actor(1,actors[0])&&terrain.register_collision_actor(2,actors[1]),"Server rejected valid actors");
            await WaitForActors(terrain,1,2);var query=PhysicsRayQueryParameters3D.Create(new Vector3(-714,2000,-548),new Vector3(-714,-1000,-548),1);
            using(query)Require(actors[0].GetWorld3D().DirectSpaceState.IntersectRay(query).Count>0,"Server actor has no physical ground");
            for(int i=2;i<16;i++)Require(terrain.register_collision_actor(i+1,actors[i]),"Server rejected an actor below the supported limit");
            Require(!terrain.register_collision_actor(17,actors[16]),"Server accepted more than 16 actors");
            for(int i=1;i<=16;i++)terrain.unregister_collision_actor(i);
            Require(terrain.get_loaded_chunk_count()==0,"Server retained terrain after its last actor left");
            Require(terrain.register_collision_actor(1,actors[0]),"Server rejected a returning actor");await WaitForActors(terrain,1);
            Require(terrain.last_error.Length==0,"Server reported a worker failure");
            terrain.Free();terrain=null;
            MigrationEvidence.Write("authority",checks,true);GD.Print($"C# authoritative terrain checks passed: {checks}");
            await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);GC.Collect();GC.WaitForPendingFinalizers();GetTree().CallDeferred(SceneTree.MethodName.Quit,0);
        }
        catch(Exception error){terrain?.Free();MigrationEvidence.Write("authority",checks,false,error:error.ToString());GD.PushError(error.ToString());GetTree().CallDeferred(SceneTree.MethodName.Quit,1);}
    }
    private async Task WaitForActors(ChunkTerrain terrain,params int[] ids)
    {
        var clock=Stopwatch.StartNew();while(true){bool ready=true;foreach(int id in ids)ready&=terrain.collision_actor_ready(id);if(ready)break;Require(terrain.last_error.Length==0,"Server terrain worker failed: "+terrain.last_error);if(clock.Elapsed.TotalSeconds>70)throw new TimeoutException("Server actor collision failed to become ready");await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);}
        checks++;
    }
}
