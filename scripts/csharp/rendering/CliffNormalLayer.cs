using Godot;

namespace PredatorIsle.Rendering;

[Tool, GlobalClass]
public partial class CliffNormalLayer : Resource
{
    private string _label = "New rock";
    [Export] public string label { get => _label; set { _label = value; ResourceName = value; } }
    [Export] public bool enabled { get; set; } = true;
    [Export] public Texture2D? normal_texture { get; set; }
    [Export(PropertyHint.Enum, "Macro,Medium")] public int band { get; set; }
    [Export(PropertyHint.Range, "0,4,0.01")] public double strength { get; set; } = 1;
    [Export(PropertyHint.Range, "0.5,500,0.5")] public double texture_size_metres { get; set; } = 72;
    [Export(PropertyHint.Range, "1,1000,1")] public double noise_size_metres { get; set; } = 95;
    [Export(PropertyHint.Range, "0,1,0.01")] public double noise_cutoff { get; set; } = .28;
    [Export(PropertyHint.Range, "0.01,0.8,0.01")] public double noise_edge_softness { get; set; } = .18;
    [Export(PropertyHint.Range, "0,1,0.01")] public double noise_breakup_strength { get; set; } = .45;
    [Export(PropertyHint.Range, "0.1,8,0.05")] public double noise_breakup_frequency { get; set; } = 2.31;
    [Export] public int noise_seed { get; set; }
    [Export(PropertyHint.Range, "-180,180,1")] public double rotation_degrees { get; set; }
    [Export] public Vector2 texture_offset { get; set; }
    [Export] public bool flip_normal_y { get; set; }
}
