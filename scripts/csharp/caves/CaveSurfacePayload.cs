using Godot;
using System;
using System.Runtime.InteropServices;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveSurfacePayload : RefCounted
{
    public const int Stride = 68, Texels = 17, Width = 1024, MaxBytes = 16777216;
    public int STRIDE => Stride;
    public int TEXELS => Texels;
    public int WIDTH => Width;
    public int MAX_BYTES => MaxBytes;
    public Vector3 unpack24(double value)
    { long n = (long)Math.Floor(value); return new Vector3((float)((n & 255) / 255.0), (float)(((n >> 8) & 255) / 255.0), (float)((n >> 16) / 255.0)); }
    public float[] channel(A arrays, int slot, int index, int count)
    {
        var result = new float[count]; if (arrays[slot].VariantType == Variant.Type.Nil) return result;
        var source = arrays[slot].AsFloat32Array(); int stride = source.Length / arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array().Length;
        for (int i = 0; i < count; i++) result[i] = i < stride ? source[index * stride + i] : i == 3 ? 1 : 0;
        return result;
    }
    private static float Round(double v) => (float)Math.Round(v, MidpointRounding.AwayFromZero);
    public float[] decode(A arrays, int index) => decode(arrays, index, false);
    public float[] decode(A arrays, int index, bool extension_normalization)
    {
        if (arrays.Count != (int)Mesh.ArrayType.Max || arrays[(int)Mesh.ArrayType.Vertex].VariantType == Variant.Type.Nil || index < 0 || index >= arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array().Length) return System.Array.Empty<float>();
        return Decode(new Buffer(arrays), index, extension_normalization);
    }
    internal sealed class Buffer
    {
        internal readonly Vector3[] Positions, Normals;
        internal readonly Color[] Colors;
        internal readonly Vector2[] Uv, Uv2;
        private readonly float[][] _custom = new float[4][];
        internal Buffer(A arrays)
        {
            Positions = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            Normals = arrays[(int)Mesh.ArrayType.Normal].VariantType == Variant.Type.Nil ? System.Array.Empty<Vector3>() : arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
            Colors = arrays[(int)Mesh.ArrayType.Color].VariantType == Variant.Type.Nil ? System.Array.Empty<Color>() : arrays[(int)Mesh.ArrayType.Color].AsColorArray();
            Uv = arrays[(int)Mesh.ArrayType.TexUV].VariantType == Variant.Type.Nil ? System.Array.Empty<Vector2>() : arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();
            Uv2 = arrays[(int)Mesh.ArrayType.TexUV2].VariantType == Variant.Type.Nil ? System.Array.Empty<Vector2>() : arrays[(int)Mesh.ArrayType.TexUV2].AsVector2Array();
            for (int i = 0; i < 4; i++) _custom[i] = arrays[(int)Mesh.ArrayType.Custom0 + i].VariantType == Variant.Type.Nil ? System.Array.Empty<float>() : arrays[(int)Mesh.ArrayType.Custom0 + i].AsFloat32Array();
        }
        internal void Channel(int slot, int index, Span<float> result)
        {
            var source = _custom[slot]; if (source.Length == 0) { result.Clear(); return; }
            int stride = source.Length / Positions.Length;
            for (int i = 0; i < result.Length; i++) result[i] = i < stride ? source[index * stride + i] : i == 3 ? 1 : 0;
        }
    }
    internal float[] Decode(Buffer buffer, int index, bool extension_normalization)
    {
        Span<float> c0 = stackalloc float[4], c1 = stackalloc float[4], c2 = stackalloc float[4], c3 = stackalloc float[4];
        buffer.Channel(0, index, c0); buffer.Channel(1, index, c1); buffer.Channel(2, index, c2); buffer.Channel(3, index, c3);
        var color = buffer.Colors[index]; var uv = buffer.Uv[index]; var uv2 = buffer.Uv2[index];
        for (int i = 0; i < 4; i++) color[i] = (float)(Math.Clamp((int)((double)color[i] * 255), 0, 255) / 255.0);
        var geology = new Vector3(c0[0], c0[1], c0[2]); var jungle = unpack24(c0[3]); var badlands = Vector2.Zero;
        if (c0[3] < 0) { jungle = unpack24(-c0[3] - 1.0); var b = unpack24(uv.Y); badlands = new Vector2(b.X, b.Y); uv.Y = (float)((Round((double)b.Z * 255) - 127.0) / 254); }
        var forest = unpack24(c1[0]); var ecology = unpack24(c1[1]); var forestGeology = new Vector2(c1[2], c1[3]); var coast = Vector3.Zero; double sediment = 0; var beach = Vector2.Zero;
        if (c1[2] < 0)
        {
            var a = unpack24(-c1[2] - 1.0); var b = unpack24(c1[3]); forestGeology = new Vector2(a.X, b.X); coast = new Vector3(a.Y, a.Z, b.Y); sediment = b.Z;
            if (c1[3] < 0) { b = unpack24(-c1[3] - 1.0); forestGeology.Y = b.X; beach = new Vector2(b.Y, b.Z); coast.Z = .5f; sediment = 0; }
        }
        var savanna = unpack24(c2[0]); var savannaGeology = unpack24(c2[1]); var savannaWater = unpack24(c2[2]); var savannaSurface = unpack24(c2[3]);
        var swamp = unpack24(c3[0]); var hydro = unpack24(c3[1]); var land = unpack24(c3[2]); var swampEcology = unpack24(c3[3]); var tropical = Vector3.Zero;
        if (c2[0] < 0)
        {
            var s = unpack24(-c2[0] - 1.0); var w = unpack24(-c3[0] - 1.0); var f = unpack24(-c1[0] - 1.0); tropical = new Vector3(s.Z, w.Z, f.Z);
            savanna = new Vector3(s.X, s.Y, (float)(Round((double)color.B * 255) / 255.0)); swamp = new Vector3(w.X, w.Y, (float)(Round((double)color.A * 255) / 255.0)); forest = new Vector3(f.X, f.Y, (float)(Round((double)color.G * 255) / 255.0));
        }
        var mountain = Vector3.Zero; var mountainGeology = Vector3.Zero; var mountainShape = Vector3.Zero; double mountainWet = 0; var surface = uv2;
        if (c0[0] < 0)
        {
            geology = unpack24(-c0[0] - 1.0); mountain = unpack24(c0[1]); mountainGeology = unpack24(c0[2]); var a = unpack24(uv2.X); var b = unpack24(uv2.Y);
            surface = new Vector2(a.X, a.Y); mountainShape = new Vector3(a.Z, b.X, b.Y); mountainWet = b.Z;
        }
        if (extension_normalization)
        {
            double total = (double)color.R + jungle.Z + forest.Z + savanna.Z + swamp.Z + mountain.Z + tropical.X + badlands.X;
            if (total > .0001) { jungle.Z = (float)(jungle.Z / total); forest.Z = (float)(forest.Z / total); savanna.Z = (float)(savanna.Z / total); swamp.Z = (float)(swamp.Z / total); mountain.Z = (float)(mountain.Z / total); tropical.X = (float)(tropical.X / total); badlands.X = (float)(badlands.X / total); }
        }
        var result = new float[Stride]; int cursor = 0;
        void V3(Vector3 v) { result[cursor++] = v.X; result[cursor++] = v.Y; result[cursor++] = v.Z; }
        void V2(Vector2 v) { result[cursor++] = v.X; result[cursor++] = v.Y; }
        V3(geology); V3(jungle); V3(forest); V3(ecology); V2(forestGeology); V3(savanna); V3(savannaGeology); V3(savannaWater); V3(savannaSurface);
        V3(swamp); V3(hydro); V3(land); V3(swampEcology); V3(mountain); V3(mountainGeology); V3(mountainShape); result[cursor++] = (float)mountainWet;
        V2(surface); V3(coast); result[cursor++] = (float)sediment; V2(beach); V3(tropical); V2(badlands); result[cursor++] = uv.X; result[cursor++] = uv.Y;
        if (cursor != 63) throw new InvalidOperationException("Unexpected decoded terrain surface layout");
        for (int i = 0; i < 4; i++) result[cursor++] = color[i]; return result;
    }
    public D triangle(Vector2 local, double span, int resolution)
    {
        if (!local.IsFinite() || !double.IsFinite(span) || span <= 0 || resolution < 1 || local.X < 0 || local.Y < 0 || local.X > span || local.Y > span) return new();
        var q = local / (float)span * resolution; int x = Math.Min((int)Math.Floor(q.X), resolution - 1), z = Math.Min((int)Math.Floor(q.Y), resolution - 1); double fx = (double)q.X - x, fz = (double)q.Y - z; int a = z * (resolution + 1) + x;
        if (fx + fz <= 1) return new D { ["indices"] = new[] { a, a + 1, a + resolution + 1 }, ["weights"] = new Vector3((float)(1 - fx - fz), (float)fx, (float)fz) };
        return new D { ["indices"] = new[] { a + 1, a + resolution + 2, a + resolution + 1 }, ["weights"] = new Vector3((float)(1 - fz), (float)(fx + fz - 1), (float)(1 - fx)) };
    }
    public float[] interpolate(A decoded, D selection)
    {
        if (selection.Count == 0) return System.Array.Empty<float>();
        var indices = selection["indices"].AsInt32Array(); var weights = selection["weights"].AsVector3(); var result = new float[Stride];
        for (int corner = 0; corner < 3; corner++)
        {
            if (indices[corner] < 0 || indices[corner] >= decoded.Count) return System.Array.Empty<float>(); var values = decoded[indices[corner]].AsFloat32Array(); if (values.Length != Stride) return System.Array.Empty<float>();
            for (int i = 0; i < Stride; i++) result[i] = (float)(result[i] + (double)values[i] * weights[corner]);
        }
        return result;
    }
    public D atlas(float[] values)
    {
        if (values.Length == 0 || values.Length % Stride != 0 || (long)values.Length * 4 > MaxBytes) return new();
        int rows = (int)Math.Ceiling((double)values.Length / (Width * 4)), size = Width * rows * 16; if (size > MaxBytes) return new();
        var bytes = new byte[size]; MemoryMarshal.AsBytes(values.AsSpan()).CopyTo(bytes);
        return new D { ["width"] = Width, ["height"] = rows, ["bytes"] = bytes, ["vertices"] = values.Length / Stride, ["semantic_components"] = 67, ["texels_per_vertex"] = Texels };
    }
}
