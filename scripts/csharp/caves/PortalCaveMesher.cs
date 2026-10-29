using Godot;

namespace PredatorIsle.Caves;

public partial class PortalCaveMesher : CaveMesher
{
    public override void emit(Vector3 a, Vector3 b, Vector3 c)
    {
        var center = (a + b + c) / 3;
        var column = new Vector2I(Mathf.FloorToInt(center.X / 64), Mathf.FloorToInt(center.Z / 64));
        if (!Field!.HasSurfaceColumn(column) && center.Y >= Field.SurfaceHeight(new Vector2(center.X, center.Z)) - 4) return;
        base.emit(a, b, c);
    }
}
