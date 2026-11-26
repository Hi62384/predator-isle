using Godot;
using System;
using System.Threading.Tasks;

namespace PredatorIsle.Checks;

public partial class FlightMaskCheck : Node3D
{
    public override async void _Ready()
    {
        try
        {
            var view=new SubViewport { Size=new Vector2I(64,64), OwnWorld3D=true,
                RenderTargetUpdateMode=SubViewport.UpdateMode.Always, TransparentBg=true };
            AddChild(view);
            var camera=new Camera3D { Projection=Camera3D.ProjectionType.Orthogonal, Size=12,
                Position=new Vector3(24,10,24), RotationDegrees=new Vector3(-90,0,0) };
            view.AddChild(camera);
            using var mask=Image.CreateEmpty(8,8,false,Image.Format.Rgbaf);
            mask.Fill(Colors.Transparent);
            var texture=ImageTexture.CreateFromImage(mask);
            var material=(ShaderMaterial)GD.Load<ShaderMaterial>("res://materials/terrain.tres").Duplicate();
            material.SetShaderParameter("flight_cell_size",16.0);
            material.SetShaderParameter("flight_coverage",texture);
            material.SetShaderParameter("debug_view",4);
            var patch=new MeshInstance3D { Mesh=new PlaneMesh {Size=Vector2.One*16},
                Position=new Vector3(24,0,24),MaterialOverride=material };
            view.AddChild(patch);
            async Task CheckPixel(bool visible)
            {
                for(int i=0;i<3;i++)await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                using var image=view.GetTexture().GetImage();
                if((image.GetPixel(32,32).A>.5f)!=visible)
                    throw new InvalidOperationException($"Unexpected visibility at world (24,24), expected {visible}");
            }
            await CheckPixel(true);
            mask.SetPixel(1,1,new Color(1,1,1,1));texture.Update(mask);
            await CheckPixel(false);
            mask.SetPixel(1,1,Colors.Transparent);texture.Update(mask);
            await CheckPixel(true);
            GD.Print("Terrain coverage pixel check passed at cell (1,1): visible, hidden, visible.");
            GetTree().Quit();
        }
        catch(Exception error){GD.PushError(error.ToString());GetTree().Quit(1);}
    }
}
