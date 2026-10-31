using Godot;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
namespace PredatorIsle.Checks;
public partial class CaveFeatureTestProvider : RefCounted
{
    public long marker { get; set; } = 99;
    public D annotate_region(D region) { region["thermal_marker"] = marker; return region; }
    public D decorate_region_with_context(D region, Callable height, long seed, D configuration, double depth, double roof, GodotObject? context)
    { region["fixture"] = new D { ["seed"] = seed, ["height"] = height.Call(3.0, 5.0), ["depth"] = depth, ["roof"] = roof, ["context"] = context != null }; return region; }
    public D build(GodotObject field, Vector3I key, long seed, A regions, D configuration, D water)
    {
        if (configuration.ContainsKey("reject") && configuration["reject"].AsBool()) return new D { ["valid"] = false, ["reason"] = "fixture rejection" };
        int count = configuration.ContainsKey("vertices") ? configuration["vertices"].AsInt32() : 3; var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); arrays[(int)Mesh.ArrayType.Vertex] = new Vector3[count];
        return new D { ["valid"] = true, ["batches"] = new A { new D { ["kind"] = "fixture", ["arrays"] = arrays, ["seed"] = seed, ["key"] = key } } };
    }
}
