using Godot;
using PredatorIsle.Rendering;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Main-thread materialization of immutable replacement surface payloads.</summary>
public partial class CaveSurfaceRenderer : RefCounted
{
    private readonly CaveSurfaceShader _surfaceShader = new(); private readonly CaveWaterRenderer _water = new(); private readonly CaveStreamFrontiers _frontiers = new(); private readonly CaveMaterialPalette _palette = new();
    private readonly Dictionary<string, Shader> _shaders = new(); private readonly Queue<string> _shaderRing = new();
    private readonly CaveBiomeMaterials _biomes = new(); private readonly CaveFeatureRenderer _features = new();
    private static Shader? _grassAndCoastShader;
    private static Variant Get(D d, string key, Variant fallback = default) => d.ContainsKey(key) ? d[key] : fallback;
    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    public bool touches(MeshInstance3D node, D columns)
    {
        if (!GodotObject.IsInstanceValid(node) || node.Mesh == null) return false;
        if(node.HasMeta("terrain_owned_regions"))
        {
            foreach(var value in node.GetMeta("terrain_owned_regions").AsGodotArray())
            {
                var owned=value.AsRect2();owned.Position+=new Vector2(node.GlobalPosition.X,node.GlobalPosition.Z);
                foreach(var key in columns.Keys)if(owned.Intersects(new Rect2((Vector2)key.AsVector2I()*64,Vector2.One*64)))return true;
            }
            return false;
        }
        var aabb = node.GetAabb(); var bounds = new Rect2(new Vector2(node.GlobalPosition.X + aabb.Position.X, node.GlobalPosition.Z + aabb.Position.Z), new Vector2(aabb.Size.X, aabb.Size.Z));
        foreach (var key in columns.Keys) if (bounds.Intersects(new Rect2((Vector2)key.AsVector2I() * 64, Vector2.One * 64))) return true; return false;
    }
    public bool matches(D snapshot, A nodes, D columns)
    {
        var seen = new HashSet<string>(); var sources = snapshot["sources"].AsGodotDictionary();
        foreach (var value in nodes)
        {
            var node = value.As<MeshInstance3D>(); if (!touches(node, columns)) continue;
            string id = node.GetMeta("tile", Vector3I.Zero).AsVector3I().ToString(); if (!sources.ContainsKey(id)) return false;
            var source = sources[id].AsGodotDictionary();
            if (source["node"].AsGodotObject() != node || source["mesh"].As<Mesh>() != node.Mesh || source["origin"].AsVector3() != node.GlobalPosition || !node.GlobalBasis.IsEqualApprox(Basis.Identity)) return false;
            seen.Add(id);
        }
        return seen.Count == sources.Count;
    }
    public D capture(A nodes, D columns)
    {
        var records = new A(); var sources = new D();
        foreach (var value in nodes)
        {
            var node = value.As<MeshInstance3D>(); if (!touches(node, columns)) continue;
            PredatorIsle.Terrain.TerrainGpuGrids.EnsureCpuSurface(node);
            if (!node.GlobalBasis.IsEqualApprox(Basis.Identity)) return Reject("Unsupported rotated/scaled terrain parent");
            int resolution = node.GetMeta("resolution", 0).AsInt32(); var key = node.GetMeta("tile", Vector3I.Zero).AsVector3I(); float span = node.Mesh.GetAabb().Size.X;
            bool ringGround = node.Mesh.GetMeta("terrain_canonical_surface",false).AsBool();
            if (resolution < 1 || (ringGround ? span / resolution > 9 : key.Z != 0 || span / (double)resolution > 2.00001)) return Reject($"Portal awaits fine terrain parent at {key} ({span} m, {resolution} subdivisions)");
            var arrays = node.Mesh.HasMeta("terrain_cpu_arrays") ? node.Mesh.GetMeta("terrain_cpu_arrays").AsGodotArray() : ((ArrayMesh)node.Mesh).SurfaceGetArrays(0);
            var material = node.Mesh.SurfaceGetMaterial(0); if (arrays.Count == 0 || material is not ShaderMaterial shaderMaterial) return Reject("Missing original surface payload/material");
            string id = key.ToString(); var ground = Get(node.Mesh.GetMeta("collision_data", new D()).AsGodotDictionary(), "ground_faces", System.Array.Empty<Vector3>());
            var record=new D { ["id"] = id, ["origin"] = node.GlobalPosition, ["span"] = span, ["resolution"] = resolution, ["arrays"] = arrays, ["extension_normalization"] = shaderMaterial.GetShaderParameter("extension_payload_enabled").AsBool(), ["ground_faces"] = ground };
            if(node.Mesh.GetMeta("terrain_canonical_surface",false).AsBool())record["canonical_surface"]=true;
            records.Add(record);
            sources[id] = new D { ["node"] = node, ["mesh"] = node.Mesh, ["material"] = material, ["origin"] = node.GlobalPosition, ["span"] = span };
        }
        if (records.Count == 0) return Reject("No parent coverage for portal");
        foreach (var key in columns.Keys) foreach (var fraction in new[] { new Vector2(.001f, .001f), new Vector2(.999f, .001f), new Vector2(.001f, .999f), new Vector2(.999f, .999f) })
        {
            var point = ((Vector2)key.AsVector2I() + fraction) * 64; bool covered = false;
            foreach (var value in records) { var record = value.AsGodotDictionary(); var origin = record["origin"].AsVector3(); if (new Rect2(new Vector2(origin.X, origin.Z), Vector2.One * (float)record["span"].AsDouble()).HasPoint(point)) { covered = true; break; } }
            if (!covered) return Reject("Incomplete fine parent coverage");
        }
        return new D { ["valid"] = true, ["records"] = records, ["sources"] = sources };
    }
    private static D Reject(string reason) => new() { ["valid"] = false, ["reason"] = reason };
    public Shader? shader(Shader original) => shader(original, false, true);
    public Shader? shader(Shader original, bool hive_entry) => shader(original, hive_entry, true);
    public Shader? shader(Shader original, bool hive_entry, bool common_projection)
    {
        string digest = Hash(original.Code) + (hive_entry ? "/hive/" + Hash(_surfaceShader.Extensions.Code) : "") + (common_projection ? "/shared_projection" : "");
        if (_shaders.TryGetValue(digest, out var cached)) return cached;
        string code = _surfaceShader.CompactCode(original.Code, true, true, hive_entry, common_projection); if (code.Length == 0) return null;
        var result = new Shader { Code = code }; var names = new HashSet<string>(); foreach (var uniform in result.GetShaderUniformList()) names.Add(uniform.AsGodotDictionary()["name"].AsString());
        if (!names.Contains("cave_surface_payload") || !names.Contains(hive_entry ? "cave_hive_entry_material" : "cave_entry_colors") || !names.Contains("cave_parent_origin")) return null;
        if (_shaderRing.Count >= 8) _shaders.Remove(_shaderRing.Dequeue()); _shaderRing.Enqueue(digest); _shaders[digest] = result; return result;
    }

