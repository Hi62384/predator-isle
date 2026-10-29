using Godot;
using System;
using System.Linq;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class CollisionChecks
{
    internal static void Run(Node owner, Action<bool, string> require)
    {
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        var referenceIndex = GD.Load<GDScript>("res://scripts/structure_collision_index.gd");
        using var index = new StructureCollisionIndex();
        var faces = new Vector3[192 * 20 + 3];
        for (int i = 0; i < faces.Length; i++)
        {
            int block = i / 192; faces[i] = new Vector3(block * 1200 - 12000 + i % 3, block % 3 * 1200 + i % 2, block % 4 * 1100 - 2200 + i % 7);
        }
        var expectedIndex = referenceIndex.Call("build", faces).AsGodotDictionary(); var actualIndex = index.build(faces);
        require(Equal(expectedIndex, actualIndex), "Structure index metadata differs");
        require(referenceIndex.Call("numeric_bytes", expectedIndex).AsInt64() == index.numeric_bytes(actualIndex), "Index numeric size differs");
        foreach (var p in new[] { Vector3.Zero, new Vector3(-256, 500, -1000), new Vector3(-12000, 0, 0), new Vector3(17000, 2500, 3000), Vector3.Inf })
            require(Equal(referenceIndex.Call("select", faces, expectedIndex, p), index.select(faces, actualIndex, p)), $"Indexed faces differ at {p}");
        foreach (var broken in new[] { new D(), new D { ["version"] = 1, ["faces_count"] = faces.Length } })
            require(Equal(referenceIndex.Call("select", faces, broken, Vector3.Zero), index.select(faces, broken, Vector3.Zero)), "Malformed index fallback differs");
        var invalidBlock = actualIndex.Duplicate(true); invalidBlock["overflow"] = new[] { -1 };
        require(Equal(referenceIndex.Call("select", faces, invalidBlock, Vector3.Zero), index.select(faces, invalidBlock, Vector3.Zero)), "Invalid block fallback differs");
        var huge = new[] { new Vector3(-100000, 0, -100000), new Vector3(100000, 0, 100000), new Vector3(0, 1, 0) };
        require(Equal(referenceIndex.Call("build", huge), index.build(huge)), "Overflow block indexing differs");
        require(index.build(new[] { Vector3.Inf, Vector3.Zero, Vector3.One }).Count == 0, "Nonfinite index accepted");

        var reference = GD.Load<GDScript>("res://scripts/terrain_collision.gd"); using var candidate = new TerrainCollision();
        const int resolution = 8;
        foreach (float slope in new[] { 0f, .001f, 1f, 50f })
        {
            var arrays = Grid(resolution, slope);
            var structures = new A { Surface(new Vector3[] { new(0, 0, 0), new(2, 0, 0), new(0, 2, 0) }), new A() };
            foreach (bool opening in new[] { false, true })
            foreach (bool enabled in new[] { false, true })
            {
                var features = new D { ["openings"] = opening ? new[] { new Vector4(28, 25, 12, .7f), new Vector4(40, 38, 9, .2f) } : System.Array.Empty<Vector4>(),
                    ["surfaces"] = new A { Surface(new[] { new Vector3(0, -3, 0), new Vector3(2, -3, 0), new Vector3(0, -2, 0) }) } };
                var expected = reference.Call("prepare", arrays, resolution, enabled, structures, features, true).AsGodotDictionary();
                var actual = candidate.prepare(arrays, resolution, enabled, structures, features, true);
                require(Equal(expected, actual), $"Collision payload differs: slope={slope}, opening={opening}, enabled={enabled}");
                using var oldMesh = new ArrayMesh(); oldMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays); oldMesh.SetMeta("collision_data", expected);
                using var newMesh = new ArrayMesh(); newMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays); newMesh.SetMeta("collision_data", actual);
                var oldNode = new MeshInstance3D { Mesh = oldMesh }; var newNode = new MeshInstance3D { Mesh = newMesh };
                owner.AddChild(oldNode); owner.AddChild(newNode);
                reference.Call("stage", oldNode, 64.0, resolution, enabled, true, Vector3.Zero);
                candidate.stage(newNode, 64, resolution, enabled, true, Vector3.Zero);
                foreach (string name in new[] { "Heightfield", "Structures", "Cavities" })
                {
                    var left = oldNode.GetNode<CollisionShape3D>("NearTerrainCollision/" + name); var right = newNode.GetNode<CollisionShape3D>("NearTerrainCollision/" + name);
                    require(left.Position == right.Position && left.Scale == right.Scale, "Collision transform differs");
                    require(left.Shape?.GetClass() == right.Shape?.GetClass(), "Physics shape type differs");
                    if (left.Shape is ConcavePolygonShape3D lc && right.Shape is ConcavePolygonShape3D rc)
                        require(Equal(lc.GetFaces(), rc.GetFaces()) && lc.BackfaceCollision == rc.BackfaceCollision, "Concave physics faces differ");
                    if (left.Shape is HeightMapShape3D lh && right.Shape is HeightMapShape3D rh)
                        require(lh.MapWidth == rh.MapWidth && lh.MapDepth == rh.MapDepth && Equal(lh.MapData, rh.MapData), "Heightfield differs");
                }
                candidate.activate(newNode, true); require(newNode.GetNode<StaticBody3D>("NearTerrainCollision").CollisionLayer == 1, "Collision activation failed");
                candidate.release(newNode); require(newNode.GetNode<StaticBody3D>("NearTerrainCollision").CollisionLayer == 0 && newNode.GetNode<CollisionShape3D>("NearTerrainCollision/Structures").Shape == null, "Collision release failed");
                oldNode.Free(); newNode.Free();
            }
        }
    }

    private static A Surface(Vector3[] vertices)
    {
        var result = new A(); result.Resize((int)Mesh.ArrayType.Max); result[(int)Mesh.ArrayType.Vertex] = vertices; return result;
    }
    private static A Grid(int resolution, float slope)
    {
        int row = resolution + 1; var vertices = new Vector3[row * row]; var indices = new int[resolution * resolution * 6];
        for (int z = 0; z < row; z++)
        for (int x = 0; x < row; x++) vertices[x + z * row] = new Vector3(x * 8, x * slope, z * 8);
        int cursor = 0;
        for (int z = 0; z < resolution; z++)
        for (int x = 0; x < resolution; x++)
        {
            int a = x + z * row;
            foreach (int i in new[] { a, a + row, a + 1, a + 1, a + row, a + row + 1 }) indices[cursor++] = i;
        }
        var result = Surface(vertices); result[(int)Mesh.ArrayType.Index] = indices; return result;
    }
}
