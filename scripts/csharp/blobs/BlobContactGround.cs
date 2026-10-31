using Godot;
using System;

namespace PredatorIsle.Blobs;

public partial class BlobContactGround : Node3D
{
    public double get_height_at(Vector3 p)=>p.X<0?0:.12*p.Z+.17*Math.Sin(p.Z*1.8)+.09*Math.Sin(p.X*1.3);
}
