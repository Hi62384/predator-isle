using Godot;
using System;
using System.Buffers;
using System.Collections.Generic;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Native C# field implementations bypass the transitional language boundary.</summary>
public interface ICaveField
{
    double Sample(Vector3 point);
    Vector3 Normal(Vector3 point);
    bool HasChunk(Vector3I key);
    A PreciseShores { get; }
    bool HasSurfaceColumn(Vector2I column);
    double SurfaceHeight(Vector2 point);
}

internal sealed class LegacyCaveField : ICaveField
{
    private readonly GodotObject _volume;
    private readonly Callable _sample, _normal, _hasChunk, _surfaceHeight;
    public LegacyCaveField(GodotObject volume)
    {
        _volume = volume; _sample = new(volume, "sample"); _normal = new(volume, "normal");
        _hasChunk = new(volume, "has_chunk"); _surfaceHeight = new(volume, "surface_height");
    }
    public double Sample(Vector3 point) => _sample.Call(point).AsDouble();
    public Vector3 Normal(Vector3 point) => _normal.Call(point).AsVector3();
    public bool HasChunk(Vector3I key) => _hasChunk.Call(key).AsBool();
    public A PreciseShores { get { var value = _volume.Get("precise_shores"); return value.VariantType == Variant.Type.Array ? value.AsGodotArray() : new(); } }
    public bool HasSurfaceColumn(Vector2I column) => _volume.Get("surface_columns").AsGodotDictionary().ContainsKey(column);
    public double SurfaceHeight(Vector2 point) => _surfaceHeight.Call(point).AsDouble();
}

/// <summary>Fixed-grid tetrahedra, canonical welded crossings and original sign-case winding.</summary>
public partial class CaveMesher : RefCounted
{
    private static readonly int[][] Tets = CaveGpuLattice.Tets;
    private static readonly Vector3I[] CubeCorners = { new(0,0,0), new(1,0,0), new(1,1,0), new(0,1,0), new(0,0,1), new(1,0,1), new(1,1,1), new(0,1,1) };
    private static readonly bool[] Flip = { false, false, true, false, false, true, false, false, true, false, true, true, false, false, true, false };
    private readonly List<Vector3> _vertices = new(), _normals = new();
    private readonly Dictionary<Vector3, Vector3> _normalCache = new();
    // Expensive protected-shore bisections are identical for a shared tetrahedral
    // grid edge. Cache only these refinements, not cheap ordinary edge crosses.
    // Every biome uses this canonical mesher, including portals and specialty caves.
    private readonly Dictionary<(Vector3 A, Vector3 B), Vector3> _refinedEdges = new();
    private const int RefinedEdgeCapacity = 32768;
    private readonly record struct PreciseShore(Vector3 Center, double Radius);
    private PreciseShore[] _preciseShores = Array.Empty<PreciseShore>();
    public long RefinedCacheHits { get; private set; }
    public long RefinedEvaluations { get; private set; }
    public long SurfaceColumnEvaluations { get; private set; }
    public long SurfaceColumnReuseHits { get; private set; }
    internal TerrainBiomeNoiseGpu? GpuLattice{get;set;}
    internal int GpuLatticeSamples{get;private set;}
    internal int GpuLatticeExactSamples{get;private set;}
    internal int GpuTopologyCubes{get;private set;}
    protected ICaveField? Field;
    private A _shores = new();
    public Vector3 origin { get; set; }
    public bool capture_boundary_values { get; set; }
    public A boundary_values { get; set; } = new();
    public bool case_flip { get; set; }
    public Vector3[] vertices => _vertices.ToArray();
    public Vector3[] normals => _normals.ToArray();
    public Color[] colors { get { var result = new Color[_vertices.Count]; System.Array.Fill(result, new Color(.38f, .35f, .30f, 1)); return result; } }

    public Vector3 crossing(Vector3 a, Vector3 b, double va, double vb)
    {
        if (a.X > b.X || (a.X == b.X && (a.Y > b.Y || (a.Y == b.Y && a.Z > b.Z)))) { (a, b) = (b, a); (va, vb) = (vb, va); }
        if (_preciseShores.Length > 0 &&
            _refinedEdges.TryGetValue((a, b), out var cached))
        {
            RefinedCacheHits++;
            return cached;
        }
        var original = Weld(a.Lerp(b, (float)Math.Clamp(va / (va - vb), 0, 1)));
        foreach (var shore in _preciseShores)
        {
            var center = shore.Center;
            // Keep the original float length/rounding test: this predicate is
            // allowed to determine which edges receive 12 precision bisections.
            if (new Vector2(original.X - center.X, original.Z - center.Z).Length() > shore.Radius + 4 ||
                Math.Abs(original.Y - center.Y) > 6) continue;
            var low = a; var high = b; bool inside = va < 0;
            for (int iteration = 0; iteration < 12; iteration++)
            {
                var middle = (low + high) * .5f;
                RefinedEvaluations++;
                if ((Field!.Sample(middle) < 0) == inside) low = middle; else high = middle;
            }
            var refined = Weld((low + high) * .5f);
            if (_refinedEdges.Count < RefinedEdgeCapacity) _refinedEdges[(a, b)] = refined;
            return refined;
        }
        return original;
    }
    // Godot's native vector round uses half-away-from-zero; .NET Vector3.Round uses ties-to-even.
    private static Vector3 Weld(Vector3 p) => new(
        MathF.Round(p.X * 4096, MidpointRounding.AwayFromZero) / 4096,
        MathF.Round(p.Y * 4096, MidpointRounding.AwayFromZero) / 4096,
        MathF.Round(p.Z * 4096, MidpointRounding.AwayFromZero) / 4096);

