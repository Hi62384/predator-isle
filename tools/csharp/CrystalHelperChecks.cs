using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CrystalHelperChecks
{
    internal static void Run(Action<bool,string> require)
    {
        ShallowChamberChecks.Run(require);
        CrystalProfileChecks.Run(require);
        CrystalIntegrationChecks.Run(require);
        var luminous=GD.Load<GDScript>("res://scripts/caves/crystal_luminous.gd");using var current=new CrystalLuminous();
        var region=FrozenFeatureChecks.Fixture();var assignment=region["cave_biome_regions"].AsGodotDictionary();var candidate=assignment["candidates"].AsGodotArray()[0].AsGodotDictionary();candidate["biome_id"]="crystal";candidate["id"]="A/crystal";
        var forms=new A();var uv=new Vector2[300];var vertices=new Vector3[300];
        for(int i=0;i<100;i++)
        {
            forms.Add(new D {["id"]="A/form/"+i,["kind"]="crystal",["batch"]="mineral_opaque",["thin_transmission"]=i%7==0,["first_vertex"]=i*3,["vertex_count"]=3});
            for(int j=0;j<3;j++){uv[i*3+j]=new Vector2(j,i%5==0?0:2);vertices[i*3+j]=new Vector3(i,j,1);}
        }
        var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices;arrays[(int)Mesh.ArrayType.TexUV]=uv;
        var payload=new D {["valid"]=true,["placements"]=forms,["batches"]=new A {new D {["kind"]="mineral_opaque",["arrays"]=arrays}}};var before=GD.VarToBytes(payload);bool positive=false;
        foreach(long seed in new[]{-17L,17L,73921L})foreach(bool enabled in new[]{false,true})foreach(double chance in new[]{0.0,.12,1.0})foreach(int family in new[]{0,6,7})
        {
            region["cave_family"]=family;var controls=new D {["luminous_minerals"]=enabled,["luminous_region_chance"]=1.0,["luminous_form_chance"]=chance};
            var expected=luminous.Call("apply",payload,new A {region},seed,controls);var actual=current.apply(payload,new A {region},seed,controls);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Crystal luminous controls differ: "+MigrationComparison.FirstDifference(expected,actual));
            int selected=actual["placements"].AsGodotArray().Count(v=>v.AsGodotDictionary().ContainsKey("fictional_emission"));require(selected<=10,"Crystal luminous selection exceeds ten percent cap");positive|=selected>0;
            require(before.SequenceEqual(GD.VarToBytes(payload)),"Crystal luminous post-process changed its input");
            require(GD.VarToBytes(actual["batches"].AsGodotArray()[0].AsGodotDictionary()["arrays"].AsGodotArray()[(int)Mesh.ArrayType.Vertex]).SequenceEqual(GD.VarToBytes(vertices)),"Crystal luminous post-process changed geometry");
        }
        require(positive,"Crystal luminous fixture did not select any opaque mineral forms");
        var exposure=GD.Load<GDScript>("res://scripts/caves/crystal_vein_exposure.gd");using var nativeExposure=new CrystalVeinExposure();
        for(int i=-500;i<=500;i++)
        {
            var point=new Vector3(i*13.25f,i*7.5f,i*31.125f);double expected=exposure.Call("amount",point).AsDouble(),actual=nativeExposure.amount(point);
            require(Math.Abs(expected-actual)<=1e-12&&(float)expected==(float)actual,"Crystal vein exposure differs beyond scalar/mesh precision");
            require(Math.Abs(actual-nativeExposure.amount(point+new Vector3(3840,3840,3840)))<=1e-12,"Crystal vein exposure resets across the world period");
        }
    }
}