    private static Shader EntranceTerrainShader(ShaderMaterial parent, D atlas, byte[] bytes, bool hive)
    {
        var original = CaveSurfaceShader.OriginalTerrain(parent.Shader);
        const string terrainPath = "res://shaders/terrain_biomes.gdshader";
        if (hive || parent.GetShaderParameter("extension_payload_enabled").AsBool() ||
            !(original.ResourcePath == terrainPath || original.Code.StartsWith("// CONFIGURED_TERRAIN_OWNERS_", StringComparison.Ordinal)) ||
            !CaveSurfacePayload.UsesOnlyGrassAndCoast(atlas, bytes))
            return original;
        if (_grassAndCoastShader != null) return _grassAndCoastShader;
        var baseShader = GD.Load<Shader>(terrainPath);
        using var variants = new TerrainShaderVariants();
        string source = variants.source_for(baseShader.Code, 1 << 7);
        if (source == baseShader.Code) return original;
        // These entrance atlases have no texture-based biome extensions.
        // Removing unreachable material branches also reduces the driver's
        // first-draw compile cost on OpenGL.
        source = source.Replace("uniform bool extension_payload_enabled=false;",
            "const bool extension_payload_enabled=false;", StringComparison.Ordinal);
        return _grassAndCoastShader = new Shader { Code = source };
    }

