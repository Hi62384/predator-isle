using Godot;
using System;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Rendering;

[Tool, GlobalClass]
public partial class CliffNormalSettings : Resource
{
    [Export] public bool enabled { get; set; } = true;
    [Export] public Godot.Collections.Array<CliffNormalLayer> layers { get; set; } = new();
    [ExportGroup("Global Strength")]
    [Export(PropertyHint.Range, "0,4,0.01")] public double macro_strength { get; set; } = 1.2;
    [Export(PropertyHint.Range, "0,4,0.01")] public double medium_strength { get; set; } = .75;
    [Export(PropertyHint.Range, "0,3,0.01")] public double base_normal_strength { get; set; } = 1;
    [ExportGroup("Overlap and Distance")]
    [Export(PropertyHint.Range, "0,2,1")] public int max_macro_layers { get; set; } = 2;
    [Export(PropertyHint.Range, "0,2,1")] public int max_medium_layers { get; set; } = 2;
    [Export(PropertyHint.Range, "0.005,0.3,0.005")] public double selection_blend_width { get; set; } = .065;
    [Export] public double macro_fade_start { get; set; } = 1800;
    [Export] public double macro_fade_end { get; set; } = 4500;
    [Export] public double medium_fade_start { get; set; } = 200;
    [Export] public double medium_fade_end { get; set; } = 850;
    [ExportGroup("Debug")]
    [Export(PropertyHint.Enum, "Combined,Base only / overlays off,Macro only,Medium only,Coverage,Texture IDs,World normals")] public int debug_mode { get; set; }
    [Export(PropertyHint.Range, "-1,15,1")] public int isolate_layer { get; set; } = -1;
    public D uniforms()
    {
        var parameters = new Vector4[16]; var masks = new Vector4[16]; var transforms = new Vector4[16]; var extras = new Vector4[16];
        for (int i = 0; i < 16; i++)
        {
            var layer = i < layers.Count ? layers[i] : null;
            if (layer is null) { parameters[i] = new Vector4(0, 72, 0, 0); masks[i] = new Vector4(95, .28f, .18f, .45f); extras[i] = new Vector4(2.31f, 0, 0, 0); continue; }
            parameters[i] = new Vector4((float)layer.strength, (float)Math.Max(layer.texture_size_metres, .5), layer.band, layer.enabled && layer.normal_texture is not null ? 1 : 0);
            masks[i] = new Vector4((float)Math.Max(layer.noise_size_metres, 1), (float)layer.noise_cutoff, (float)Math.Max(layer.noise_edge_softness, .001), (float)layer.noise_breakup_strength);
            transforms[i] = new Vector4((float)(layer.rotation_degrees * Math.PI / 180), layer.texture_offset.X, layer.texture_offset.Y, layer.flip_normal_y ? 1 : 0);
            extras[i] = new Vector4((float)Math.Max(layer.noise_breakup_frequency, .1), layer.noise_seed, 0, 0);
        }
        return new D
        {
            ["enable_ambient_cliff_normals"] = enabled, ["cliff_layer_count"] = Math.Min(layers.Count, 16), ["cliff_layer_params"] = parameters,
            ["cliff_layer_masks"] = masks, ["cliff_layer_transforms"] = transforms, ["cliff_layer_extras"] = extras,
            ["macro_detail_strength"] = macro_strength, ["medium_detail_strength"] = medium_strength, ["cliff_micro_strength"] = base_normal_strength,
            ["max_active_macro_layers"] = max_macro_layers, ["max_active_medium_layers"] = max_medium_layers, ["selection_blend_width"] = selection_blend_width,
            ["distance_fade_start"] = Math.Max(macro_fade_start, 0), ["distance_fade_end"] = Math.Max(macro_fade_end, macro_fade_start + 1),
            ["medium_fade_start"] = Math.Max(medium_fade_start, 0), ["medium_fade_end"] = Math.Max(medium_fade_end, medium_fade_start + 1),
            ["cliff_normal_debug"] = debug_mode, ["cliff_force_layer"] = isolate_layer < layers.Count ? isolate_layer : -1
        };
    }
    public A texture_signature()
    { var result = new A(); for (int i = 0; i < Math.Min(layers.Count, 16); i++) { var texture = layers[i]?.normal_texture; if (texture is null) result.Add(default(Variant)); else result.Add(texture); } return result; }
    public Texture2DArray? build_texture_array()
    {
        var images = new Godot.Collections.Array<Image>();
        try
        {
            for (int i = 0; i < Math.Min(layers.Count, 16); i++)
            {
                using var source = layers[i]?.normal_texture?.GetImage();
                Image data;
                if (source is null) { data = Image.CreateEmpty(2048, 2048, false, Image.Format.Rg8); data.Fill(new Color(.5f, .5f, 1)); }
                else data = (Image)source.Duplicate();
                // Retain every temporary image in the cleanup list, including conversion failures.
                images.Add(data);
                if (data.GetFormat() != Image.Format.RgtcRg || data.GetSize() != new Vector2I(2048, 2048) || !data.HasMipmaps())
                {
                    if (data.IsCompressed() && data.Decompress() != Error.Ok) return null;
                    data.ClearMipmaps(); data.Resize(2048, 2048, Image.Interpolation.Lanczos); data.Convert(Image.Format.Rg8); data.GenerateMipmaps();
                    if (data.CompressFromChannels(Image.CompressMode.S3Tc, Image.UsedChannels.Rg) != Error.Ok) return null;
                }
            }
            if (images.Count == 0)
            {
                var neutral = Image.CreateEmpty(2048, 2048, false, Image.Format.Rg8); images.Add(neutral);
                neutral.Fill(new Color(.5f, .5f, 1)); neutral.GenerateMipmaps(); neutral.CompressFromChannels(Image.CompressMode.S3Tc, Image.UsedChannels.Rg);
            }
            var result = new Texture2DArray();
            if (result.CreateFromImages(images) == Error.Ok) return result;
            result.Dispose(); return null;
        }
        finally { foreach (var image in images) image.Dispose(); images.Clear(); }
    }
}
