using Godot;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>The loading margin surrounds the whole capsule, including diagonal frontier cells.</summary>
public partial class TraversalEnvelope : RefCounted
{
    public bool ready(Vector3 point, D resident, D wanted)
    {
        if (!point.IsFinite()) return false;
        var key = new Vector3I(Mathf.FloorToInt(point.X / 64), Mathf.FloorToInt(point.Y / 64), Mathf.FloorToInt(point.Z / 64));
        if (!resident.ContainsKey(key)) return false;
        var local = point - (Vector3)key * 64; var first = Vector3I.Zero; var last = Vector3I.Zero;
        for (int axis = 0; axis < 3; axis++)
        {
            if (local[axis] <= 2) first[axis] = -1;
            if (64 - local[axis] <= 2) last[axis] = 1;
        }
        for (int z = first.Z; z <= last.Z; z++)
        for (int y = first.Y; y <= last.Y; y++)
        for (int x = first.X; x <= last.X; x++)
        {
            var neighbor = key + new Vector3I(x, y, z);
            if (wanted.ContainsKey(neighbor) && !resident.ContainsKey(neighbor)) return false;
        }
        return true;
    }
}
