using Godot;
using System;
using System.Linq;
using System.Numerics;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
using Vector2 = Godot.Vector2;
using Vector3 = Godot.Vector3;

namespace PredatorIsle.Checks;

/// <summary>Lossless entrance payloads and unchanged shared cave surface geometry.</summary>
internal static class CaveGpuPayloadChecks
{
    internal static D Measurements { get; private set; } = new();
    internal static void Run(Action<bool, string> require)
    {
        using var payload = new CaveSurfacePayload();
        const int full = (1 << CaveSurfacePayload.Texels) - 1;
        int cases = 0;
        foreach (int vertices in new[] { 1, 3, 121, 1025 })
        foreach (int mask in new[] { 0, 1, 1 << 16, 0x15555, 0xAAAA, full })
        {
            var source = Values(vertices, mask);
            var compact = payload.CompactAtlas(source);
            require(compact.Count > 0 && compact["texel_mask"].AsInt32() == mask, "Cave atlas omitted or invented a control bank");
            require(compact["texels_per_vertex"].AsInt32() == BitOperations.PopCount((uint)mask), "Cave atlas stride does not match occupied control banks");
            require(EqualBits(source, Expand(compact)), "Compact cave atlas changed a floating-point payload lane");
            var legacy = payload.atlas(source);
            require(compact["bytes"].AsByteArray().Length <= legacy["bytes"].AsByteArray().Length, "Compact cave upload grew beyond the original atlas");
            cases++;
        }
        // A negative zero is not a missing +0 control, even when it is the only
        // occupied value in its texel. Preserve subnormals and NaN payload bits too.
        var unusual = new float[CaveSurfacePayload.Stride * 3];
        foreach (var item in new[] { (0, unchecked((int)0x80000000)), (41, 1), (111, 0x7fc01234), (200, 0x7f800000) })
            unusual[item.Item1] = BitConverter.Int32BitsToSingle(item.Item2);
        var unusualAtlas = payload.CompactAtlas(unusual);
        require(EqualBits(unusual, Expand(unusualAtlas)), "Cave atlas lost signed zero or special IEEE-754 bits");
        require(payload.CompactAtlas(Array.Empty<float>()).Count == 0 && payload.CompactAtlas(new float[67]).Count == 0,
            "Malformed cave payload was accepted");
        require(payload.CompactAtlas(new float[(CaveSurfacePayload.MaxBytes / CaveSurfacePayload.Stride / 4 + 1) * CaveSurfacePayload.Stride]).Count == 0,
            "Compaction bypassed the original cave group memory budget");
        foreach (Variant typed in new Variant[] { new Godot.Collections.Array<string>(),
            new Godot.Collections.Dictionary<string, int> { ["control"] = 7 } })
            require(GD.VarToBytes(typed).SequenceEqual(GD.VarToBytes(CanonicalPayload(typed, require))),
                "Independent cave atlas normalization lost typed-container metadata");

        // Existing independent GDScript checks cover all categorical controls,
        // triangle diagonals, normals, and complete generated mesh dictionaries.
        CavePayloadChecks.Run(require);
        CaveContextChecks.Run(require);
        CaveSurfaceCutChecks.Run(require);
        CheckSurfaceIntegration(require);
        CheckProductionAdapters(require);

        var sparse = Values(1025, (1 << 0) | (1 << 12) | (1 << 15) | (1 << 16));
        var packed = payload.CompactAtlas(sparse); var original = payload.atlas(sparse);
        var selectionAllocations = MeasureSelections(payload, require);
        Measurements = new D
        {
            ["compact_layout_cases"] = cases,
            ["representative_vertices"] = 1025,
            ["legacy_texels_per_vertex"] = 17,
            ["sparse_texels_per_vertex"] = packed["texels_per_vertex"],
            ["legacy_upload_bytes"] = original["bytes"].AsByteArray().Length,
            ["sparse_upload_bytes"] = packed["bytes"].AsByteArray().Length,
            ["selection_allocations"] = selectionAllocations,
            ["scope"] = "Lossless sparse entrance payloads; shared cave geometry and collision retain exact legacy equality"
        };
    }

