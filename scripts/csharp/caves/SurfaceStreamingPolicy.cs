using Godot;

namespace PredatorIsle.Caves;

public partial class SurfaceStreamingPolicy : RefCounted
{
    public bool can_defer(Vector3 point, double ground, bool enabled, bool required_entrance) =>
        enabled && point.IsFinite() && double.IsFinite(ground) && ground - point.Y > 96 && !required_entrance;
}
