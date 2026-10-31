using Godot;
using System;

namespace PredatorIsle.Caves;
public partial class CrystalVeinExposure : RefCounted
{
    public double amount(Vector3 point)
    {
        var p=new Vector3((float)Mathf.PosMod((double)point.X,3840),(float)Mathf.PosMod((double)point.Y,3840),(float)Mathf.PosMod((double)point.Z,3840));
        double patch=.5+.5*Math.Sin(p.X*Math.Tau/48+.7*Math.Sin(p.Z*Math.Tau/32))*Math.Sin(p.Z*Math.Tau/60-p.Y*Math.Tau/48);
        double t=Math.Clamp((patch-.60)/(.82-.60),0,1);return t*t*(3-2*t);
    }
}
