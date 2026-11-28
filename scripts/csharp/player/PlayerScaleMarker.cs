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
    private Camera3D? placementCamera;

    public void place(Camera3D camera, Node terrain) => placementCamera = camera;

    public override void _PhysicsProcess(double delta)
    {
        var camera = placementCamera;
        placementCamera = null;
        if (!IsInstanceValid(camera)) return;
        var origin = camera!.GlobalPosition;
        var query = PhysicsRayQueryParameters3D.Create(origin, origin - camera.GlobalBasis.Z * 4096, 1);
        var space = camera.GetWorld3D().DirectSpaceState;
        var hit = space.IntersectRay(query);
        if (hit.Count > 0 && hit["normal"].AsVector3().Y < .45f)
        {
            var besideWall = hit["position"].AsVector3() + hit["normal"].AsVector3() * .5f;
            query.From = besideWall;
            query.To = besideWall + Vector3.Down * 64;
            hit = space.IntersectRay(query);
        }
        Visible = hit.Count > 0 && hit["normal"].AsVector3().Y >= .45f;
        if (Visible) GlobalPosition = hit["position"].AsVector3();
    }
}
