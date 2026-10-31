using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobLabCamera : Camera3D
{
    public double angle{get;set;}=.6;
    public double pitch{get;set;}=.3;
    public double distance{get;set;}=8.5;
    public Vector3 focus{get;set;}=new(0,1.5f,0);
    public Vector3 home_focus{get;set;}=new(0,1.5f,0);
    public double home_distance{get;set;}=8.5;
    public Node3D? follow{get;set;}
    public bool follow_enabled{get;set;}=true;
    private Vector3 lastFollow;
    public override void _Ready()=>UpdateView();
    public override void _UnhandledInput(InputEvent input)
    {
        if(input is InputEventMouseMotion motion)
        {
            if(Input.IsMouseButtonPressed(MouseButton.Right)){angle-=motion.Relative.X*.008;pitch=Math.Clamp(pitch+motion.Relative.Y*.008,-1.48,1.48);UpdateView();}
            else if(Input.IsMouseButtonPressed(MouseButton.Middle)){focus+=(-GlobalBasis.X*motion.Relative.X+GlobalBasis.Y*motion.Relative.Y)*(float)distance*.0015f;UpdateView();}
        }
        if(input is InputEventMouseButton button&&button.Pressed)
        {
            if(button.ButtonIndex==MouseButton.WheelUp)distance=Math.Max(.35,distance*.9);
            if(button.ButtonIndex==MouseButton.WheelDown)distance=Math.Min(100,distance/.9);
            UpdateView();
        }
        if(input is InputEventKey key&&key.Pressed)
        {
            switch(key.PhysicalKeycode)
            {
                case Key.F:focus=home_focus;distance=home_distance;break;
                case Key.R:focus=home_focus;distance=home_distance;angle=.6;pitch=.3;break;
                case Key.Key1:angle=0;pitch=0;break;
                case Key.Key2:angle=Math.PI*.5;pitch=0;break;
                case Key.Key3:pitch=1.48;break;
                case Key.Key4:angle=Math.PI;pitch=0;break;
                case Key.Key5:angle=-Math.PI*.5;pitch=0;break;
                case Key.Key6:pitch=-1.48;break;
            }
            UpdateView();
        }
    }
    private void UpdateView()
    {
        Position=focus+new Vector3((float)(Math.Sin(angle)*Math.Cos(pitch)),(float)Math.Sin(pitch),(float)(Math.Cos(angle)*Math.Cos(pitch)))*(float)distance;
        LookAt(focus);
    }
    public void frame_creature(D data,double bodyHeight)
    {
        var bounds=new Aabb(Vector3.Zero,Vector3.One*.001f);
        foreach(var p in data["body"].AsGodotDictionary()["vertices"].AsVector3Array())bounds=bounds.Expand(p);
        foreach(var item in data["appendages"].AsGodotArray())foreach(var p in item.AsGodotDictionary()["mesh"].AsGodotDictionary()["vertices"].AsVector3Array())bounds=bounds.Expand(p);
        focus=bounds.GetCenter()+Vector3.Up*(float)bodyHeight;distance=Math.Max(4,bounds.Size[(int)bounds.Size.MaxAxisIndex()]*1.5);home_focus=focus;home_distance=distance;HOffset=.5f;UpdateView();
    }
    public void focus_feature(Node3D actor,int id)
    {
        focus=actor.Call("attachment_position",id).AsVector3();var anatomy=actor.Get("anatomy").AsGodotDictionary();
        distance=Math.Max(.8,anatomy["features"].AsGodotArray()[id].AsGodotDictionary()["radii"].AsVector3().Length()*4.0);UpdateView();
    }
    public void quick_view(int index)
    {
        switch(index){case 0:angle=0;pitch=0;break;case 1:angle=Math.PI;pitch=0;break;case 2:angle=-Math.PI*.5;pitch=0;break;case 3:angle=Math.PI*.5;pitch=0;break;case 4:pitch=1.48;break;case 5:pitch=-1.48;break;case 6:angle=.6;pitch=.3;break;}UpdateView();
    }
    public void follow_actor(Node3D actor){follow=actor;lastFollow=actor.GlobalPosition;}
    public override void _Process(double delta)
    {
        if(!IsInstanceValid(follow))return;var offset=follow!.GlobalPosition-lastFollow;lastFollow=follow.GlobalPosition;if(follow_enabled){focus+=offset;home_focus+=offset;UpdateView();}
    }
}
