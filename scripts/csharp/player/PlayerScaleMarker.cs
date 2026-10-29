using Godot;

namespace PredatorIsle.Player;

public partial class PlayerScaleMarker : Node3D
{
    private StandardMaterial3D _material = null!;
    public override void _Ready()
    {
        _material = new StandardMaterial3D { AlbedoColor = new Color(1, .32f, .045f), Roughness = .8f };
        Box(new(-.14f, .425f, 0), new(.20f, .85f, .25f));
        Box(new(.14f, .425f, 0), new(.20f, .85f, .25f));
        Box(new(0, 1.15f, 0), new(.46f, .60f, .26f));
        Box(new(-.32f, 1.13f, 0), new(.16f, .62f, .18f));
        Box(new(.32f, 1.13f, 0), new(.16f, .62f, .18f));
        Part(new SphereMesh { Radius = .175f, Height = .35f }, new(0, 1.625f, 0));
        Box(new(0, .015f, .40f), new(1, .03f, .03f));
        Box(new(.65f, .90f, 0), new(.025f, 1.8f, .025f));
        foreach (float height in new[] { 0f, .5f, 1f, 1.5f, 1.8f }) Box(new(.71f, height, 0), new(.15f, .025f, .025f));
        AddChild(new Label3D
        {
            Text = "PLAYER SCALE\n1.80 m tall | 1 m ground ruler", Position = new(0, 2.25f, 0),
            Billboard = BaseMaterial3D.BillboardModeEnum.Enabled, FontSize = 40, PixelSize = .005f, OutlineSize = 8
        });
    }
    private void Box(Vector3 center, Vector3 size) => Part(new BoxMesh { Size = size }, center);
    private void Part(Mesh mesh, Vector3 center) => AddChild(new MeshInstance3D { Mesh = mesh, MaterialOverride = _material, Position = center });
    private static double Height(Node terrain, Vector3 point) => terrain.Call("get_height_at", point).AsDouble();

    public void place(Camera3D camera, Node terrain)
    {
        var origin = camera.GlobalPosition;
        var ray = -camera.GlobalBasis.Z;
        double previous = 0;
        bool found = false;
        var point = origin;
        for (int step = 1; step <= 512; step++)
        {
            double distance = step * 8.0;
            point = origin + ray * (float)distance;
            if (point.Y <= Height(terrain, point))
            {
                double low = previous, high = distance;
                for (int iteration = 0; iteration < 14; iteration++)
                {
                    double middle = (low + high) * .5;
                    var sample = origin + ray * (float)middle;
                    if (sample.Y > Height(terrain, sample)) low = middle; else high = middle;
                }
                point = origin + ray * (float)high; found = true; break;
            }
            previous = distance;
        }
        if (!found) point = origin + new Vector3(ray.X, 0, ray.Z).Normalized() * 12;
        point.Y = (float)Height(terrain, point); GlobalPosition = point; Visible = true;
    }
}
