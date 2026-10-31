using Godot;
using System;
using System.Linq;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Reserves physical hive conduits, junction shoulders and finite galleries around open cave breaches.</summary>
public partial class CaveHiveEntryGuard : RefCounted
{
    public GodotObject builder { get; set; } = null!;
    public D _finite { get; set; } = new();
    public void configure(GodotObject owner) { builder = owner; _finite.Clear(); }
    private GodotObject? Field => builder.Get("_extras").AsGodotArray()[7].AsGodotObject();
    public bool clear_point(Vector3 point, double radius)
    {
        if (!point.IsFinite()) return false;
        var field = Field; if (field == null) return true;
        var p = new Vector2(point.X,point.Z); var network = field.Call("network",p).AsGodotDictionary(); var settings = field.Get("settings").AsGodotObject();
        double junction = settings.Get("hive_junction_width").AsDouble() * settings.Get("feature_scale").AsDouble() * 4 + 64;
        if (network["trunk_distance"].AsDouble() < 240 + radius || network["branch_distance"].AsDouble() < 160 + radius || network["center_distance"].AsDouble() < junction + radius) return false;
        var cell = new Vector2I((int)Math.Floor((double)p.X/64),(int)Math.Floor((double)p.Y/64));
        if (!_finite.ContainsKey(cell))
        {
            using var features = new Terrain.TerrainFeatureMeshes { builder = builder };
            if (_finite.Count >= 64) _finite.Remove(_finite.Keys.First());
            _finite[cell] = features.portal_sites(new Rect2((Vector2)cell*64,Vector2.One*64).Grow((float)(400+radius)));
        }
        foreach (var item in _finite[cell].AsGodotArray())
        {
            var site = item.AsGodotDictionary(); if (p.DistanceTo(site["position"].AsVector2()) < Math.Max(320,site["half"].AsDouble()*1.2)+radius) return false;
        }
        return true;
    }
    public bool clear_access(D edge)
    {
        if (Field == null) return true;
        var points = edge["points"].AsVector3Array(); if (points.Length < 2) return false;
        var first = points[0]; var direction = new Vector2(points[1].X-first.X,points[1].Z-first.Z).Normalized(); double width = edge["half_width"].AsDouble();
        for (int station=0;station<6;station++)
        {
            var p = first-new Vector3(direction.X,0,direction.Y)*station*8; p.Y=(float)builder.Call("_get_height",p.X,p.Z).AsDouble();
            if (p.Y <= builder.Call("get_water_surface_height",p.X,p.Z).AsDouble()+2 || !clear_point(p,width)) return false;
        }
        foreach (var p in points) if (builder.Call("_get_height",p.X,p.Z).AsDouble()-p.Y<=64 && !clear_point(p,width)) return false;
        return true;
    }
}