    internal static float[] Values(int vertices, int mask)
    {
        var values = new float[vertices * CaveSurfacePayload.Stride];
        for (int vertex = 0; vertex < vertices; vertex++)
            for (int texel = 0; texel < CaveSurfacePayload.Texels; texel++)
                if ((mask & (1 << texel)) != 0)
                    for (int lane = 0; lane < 4; lane++)
                        values[vertex * CaveSurfacePayload.Stride + texel * 4 + lane] = .05f + ((vertex * 17 + texel * 13 + lane * 19) % 101) / 128f;
        return values;
    }
    private static bool EqualBits(float[] a, float[] b) => MemoryMarshal.AsBytes(a.AsSpan()).SequenceEqual(MemoryMarshal.AsBytes(b.AsSpan()));
    internal static Variant CanonicalPayload(Variant value, Action<bool, string> require)
    {
        if (value.VariantType == Variant.Type.Array)
        {
            // Preserve Godot's typed-container metadata as well as contents;
            // even an empty Array[String] has a distinct canonical byte form.
            var result = value.AsGodotArray().Duplicate();
            for (int index = 0; index < result.Count; index++) result[index] = CanonicalPayload(result[index], require);
            return result;
        }
        if (value.VariantType != Variant.Type.Dictionary) return value;
        var source = value.AsGodotDictionary(); var copy = source.Duplicate();
        foreach (var item in source) copy[item.Key] = CanonicalPayload(item.Value, require);
        if (!source.ContainsKey("texel_mask")) return copy;
        int mask = source["texel_mask"].AsInt32(), count = source["vertices"].AsInt32();
        int packedTexels = source["texels_per_vertex"].AsInt32(), width = source["width"].AsInt32();
        var packed = source["bytes"].AsByteArray();
        require(mask >= 0 && mask < 1 << 17 && packedTexels == BitOperations.PopCount((uint)mask)
            && width == 1024 && count > 0 && source["semantic_components"].AsInt32() == 67,
            "Worker compact cave atlas metadata is invalid");
        int packedLength = checked(count * packedTexels * 16);
        require(packed.Length == Math.Max(1, (packedLength + 16383) / 16384) * 16384 &&
            source["height"].AsInt32() == packed.Length / 16384, "Worker compact atlas has an invalid texture extent");
        bool zeroPadding = true;
        for (int i = packedLength; i < packed.Length; i++) zeroPadding &= packed[i] == 0;
        require(zeroPadding, "Worker compact atlas padding is not zero");
        int rows = checked((count * 17 + 1023) / 1024);
        var full = new byte[rows * 1024 * 16];
        // Independent decoder: compute each texel's rank directly from its
        // mask rather than sharing the producer's cursor or float helpers.
        for (int vertex = 0; vertex < count; vertex++)
            for (int texel = 0; texel < 17; texel++)
                if ((mask & (1 << texel)) != 0)
                {
                    int rank = BitOperations.PopCount((uint)(mask & ((1 << texel) - 1)));
                    Buffer.BlockCopy(packed, (vertex * packedTexels + rank) * 16, full, (vertex * 17 + texel) * 16, 16);
                }
        copy["height"] = rows; copy["bytes"] = full; copy["texels_per_vertex"] = 17; copy.Remove("texel_mask");
        return copy;
    }
    internal static void CheckProductionAdapters(Action<bool, string> require)
    {
        using var renderer = new CaveSurfaceRenderer(); using var biomes = new CaveBiomeMaterials();
        var original = GD.Load<Shader>("res://shaders/terrain_biomes.gdshader");
        var registry = GD.Load<Resource>("res://config/caves/cave_biome_regions.tres");
        foreach (bool hive in new[] { false, true })
        foreach (bool common in new[] { false, true })
        {
            var shader = renderer.shader(original, hive, common);
            require(shader is not null && shader.Code.Contains("surface_base=VERTEX_ID*cave_surface_texels", StringComparison.Ordinal),
                "Runtime cave renderer did not compose its compact vertex adapter");
            using var blend = new CaveBiomeBlend();
            string fourWeights = blend.source(shader!.Code, 4, true);
            fourWeights = fourWeights.Insert(fourWeights.LastIndexOf('}'), blend.begin(4));
            require(CaveVaryingPacking.Pack(fourWeights) == fourWeights,
                "Cave packing changed an unsupported fourth provider weight instead of preserving its original interface");
            foreach (var ids in new[] { new A(), new A { "frozen" }, new A { "crystal" }, new A { "magma" }, new A { "frozen", "crystal", "magma" } })
            {
                var composed = biomes.shader(shader!, ids, registry, true);
                require(composed is not null, "Compact cave payload rejected a registered cave biome adapter");
                var names = composed!.GetShaderUniformList().Select(item => item.AsGodotDictionary()["name"].AsString()).ToHashSet();
                require(names.Contains("cave_surface_payload") && names.Contains("cave_surface_texel_mask") && names.Contains("cave_surface_texels"),
                    "Cave biome composition lost compact GPU payload uniforms");
                require(Regex.Matches(composed.Code, @"(?m)^\s*varying\s+").Count <= Regex.Matches(shader!.Code, @"(?m)^\s*varying\s+").Count,
                    "Composed cave biomes exceeded the base entrance varying budget");
            }
        }
        GC.KeepAlive(original); GC.KeepAlive(registry);
    }
    private static D MeasureSelections(CaveSurfacePayload payload, Action<bool, string> require)
    {
        const int iterations = 10000;
        for (int i = 0; i < 256; i++) CaveSurfacePayload.TryTriangle(new Vector2(i % 64, (i * 7) % 64), 64, 32, out _);
        long typedBefore = GC.GetAllocatedBytesForCurrentThread(), typedChecksum = 0;
        for (int i = 0; i < iterations; i++)
        {
            CaveSurfacePayload.TryTriangle(new Vector2(i % 64, (i * 7) % 64), 64, 32, out var selection);
            typedChecksum += selection.A + selection.B + selection.C;
        }
        long typedBytes = GC.GetAllocatedBytesForCurrentThread() - typedBefore;
        long legacyBefore = GC.GetAllocatedBytesForCurrentThread(), legacyChecksum = 0;
        for (int i = 0; i < iterations; i++)
        {
            using var selection = payload.triangle(new Vector2(i % 64, (i * 7) % 64), 64, 32);
            var indices = selection["indices"].AsInt32Array(); legacyChecksum += indices[0] + indices[1] + indices[2];
        }
        long legacyBytes = GC.GetAllocatedBytesForCurrentThread() - legacyBefore;
        require(typedChecksum == legacyChecksum && typedBytes < legacyBytes, "Typed cave selections changed indices or retained dictionary allocation cost");
        return new D { ["queries"] = iterations, ["typed_managed_bytes"] = typedBytes, ["dictionary_managed_bytes"] = legacyBytes };
    }
    private static float[] Expand(D atlas)
    {
        int count = atlas["vertices"].AsInt32(), mask = atlas["texel_mask"].AsInt32();
        var result = new float[count * CaveSurfacePayload.Stride];
        var packed = MemoryMarshal.Cast<byte, float>(atlas["bytes"].AsByteArray().AsSpan());
        for (int vertex = 0, cursor = 0; vertex < count; vertex++)
            for (int texel = 0; texel < CaveSurfacePayload.Texels; texel++)
                if ((mask & (1 << texel)) != 0)
                {
                    packed.Slice(cursor, 4).CopyTo(result.AsSpan(vertex * CaveSurfacePayload.Stride + texel * 4, 4));
                    cursor += 4;
                }
        return result;
    }
    private static void CheckSurfaceIntegration(Action<bool, string> require)
    {
        var parent = new A(); parent.Resize((int)Mesh.ArrayType.Max);
        parent[(int)Mesh.ArrayType.Vertex] = new[] { Vector3.Zero, new Vector3(64, 0, 0), new Vector3(0, 0, 64), new Vector3(64, 0, 64) };
        parent[(int)Mesh.ArrayType.Normal] = Enumerable.Repeat(Vector3.Up, 4).ToArray();
        parent[(int)Mesh.ArrayType.Color] = Enumerable.Repeat(Colors.White, 4).ToArray();
        parent[(int)Mesh.ArrayType.TexUV] = new Vector2[4]; parent[(int)Mesh.ArrayType.TexUV2] = new Vector2[4];
        for (int slot = (int)Mesh.ArrayType.Custom0; slot <= (int)Mesh.ArrayType.Custom3; slot++) parent[slot] = new float[16];
        var records = new A { new D { ["id"] = "parent", ["origin"] = Vector3.Zero, ["span"] = 64.0, ["resolution"] = 1, ["arrays"] = parent } };
        var height = Callable.From<double, double, double>((_, _) => 0);
        using var context = new CaveSurfaceContext();
        require(context.configure(records, height), "Compact cave context rejected valid parent");
        var source = new A(); source.Resize((int)Mesh.ArrayType.Max);
        source[(int)Mesh.ArrayType.Vertex] = new[] { new Vector3(4, -1, 4), new Vector3(8, -1, 4), new Vector3(4, -1, 8), new Vector3(8, -1, 4), new Vector3(8, -1, 8), new Vector3(4, -1, 8) };
        source[(int)Mesh.ArrayType.Normal] = Enumerable.Repeat(Vector3.Up, 6).ToArray();
        source[(int)Mesh.ArrayType.Color] = Enumerable.Repeat(Colors.White, 6).ToArray();
        var reference = context.surfaces_indexed(source, Vector3.Zero, true);
        context.CompactGpuPayload = true;
        var actual = context.surfaces_indexed(source, Vector3.Zero, true);
        var group = actual["groups"].AsGodotDictionary()["parent"].AsGodotDictionary();
        var oldGroup = reference["groups"].AsGodotDictionary()["parent"].AsGodotDictionary();
        var atlas = group["atlas"].AsGodotDictionary();
        require(atlas["texels_per_vertex"].AsInt32() < 17, "Shared cave worker payload did not compact inactive biome data");
        require(EqualBits(oldGroup["payload"].AsFloat32Array(), Expand(atlas)), "Shared cave worker compact controls differ");
        // Only the texture representation changes. Compare every other complete
        // product, including indices, normals, source controls and physical faces.
        group["atlas"] = oldGroup["atlas"];
        require(GD.VarToBytes(reference).SequenceEqual(GD.VarToBytes(actual)), "Cave compaction changed mesh topology, controls, normals or collision");
    }
}
