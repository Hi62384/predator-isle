using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class CaveFieldChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var original = GD.Load<GDScript>("res://scripts/caves/field.gd");
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        foreach (int style in Enumerable.Range(0, 8))
        foreach (float offset in new[] { 0f, 20000f, -20000f, 10000000f, -10000000f })
        foreach (bool cap in new[] { true, false })
        {
            using var old = original.New().AsGodotObject(); using var current = new CaveField { continuous_route_floors = cap };
            old.Set("continuous_route_floors", cap);
            var basis = new Vector3(offset, 20, -offset);
            var room = new D { ["id"] = "A", ["level"] = 1, ["point"] = basis + new Vector3(24, 0, 24), ["chamber_radius"] = 22.0, ["chamber_height"] = 34.0 };
            var edge = new D { ["from"] = "A", ["to"] = "B", ["points"] = new[] { basis, basis + new Vector3(12, -2.4f, 0), basis + new Vector3(24, 0, 0), basis + new Vector3(36, 2.4f, 4) }, ["half_width"] = 4.0, ["headroom"] = 8.0, ["entrance"] = false };
            var region = new D { ["valid"] = true, ["id"] = Vector2I.Zero, ["nodes"] = new A { room }, ["edges"] = new A { edge }, ["cross_section_style"] = style };
            var assignment = Assignment("crystal"); var surface = Callable.From<double, double, double>((x, z) => 200);
            require(old.Call("compile", new A { region }, surface, new A(), assignment).AsBool() && current.compile(new A { region }, surface, new A(), assignment), "Field compile failed");
            foreach (string name in new[] { "directions", "span_squared", "span_length", "arch_height", "arch_center", "arch_scale", "begins", "ends", "dimensions", "kinds", "styles", "endpoint_grades", "bins", "chunks", "_biome_fields" })
                require(Equal(old.Get(name), current.Get(name)), $"Compiled field {name} differs: style={style}, offset={offset}, cap={cap}");
            for (int i = 0; i < 360; i++)
            {
                var point = basis + new Vector3(i % 61 * .8125f - 4, i % 47 * .8125f - 3, i % 53 * .8125f - 4);
                double expected = old.Call("sample", point).AsDouble(), actual = current.sample(point);
                require(expected == actual, $"Scalar differs: style={style}, offset={offset}, cap={cap}, point={point}, old={expected:R}, new={actual:R}");
                require(old.Call("normal", point).AsVector3() == current.normal(point), $"Field normal differs: style={style}, offset={offset}, point={point}");
                var ids = new A { "crystal" };
                require(old.Call("biome_weights_at", point, ids).AsVector4() == current.biome_weights_at(point, ids), "Field material weights differ");
            }
            require(old.Call("numeric_bytes").AsInt64() == current.numeric_bytes(), "Field numeric count differs");
        }
        CheckReliefThermalAndPortal(require, Equal);
    }

    private static D Assignment(params string[] biomes)
    {
        var candidates = new A();
        foreach (string id in biomes) candidates.Add(new D { ["id"] = "A/" + id, ["biome_id"] = id, ["reach_m"] = 200.0, ["transition_m"] = 48.0, ["distances"] = new D { ["A"] = 0.0, ["B"] = 38.0 } });
        return new D { ["fallback"] = "default", ["candidates"] = candidates };
    }
    private static void CheckReliefThermalAndPortal(Action<bool, string> require, Func<Variant, Variant, bool> equal)
    {
        var source = GD.Load<GDScript>("res://scripts/caves/portal_field.gd");
        using var old = source.New().AsGodotObject(); using var current = new PortalCaveField();
        var height = Callable.From<double, double, double>((x, z) => 70 + .01 * x);
        var room = new D { ["id"] = "A", ["level"] = 0, ["point"] = new Vector3(32, 20, 32), ["chamber_radius"] = 22.0, ["chamber_height"] = 24.0 };
        var thermal = new D { ["point"] = new Vector3(32, 20, 32), ["radius"] = 24.0, ["height"] = 24.0, ["heat"] = .7 };
        var region = new D { ["valid"] = true, ["id"] = Vector2I.Zero, ["nodes"] = new A { room }, ["edges"] = new A(), ["cave_floor_relief"] = new D { ["crystal"] = .45 }, ["cave_thermal_sources"] = new A { thermal } };
        var assignment = Assignment("crystal", "frozen", "magma");
        require(old.Call("compile", new A { region }, height, new A(), assignment).AsBool() && current.compile(new A { region }, height, new A(), assignment), "Relief/thermal field compile failed");
        foreach (bool air in new[] { false, true })
        {
            old.Set("include_surface_air", air); current.include_surface_air = air;
            for (int i = 0; i < 600; i++)
            {
                var p = new Vector3(i % 63 * 1.125f - 5, i % 71 * 1.125f - 4, i % 61 * 1.125f - 5);
                require(old.Call("sample", p).AsDouble() == current.sample(p), "Relief/thermal portal scalar differs");
                require(old.Call("normal", p).AsVector3() == current.normal(p), "Relief/thermal portal normal differs");
                require(old.Call("heat_at", p).AsDouble() == current.heat_at(p), "Heat field differs");
                var ids = new A { "frozen", "crystal", "magma" };
                require(old.Call("biome_weights_at", p, ids).AsVector4() == current.biome_weights_at(p, ids), "Thermal material exclusion differs");
            }
        }
        var columns = new D { [Vector2I.Zero] = true, [new Vector2I(-1, 0)] = true };
        require(old.Call("measure_surface", columns).AsBool() == current.measure_surface(columns), "Portal column admission differs");
        require(equal(old.Get("surface_limits"), current.surface_limits), "Portal height limits differ");
        foreach (var key in new[] { Vector3I.Zero, new Vector3I(0, 1, 0), new Vector3I(-1, 1, 0), new Vector3I(1, 1, 0) })
            require(old.Call("has_chunk", key).AsBool() == current.has_chunk(key), "Portal chunk extent differs");
        foreach (var bounds in new[] { new Aabb(new Vector3(30, 20, 30), new Vector3(2, 2, 2)), new Aabb(new Vector3(-100, -100, -100), Vector3.One) })
            require(old.Call("hot_bounds", bounds).AsBool() == current.hot_bounds(bounds), "Thermal bounds exclusion differs");
    }
}
