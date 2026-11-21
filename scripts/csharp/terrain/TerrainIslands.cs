using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Worker-owned warped power cells. Neighboring shores use the same boundary planes.</summary>
public partial class TerrainIslands : RefCounted
{
    public Resource settings { get; set; } = null!;
    public long world_seed { get; set; }
    public FastNoiseLite continent { get; set; } = null!;
    public FastNoiseLite shoreline { get; set; } = null!;
    // C# workers keep numerical caches entirely managed. Legacy callers can still
    // request live dictionaries and clear/edit them; only that compatibility path
    // pays for maintaining and reading the native mirrors.
    private D? sitesMirror,planesMirror,ownersMirror,certificatesMirror;
    public D sites_cache
    {
        get
        {
            if(sitesMirror is null){sitesMirror=new D();foreach(var pair in _sites)PublishSites(pair.Key,pair.Value);}
            return sitesMirror;
        }
    }
    public D plane_cache
    {
        get
        {
            if(planesMirror is null){planesMirror=new D();foreach(var pair in _planes)planesMirror[pair.Key]=pair.Value;}
            return planesMirror;
        }
    }
    public D owner_cache
    {
        get
        {
            if(ownersMirror is null){ownersMirror=new D();foreach(var pair in _owners)ownersMirror[pair.Key]=pair.Value;_owners.Clear();}
            return ownersMirror;
        }
    }
    public D coast_certificates
    {
        get
        {
            if(certificatesMirror is null){certificatesMirror=new D();foreach(var pair in _certificates)certificatesMirror[pair.Key]=pair.Value;_certificates.Clear();}
            return certificatesMirror;
        }
    }
    private readonly Dictionary<Vector2I, double[][]> _sites = new();
    private readonly Dictionary<Vector3I, Vector3[]> _planes = new();
    private readonly Dictionary<Vector2I, int> _owners = new();
    private readonly Dictionary<Vector2I, Vector3> _certificates = new();
    private readonly TerrainRegions _hash = new();
    private readonly TerrainParameterSnapshot _parameters = new();
    private double P(string key) => _parameters[key];
    private double Random(Vector2I cell, int salt) => _hash.random(cell.X, cell.Y, 71, salt, world_seed);

