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
        CheckRetention(owner, candidate, require);
    }

    private static void CheckRetention(Node owner, TerrainCollision collision, Action<bool, string> require)
    {
        const int resolution = 8;
        var arrays = Grid(resolution, .001f);
        var faces = new[] { new Vector3(0, 0, 0), new Vector3(2, 0, 0), new Vector3(0, 2, 0) };
        var structures = new A { Surface(faces) };
        var features = new D { ["openings"] = System.Array.Empty<Vector4>(), ["surfaces"] = new A { Surface(faces.Select(p => p + Vector3.Down * 3).ToArray()) } };
        var data = collision.prepare(arrays, resolution, true, structures, features, true);
        using var mesh = new ArrayMesh();mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);mesh.SetMeta("collision_data", data);
        var node = new MeshInstance3D { Mesh = mesh };owner.AddChild(node);node.SetMeta("resolution", resolution);
        collision.stage(node, 64, resolution, true, true, Vector3.Zero);
        var body = node.GetNode<StaticBody3D>("NearTerrainCollision");
        var ground = body.GetNode<CollisionShape3D>("Heightfield");
        var details = body.GetNode<CollisionShape3D>("Structures");
        var cavity = body.GetNode<CollisionShape3D>("Cavities");
        var initialGround = ground.Shape;var initialDetails = details.Shape;var initialCavity = cavity.Shape;
        require(initialGround is HeightMapShape3D && initialDetails is ConcavePolygonShape3D && initialCavity is ConcavePolygonShape3D,
            "Retention fixture did not create ground, structure and cavity collision");
        collision.stage(node, 64, resolution, true, false, Vector3.One);
        require(ReferenceEquals(initialGround, ground.Shape) && ReferenceEquals(initialDetails, details.Shape) && ReferenceEquals(initialCavity, cavity.Shape),
            "A same-source interest change rebuilt terrain or detail collision");
        collision.stage(node, 64, resolution, false, false, Vector3.Zero);collision.activate(node, true);
        require(ground.Disabled && details.Disabled && cavity.Disabled && ReferenceEquals(initialGround, ground.Shape) && ReferenceEquals(initialCavity, cavity.Shape),
            "Unneeded retained shapes were released or remained enabled for collision");
        collision.stage(node, 64, resolution, true, true, Vector3.Zero);
        require(!ground.Disabled && !details.Disabled && !cavity.Disabled && ReferenceEquals(initialGround, ground.Shape) && ReferenceEquals(initialCavity, cavity.Shape),
            "Reentering a resident chunk rebuilt retained collision or left it disabled");

        collision.refresh_structure_subset(node, new Vector3(300, 0, 0));
        require(!ReferenceEquals(initialDetails, details.Shape) && ReferenceEquals(initialGround, ground.Shape) && ReferenceEquals(initialCavity, cavity.Shape),
            "Structure interest movement rebuilt ground/cavities or failed to refresh its indexed subset");
        var shiftedDetails = details.Shape;
        collision.refresh_structure_subset(node, new Vector3(301, 0, 0));
        require(ReferenceEquals(shiftedDetails, details.Shape), "An unchanged structure cell regenerated collision");

        using var clipped = new ConcavePolygonShape3D { Data = faces };
        ground.Shape = clipped;ground.Transform = new Transform3D(Basis.Identity, new Vector3(1, 2, 3));
        var clippedTransform = ground.Transform;
        collision.stage(node, 64, resolution, false, true, new Vector3(300, 0, 0));
        collision.stage(node, 64, resolution, true, true, new Vector3(300, 0, 0));
        require(ReferenceEquals(clipped, ground.Shape) && ground.Transform == clippedTransform,
            "A same-source activation restored uncut ground over a cave opening");
        ground.Shape = null;
        collision.stage(node, 64, resolution, false, false);collision.stage(node, 64, resolution, true, true);
        require(ground.Shape is null, "An entirely clipped ground region was incorrectly regenerated from its original payload");

        collision.release(node);
        require(body.CollisionLayer == 0 && ground.Shape is null && details.Shape is null && cavity.Shape is null && ground.Disabled && details.Disabled && cavity.Disabled,
            "Chunk release retained physics resources or active shapes");
        collision.stage(node, 64, resolution, true, true);
        require(ground.Shape is HeightMapShape3D && !ReferenceEquals(initialGround, ground.Shape), "Reused pool node kept a released generation flag");

        using var replacement = new ArrayMesh();replacement.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);replacement.SetMeta("collision_data", data);
        var beforeReplacement = ground.Shape;node.Mesh = replacement;
        collision.stage(node, 64, resolution, true, true);
        require(!ReferenceEquals(beforeReplacement, ground.Shape), "A different mesh instance reused another source's collision");
        var beforeSpan = ground.Shape;collision.stage(node, 32, resolution, true, true);
        require(!ReferenceEquals(beforeSpan, ground.Shape) && ground.Position == new Vector3(16, 0, 16) && ground.Scale == new Vector3(4, 1, 4),
            "Changed chunk span reused stale collision spacing");
        var smallArrays = Grid(4, .001f);var smallData = collision.prepare(smallArrays, 4, true, structures, features, true);
        replacement.SetMeta("collision_data", smallData);var beforeResolution = ground.Shape;node.SetMeta("resolution", 4);
        collision.stage(node, 32, 4, true, true);
        require(!ReferenceEquals(beforeResolution, ground.Shape) && ground.Shape is HeightMapShape3D heightmap && heightmap.MapWidth == 5 && heightmap.MapDepth == 5,
            "Changed collision resolution reused a previous sample layout");

        // GPU-to-CPU rendering conversion copies exactly the same collision payload;
        // preserve an already clipped shape across that explicitly proven conversion.
        var patch = new TerrainRingLayout.Patch(Vector3I.Zero, 32, TerrainRingLayout.Mask.None);
        var source = new TerrainRingMeshGeometry.Data(patch, new TerrainRingTopology().Get(4, false, TerrainRingLayout.Mask.None), smallArrays,
            System.Array.Empty<byte>(), 0, 0, -1, System.Array.Empty<byte>(), 0);
        replacement.SetMeta("terrain_cpu_payload", new TerrainCpuSurfacePayload { Data = source });
        using var unrelated = new ArrayMesh();unrelated.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, smallArrays);
        unrelated.SetMeta("terrain_cpu_arrays", smallArrays);unrelated.SetMeta("collision_data", data);node.Mesh = unrelated;
        require(!TerrainCollision.RebindEquivalentMesh(node, replacement, unrelated), "Collision rebind accepted different numerical collision data");
        using var converted = new ArrayMesh();converted.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, smallArrays);
        converted.SetMeta("terrain_cpu_arrays", smallArrays);converted.SetMeta("collision_data", smallData);
        ground.Shape = clipped;ground.Transform = clippedTransform;node.Mesh = converted;
        require(TerrainCollision.RebindEquivalentMesh(node, replacement, converted), "Equivalent GPU carrier conversion rejected its copied collision payload");
        collision.stage(node, 32, 4, true, true);
        require(ReferenceEquals(clipped, ground.Shape) && ground.Transform == clippedTransform, "GPU carrier conversion restored uncut cave ground");
        require(!TerrainCollision.RebindEquivalentMesh(node, mesh, converted), "Collision rebind accepted an unrelated previous source");

        var thirdGrid = new TerrainRingTopology().Get(16, true, TerrainRingLayout.Mask.None);
        int thirdRow = thirdGrid.Axis.Length;var knots = thirdGrid.Axis.Span;var thirdVertices = new Vector3[thirdGrid.VertexCount];
        for (int z = 0; z < thirdRow; z++)for (int x = 0; x < thirdRow; x++)
            thirdVertices[z * thirdRow + x] = new Vector3(48f * knots[x] / thirdGrid.Denominator, 0, 48f * knots[z] / thirdGrid.Denominator);
        var thirdArrays = Surface(thirdVertices);thirdArrays[(int)Mesh.ArrayType.Index] = thirdGrid.Indices.ToArray();
        var thirdData = collision.prepare_irregular(thirdArrays, true, new A(), new D(), false);
        var thirdSource = new TerrainRingMeshGeometry.Data(new TerrainRingLayout.Patch(new Vector3I(0, 0, 1), 48, TerrainRingLayout.Mask.None),
            thirdGrid, thirdArrays, System.Array.Empty<byte>(), 0, 0, -1, System.Array.Empty<byte>(), 0);
        using var thirdCarrier = new ArrayMesh();thirdCarrier.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, thirdArrays);
        thirdCarrier.SetMeta("collision_data", thirdData);thirdCarrier.SetMeta("terrain_cpu_payload", new TerrainCpuSurfacePayload { Data = thirdSource });
        node.Mesh = thirdCarrier;node.SetMeta("resolution", thirdRow - 1);collision.stage(node, 48, thirdRow - 1, true);
        ground.Shape = clipped;ground.Transform = clippedTransform;
        using var thirdConverted = new ArrayMesh();thirdConverted.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, thirdArrays);
        thirdConverted.SetMeta("collision_data", thirdData);thirdConverted.SetMeta("terrain_cpu_arrays", thirdArrays);node.Mesh = thirdConverted;
        require(thirdRow - 1 != 16 && TerrainCollision.RebindEquivalentMesh(node, thirdCarrier, thirdConverted),
            "Inserted third-boundary knots were mistaken for a changed collision resolution");
        collision.stage(node, 48, thirdRow - 1, true);
        require(ReferenceEquals(clipped, ground.Shape) && ground.Transform == clippedTransform, "Third-knot carrier conversion rebuilt clipped collision");
        collision.release(node);node.Free();
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
