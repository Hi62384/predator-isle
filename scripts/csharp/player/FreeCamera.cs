using Godot;
using System.Text;

namespace PredatorIsle.Player;

public partial class FreeCamera : Camera3D
{
    [Export(PropertyHint.Range, "1,500,1")] public double move_speed { get; set; } = 35;
    [Export(PropertyHint.Range, "1,10,0.1")] public double sprint_multiplier { get; set; } = 3;
    [Export(PropertyHint.Range, "0.01,1,0.01")] public double mouse_sensitivity { get; set; } = .12;
    [Export] public Node? terrain { get; set; }
    [Export] public Label? debug_label { get; set; }
    [Export] public bool debug_overlay_visible { get; set; }
    private double _pitch = -25;
    private double _debugRefresh;
    private PlayerScaleMarker _marker = null!;
    private int _extensionIndex = -1;
    private static readonly string[] Extensions = { "quarry", "wise_mountains", "volcanic", "spore_forest", "radiation_wasteland", "crystal_wastes", "insect_colony", "alien_infected" };

    public override void _Ready()
    {
        CreateInputActions(); _set_debug_overlay_visible(debug_overlay_visible);
        Input.MouseMode = Input.MouseModeEnum.Captured;
        foreach (string name in new[] { "_badlands_feature_active", "badlands_preview", "start_in_badlands", "_tropical_feature_active", "tropical_preview", "start_in_tropical", "_coast_feature_active", "start_in_coast", "_mountain_feature_active", "start_in_mountain", "_jungle_feature_active", "_forest_feature_active", "_savanna_feature_active", "_swamp_feature_active", "start_in_swamp", "start_in_jungle", "start_in_forest", "start_in_savanna" })
            if (Flag(name)) { _pitch = RotationDegrees.X; break; }
        RotationDegrees = new((float)_pitch, RotationDegrees.Y, RotationDegrees.Z); Far = 50000;
        _marker = new PlayerScaleMarker { Name = "PlayerScaleReference", Visible = false };
        GetParent().CallDeferred(Node.MethodName.AddChild, _marker);
    }

    private bool Flag(string name) => terrain != null && terrain.Get(name).AsBool();
    private int DebugView => terrain?.Get("terrain_debug_view").AsInt32() ?? 0;
    private void SetDebug(int mode) => terrain?.Call("set_debug_view", mode);
    private void CycleRange(int low, int high) => SetDebug(DebugView >= low && DebugView < high ? DebugView + 1 : low);

    public void _set_debug_overlay_visible(bool value)
    {
        debug_overlay_visible = value;
        foreach (var overlay in GetTree().GetNodesInGroup("terrain_debug_overlay"))
            if (overlay is CanvasLayer layer) layer.Visible = value;
        if (!IsInstanceValid(debug_label)) return;
        debug_label!.MouseFilter = Control.MouseFilterEnum.Ignore;
        if (debug_label.GetParent() is Control panel) { panel.MouseFilter = Control.MouseFilterEnum.Ignore; panel.Visible = value; }
    }

