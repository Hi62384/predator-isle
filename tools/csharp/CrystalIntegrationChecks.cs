using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CrystalIntegrationChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var corridorReference=GD.Load<GDScript>("res://scripts/caves/crystal_corridor_features.gd");using var corridor=new CrystalCorridorFeatures();var proposals=new A();var expectedProposals=new A();var seen=new D();var expectedSeen=new D();var proposalRegion=CrystalProfileChecks.Fixture();var proposalEdge=proposalRegion["edges"].AsGodotArray()[0].AsGodotDictionary();
        for(int station=-4;station<100;station++)
        {
            var middle=new Vector3(station%8*8,24,32);corridorReference.Call("propose",expectedProposals,expectedSeen,proposalRegion,proposalEdge,64.0,24.0,middle,Vector3.Forward,station,Vector3.Zero,17,1.0);corridor.propose(proposals,seen,proposalRegion,proposalEdge,64,24,middle,Vector3.Forward,station,Vector3.Zero,17,1);
            require(GD.VarToBytes(expectedProposals).SequenceEqual(GD.VarToBytes(proposals))&&GD.VarToBytes(expectedSeen).SequenceEqual(GD.VarToBytes(seen)),"Crystal corridor candidate ordering/cap differs");
        }
        require(proposals.Count==64&&seen.Count>64,"Crystal corridor fixture did not exercise bounded candidate replacement");
        var current=GD.Load<GDScript>("res://scripts/caves/crystal_features.gd");string source=Godot.FileAccess.GetFileAsString(current.ResourcePath);
        foreach(var replacement in new[]{("CrystalCaveGeometry","crystal_geometry"),("CrystalConnectedProfiles","crystal_profiles"),("CrystalVeinExposure","crystal_vein_exposure"),("CrystalLakeChambers","crystal_lake_chambers"),("CrystalLuminous","crystal_luminous"),("CrystalShallowChambers","crystal_shallow"),("CrystalCorridorFeatures","crystal_corridor_features")})source=source.Replace("res://scripts/csharp/caves/"+replacement.Item1+".cs","res://scripts/caves/"+replacement.Item2+".gd",StringComparison.Ordinal);
        using var original=new GDScript {SourceCode=source};require(original.Reload()==Error.Ok,"Independent original Crystal provider did not compile");
        var region=CrystalProfileChecks.Fixture();var room=region["nodes"].AsGodotArray()[0].AsGodotDictionary();room["crystal_profile"]="geode";room["crystal_layout"]=2;
        var height=Callable.From<double,double,double>((x,z)=>200);using var field=new PortalCaveField();require(field.compile(new A {region},height,new A(),region["cave_biome_regions"].AsGodotDictionary()),"Crystal integration chamber did not compile");
        int forms=0,veins=0,lining=0;
        foreach(int seed in new[]{17,73921})foreach(var key in new[]{Vector3I.Zero,new Vector3I(-1,0,0),new Vector3I(0,1,0)})
        {
            var controls=new D {["density"]=1.0,["localized_veins"]=false,["geode_lining"]=true,["corridor_growth"]=true,["luminous_minerals"]=true,["luminous_region_chance"]=1.0,["luminous_form_chance"]=1.0};
            using var reference=original.New().AsGodotObject();using var native=new CrystalCaveFeatures();var expected=reference.Call("build",field,key,seed,new A {region},controls,new D());var actual=native.Call("build",field,key,seed,new A {region},controls,new D());
            // Native cos(3π/2) and System.Math differ by ~6e-21 here.
            // Bound only effectively-zero orientation metadata; geometry stays byte exact.
            var comparable=actual.AsGodotDictionary().Duplicate(true);
            var ep=expected.AsGodotDictionary()["placements"].AsGodotArray();var ap=comparable["placements"].AsGodotArray();
            if(ep.Count==ap.Count)for(int i=0;i<ep.Count;i++)
            {
                var e=ep[i].AsGodotDictionary();var a=ap[i].AsGodotDictionary();if(!e.ContainsKey("axis")||!a.ContainsKey("axis"))continue;
                var ev=e["axis"].AsVector3();var av=a["axis"].AsVector3();
                for(int c=0;c<3;c++)if(Math.Abs(ev[c])<1e-12&&Math.Abs(av[c])<1e-12&&Math.Abs((double)ev[c]-av[c])<=1e-20)av[c]=ev[c];
                a["axis"]=av;
            }
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(comparable)),"Complete integrated Crystal mesh differs: "+MigrationComparison.FirstDifference(expected,comparable));
            foreach(var item in actual.AsGodotDictionary()["placements"].AsGodotArray())
            {
                string kind=item.AsGodotDictionary()["kind"].AsString();if(kind=="crystal")forms++;if(kind=="mineral_vein")veins++;if(kind=="crystal_lining")lining++;
            }
            require(field.include_surface_air&&field.opening_rock_cover==0,"Crystal integration retained extraction flags");
        }
        require(forms>0&&veins>0&&lining>0,$"Crystal integration fixture did not exercise attached mineral, vein and lining payloads: {forms}/{veins}/{lining}");
    }
}