    public virtual void emit(Vector3 a, Vector3 b, Vector3 c)
    {
        var cross = (c - a).Cross(b - a);
        if (cross.LengthSquared() == 0) return;
        if (case_flip) { (b, c) = (c, b); cross = -cross; }
        var face = cross.Normalized();
        AddVertex(a, face); AddVertex(b, face); AddVertex(c, face);
    }
    private void AddVertex(Vector3 point, Vector3 face)
    {
        if (!_normalCache.TryGetValue(point, out var normal))
        {
            normal = Field!.Normal(point);
            if (_normalCache.Count < 65536) _normalCache[point] = normal;
        }
        if (normal.LengthSquared() < .5 || normal.Dot(face) < .15) normal = face;
        _vertices.Add(point - origin); _normals.Add(normal);
    }

    private void Tetra(ReadOnlySpan<Vector3> points, ReadOnlySpan<float> values, int[] indices,int mask=-1)
    {
        if(mask<0)
        {
            mask=0;
            for (int i=0;i<4;i++)if(values[indices[i]]<0)mask|=1<<i;
        }
        if (mask is 0 or 15) return;
        var p = points[indices[0]]; var a = points[indices[1]] - p; var b = points[indices[2]] - p; var c = points[indices[3]] - p;
        case_flip = Flip[mask] != (a.Dot(b.Cross(c)) < 0);
        Span<int> inside = stackalloc int[4], outside = stackalloc int[4]; int ni = 0, no = 0;
        for(int j=0;j<4;j++){int index=indices[j];if((mask&(1<<j))!=0)inside[ni++]=index;else outside[no++]=index;}
        if (ni == 1 || no == 1)
        {
            int single = ni == 1 ? inside[0] : outside[0]; var others = ni == 1 ? outside[..no] : inside[..ni];
            Span<Vector3> cuts = stackalloc Vector3[3]; int cursor = 0;
            foreach (int other in others) cuts[cursor++] = crossing(points[single], points[other], values[single], values[other]);
            emit(cuts[0], cuts[1], cuts[2]); return;
        }
        var c0 = crossing(points[inside[0]], points[outside[0]], values[inside[0]], values[outside[0]]);
        var c1 = crossing(points[inside[0]], points[outside[1]], values[inside[0]], values[outside[1]]);
        var c2 = crossing(points[inside[1]], points[outside[1]], values[inside[1]], values[outside[1]]);
        var c3 = crossing(points[inside[1]], points[outside[0]], values[inside[1]], values[outside[0]]);
        emit(c0, c1, c2); emit(c0, c2, c3);
    }

