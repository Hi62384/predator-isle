using Godot;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

public partial class MesherFixture : RefCounted, ICaveField
{
    public Vector3 center { get; set; } = new(32, 32, 32);
    public A precise_shores { get; set; } = new();
    public D surface_columns { get; set; } = new();
    public double sample(Vector3 point) => Sample(point);
    public Vector3 normal(Vector3 point) => Normal(point);
    public bool has_chunk(Vector3I key) => HasChunk(key);
    public double surface_height(Vector2 point) => SurfaceHeight(point);
    public double Sample(Vector3 point) => (point - center).Length() - 18.25;
    public Vector3 Normal(Vector3 point) => (point - center).Normalized();
    public bool HasChunk(Vector3I key) => key.Y == 0 && key.Z == 0 && (key.X == 0 || key.X == -1);
    public A PreciseShores => precise_shores;
    public bool HasSurfaceColumn(Vector2I column) => surface_columns.ContainsKey(column);
    public double SurfaceHeight(Vector2 point) => 40;
}