    public void release_uploaded_data(D data) { foreach (string field in new[] { "groups", "collision_faces", "water", "frontiers", "features", "biome_ids" }) data.Remove(field); }
    public D node(D data, D sources, ShaderMaterial interior, int style) => node(data, sources, interior, style, true, true);
    public D node(D data, D sources, ShaderMaterial interior, int style, bool shadows) => node(data, sources, interior, style, shadows, true);
    public D node(D data, D sources, ShaderMaterial interior, int style, bool shadows, bool specialize_insect)
    {
        if (!Get(data, "valid", false).AsBool()) return Reject(Get(data, "reason", "Invalid surface result").AsString());
        var mesh = new ArrayMesh(); var origin = (Vector3)data["key"].AsVector3I() * 64; bool common = interior.GetMeta("cave_common_projection", true).AsBool();
        foreach (var entry in data["groups"].AsGodotDictionary())
        {
            string id = entry.Key.AsString(); var group = entry.Value.AsGodotDictionary(); var material = interior;
            if (id != "__interior__")
            {
                if (!sources.ContainsKey(id)) return Reject("Original parent material unavailable"); var parent = sources[id].AsGodotDictionary(); material = (ShaderMaterial)parent["material"].As<ShaderMaterial>().Duplicate();
                var atlas = group["atlas"].AsGodotDictionary();
                var atlasBytes = atlas["bytes"].AsByteArray();
                var ids = interior.GetMeta("biome_ids", new A()).AsGodotArray(); var registry = interior.HasMeta("biome_registry") ? interior.GetMeta("biome_registry").As<Resource>() : null;
                if (style != 7 && ids.Count == 0 && CaveSurfaceShader.IsSharedTerrain(material.Shader))
                {
                    material.SetShaderParameter("cave_surface_enabled", true);
                    material.SetShaderParameter("cave_common_projection", common);
                    material.SetShaderParameter("terrain_grid_enabled", false);
                    material.SetShaderParameter("cave_cut_enabled", false);
                    material.SetShaderParameter("flight_cell_size", 0.0);
                }
                else
                {
                    var alternate = shader(EntranceTerrainShader(material, atlas, atlasBytes, style == 7), style == 7, common);
                    if (alternate == null) return Reject("Surface material compilation rejected");
                    alternate = _biomes.shader(alternate, ids, registry, true);
                    if (alternate == null) return Reject("Cave biome surface adapter rejected");
                    material.Shader = alternate;
                }
                material.SetShaderParameter("cave_parent_offset", origin - parent["origin"].AsVector3()); material.SetShaderParameter("cave_parent_origin", parent["origin"]);
                if (ids.Count > 0) _biomes.bind(material, ids, registry, interior.GetMeta("biome_context", new D()).AsGodotDictionary());
                if (style == 7)
                { material.SetShaderParameter("biological_colors", GD.Load<Resource>("res://materials/biological_colors_v3.tres")); material.SetShaderParameter("cave_hive_entry_material", true); material.SetShaderParameter("alien_tissue_variation_enabled", interior.GetShaderParameter("alien_tissue_variation_enabled")); }
                else
                { var bank = _palette.paths(style, specialize_insect); material.SetShaderParameter("cave_entry_geology", style); material.SetShaderParameter("cave_entry_colors", GD.Load<Resource>(bank["colors"].AsString())); material.SetShaderParameter("cave_entry_normals", GD.Load<Resource>(bank["normals"].AsString())); material.SetShaderParameter("cave_entry_compact_palette", bank["compact"]); }
                material.SetShaderParameter("cave_surface_payload", ImageTexture.CreateFromImage(
                    Image.CreateFromData(atlas["width"].AsInt32(), atlas["height"].AsInt32(), false, Image.Format.Rgbaf, atlasBytes)));
                material.SetShaderParameter("cave_surface_texel_mask", Get(atlas, "texel_mask", (1 << CaveSurfacePayload.Texels) - 1));
                material.SetShaderParameter("cave_surface_texels", Get(atlas, "texels_per_vertex", CaveSurfacePayload.Texels));
            }
            mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, group["arrays"].AsGodotArray()); mesh.SurfaceSetMaterial(mesh.GetSurfaceCount() - 1, material);
        }
        if (mesh.GetSurfaceCount() == 0 && Get(data, "frontiers", new D()).AsGodotDictionary().Count == 0 && Get(data, "features", new A()).AsGodotArray().Count == 0) return new D { ["valid"] = true, ["node"] = default(Variant) };
        var result = new MeshInstance3D { Mesh = mesh, Position = origin, Visible = false, CastShadow = shadows ? GeometryInstance3D.ShadowCastingSetting.DoubleSided : GeometryInstance3D.ShadowCastingSetting.Off }; result.SetMeta("cave_cell", data["key"]);
        var body = new StaticBody3D { Name = "CaveCollision", CollisionLayer = 0, CollisionMask = 0 }; var faces = data["collision_faces"].AsVector3Array();
        if (faces.Length > 0) body.AddChild(new CollisionShape3D { Shape = new ConcavePolygonShape3D { BackfaceCollision = true, Data = faces } }); result.AddChild(body);
        if (!_features.attach(result, Get(data, "features", new A()).AsGodotArray(), interior.HasMeta("biome_registry") ? interior.GetMeta("biome_registry").As<Resource>() : null, common, shadows)) { result.Free(); return Reject("Cave biome feature material rejected"); }
        _water.attach(result, Get(data, "water", new D()).AsGodotDictionary(), common); _frontiers.attach(result, Get(data, "frontiers", new D()).AsGodotDictionary(), interior, shadows);
        return new D { ["valid"] = true, ["node"] = result };
    }
}

