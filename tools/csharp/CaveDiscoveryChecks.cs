using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
namespace PredatorIsle.Checks;
internal static class CaveDiscoveryChecks
{
    internal static void Run(Action<bool,string> require)
    {
        using var ground=new CaveDiscoveryFixture();
        CaveWorkload Make()
        {
            var config=GD.Load<Resource>("res://config/caves/cave_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);config.Get("biome_regions").As<Resource>().Set("enabled",false);
            var network=new CaveNetwork{activity=1};network.configure(new Callable(ground,"_get_height"),new Callable(ground,"water"),17);
            return new CaveWorkload{builder=ground,configuration=config,network=network,field=new PortalCaveField()};
        }
        using var reference=Make();using var incremental=Make();var cell=new Vector2I(-1,1);var expected=reference.discover(cell);var actual=new Godot.Collections.Dictionary();int steps=0,regions=0;
        do
        {
            actual=incremental.discover_step(cell);steps++;
            if(actual.ContainsKey("discovery_pending"))
            {
                int next=actual["regions_ready"].AsInt32();require(next>=regions&&next-regions<=1,"Incremental cave discovery skipped or combined region work");regions=next;
                require(!actual.ContainsKey("regions")&&!actual.ContainsKey("cells"),"Partial cave discovery was exposed as a complete solid-ground proof");
            }
            require(!actual.ContainsKey("error")&&steps<1024,"Incremental cave discovery failed to finish its bounded graph");
        }while(actual.ContainsKey("discovery_pending")&&steps<1024);
        require(expected["entrances"].AsGodotArray().Count>0,"Cave discovery fixture did not exercise admitted entrances");
        require(steps>regions&&GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Yielding cave discovery changed the deterministic graph, exposure columns, or compiled cells");
        var cache=new CaveDiscoveryCache();cache.Add(cell,actual,incremental.DiscoveryBytes);require(cache.TryGet(cell,out var reused)&&ReferenceEquals(reused,actual),"Completed cave discovery was not reused across worker consumers");
        for(int i=0;i<32;i++)cache.Add(new Vector2I(i,0),new Godot.Collections.Dictionary(),cache.BudgetBytes/3);
        require(cache.ResidentBytes<=cache.BudgetBytes&&!cache.TryGet(cell,out _)&&cache.TryGet(new Vector2I(31,0),out _),"Cave discovery cache eviction lost its bound or newest result");
        require(!new CaveDiscoveryCache().TryGet(cell,out _),"Different cave world scopes reused stale discovery");
        // A changed interest discards partial cursor state while retaining valid region memoization.
        incremental.discover_step(new Vector2I(3,4));var restarted=incremental.discover_step(new Vector2I(-5,-6));require(restarted["regions_ready"].AsInt32()==1,"A stale regional cursor crossed destination changes");
        var stream=new CaveStreamer{configuration=reference.configuration.DuplicateDeep(Resource.DeepDuplicateMode.All),_surface_transaction=new CaveSurfaceTransaction{committed=true}};stream.configuration.Set("seal_stream_frontiers",false);var point=new Vector3(10,20,10);stream._cells[Vector3I.Zero]=true;
        stream._bundle["entrances"]=new Godot.Collections.Array{new Godot.Collections.Dictionary{["point"]=point,["columns"]=new Godot.Collections.Dictionary{[Vector2I.Zero]=true}}};
        require(!stream.traversal_ready(point),"Cave traversal accepted an unpublished entrance column");stream._surface_columns[Vector2I.Zero]=true;require(stream.traversal_ready(point),"Cave traversal did not read exposure dictionary keys");stream.Free();
    }
}
