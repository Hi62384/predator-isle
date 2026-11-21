using Godot;
namespace PredatorIsle.Terrain;
/// <summary>Keeps CPU fallback data without eagerly copying every GPU patch into engine collections.</summary>
public partial class TerrainCpuSurfacePayload : RefCounted
{
    internal TerrainRingMeshGeometry.Data Data=null!;
}
