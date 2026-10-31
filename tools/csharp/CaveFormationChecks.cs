using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveFormationChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var script=GD.Load<GDScript>("res://scripts/caves/formations.gd");
        using var opaque=new MagmaCaveGeometry();using var opaqueReference=GD.Load<GDScript>("res://scripts/caves/magma_geometry.gd").New().AsGodotObject();
        foreach(int kind in new[]{0,1,2})for(int variant=-5;variant<9;variant++)
        {
            var expectedPrototype=opaqueReference.Call("prototype",kind,variant).AsVector3Array();var actualPrototype=opaque.prototype(kind,variant);
            require(expectedPrototype.Length==actualPrototype.Length,"Opaque volcanic prototype changed topology");
            for(int i=0;i<expectedPrototype.Length;i++)for(int component=0;component<3;component++)
            {
                float expectedComponent=expectedPrototype[i][component],actualComponent=actualPrototype[i][component];
                // Native math libraries differ at sin(pi) by ~4e-21m. Every non-negligible coordinate remains exact.
                require(expectedComponent==actualComponent||Math.Abs(expectedComponent)<1e-9&&Math.Abs((double)expectedComponent-actualComponent)<=1e-12,"Opaque volcanic prototype exceeds near-zero rounding allowance");
            }
        }
        var fitReference=GD.Load<GDScript>("res://scripts/caves/measured_formation.gd");using var fit=new CaveMeasuredFormation();int fitted=0;
        require(opaque.Get("templates").AsGodotDictionary().Count==6&&opaqueReference.Get("templates").AsGodotDictionary().Count==6,"Volcanic prototype cache metadata was not retained across the script boundary");
        foreach(double phase in new[]{0.0,2.0,6.1})foreach(double up in new[]{-1.0,1.0})foreach(bool flowing in new[]{false,true})foreach(bool breakdown in new[]{false,true})
        {
            using var old=script.New().AsGodotObject();using var current=new CaveFormations();var root=new Vector3(10,-16,20);var foot=Enumerable.Range(0,14).Select(i=>root+new Vector3(0,(float)(up*(-.35+.01*i)),0)).ToArray();var origin=new Vector3(-64,0,64);old.Set("origin",origin);current.origin=origin;
            old.Call("growth",root,2.7,7.3,up,phase,foot,flowing,breakdown);current.growth(root,2.7,7.3,up,phase,foot,flowing,breakdown);
            foreach(string property in new[]{"vertices","normals","colors"})require(GD.VarToBytes(old.Get(property)).SequenceEqual(GD.VarToBytes(current.Get(property))),"Formation growth differs "+property+": "+MigrationComparison.FirstDifference(old.Get(property),current.Get(property)));
        }
        foreach(double phase in new[]{0.0,2.0,6.1})
        {
            using var old=script.New().AsGodotObject();using var current=new CaveFormations();var root=new Vector3(10,-16,20);var ceiling=root+Vector3.Up*17.3f;var foot=Enumerable.Range(0,14).Select(i=>root+Vector3.Down*(.35f+i*.01f)).ToArray();var crown=Enumerable.Range(0,14).Select(i=>ceiling+Vector3.Up*(.35f+i*.01f)).ToArray();
            old.Call("column",root,ceiling,2.7,phase,foot,crown);current.column(root,ceiling,2.7,phase,foot,crown);
            foreach(string property in new[]{"vertices","normals","colors"})require(GD.VarToBytes(old.Get(property)).SequenceEqual(GD.VarToBytes(current.Get(property))),"Formation column differs "+property+": "+MigrationComparison.FirstDifference(old.Get(property),current.Get(property)));
        }
        int placed=0;
        foreach(int style in new[]{0,2,3,5})foreach(int seed in new[]{17,73921})foreach(var key in new[]{Vector3I.Zero,new Vector3I(-1,-1,1)})
        {
            var origin=(Vector3)key*64;var center=origin+new Vector3(32,16,32);
            var room=new D {["id"]="room",["point"]=center,["level"]=0,["chamber_radius"]=26.0,["chamber_height"]=28.0};
            using var field=new CaveField();require(field.compile(new A {new D {["valid"]=true,["nodes"]=new A {room},["edges"]=new A(),["cross_section_style"]=style}},Callable.From<double,double,double>((x,z)=>200)),"Formation room fixture not admitted");
            using var old=script.New().AsGodotObject();using var current=new CaveFormations();var expected=old.Call("build",field,key,seed,style,1.0);var actual=current.build(field,key,seed,style,1);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Complete attached formation payload differs: "+MigrationComparison.FirstDifference(expected,actual));placed+=actual["placements"].AsGodotArray().Count;
            require(GD.VarToBytes(script.Call("join",actual["arrays"],actual["arrays"])).SequenceEqual(GD.VarToBytes(current.join(actual["arrays"].AsGodotArray(),actual["arrays"].AsGodotArray()))),"Joined formation arrays differ");
            var root=current.boundary(field,center-Vector3.Up*4,center+Vector3.Up*4);
            foreach(int kind in new[]{0,1,2})foreach(double phase in new[]{0.0,2.0})
            {
                var points=opaque.prototype(kind,seed%4);var expectedFit=fitReference.Call("fit",field,opaqueReference.Call("prototype",kind,seed%4),root,Vector3.Up,1.5,4.0,phase);var actualFit=fit.fit(field,points,root,Vector3.Up,1.5,4,phase);
                require(GD.VarToBytes(expectedFit).SequenceEqual(GD.VarToBytes(actualFit)),"Measured opaque attachment differs: "+MigrationComparison.FirstDifference(expectedFit,actualFit));if(actualFit["valid"].AsBool())fitted++;
            }
            require(!fit.fit(field,System.Array.Empty<Vector3>(),root,Vector3.Up,1,4,0)["valid"].AsBool()&&!fit.fit(field,opaque.prototype(1),root,Vector3.One,1,4,0)["valid"].AsBool(),"Opaque attachment accepted invalid geometry");
        }
        require(placed>0,"Formation fixtures did not attach a geological growth");
        require(fitted>0,"Opaque attachment fixtures did not attach a complete prototype");
    }
}
