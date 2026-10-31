using Godot;
using D=Godot.Collections.Dictionary;
namespace PredatorIsle.Checks;
public partial class CaveHeatFixture : RefCounted
{
    public double heat {get;set;}=1;
    public string source_id {get;set;}="fixture-heat";
    public D sample(Vector3 point)=>new(){["heat"]=heat,["id"]=source_id,["surface_witness"]=point+Vector3.Up*100};
}
