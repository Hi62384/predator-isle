using Godot;
using System;
namespace PredatorIsle.Checks;
/// <summary>Deterministic synthetic pool basin for exact tessellation checks.</summary>
public partial class TerrainPoolTestField : RefCounted
{
    public double water_level {get;set;}
    public int HeightCalls {get;private set;}
    public double _get_height(double x,double z)
    {
        HeightCalls++;
        return 10.0+Math.Sqrt(x*x+z*z)*2.5;
    }
}