    public override void _Input(InputEvent input)
    {
        if (input is InputEventMouseMotion motion && Input.MouseMode == Input.MouseModeEnum.Captured)
        {
            _pitch = System.Math.Clamp(_pitch - motion.Relative.Y * mouse_sensitivity, -89, 89);
            RotationDegrees = new((float)_pitch, RotationDegrees.Y - (float)(motion.Relative.X * mouse_sensitivity), RotationDegrees.Z);
            GetViewport().SetInputAsHandled();
        }
        else if (input.IsActionPressed("freecam_release_mouse")) { Input.MouseMode = Input.MouseModeEnum.Visible; GetViewport().SetInputAsHandled(); }
        else if (input.IsActionPressed("toggle_debug_overlay") && !input.IsEcho()) { _set_debug_overlay_visible(!debug_overlay_visible); GetViewport().SetInputAsHandled(); }
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut && Input.MouseMode == Input.MouseModeEnum.Captured) Input.MouseMode = Input.MouseModeEnum.Visible;
    }

    public override void _UnhandledInput(InputEvent input)
    {
        if (input is InputEventMouseButton mouse)
        {
            if (mouse.ButtonIndex == MouseButton.Left && mouse.Pressed) Input.MouseMode = Input.MouseModeEnum.Captured;
            else if (mouse.Pressed && mouse.ButtonIndex == MouseButton.WheelUp) move_speed = System.Math.Min(move_speed * 1.2, 500);
            else if (mouse.Pressed && mouse.ButtonIndex == MouseButton.WheelDown) move_speed = System.Math.Max(move_speed / 1.2, 1);
        }
        else if (input.IsActionPressed("toggle_fullscreen")) ToggleFullscreen();
        else if (input.IsActionPressed("scale_toggle")) { if (_marker.Visible) _marker.Hide(); else if (terrain != null) _marker.place(this, terrain); }
        else if (input.IsActionPressed("scale_place") && terrain != null) _marker.place(this, terrain);
        else if (input.IsActionPressed("terrain_debug_shaded") && terrain != null) SetDebug(0);
        else if (input is InputEventKey key && key.Pressed && terrain != null)
        {
            if (key.PhysicalKeycode == Key.F10 && key.ShiftPressed && key.CtrlPressed) CycleRange(149, 153);
            else if (key.PhysicalKeycode == Key.F10 && key.ShiftPressed)
            {
                for (int attempt = 0; attempt < 8; attempt++)
                {
                    _extensionIndex = (_extensionIndex + 1) % 8;
                    if (terrain.Call("jump_to_extension", Extensions[_extensionIndex]).AsBool()) break;
                }
            }
            else if (key.PhysicalKeycode == Key.F12 && key.CtrlPressed) CycleRange(119, 130);
            else if (key.PhysicalKeycode == Key.F12) terrain.Call("jump_to_beach");
            else if (key.PhysicalKeycode == Key.F1 && key.CtrlPressed) CycleRange(99, 118);
            else if (key.PhysicalKeycode == Key.F1) terrain.Call("jump_to_coast");
            else if (key.PhysicalKeycode == Key.F2 && key.CtrlPressed) CycleRange(81, 98);
            else if (key.PhysicalKeycode == Key.F2) terrain.Call("jump_to_mountain");
            else if (key.PhysicalKeycode == Key.F3 && key.CtrlPressed) CycleRange(61, 80);
            else if (key.PhysicalKeycode == Key.F3) terrain.Call("jump_to_swamp");
            else if (key.PhysicalKeycode == Key.F4) terrain.Call("jump_to_savanna");
            else if (key.PhysicalKeycode == Key.F10 && key.CtrlPressed) CycleRange(47, 60);
            else if (key.PhysicalKeycode == Key.F6) CycleRange(28, 35);
            else if (key.PhysicalKeycode == Key.F8 && key.CtrlPressed) CycleRange(131, 140);
            else if (key.PhysicalKeycode == Key.F8 && key.ShiftPressed) terrain.Call("jump_to_tropical");
            else if (key.PhysicalKeycode == Key.F8) terrain.Call("jump_to_jungle");
            else if (key.PhysicalKeycode == Key.F9 && key.CtrlPressed) CycleRange(141, 148);
            else if (key.PhysicalKeycode == Key.F9 && key.ShiftPressed) terrain.Call("jump_to_badlands");
            else if (key.PhysicalKeycode == Key.F9) terrain.Call("jump_to_forest");
            else if (key.PhysicalKeycode == Key.F10) CycleRange(36, 46);
            else if (input.IsActionPressed("terrain_debug")) terrain.Call("cycle_debug_view");
        }
        else if (input.IsActionPressed("terrain_debug") && terrain != null) terrain.Call("cycle_debug_view");
    }

    public override void _Process(double delta)
    {
        var axes = Input.GetVector("freecam_left", "freecam_right", "freecam_forward", "freecam_back");
        var direction = Basis * new Vector3(axes.X, 0, axes.Y) + Vector3.Up * Input.GetAxis("freecam_down", "freecam_up");
        if (direction.LengthSquared() > 0) direction = direction.Normalized();
        double speed = move_speed * (Input.IsActionPressed("freecam_sprint") ? sprint_multiplier : 1);
        GlobalPosition += direction * (float)(speed * delta);
        _debugRefresh -= delta;
        if (_debugRefresh > 0) return;
        _debugRefresh = .2;
        if (terrain != null) Near = (float)System.Math.Clamp((GlobalPosition.Y - terrain.Call("get_height_at", GlobalPosition).AsDouble()) * .01, .1, 10);
        if (debug_label != null && debug_label.IsVisibleInTree()) UpdateDebugLabel(speed);
    }

    private void UpdateDebugLabel(double speed)
    {
        var p = GlobalPosition;
        string chunk = terrain?.Call("get_target_chunk").ToString() ?? "n/a";
        string biome = terrain?.Call("get_biome_name_at", p).AsString() ?? "n/a";
        int loaded = terrain?.Call("get_loaded_chunk_count").AsInt32() ?? 0;
        double temperature = terrain?.Call("get_temperature_at", p).AsDouble() ?? 0;
        string climate = terrain?.Call("get_climate_description", p).AsString() ?? "";
        var text = new StringBuilder();
        text.AppendLine($"PREDATOR ISLE  |  TERRAIN STREAMING TEST  |  FPS: {Engine.GetFramesPerSecond()}");
        text.AppendLine("WASD move   Q/E down/up   Shift boost   Mouse look   Wheel speed   F11 fullscreen   Esc release");
        text.AppendLine($"Position: ({p.X:F1}, {p.Y:F1}, {p.Z:F1})   Chunk: {chunk}   Biome below camera: {biome}   Loaded: {loaded}   Speed: {speed:F0}");
        text.Append($"{temperature:F1} C ({climate})   |   F7 scale on/off   P place   Reference: 1.80 m");
        if (terrain != null) text.Append($"\nF5: {terrain.Call("get_debug_view_name")}   Ctrl+F5 shaded   F2 Mountain / Ctrl+F2 views");
        text.Append("\nF3 Swamp / Ctrl+F3 views   F4 Savanna / Ctrl+F10 views   F8 Jungle   F9 Forest\nF1 Rocky Coast / Ctrl+F1 Coast views\nF12 Beaches / Ctrl+F12 Sand views\nShift+F8 Tropical / Ctrl+F8 Tropical views\nShift+F9 Badlands / Ctrl+F9 Badlands views");
        foreach (string family in new[] { "coast", "mountain", "swamp", "savanna", "forest", "jungle" })
            if (Flag(family + "_preview")) text.Append($"\n{family.ToUpperInvariant()} PREVIEW: {terrain!.Get(family + "_preview_feature")}");
        if (terrain != null) text.Append('\n').Append(terrain.Call("get_partition_debug"));
        debug_label!.Text = text.ToString();
    }

    private static void CreateInputActions()
    {
        foreach (var (name, key) in new (string, Key)[]
        {
            ("toggle_debug_overlay", Key.Quoteleft), ("freecam_forward", Key.W), ("freecam_back", Key.S),
            ("freecam_left", Key.A), ("freecam_right", Key.D), ("freecam_down", Key.Q), ("freecam_up", Key.E),
            ("freecam_sprint", Key.Shift), ("freecam_release_mouse", Key.Escape), ("toggle_fullscreen", Key.F11),
            ("scale_toggle", Key.F7), ("scale_place", Key.P), ("terrain_debug", Key.F5)
        }) AddKey(name, new InputEventKey { PhysicalKeycode = key });
        AddKey("terrain_debug_shaded", new InputEventKey { PhysicalKeycode = Key.F5, CtrlPressed = true });
        AddKey("toggle_fullscreen", new InputEventKey { PhysicalKeycode = Key.Enter, AltPressed = true });
    }
    private static void AddKey(string name, InputEventKey key)
    {
        if (!InputMap.HasAction(name)) InputMap.AddAction(name);
        if (!InputMap.ActionHasEvent(name, key)) InputMap.ActionAddEvent(name, key);
    }
    private static void ToggleFullscreen()
    {
        var mode = DisplayServer.WindowGetMode();
        DisplayServer.WindowSetMode(mode is DisplayServer.WindowMode.Fullscreen or DisplayServer.WindowMode.ExclusiveFullscreen
            ? DisplayServer.WindowMode.Windowed : DisplayServer.WindowMode.ExclusiveFullscreen);
    }
}
