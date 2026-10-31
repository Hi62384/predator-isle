using Godot;
using System;
using D = Godot.Collections.Dictionary;
using A = Godot.Collections.Array<string>;

namespace PredatorIsle.Caves;

[Tool]
public partial class CaveBiomeDefinition : Resource
{
    [Export] public StringName biome_id { get; set; } = "default";
    [Export] public string display_name { get; set; } = "Default Cave";
    [Export] public bool enabled { get; set; } = true;
    [Export(PropertyHint.Range, "0,100,0.1")] public double spawn_chance_percent { get; set; } = 100;
    [Export(PropertyHint.Range, "50,2048,1")] public double minimum_extent_metres { get; set; } = 200;
    [Export(PropertyHint.Range, "50,2048,1")] public double maximum_extent_metres { get; set; } = 1200;
    [Export] public float[] depth_preferences { get; set; } = { 100, 85, 65, 40, 15 };
    [Export] public bool exclude_zero_depth_bands { get; set; }
    [Export] public D surface_preferences { get; set; } = new();
    [Export] public D geological_preferences { get; set; } = new();
    [Export(PropertyHint.Range, "1,128,1")] public double transition_metres { get; set; } = 32;
    [Export(PropertyHint.Range, "-8,8,1")] public int selection_priority { get; set; }
    [Export] public bool independent_suitability_admission { get; set; }
    [Export] public D material_configuration { get; set; } = new() { ["palette"] = "default_geology" };
    [Export] public D geometry_variation { get; set; } = new();
    [Export] public D feature_configuration { get; set; } = new();
    [Export] public Script? surface_provider { get; set; }
    [Export] public Script? feature_provider { get; set; }
    [Export] public Color debug_color { get; set; } = new(.55f, .42f, .27f);
    [Export] public StringName temperature_channel { get; set; } = "";
    [Export] public StringName moisture_channel { get; set; } = "";

    public A validation_errors()
    {
        var errors = new A();
        if (biome_id.IsEmpty || display_name.Length == 0) errors.Add("Cave biome requires a stable ID and display name");
        foreach (double value in new[] { spawn_chance_percent, minimum_extent_metres, maximum_extent_metres, transition_metres })
            if (!double.IsFinite(value)) { errors.Add("Cave biome controls must be finite"); return errors; }
        if (spawn_chance_percent < 0 || spawn_chance_percent > 100) errors.Add("Spawn chance must be0–100percent");
        if (minimum_extent_metres < 50 || maximum_extent_metres < minimum_extent_metres || maximum_extent_metres > 2048)
            errors.Add("Biome extent must be ordered within50–2048m bounded canonical discovery");
        if (transition_metres < 1 || transition_metres > 128 || transition_metres > minimum_extent_metres * .5)
            errors.Add("Transition must fit within half the smallest region");
        if (depth_preferences.Length != 5) errors.Add("Exactly five depth preferences are required");
        foreach (float value in depth_preferences)
            if (!float.IsFinite(value) || value < 0 || value > 100) errors.Add("Depth preferences must be finite0–100");
        foreach (D preferences in new[] { surface_preferences, geological_preferences })
        foreach (Variant value in preferences.Values)
            if ((value.VariantType != Variant.Type.Float && value.VariantType != Variant.Type.Int) || !double.IsFinite(value.AsDouble()) || value.AsDouble() < 0 || value.AsDouble() > 100)
                errors.Add("Suitability preferences must be finite0–100");
        foreach (Variant key in surface_preferences.Keys)
            if (key.VariantType != Variant.Type.String && key.VariantType != Variant.Type.StringName)
                errors.Add("Surface preferences use stable biome names,not numeric owner indices");
        if (selection_priority < -8 || selection_priority > 8) errors.Add("Selection priority must be within-8–8");
        foreach (var provider in new[] { surface_provider, feature_provider })
            if (provider != null && (!provider.CanInstantiate() || provider.GetInstanceBaseType() != "RefCounted"))
            { errors.Add("Cave providers must instantiate numeric RefCounted adapters,not scene nodes"); return errors; }
        if (surface_provider != null)
        {
            bool source = HasMethod(surface_provider, "source"), bind = HasMethod(surface_provider, "bind");
            if (!source || !bind) errors.Add("Cave surface provider requires source and bind methods");
            else if (HasMethod(surface_provider, "validation_errors"))
            {
                using var instance = surface_provider.Call("new").AsGodotObject();
                foreach (Variant error in instance.Call("validation_errors", material_configuration, feature_configuration).AsGodotArray()) errors.Add(error.AsString());
            }
        }
        if (feature_provider != null && !HasMethod(feature_provider, "build")) errors.Add("Cave numeric feature provider requires build method");
        return errors;
    }
    private static bool HasMethod(Script script, string name)
    {
        foreach (var method in script.GetScriptMethodList()) if (method["name"].AsString() == name) return true;
        return false;
    }
    public double preference(D preferences, D mix)
    {
        if (preferences.Count == 0) return 1;
        double maximum = 0;
        foreach (Variant value in preferences.Values) maximum = Math.Max(maximum, value.AsDouble());
        if (maximum <= 0) return 0;
        double result = 0, total = 0;
        foreach (var pair in mix)
        {
            double weight = Math.Max(0, pair.Value.AsDouble());
            Variant value = preferences.ContainsKey(pair.Key) ? preferences[pair.Key] : preferences.ContainsKey(pair.Key.ToString()) ? preferences[pair.Key.ToString()] : 0;
            result += weight * value.AsDouble() / maximum; total += weight;
        }
        return total > 0 ? Math.Clamp(result / total, 0, 1) : 0;
    }
    public double depth_preference(double depth, float[] bands)
    {
        if (depth_preferences.Length != 5 || bands.Length != 6 || !double.IsFinite(depth)) return 0;
        double maximum = 0; foreach (float value in depth_preferences) maximum = Math.Max(maximum, value);
        if (maximum <= 0) return 0;
        Span<float> anchors = stackalloc float[5];
        for (int i = 0; i < 5; i++) anchors[i] = (float)(((double)bands[i] + bands[i + 1]) * .5);
        if (depth <= anchors[0]) return depth_preferences[0] / maximum;
        for (int i = 0; i < 4; i++)
        {
            if (depth > anchors[i + 1]) continue;
            double lower = anchors[i], upper = anchors[i + 1];
            if (exclude_zero_depth_bands)
            {
                if (depth_preferences[i] <= 0) lower = bands[i + 1];
                if (depth_preferences[i + 1] <= 0) upper = bands[i + 1];
                if (depth <= lower && depth_preferences[i] <= 0 || depth >= upper && depth_preferences[i + 1] <= 0 || upper <= lower) return 0;
            }
            double t = Math.Clamp((depth - lower) / (upper - lower), 0, 1); t = t * t * (3 - 2 * t);
            return (depth_preferences[i] + (depth_preferences[i + 1] - (double)depth_preferences[i]) * t) / maximum;
        }
        return depth_preferences[4] / maximum;
    }
}