    public void configure(Resource config, long seed, FastNoiseLite continentNoise, FastNoiseLite shorelineNoise)
    {
        settings = config; world_seed = seed; continent = continentNoise; shoreline = shorelineNoise;
        _parameters.Capture(config);
        sitesMirror?.Clear(); planesMirror?.Clear(); ownersMirror?.Clear(); certificatesMirror?.Clear();
        _sites.Clear(); _planes.Clear(); _owners.Clear(); _certificates.Clear();
    }
    public double gap() => Math.Max(P("island_spacing"), 1) * Math.Max(P("island_size"), 16) / 1388.89;
    public double pitch() => Math.Max(P("island_size"), 16) * .65 + gap();
    public double[] candidate(Vector2I cell)
    {
        double p = pitch();
        var center = (Vector2)cell * (float)p + new Vector2((float)(Random(cell, 211) - .5), (float)(Random(cell, 313) - .5))
            * (float)p * .8f * (float)Math.Clamp(P("island_position_jitter"), 0, 1);
        double weight = Random(cell, 419) * p * p * .25 * Math.Clamp(P("island_size_variation"), 0, .7);
        return new double[] { center.X, center.Y, weight, Random(cell, 859) };
    }
    public Vector2 shoreline_offset(double x, double z)
    {
        double strength = Math.Min(Math.Max(P("shoreline_detail_strength"), 0), Math.Max(P("shoreline_detail_size"), 50) * .3);
        return new Vector2(shoreline.GetNoise2D((float)x, (float)z), shoreline.GetNoise2D((float)(x + 9371), (float)(z - 3517))) * (float)strength;
    }
    private double[][] Sites(Vector2I cell)
    {
        if(sitesMirror is null)
        {
            if (_sites.TryGetValue(cell, out var cached)) return cached;
        }
        else
        {
            if(sitesMirror.Count==0)_sites.Clear();
            if(sitesMirror.TryGetValue(cell,out var data))
            {
                if(_sites.TryGetValue(cell,out var cached))return cached;
                var payload=data.AsGodotArray();var imported=new double[payload.Count][];
                for(int i=0;i<imported.Length;i++)imported[i]=payload[i].AsFloat64Array();
                return _sites[cell]=imported;
            }
        }
        var result = new double[25][]; int index = 0;
        for (int z = -2; z <= 2; z++) for (int x = -2; x <= 2; x++)
            result[index++] = candidate(cell + new Vector2I(x, z));
        if ((sitesMirror?.Count??_sites.Count) > 512) { sitesMirror?.Clear(); _sites.Clear(); }
        PublishSites(cell,result);_sites[cell] = result; return result;
    }
    private void PublishSites(Vector2I cell,double[][] values)
    {
        if(sitesMirror is null)return;
        var payload=new A();foreach(var value in values)payload.Add(value);sitesMirror[cell]=payload;
    }
    private bool TryPlanes(Vector3I key,out Vector3[] result)
    {
        if(planesMirror is null)return _planes.TryGetValue(key,out result!);
        if(planesMirror.Count==0)_planes.Clear();
        if(!planesMirror.TryGetValue(key,out var payload)){result=System.Array.Empty<Vector3>();return false;}
        if(_planes.TryGetValue(key,out result!))return true;
        result=payload.AsVector3Array();_planes[key]=result;return true;
    }
    private bool TryOwner(Vector2I cell,out int owner)
    {
        if(ownersMirror is null)return _owners.TryGetValue(cell,out owner);
        if(ownersMirror.TryGetValue(cell,out var value)){owner=value.AsInt32();return true;}
        owner=0;return false;
    }
    private bool TryCertificate(Vector2I cell,out Vector3 certificate)
    {
        if(certificatesMirror is null)return _certificates.TryGetValue(cell,out certificate);
        if(certificatesMirror.TryGetValue(cell,out var value)){certificate=value.AsVector3();return true;}
        certificate=default;return false;
    }
    public void remember_coast(Vector2I cell, Vector2 point, double distance)
    {
        if((certificatesMirror?.Count??_certificates.Count)>=512){certificatesMirror?.Clear();_certificates.Clear();}
        var value=new Vector3(point.X,point.Y,(float)distance);
        if(certificatesMirror is not null)certificatesMirror[cell]=value;else _certificates[cell]=value;
    }
    public double mask(double x, double z) => mask(x, z, false, 0);
    public double mask(double x, double z, bool heightQuery, double coastLimit)
    {
        double p = pitch(), size = P("island_size"), warp = Math.Max(size, 16) * Math.Clamp(P("island_coast_irregularity"), 0, .6) * .55;
        var point = new Vector2((float)x, (float)z);
        point.X = (float)(point.X + continent.GetNoise2D((float)x, (float)z) * warp);
        double scale = Math.Max(size, 16) / 1388.89;
        point.Y = (float)(point.Y + continent.GetNoise2D((float)(x + 7139 * scale), (float)(z - 4193 * scale)) * warp);
        point += shoreline_offset(x, z);
        var cell = new Vector2I((int)Math.Floor(point.X / p + .5), (int)Math.Floor(point.Y / p + .5));
        double coast = Math.Max(Math.Max(P("coast_width") * 694.445, .1), coastLimit) + 1, denominator = Math.Max(size * .5, 8);
        if (heightQuery && TryCertificate(cell,out var certificate))
        {
            if (certificate.Z - (double)point.DistanceTo(new Vector2(certificate.X, certificate.Y)) > coast)
                return Math.Max(1, coast / denominator);
        }
        var candidates = Sites(cell);
        double erosion = Math.Max(P("land_threshold") - .4, 0) * size * .25;
        if (TryOwner(cell,out int previous))
        {
            var previousKey = new Vector3I(cell.X, cell.Y, previous);
            if (TryPlanes(previousKey,out var previousPlanes))
            {
                var oldOwner = candidates[previous];
                var oldRelative = new Vector3((float)(point.X - oldOwner[0]), (float)(point.Y - oldOwner[1]), 1);
                double interior = double.PositiveInfinity;
                foreach (var plane in previousPlanes) interior = Math.Min(interior, plane.Dot(oldRelative));
                if (interior > 0) { double distance = interior - erosion; remember_coast(cell, point, distance); return distance / denominator; }
            }
        }
        double best = double.PositiveInfinity; int winner = 0;
        for (int i = 0; i < candidates.Length; i++)
        {
            var site = candidates[i]; double score = point.DistanceSquaredTo(new Vector2((float)site[0], (float)site[1])) - site[2];
            if (score < best) { best = score; winner = i; }
        }
        var owner = candidates[winner];
        if((ownersMirror?.Count??_owners.Count)>=512){ownersMirror?.Clear();_owners.Clear();}
        if(ownersMirror is not null)ownersMirror[cell]=winner;else _owners[cell]=winner;
        var key = new Vector3I(cell.X, cell.Y, winner);
        if (!TryPlanes(key,out var currentPlanes))
        {
            var planes = new Vector3[candidates.Length - 1]; int index = 0;
            for (int i = 0; i < candidates.Length; i++)
            {
                if (i == winner) continue;
                var site = candidates[i]; var delta = new Vector2((float)(site[0] - owner[0]), (float)(site[1] - owner[1]));
                double length = delta.Length(), pair = (site[3] + owner[3]) * 43758.5453; pair -= Math.Floor(pair);
                double variation = Math.Clamp(P("island_spacing_variation"), 0, .95), opening = gap() * ((1 - variation) + ((1 + variation) - (1 - variation)) * pair);
                planes[index++] = new Vector3((float)(-delta.X / length), (float)(-delta.Y / length), (float)((delta.LengthSquared() + owner[2] - site[2]) / (2 * length) - opening * .5));
            }
            if((planesMirror?.Count??_planes.Count)>=128){planesMirror?.Clear();_planes.Clear();}
            _planes[key]=planes;if(planesMirror is not null)planesMirror[key]=planes;currentPlanes=planes;
        }
        double boundary = double.PositiveInfinity;
        var relative = new Vector3((float)(point.X - owner[0]), (float)(point.Y - owner[1]), 1);
        foreach (var plane in currentPlanes) boundary = Math.Min(boundary, plane.Dot(relative));
        remember_coast(cell, point, boundary - erosion); return (boundary - erosion) / denominator;
    }
}
