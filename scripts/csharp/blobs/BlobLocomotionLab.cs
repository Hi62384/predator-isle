using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobLocomotionLab : Node3D
{
    public Godot.Collections.Array<BlobOrganism> organisms{get;set;}=new();
    public double elapsed{get;set;}
    public bool automatic{get;set;}=true;
    public Label readout{get;set;}=new();
    private readonly BlobMeshCache Cache=new();
    public override void _Ready()
    {
        var ground=new BlobContactGround{Name="ContactSurface"};AddChild(ground);BuildGround(ground);
        var camera=new Camera3D{Position=new Vector3(12,9,15),Projection=Camera3D.ProjectionType.Orthogonal,Size=17,Current=true};AddChild(camera);camera.LookAt(new Vector3(0,1,0));
        AddChild(new WorldEnvironment{Environment=new Godot.Environment{BackgroundMode=Godot.Environment.BGMode.Color,BackgroundColor=new Color(.12f,.14f,.15f),AmbientLightSource=Godot.Environment.AmbientSource.Color,AmbientLightColor=new Color(.7f,.75f,.8f),AmbientLightEnergy=.6f}});
        AddChild(new DirectionalLight3D{RotationDegrees=new Vector3(-48,-30,0),LightEnergy=1.6f,ShadowEnabled=true});
        for(int lane=0;lane<2;lane++)
        {
            var result=Cache.build(6200+lane,1,"roll",7,null,new D{["profile"]=lane==0?"swollen":"mimic",["body_plan"]=lane==0?"multilobe":"lopsided"});
            if(result.ContainsKey("error")||result.ContainsKey("cancelled")){GD.PushError("Locomotion lab could not build an organism: "+result);continue;}
            var organism=new BlobOrganism{Position=new Vector3(lane==0?-4.5f:4.5f,0,2),terrain=ground};AddChild(organism);var position=organism.Position;position.Y=(float)ground.get_height_at(position);organism.Position=position;organism.ground_height=position.Y;organism.configure(result);organism.travel_enabled=true;organism.speed=.9;organism.debug_circulation=true;organism.simulation_enabled=false;organisms.Add(organism);
            AddChild(new Label3D{Text=lane==0?"FLAT CONTACT":"SLOPE + UNEVEN CONTACT",Position=new Vector3(position.X,0,-5.5f),Billboard=BaseMaterial3D.BillboardModeEnum.Enabled,PixelSize=.008f,FontSize=40});
        }
        var ui=new CanvasLayer();AddChild(ui);var box=new VBoxContainer{Position=new Vector2(24,20)};ui.AddChild(box);readout.AddThemeFontSizeOverride("font_size",22);box.AddChild(readout);box.AddChild(new Label{Text="MATERIAL-COORDINATE CIRCULATION / stationary body frame\nSpace: pause  |  D: tissue/markers  |  R: reverse  |  M: movement profile"});
    }
    public override void _PhysicsProcess(double delta){if(automatic)advance(delta);}
    public void advance(double delta)
    {
        elapsed+=delta;double cycle=elapsed%10,speed=cycle<4?.9:cycle<5?0:cycle<9?-.9:0;foreach(var organism in organisms){organism.speed=speed;organism.simulate(delta);}readout.Text=$"PREDATOR ISLE / SOFT TREAD TEST · {elapsed:F2} s · {(speed>0?"FORWARD":speed<0?"REVERSE":"SETTLING")}";
    }
    public override void _UnhandledInput(InputEvent input)
    {
        if(input is not InputEventKey key||!key.Pressed||key.Echo)return;switch(key.PhysicalKeycode){case Key.Space:automatic=!automatic;break;case Key.D:foreach(var organism in organisms)organism.debug_circulation=!organism.debug_circulation;break;case Key.R:foreach(var organism in organisms)organism.direction=-organism.direction;break;case Key.M:var modes=new[]{"roll","drag","undulate","limb","hybrid"};foreach(var organism in organisms)organism.set_locomotion(modes[(Array.IndexOf(modes,organism.Get("locomotion").AsString())+1)%modes.Length]);break;}
    }
    private void BuildGround(BlobContactGround provider)
    {
        using var surface=new SurfaceTool();surface.Begin(Mesh.PrimitiveType.Triangles);var corners=new[]{new Vector2(0,0),new Vector2(1,0),new Vector2(0,1),new Vector2(1,1)};var indices=new[]{0,1,2,1,3,2};
        for(int z=0;z<48;z++)for(int x=0;x<48;x++){var points=new Vector3[4];for(int i=0;i<4;i++){var p=new Vector3((float)((x+(double)corners[i].X)/48*24-12),0,(float)((z+(double)corners[i].Y)/48*24-12));p.Y=(float)provider.get_height_at(p);points[i]=p;}foreach(int i in indices){surface.SetColor(x<24?new Color(.18f,.2f,.19f):new Color(.23f,.22f,.19f));surface.AddVertex(points[i]);}}
        surface.GenerateNormals();var mesh=new MeshInstance3D{Mesh=surface.Commit(),MaterialOverride=new StandardMaterial3D{VertexColorUseAsAlbedo=true,Roughness=.9f}};AddChild(mesh);mesh.CreateTrimeshCollision();
    }
}
