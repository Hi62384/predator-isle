using Godot;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveWaterRenderer : RefCounted
{
    private readonly Dictionary<bool, ShaderMaterial> _materials = new();
    public ShaderMaterial material() => material(true);
    public ShaderMaterial material(bool common_projection)
    {
        if (_materials.TryGetValue(common_projection, out var cached)) return cached;
        string source = FileAccess.GetFileAsString("res://shaders/swamp_water.gdshader");
        source = source.Replace(" SPECULAR=.4;", " SPECULAR=.4;\n AO=.08;AO_LIGHT_AFFECT=0.0;", System.StringComparison.Ordinal);
        source = source.Replace(" NORMAL_MAP=vec3(.5+r.x,.5+r.y,1);", " r+=vec2(cos(UV2.x),sin(UV2.x))*sin(UV.y*.8-TIME*.8)*swamp_ripple*COLOR.a;\n NORMAL_MAP=vec3(.5+r.x,.5+r.y,1);", System.StringComparison.Ordinal);
        if (common_projection) source = CaveVertexProjection.Source(source);
        var result = new ShaderMaterial { Shader = new Shader { Code = source } };
        result.SetShaderParameter("swamp_water_opacity", .72); result.SetShaderParameter("swamp_ripple", .004); result.SetShaderParameter("swamp_flood_stage", 0.0);
        _materials[common_projection] = result; return result;
    }
    public MeshInstance3D? attach(Node3D parent, D data) => attach(parent, data, true);
    public MeshInstance3D? attach(Node3D parent, D data, bool common_projection)
    {
        var arrays = data.ContainsKey("arrays") ? data["arrays"].AsGodotArray() : new A(); if (arrays.Count == 0) return null;
        var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays); mesh.SurfaceSetMaterial(0, material(common_projection));
        var node = new MeshInstance3D { Name = "CaveSeepageWater", Mesh = mesh, CastShadow = GeometryInstance3D.ShadowCastingSetting.Off };
        node.SetMeta("pool_ids", data.ContainsKey("ids") ? data["ids"] : new A()); parent.AddChild(node); return node;
    }
}