    public A build(GodotObject volume, Vector3I coordinate) => build(volume, coordinate, 2);
    public A build(GodotObject volume, Vector3I coordinate, double step_metres)
    {
        _vertices.Clear(); _normals.Clear(); _normalCache.Clear(); _refinedEdges.Clear();
        RefinedCacheHits = RefinedEvaluations = 0;
        SurfaceColumnEvaluations = SurfaceColumnReuseHits = 0;
        GpuLatticeSamples=GpuLatticeExactSamples=GpuTopologyCubes=0;
        boundary_values = new();
        Field = volume as ICaveField ?? new LegacyCaveField(volume); origin = (Vector3)coordinate * 64;
        _shores = Field.PreciseShores;
        if (_shores.Count == 0) _preciseShores = Array.Empty<PreciseShore>();
        else
        {
            _preciseShores = new PreciseShore[_shores.Count];
            for (int i = 0; i < _shores.Count; i++)
            {
                var shore = _shores[i].AsGodotDictionary();
                _preciseShores[i] = new PreciseShore(shore["center"].AsVector3(), shore["radius"].AsDouble());
            }
        }
        if ((step_metres != 1 && step_metres != 2 && step_metres != 4) || !Field.HasChunk(coordinate)) return new();
        int count = (int)Math.Round(64 / step_metres), row = count + 1, plane = row * row;
        // The regular lattice needs only its scalar field and three coordinate axes.
        // Reconstruct corners for occupied cubes instead of storing a Vector3 for
        // every voxel (3,295,500 unnecessary bytes at the one-metre resolution).
        // Compute each axis using the exact original float vector arithmetic.
        int latticeCount = checked(row * plane);
        Span<float> xs=stackalloc float[row],ys=stackalloc float[row],zs=stackalloc float[row];
        for(int i=0;i<row;i++)
        {
            var p=origin+new Vector3(i,i,i)*(float)step_metres;
            xs[i]=p.X;ys[i]=p.Y;zs[i]=p.Z;
        }
        var values = ArrayPool<float>.Shared.Rent(latticeCount);
        // A portal's surface term depends only on X/Z. Sampling it again
        // for every Y voxel traverses terrain height caches needlessly.
        // Other cave fields and portals with surface air disabled keep the
        // original exact sample callback.
        var portal = Field as PortalCaveField;
        bool reuseSurface = portal is not null && portal.include_surface_air;
        var surfaceColumns = reuseSurface?ArrayPool<double>.Shared.Rent(plane):null;
        var surfaceReady = reuseSurface?ArrayPool<bool>.Shared.Rent(plane):null;
        if(surfaceReady is not null)Array.Clear(surfaceReady,0,plane);
        using var attempt=GpuLattice is {Available:true,AdaptivePolicy:not null} adaptive&&Field is CaveField cave
            ?adaptive.AdaptivePolicy!.Begin(new(0,row,reuseSurface?1:0,Math.Min(cave.Bins.Count/32,31))):null;
        try
        {
        bool screened=false;
        int[]? gpuCases=null;
        if((attempt is null||attempt.UseGpu)&&GpuLattice is {Available:true} gpu&&Field is CaveField native)
        {
            int exactSamples=0;
            if(gpu.TopologyAvailable)
            {
                gpuCases=CaveGpuLattice.TryFillTopology(gpu,native,origin,row,(float)step_metres,values,out exactSamples);
                screened=gpuCases is not null;
                GpuTopologyCubes=gpuCases?.Length??0;
            }
            else if(gpu.TopologyShaderPath is null)
                screened=CaveGpuLattice.TryFill(gpu,native,origin,row,(float)step_metres,values,out exactSamples);
            if(screened){GpuLatticeSamples=latticeCount;GpuLatticeExactSamples=exactSamples;}
        }
        if(!screened)
        for (int z = 0; z < row; z++)
        for (int y = 0; y < row; y++)
        for (int x = 0; x < row; x++)
        {
            int index = x + row * y + plane * z;
            var point = new Vector3(xs[x],ys[y],zs[z]);
            if(!reuseSurface){values[index]=(float)Field.Sample(point);continue;}
            if(!CaveField.SafePoint(point)){values[index]=(float)CaveField.Far;continue;}
            int column=x+row*z;
            if(!surfaceReady![column])
            {
                surfaceColumns![column]=portal!.SurfaceHeight(new Vector2(point.X,point.Z));
                surfaceReady[column]=true;SurfaceColumnEvaluations++;
            }
            else SurfaceColumnReuseHits++;
            values[index]=(float)portal!.SampleWithSurfaceHeight(point,surfaceColumns![column]);
        }
        if (capture_boundary_values && step_metres == 2)
            for (int face = 0; face < 6; face++)
            {
                var faceValues = new float[plane];
                for (int y = 0; y < row; y++)
                for (int x = 0; x < row; x++)
                {
                    int index = face < 2 ? ((face % 2 == 1 ? count : 0) + row * x + plane * y)
                        : face < 4 ? (x + row * (face % 2 == 1 ? count : 0) + plane * y)
                        : x + row * y + plane * (face % 2 == 1 ? count : 0);
                    faceValues[x + row * y] = values[index];
                }
                boundary_values.Add(faceValues);
            }
        ReadOnlySpan<int> offsets = stackalloc int[] { 0, 1, 1 + row, row, plane, 1 + plane, 1 + row + plane, row + plane };
        Span<Vector3> cubePoints = stackalloc Vector3[8]; Span<float> cubeValues = stackalloc float[8];
        for (int z = 0; z < count; z++)
        for (int y = 0; y < count; y++)
        for (int x = 0; x < count; x++)
        {
            int start=x+row*y+plane*z;
            int cases=gpuCases is null?-1:gpuCases[x+count*(y+count*z)];
            if(cases is 0 or 0xffffff)continue;
            if(cases<0)
            {
                bool air=false,rock=false;
                foreach(int offset in offsets)
                {
                    air|=values[start+offset]<0;rock|=values[start+offset]>=0;
                    if(air&&rock)break;
                }
                if(!air||!rock)continue;
            }
            for (int i = 0; i < 8; i++)
            {
                var corner=CubeCorners[i];
                cubePoints[i]=new Vector3(xs[x+corner.X],ys[y+corner.Y],zs[z+corner.Z]);
                cubeValues[i]=values[start+offsets[i]];
            }
            for(int t=0;t<Tets.Length;t++)Tetra(cubePoints,cubeValues,Tets[t],cases<0?-1:(cases>>(t*4))&15);
        }
        if (_vertices.Count == 0){attempt?.Complete();return new();}
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices; arrays[(int)Mesh.ArrayType.Normal] = normals; arrays[(int)Mesh.ArrayType.Color] = colors;
        attempt?.Complete();return arrays;
        }
        finally
        {
            ArrayPool<float>.Shared.Return(values,clearArray:false);
            if(surfaceColumns is not null)ArrayPool<double>.Shared.Return(surfaceColumns,clearArray:false);
            if(surfaceReady is not null)ArrayPool<bool>.Shared.Return(surfaceReady,clearArray:false);
        }
    }
}
