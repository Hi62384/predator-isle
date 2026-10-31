using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CavePayloadChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var old = GD.Load<GDScript>("res://scripts/caves/surface_payload.gd"); using var current = new CaveSurfacePayload();
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); const int count = 256;
        arrays[(int)Mesh.ArrayType.Vertex] = new Vector3[count]; var colors = new Color[count]; var uv = new Vector2[count]; var uv2 = new Vector2[count]; var random = new Random(73921);
        for (int i = 0; i < count; i++) { colors[i] = new Color((float)random.NextDouble(), (float)random.NextDouble(), (float)random.NextDouble(), (float)random.NextDouble()); uv[i] = new Vector2(i * .25f, random.Next(16777216)); uv2[i] = new Vector2(random.Next(16777216), random.Next(16777216)); }
        arrays[(int)Mesh.ArrayType.Color] = colors; arrays[(int)Mesh.ArrayType.TexUV] = uv; arrays[(int)Mesh.ArrayType.TexUV2] = uv2;
        for (int slot = (int)Mesh.ArrayType.Custom0; slot <= (int)Mesh.ArrayType.Custom3; slot++)
        {
            var values = new float[count * 4]; for (int i = 0; i < values.Length; i++) values[i] = random.Next(16777216) * ((i / 4 + slot) % 2 == 0 ? -1 : 1);
            arrays[slot] = values;
        }
        var decoded = new A();
        for (int i = 0; i < count; i++) foreach (bool normalize in new[] { false, true })
        {
            var expected = old.Call("decode", arrays, i, normalize); var actual = current.decode(arrays, i, normalize);
            require(Equal(expected, actual), $"Decoded cave terrain payload differs: {i}/{normalize}");
            if (!normalize) decoded.Add(actual);
        }
        foreach (var p in new[] { Vector2.Zero, new Vector2(64, 64), new Vector2(-1, 0), new Vector2(32, 32), Vector2.Inf, new Vector2(17.25f, 49.5f) })
        foreach (int resolution in new[] { 1, 8, 16 })
        {
            var expected = old.Call("triangle", p, 64.0, resolution); var selection = current.triangle(p, 64, resolution);
            require(Equal(expected, selection), "Surface triangle selection differs");
            require(Equal(old.Call("interpolate", decoded, expected), current.interpolate(decoded, selection)), "Barycentric payload interpolation differs");
        }
        foreach (int length in new[] { 0, 1, 68, 68 * 3, 68 * 120 })
        {
            var values = new float[length]; for (int i = 0; i < values.Length; i++) values[i] = (float)(random.NextDouble() - .5);
            require(Equal(old.Call("atlas", values), current.atlas(values)), "Surface texture atlas differs");
        }
    }
}
