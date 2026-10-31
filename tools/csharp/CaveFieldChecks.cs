using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class CaveFieldChecks
{
    internal static D Measurements { get; private set; } = new();
    internal static void Run(Action<bool, string> require)
    {
        CheckGraphBlending(require);
        var original = GD.Load<GDScript>("res://scripts/caves/field.gd");
        double maximumScalarError = 0; int scalarRoundingDifferences = 0;
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
                if (expected != actual) scalarRoundingDifferences++;
                maximumScalarError = Math.Max(maximumScalarError, Math.Abs(expected - actual));
                // Different native math libraries can round a double sine by one ULP.
                // Require identical extraction samples, signs, and a sub-picometre scalar bound.
                require((float)expected == (float)actual && (expected < 0) == (actual < 0) && Math.Abs(expected - actual) <= 1e-12,
                    $"Scalar differs beyond extraction precision: style={style}, offset={offset}, cap={cap}, point={point}, old={expected:R}, new={actual:R}");
                require(old.Call("normal", point).AsVector3() == current.normal(point), $"Field normal differs: style={style}, offset={offset}, point={point}");
                var ids = new A { "crystal" };
                require(old.Call("biome_weights_at", point, ids).AsVector4() == current.biome_weights_at(point, ids), "Field material weights differ");
            }
            require(old.Call("numeric_bytes").AsInt64() == current.numeric_bytes(), "Field numeric count differs");
            if (offset == 0 && cap && style is 0 or 3 or 7)
            {
                using var oldMesher = GD.Load<GDScript>("res://scripts/caves/mesher.gd").New().AsGodotObject(); using var newMesher = new CaveMesher();
                var expected = oldMesher.Call("build", old, Vector3I.Zero, 2.0); var actual = newMesher.build(current, Vector3I.Zero, 2);
                require(Equal(expected, actual), $"Whole field mesh differs: style={style}");
            }
        }
        GD.Print($"Field scalar diagnostic: {scalarRoundingDifferences} double rounding differences; maximum absolute error {maximumScalarError:R} m. Float32 extraction samples and signs must match.");
        CheckReliefThermalAndPortal(require, Equal);
        using var bridge = new CaveField();
        var callable = Callable.From<double, double, double>((x, z) => 200);
        require(bridge.Call("compile", new A(), callable).AsBool(), "Default arguments unavailable through the field bridge");
        require(!bridge.append_feature(Vector3.Zero, Vector3.Zero, new Vector2(5000, 5000), 2), "Oversized primitive bypassed field limits");
        require(!bridge.append_thermal_source(new D { ["point"] = Vector3.Inf, ["radius"] = 20.0, ["height"] = 20.0, ["heat"] = .5 }), "Invalid heat source accepted");
        Measurements = new D { ["geometric_cases"] = 80, ["scalar_normal_weight_probe_sets"] = 28800, ["whole_mesh_cases"] = 3,
            ["double_rounding_differences"] = scalarRoundingDifferences, ["maximum_scalar_error_m"] = maximumScalarError,
            ["scalar_acceptance"] = "At most 1e-12m absolute error, identical Float32 extraction samples and identical signs. Normals/weights and three complete mesh payloads required exact equality. Not exact Float64 equality across math libraries." };
    }

    private static void CheckGraphBlending(Action<bool, string> require)
    {
        var original = GD.Load<GDScript>("res://scripts/caves/biome_regions.gd");
        foreach (double transition in new[] { 0.0, .001, 10.0, 100.0 })
        foreach (double length in new[] { -1.0, 0.0, 20.0, 200.0, double.PositiveInfinity })
        {
            var assignment = new D { ["fallback"] = "default", ["candidates"] = new A() };
            var candidates = assignment["candidates"].AsGodotArray();
            for (int i = 0; i < 8; i++) candidates.Add(new D {
                ["id"] = "anchor/" + (7 - i), ["biome_id"] = i % 2 == 0 ? "crystal" : "frozen",
                ["reach_m"] = 100.0, ["transition_m"] = transition,
                ["distances"] = new D { ["A"] = i * 3.0, ["B"] = (7 - i) * 4.0 } });
            foreach (double station in new[] { -1.0, 0.0, .00001, 10.0, 90.0, 99.99999, 100.0, 101.0, 200.0, double.NaN })
            {
                var expected = original.Call("along_edge", assignment, "A", "B", station, length);
                var actual = CaveBiomeSelection.AlongEdge(assignment, "A", "B", station, length);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),
                    $"Graph blend differs: transition={transition}, length={length}, station={station}");
            }
        }
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
