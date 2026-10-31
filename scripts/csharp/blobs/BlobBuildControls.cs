using Godot;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Worker-owned cancellation and progress, synchronized independently of scene state.</summary>
public partial class BlobBuildControls : RefCounted
{
    private readonly object sync=new();
    private bool cancelled;
    private double progress;
    private string message="Planning anatomy";
    public bool is_cancelled(){lock(sync)return cancelled;}
    public void cancel(){lock(sync)cancelled=true;}
    public void set_progress(double value,string detail){lock(sync){progress=value;message=detail;}}
    public D snapshot(){lock(sync)return new D{["progress"]=progress,["message"]=message};}
}
