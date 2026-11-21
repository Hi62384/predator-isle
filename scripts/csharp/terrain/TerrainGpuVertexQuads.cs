using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>
/// Reusable 2D quads for a GPU numerical texture. Each quad covers one 1x9
/// pixel strip, allowing four vertex invocations to replace nine expensive
/// fragment evaluations. Index/vertex topology is immutable after creation.
/// </summary>
internal sealed class TerrainGpuVertexQuads : IDisposable
{
    private readonly Dictionary<int, ArrayMesh> templates = new();
    internal int CachedTemplates => templates.Count;

    internal ArrayMesh Get(int sampleCount)
    {
        if (sampleCount < 1 || sampleCount > TerrainGpuSampler.MaximumSamples)
            throw new ArgumentOutOfRangeException(nameof(sampleCount));

        int capacity = 1024;
        while (capacity < sampleCount) capacity = checked(capacity * 2);
        if (templates.TryGetValue(capacity, out var cached)) return cached;

        const int columns = 512, scalarRows = 9;
        var vertices = new Vector2[checked(capacity * 4)];
        var indices = new int[checked(capacity * 6)];
        for (int sample = 0; sample < capacity; sample++)
        {
            int v = sample * 4, k = sample * 6;
            float x = sample % columns, y = sample / columns * scalarRows;
            vertices[v] = new Vector2(x, y);
            vertices[v + 1] = new Vector2(x + 1, y);
            vertices[v + 2] = new Vector2(x + 1, y + scalarRows);
            vertices[v + 3] = new Vector2(x, y + scalarRows);
            indices[k] = v;
            indices[k + 1] = v + 1;
            indices[k + 2] = v + 2;
            indices[k + 3] = v;
            indices[k + 4] = v + 2;
            indices[k + 5] = v + 3;
        }
        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices;
        arrays[(int)Mesh.ArrayType.Index] = indices;
        var mesh = new ArrayMesh();
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays,
            flags: Mesh.ArrayFormat.FlagUse2DVertices);
        templates.Add(capacity, mesh);
        return mesh;
    }

    public void Dispose()
    {
        foreach (var mesh in templates.Values) mesh.Dispose();
        templates.Clear();
    }
}
