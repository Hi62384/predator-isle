using Godot;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveSurfaceBiomes : RefCounted
{
    public D bind(A arrays, GodotObject field, Vector3I key) => bind(arrays, field, key, new A());
    public D bind(A arrays, GodotObject field, Vector3I key, A chosen_ids)
    {
        var native = field as CaveField; var ids = chosen_ids.Count > 0 ? chosen_ids : native != null ? native.biome_ids_for_cell(key) : field.Call("biome_ids_for_cell", key).AsGodotArray();
        if (ids.Count > 4) return new D { ["valid"] = false, ["reason"] = "More than four surface-biome overlaps in one cave cell", ["arrays"] = new A(), ["ids"] = ids };
        if (ids.Count == 0 || arrays.Count == 0) return new D { ["valid"] = true, ["arrays"] = arrays, ["ids"] = ids };
        var output = arrays.Duplicate(); var vertices = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(); var first = new Vector2[vertices.Length]; var second = new Vector2[vertices.Length]; var cache = new Dictionary<Vector3, Vector4>(); var origin = (Vector3)key * 64;
        for (int i = 0; i < vertices.Length; i++)
        {
            var point = vertices[i] + origin;
            if (!cache.TryGetValue(point, out var weights)) { weights = native != null ? native.biome_weights_at(point, ids) : field.Call("biome_weights_at", point, ids).AsVector4(); cache[point] = weights; }
            first[i] = new Vector2(weights.X, weights.Y); second[i] = new Vector2(weights.Z, weights.W);
        }
        output[(int)Mesh.ArrayType.TexUV] = first; output[(int)Mesh.ArrayType.TexUV2] = second; return new D { ["valid"] = true, ["arrays"] = output, ["ids"] = ids };
    }
}
