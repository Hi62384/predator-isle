using System.Linq;
using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Bounded, deterministic regions with independently proven dry return routes.</summary>
public partial class CaveNetwork : RefCounted
{
    private static readonly StringName NodeIdKey = "id";
    public GodotObject Solver { get; set; } = new RouteSolver();
    private readonly CaveChamberProfiles Profiles = new();
    private readonly CaveSeepageBasins Basins = new();
    internal double OceanLevel {get;set;}=double.NegativeInfinity;
    internal int EntrancesPerRegion {get;set;}=1;
    public double REGION_METRES => 1536; public int MAX_REGIONS => 32;
    private Callable _height,_water;
    private Func<double,double,double>? _sampleHeight,_sampleWater;
    public Callable height { get=>_height; set { _height=value;_sampleHeight=CaveHeightSampler.Bind(value); } }
    public Callable water { get=>_water; set { _water=value;_sampleWater=CaveHeightSampler.Bind(value); } }
    private double Height(double x,double z)=>_sampleHeight is not null?_sampleHeight(x,z):_height.Call(x,z).AsDouble();
    private double Water(double x,double z)=>_sampleWater is not null?_sampleWater(x,z):_water.Call(x,z).AsDouble();
    public long seed_id { get; set; } = 73921; public double max_depth { get; set; } = 400;
    public double half_width { get; set; } = 4; public double headroom { get; set; } = 8; public double minimum_roof { get; set; } = 10; public double maximum_grade { get; set; } = .2; public double activity { get; set; } = .85;
    public bool chamber_variety { get; set; } public bool geological_morphology { get; set; } public double seepage_density { get; set; } public double flat_radius { get; set; } = 26;
    public Callable region_context { get; set; } public Callable region_decorator { get; set; } public Callable region_finalizer { get; set; } public Callable access_admission { get; set; }
    public D _active_context { get; set; } = new(); public D _regions { get; set; } = new(); public D last_support_conflict { get; set; } = new();
    private readonly Queue<Vector2I> _ring = new();
    private static Variant Get(D d, string key, Variant fallback = default) => d.ContainsKey(key) ? d[key] : fallback;
    private static double Number(D d, string key, double fallback = 0) => d.ContainsKey(key) ? d[key].AsDouble() : fallback;
    private static A Items(D d, string key) => Get(d, key, new A()).AsGodotArray();
    private static bool Valid(Callable c) => c.Delegate != null || GodotObject.IsInstanceValid(c.Target) && c.Target.HasMethod(c.Method);
    private static Vector2 Xz(Vector3 p) => new(p.X, p.Z);
    private static double Lerp(double a, double b, double t) => a + (b - a) * t;
    private static double Smooth(double a, double b, double x) { double t = Math.Clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    public void configure(Callable surface, Callable water_surface, long seed_value) => configure(surface, water_surface, seed_value, 400);
    public void configure(Callable surface, Callable water_surface, long seed_value, double depth)
    { height = surface; water = water_surface; seed_id = seed_value; max_depth = depth; _regions.Clear(); _ring.Clear(); }
    // Independent avalanche mixing avoids correlated regional/salt sequences,
    // including negative coordinates. Values are strictly in [0,1).
    internal static double SeededRandom(Vector2I cell,long seed,long salt)
    {
        static ulong Mix(ulong x)
        {
            unchecked { x=(x^(x>>30))*0xbf58476d1ce4e5b9UL; x=(x^(x>>27))*0x94d049bb133111ebUL; return x^(x>>31); }
        }
        unchecked
        {
            ulong h=Mix((ulong)seed+0x9e3779b97f4a7c15UL);
            h=Mix(h^Mix((ulong)(long)cell.X+0x243f6a8885a308d3UL));
            h=Mix(h^Mix((ulong)(long)cell.Y+0x13198a2e03707344UL));
            h=Mix(h^Mix((ulong)salt+0xa4093822299f31d0UL));
            return (h>>11)*(1.0/9007199254740992.0);
        }
    }
    public double random(Vector2I cell,long salt)=>SeededRandom(cell,seed_id,salt);
    // Continuous value fields at independent geological scales. Coordinates,
    // not the discovery region or iteration order, own each lattice corner.
    internal double GeologyAt(Vector2 point,double scale,long salt)
    {
        double x=point.X/scale,z=point.Y/scale;
        int ix=(int)Math.Floor(x),iz=(int)Math.Floor(z);
        double u=Smooth(0,1,x-ix),v=Smooth(0,1,z-iz);
        return Lerp(Lerp(random(new(ix,iz),salt),random(new(ix+1,iz),salt),u),
            Lerp(random(new(ix,iz+1),salt),random(new(ix+1,iz+1),salt),u),v);
    }
    private double FractureBearing(Vector2 p)
    {
        double x=GeologyAt(p,2700,82001)*2-1,z=GeologyAt(p,2700,82005)*2-1;
        return Math.Atan2(z,x)+(GeologyAt(p,430,82006)-.5)*1.8;
    }
    public Vector2[] curve(Vector2[] control)
    {
        var path = new List<Vector2>();
        for (int segment = 0; segment < control.Length - 1; segment++)
        {
            var a = control[segment]; var b = control[segment + 1]; var before = control[Math.Max(0, segment - 1)]; var after = control[Math.Min(control.Length - 1, segment + 2)];
            var c = a + (b - before) / 6; var d = b - (after - a) / 6; int count = Math.Max(2, (int)Math.Ceiling(((double)a.DistanceTo(c) + c.DistanceTo(d) + d.DistanceTo(b)) / 6));
            for (int i = 0; i < count; i++) { double t = (double)i / count, s = 1 - t; path.Add(a * (float)s * (float)s * (float)s + c * 3 * (float)s * (float)s * (float)t + d * 3 * (float)s * (float)t * (float)t + b * (float)t * (float)t * (float)t); }
        }
        path.Add(control[^1]); return path.ToArray();
    }
    public D node_floor(Vector2 p, double depth)
    {
        double low = double.NegativeInfinity, high = double.PositiveInfinity;
        for (int dz = -1; dz <= 1; dz++) for (int dx = -1; dx <= 1; dx++)
        {
            double h = Height((double)p.X + dx * 24, (double)p.Y + dz * 24); if (!double.IsFinite(h)) return new();
            low = Math.Max(low, h - max_depth + 4 + Number(_active_context, "planning_depth_reserve")); high = Math.Min(high, h - minimum_roof - 18);
        }
        low=Math.Max(low,-1000.0);
        if (low > high) return new();
        return new D { ["point"] = new Vector3(p.X, (float)Math.Clamp(Height(p.X, p.Y) - depth, low, high), p.Y), ["half_width"] = half_width, ["headroom"] = headroom, ["chamber_radius"] = 18.0, ["chamber_height"] = 18.0 };
    }
    public D route(D a, D b, Vector2[] controls) => route(a, b, controls, false, 0);
    public D route(D a, D b, Vector2[] controls, bool entry) => route(a, b, controls, entry, 0);
    public D route(D a, D b, Vector2[] controls, bool entry, double extra_depth_reserve)
    {
        var path = curve(controls); float[] cover = System.Array.Empty<float>();
        double startFlat=entry?0:Math.Max(flat_radius,Number(a,"chamber_radius")+half_width+2);
        double endFlat=Math.Max(flat_radius,Number(b,"chamber_radius")+half_width+2);
        if (entry)
        { double length = 0; var distances = new double[path.Length]; for (int i = 1; i < path.Length; i++) { length += path[i].DistanceTo(path[i - 1]); distances[i] = length; } cover = new float[path.Length]; for (int i = 0; i < path.Length; i++) cover[i] = (float)Smooth(0, .75, distances[i] / length); }
        double reserve = Math.Max(extra_depth_reserve, Number(_active_context, "planning_depth_reserve"));
        var solved = Solver is RouteSolver native ? native.solve(path, height, half_width, headroom, minimum_roof, max_depth - reserve, maximum_grade, a["point"].AsVector3().Y, b["point"].AsVector3().Y, cover, startFlat, endFlat)
            : Solver.Call("solve", path, height, half_width, headroom, minimum_roof, max_depth - reserve, maximum_grade, a["point"].AsVector3().Y, b["point"].AsVector3().Y, cover, startFlat, endFlat).AsGodotDictionary();
        if (!solved["valid"].AsBool() || solved["points"].AsVector3Array().Any(p=>p.Y < -1000.001f)) return new();
        return new D { ["from"] = a["id"], ["to"] = b["id"], ["points"] = solved["points"], ["half_width"] = half_width, ["headroom"] = headroom, ["entrance"] = entry, ["maximum_grade"] = solved["maximum_grade"], ["minimum_measured_roof_m"] = solved["minimum_measured_roof_m"], ["maximum_measured_depth_m"] = solved["maximum_measured_depth_m"] };
    }
    // Fractures occasionally divide a buried reach and rejoin it downstream.
    // Follow its local floor so both openings share a traversable threshold.
    private A BuildBypasses(Vector2I cell,A edges)
    {
        var bypasses=new A();
        int originalCount=edges.Count;
        for(int i=0;i<originalCount;i++)
        {
            var edge=edges[i].AsGodotDictionary();
            var points=edge["points"].AsVector3Array();
            int salt=64000+i*5;
            if(points.Length<12 || random(cell,salt)>.43)continue;
            int first=(int)(points.Length*(.22+.17*random(cell,salt+1)));
            int last=Math.Min(points.Length-1,first+6+(int)(random(cell,salt+2)*10));
            var a=points[first];var b=points[last];
            if(Height(a.X,a.Z)-a.Y<headroom+minimum_roof+3 || Height(b.X,b.Z)-b.Y<headroom+minimum_roof+3)continue;
            var normal=(Xz(b)-Xz(a)).Normalized().Orthogonal();
            float offset=(float)((12+random(cell,salt+3)*22)*(random(cell,salt+4)<.5?-1:1));
            var start=new D{["id"]=edge["from"],["point"]=a};
            var end=new D{["id"]=edge["to"],["point"]=b};
            var side=route(start,end,new[]{Xz(a),Xz(points[(2*first+last)/3])+normal*offset,
                Xz(points[(first+2*last)/3])+normal*offset*.62f,Xz(b)});
            if(side.Count==0 || !supported_join(side,edges) || !supported_join(side,bypasses))continue;
            side["half_width"]=half_width*(.56+.23*random(cell,salt+2));
            side["headroom"]=headroom*(.62+.35*random(cell,salt+4));
            side["bypass"]=true;
            side["profile_phase"]=random(cell,salt)*Math.Tau;
            bypasses.Add(side);
        }
        return bypasses;
    }
    // Spatial broad phase for the exact symmetric support test. Segment IDs
    // are visited at most once per candidate station regardless of bin overlap.
    private readonly record struct SupportSegment(D Edge,Vector3 A,Vector3 B,double Width,double Height);
    public bool supported_join(D candidate,A retained)
    {
        last_support_conflict=new D();
        var points=candidate["points"].AsVector3Array();
        var segments=new List<SupportSegment>();
        var bins=new Dictionary<Vector2I,List<int>>();
        double candidateWidth=Number(candidate,"half_width"),candidateHeight=Number(candidate,"headroom"),largestWidth=0;
        static int Cell(float x)=>Mathf.FloorToInt(x/64);
        foreach(var value in retained)
        {
            var edge=value.AsGodotDictionary();var previous=edge["points"].AsVector3Array();
            double width=Number(edge,"half_width"),height=Number(edge,"headroom");
            largestWidth=Math.Max(largestWidth,width);
            for(int j=0;j<previous.Length-1;j++)
            {
                var c=previous[j];var d=previous[j+1];int id=segments.Count;
                segments.Add(new SupportSegment(edge,c,d,width,height));
                for(int z=Cell(Math.Min(c.Z,d.Z));z<=Cell(Math.Max(c.Z,d.Z));z++)
                    for(int x=Cell(Math.Min(c.X,d.X));x<=Cell(Math.Max(c.X,d.X));x++)
                    {
                        var key=new Vector2I(x,z);
                        if(!bins.TryGetValue(key,out var bucket))bins[key]=bucket=new();
                        bucket.Add(id);
                    }
            }
        }
        var seen=new int[segments.Count];
        float reach=(float)(candidateWidth+largestWidth+2);
        for(int i=0;i<points.Length-1;i++)
        {
            var a=points[i];var b=points[i+1];var ab=Xz(b-a);
            for(int z=Cell(Math.Min(a.Z,b.Z)-reach);z<=Cell(Math.Max(a.Z,b.Z)+reach);z++)
                for(int x=Cell(Math.Min(a.X,b.X)-reach);x<=Cell(Math.Max(a.X,b.X)+reach);x++)
                {
                    if(!bins.TryGetValue(new Vector2I(x,z),out var bucket))continue;
                    foreach(int id in bucket)
                    {
                        if(seen[id]==i+1)continue;seen[id]=i+1;
                        var segment=segments[id];var c=segment.A;var d=segment.B;
                        double clearance=candidateWidth+segment.Width+2,height=Math.Max(candidateHeight,segment.Height)+3;
                        if(Math.Max(a.X,b.X)+clearance<Math.Min(c.X,d.X)||Math.Min(a.X,b.X)-clearance>Math.Max(c.X,d.X)||
                           Math.Max(a.Z,b.Z)+clearance<Math.Min(c.Z,d.Z)||Math.Min(a.Z,b.Z)-clearance>Math.Max(c.Z,d.Z)||
                           Math.Max(a.Y,b.Y)+height<Math.Min(c.Y,d.Y)||Math.Min(a.Y,b.Y)-height>Math.Max(c.Y,d.Y))continue;
                        var cd=Xz(d-c);
                        for(int step=0;step<3;step++)
                        {
                            var p=a.Lerp(b,step*.5f);var q=Xz(p-c);double u=Math.Clamp(q.Dot(cd)/Math.Max(cd.LengthSquared(),.000001),0,1);
                            if((q-cd*(float)u).Length()>=clearance)continue;
                            if(Conflict(Math.Abs(p.Y-Lerp(c.Y,d.Y,u)),height,p,segment.Edge))return false;
                        }
                        for(int step=0;step<3;step++)
                        {
                            var p=c.Lerp(d,step*.5f);var q=Xz(p-a);double t=Math.Clamp(q.Dot(ab)/Math.Max(ab.LengthSquared(),.000001),0,1);
                            if((q-ab*(float)t).Length()>=clearance)continue;
                            if(Conflict(Math.Abs(p.Y-Lerp(a.Y,b.Y,t)),height,p,segment.Edge))return false;
                        }
                    }
                }
        }
        return true;
        bool Conflict(double separation,double height,Vector3 point,D edge)
        {
            if(separation<=.35||separation>=height)return false;
            last_support_conflict=new D{["point"]=point,["separation"]=separation,["edge"]=edge["from"].AsString()+">"+edge["to"].AsString()};
            return true;
        }
    }
    // Follow locally varying fractures. Keep the initial heading at the lip so
    // the surface opening still ties into the same approach.
    private Vector2[] AccessControls(Vector2I cell, int attempt, Vector2 start, Vector2 end)
    {
        var delta = end - start;
        var side = delta.Orthogonal().Normalized();
        int salt = 18000 + attempt * 40;
        int spans = Math.Clamp((int)(delta.Length() / (40 + 35 * random(cell, salt))), 3, 18);
        var controls = new Vector2[spans + 1];
        controls[0] = start;
        controls[spans] = end;
        for (int i = 1; i < spans; i++)
        {
            float t = (float)i / spans;
            float bend = (float)((random(cell, salt + i) - .5) * Math.Min(80, delta.Length() / spans));
            controls[i] = start + delta * t + side * (bend * Mathf.Sin(Mathf.Pi * t));
        }
        return controls;
    }
    public D _build(Vector2I cell)
    {
        var empty = new D { ["id"] = cell, ["nodes"] = new A(), ["edges"] = new A(), ["entrances"] = new A(), ["valid"] = false, ["reason"] = "no_admitted_dry_return_route" };
        if (!Valid(height) || !Valid(water) || max_depth < 80 || max_depth > 10000) return empty;
        if (random(new Vector2I((int)Math.Floor(cell.X / 3.0), (int)Math.Floor(cell.Y / 3.0)), 17) > activity) return empty;
        var center = ((Vector2)cell + new Vector2((float)(.4 + .2 * random(cell, 1)), (float)(.4 + .2 * random(cell, 2)))) * 1536; double angle = random(cell, 3) * Math.Tau; var nodes = new A(); var edges = new A(); var entrances = new A();
        var first=node_floor(center+new Vector2(-120,-120).Rotated((float)angle),Math.Min(50,max_depth*.2));
        if(first.Count==0)return empty;
        first[NodeIdKey]=FormattableString.Invariant($"{cell.X}:{cell.Y}:root");
        first["level"]=0;
        first["entry_anchor"]=true;
        first["shape_seed"]=(long)(random(cell,82000)*9007199254740992.0);
        nodes.Add(first);
        var origin=(Vector2)cell*(float)REGION_METRES;
        bool Inside(Vector2 p,float margin)=>p.X>=origin.X+margin&&p.Y>=origin.Y+margin&&
            p.X<=origin.X+REGION_METRES-margin&&p.Y<=origin.Y+REGION_METRES-margin;

        // A region's fracture bearing changes continuously through space,
        // while its branching, extent and depth are independently seeded.
        double Fracture(Vector2 p)=>FractureBearing(p);
        int serial=0;
        double reserve=Number(_active_context,"planning_depth_reserve");
        double floorLimit=Math.Max(-1000,Height(center.X,center.Y)-max_depth+reserve+8);
        double startY=first["point"].AsVector3().Y;
        double depthRoll=random(cell,82002),depthFraction=random(cell,82003);
        double fraction=depthRoll<.23?.13+.24*depthFraction:depthRoll<.58?.40+.43*depthFraction:1;
        double targetY=Lerp(startY,Math.Min(startY,floorLimit),fraction);
        double permeability=GeologyAt(center,1800,82007);
        double regionalDensity=.45*random(cell,82004)+.55*permeability;
        double bedding=GeologyAt(center,940,82008);
        int shallowSteps=1+(int)(regionalDensity*3);

        // Every admitted child is connected by a proven grade/roof-safe route.
        // Failed proposals retry different headings, lengths, parents and
        // floor targets instead of ending a complete depth tier.
        bool Grow(D parent,bool descending,bool shallow,double desiredFloor,out D child)
        {
            int ordinal=serial++;
            child=new D();
            var a=parent["point"].AsVector3();var p=Xz(a);
            for(int attempt=0;attempt<16;attempt++)
            {
                long salt=90000+ordinal*256L+attempt*12L;
                double bearing=attempt<6?Fracture(p)+(random(cell,salt)<.5?0:Math.PI)+(random(cell,salt+1)-.5)*2.5:random(cell,salt+1)*Math.Tau;
                double span=(descending?245:105)+(descending?295:390)*random(cell,salt+2);
                if(!descending&&!shallow)span*=.75+.5*GeologyAt(p,670,82009);
                var q=p+new Vector2((float)Math.Cos(bearing),(float)Math.Sin(bearing))*(float)span;
                if(!Inside(q,85))continue;
                var delta=q-p;var side=delta.Orthogonal();
                float bend=(float)((random(cell,salt+3)-.5)*.64);
                float bend2=(float)((random(cell,salt+4)-.5)*.50);
                var m1=p.Lerp(q,.28f)+side*bend;var m2=p.Lerp(q,.71f)+side*bend2;
                // A second fracture family can create sinuous longer descents,
                // instead of forcing every edge into a two-bend motif.
                var controls=new List<Vector2>{p,m1};
                if(random(cell,salt+9)<.42)
                {
                    var middle=p.Lerp(q,.50f)+side*(float)((random(cell,salt+10)-.5)*.84);
                    if(!Inside(middle,40))continue;
                    controls.Add(middle);
                }
                controls.Add(m2);controls.Add(q);
                if(!Inside(m1,40)||!Inside(m2,40))continue;
                double routeLength=0;for(int j=1;j<controls.Count;j++)routeLength+=controls[j].DistanceTo(controls[j-1]);
                double possible=Math.Max(0,Math.Min(routeLength*.92,span*1.20)-Math.Max(flat_radius,Number(parent,"chamber_radius")+half_width+2)-flat_radius-12)*maximum_grade;
                double goal=descending?Math.Max(desiredFloor,a.Y-possible*(.67+.25*random(cell,salt+5))):
                    a.Y+possible*(random(cell,salt+5)-.5)*(shallow?.28:1.35);
                var node=node_floor(q,Height(q.X,q.Y)-goal);
                if(node.Count==0)continue;
                var point=node["point"].AsVector3();
                if(descending&&point.Y>a.Y-Math.Min(8,Math.Max(0,a.Y-desiredFloor)*.5))continue;
                if(shallow&&Height(q.X,q.Y)-point.Y>100)continue;
                if(nodes.Any(raw=>raw.AsGodotDictionary()["point"].AsVector3().DistanceSquaredTo(point)<72*72))continue;
                double localDepth=Height(q.X,q.Y)-point.Y;
                node[NodeIdKey]=FormattableString.Invariant($"{cell.X}:{cell.Y}:growth:{ordinal}");
                // Legacy level metadata is only a coarse classification for
                // biome consumers and entrance access, never a generation tier.
                node["level"]=shallow?0:Math.Clamp((int)(localDepth/Math.Max(100,max_depth*.27)),0,3);
                node["shape_seed"]=(long)(random(cell,salt+6)*9007199254740992.0);
                if(shallow)node["entry_anchor"]=true;
                // Independently vary horizontal and vertical growth. Rare
                // soluble zones admit rooms over 100m across; resistant zones
                // stay narrow. Large envelopes are cleared BEFORE solving so
                // the joining route has a genuinely level room threshold.
                double localSolubility=GeologyAt(q,560,82007);
                double radius=Math.Max(half_width+2,7+(25+47*localSolubility)*Math.Pow(random(cell,salt+7),2.0));
                double room=Math.Max(headroom,8+(26+48*bedding)*Math.Pow(random(cell,salt+8),1.8));
                if(!geological_morphology){radius=Math.Min(radius,30);room=Math.Min(room,30);}
                if(shallow){radius=Math.Min(radius,28);room=Math.Min(room,30);}
                var occupancy=new D{["nodes"]=nodes,["edges"]=edges};
                D edge=new();
                for(int shrink=0;shrink<3;shrink++)
                {
                    node["chamber_radius"]=radius;node["chamber_height"]=room;
                    if(RoomFits(point,radius,room)&&Profiles.compatible(point,radius,room,occupancy,new A()))
                    {
                        edge=route(parent,node,controls.ToArray());
                        if(edge.Count>0&&supported_join(edge,edges)&&
                            !edge["points"].AsVector3Array().Any(v=>!Inside(Xz(v),12)))break;
                    }
                    edge=new();
                    radius=shrink==0?Math.Max(half_width+1,radius*.58):half_width+1;
                    room=shrink==0?Math.Max(headroom,room*.65):headroom;
                }
                if(edge.Count==0)continue;
                edge["growth_role"]=descending?"descent":shallow?"access_spine":"branch";
                node["geology_bearing"]=Fracture(q);
                node["geology_solubility"]=localSolubility;
                node["geology_bedding"]=GeologyAt(q,940,82008);
                nodes.Add(node);edges.Add(edge);child=node;return true;
            }
            return false;
        }
        bool RoomFits(Vector3 point,double radius,double room)
        {
            if(!Inside(Xz(point),(float)(radius+8)))return false;
            for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++)
            {
                if(x*x+z*z>4)continue;
                double h=Height(point.X+x*radius*.5,point.Z+z*radius*.5);
                if(!double.IsFinite(h)||h-point.Y<minimum_roof+room+4||h-point.Y>max_depth-reserve-4)return false;
            }
            return true;
        }
        var previous=first;
        for(int i=0;i<shallowSteps;i++)
        {
            if(Grow(previous,false,true,startY,out var child))previous=child;
            else if(Grow(first,false,true,startY,out child))previous=child;
        }
        if(nodes.Count<2)return empty;
        var descent=previous;
        int failed=0,steps=Math.Clamp((int)Math.Ceiling((startY-targetY)/22)+5,8,48);
        for(int i=0;i<steps&&descent["point"].AsVector3().Y>targetY+1;i++)
        {
            if(Grow(descent,true,false,targetY,out var child)){descent=child;failed=0;continue;}
            // A difficult junction need not strand an otherwise viable network.
            // Continue from another deepest reachable room, or lengthen the
            // current descent by first establishing a lateral tributary.
            var alternatives=nodes.Select(v=>v.AsGodotDictionary()).OrderBy(n=>n["point"].AsVector3().Y).Take(4).ToArray();
            bool progressed=false;
            foreach(var parent in alternatives)
            {
                if(parent==descent)continue;
                if(Grow(parent,true,false,targetY,out child)){if(child["point"].AsVector3().Y<descent["point"].AsVector3().Y)descent=child;progressed=true;break;}
            }
            if(!progressed&&Grow(descent,false,false,targetY,out child)){descent=child;progressed=true;}
            if(progressed)failed=0;else if(++failed>=3)break;
        }
        int tributaries=3+(int)(regionalDensity*regionalDensity*19);
        for(int i=0;i<tributaries&&nodes.Count<72;i++)
        {
            // Repeated branching from a newly grown tributary creates
            // hierarchies; a separate roll returns to a primary trunk.
            int parentIndex=(int)(random(cell,83000+i)*nodes.Count);
            if(i>0&&random(cell,83100+i)<.35+regionalDensity*.3)parentIndex=nodes.Count-1;
            var parent=nodes[parentIndex].AsGodotDictionary();
            Grow(parent,false,false,targetY,out _);
        }
        int loopBudget=1+(int)(random(cell,83080)*(5+regionalDensity*9));
        for(int i=0,attempt=0;i<loopBudget&&attempt<loopBudget*12;attempt++)
        {
            long salt=84000+attempt*4;
            var from=nodes[(int)(random(cell,salt)*nodes.Count)].AsGodotDictionary();
            var to=nodes[(int)(random(cell,salt+1)*nodes.Count)].AsGodotDictionary();
            if(from==to)continue;
            string fromId=from["id"].AsString(),toId=to["id"].AsString();
            if(edges.Any(v=>{var e=v.AsGodotDictionary();string a=e["from"].AsString(),b=e["to"].AsString();return (a==fromId&&b==toId)||(a==toId&&b==fromId);}))continue;
            var aPoint=from["point"].AsVector3();var bPoint=to["point"].AsVector3();
            var p=Xz(aPoint);var q=Xz(bPoint);double distance=p.DistanceTo(q);
            if(distance<120||distance>570||Math.Abs(aPoint.Y-bPoint.Y)>(distance-2*flat_radius)*maximum_grade*.8)continue;
            var mid=(p+q)*.5f+(q-p).Orthogonal()*(float)((random(cell,salt+2)-.5)*.45);
            if(!Inside(mid,40))continue;
            var loop=route(from,to,new[]{p,mid,q});
            if(loop.Count==0||!supported_join(loop,edges)||loop["points"].AsVector3Array().Any(v=>!Inside(Xz(v),12)))continue;
            loop["growth_role"]="loop";edges.Add(loop);i++;
        }
        // Density is independent of underground graph size. Bias the budget toward
        // one or two mouths; the configured count is a ceiling, not a quota.
        int entranceBudget = 1 + Math.Min(EntrancesPerRegion - 1,
            (int)(Math.Pow(random(cell, 75001), 1.8) * EntrancesPerRegion));
        if(Number(_active_context,"family",-1)!=7 && random(cell,75002)<.13)entranceBudget=0;
        const float minimumSeparation = 400;
        var regionOrigin = (Vector2)cell * (float)REGION_METRES;
        for (int attempt = 0; attempt < 24 * entranceBudget; attempt++)
        {
            double yaw = angle + Math.Tau * random(cell, 40 + attempt); var p = center + new Vector2((float)Math.Cos(yaw), (float)Math.Sin(yaw)) * (float)(360 + random(cell, 80 + attempt) * 220);
            if (attempt >= 24)
            {
                // Visit all 25 sectors before retrying one. The coprime stride
                // spreads successive candidates across the whole region.
                int sector = attempt * 7 % 25;
                double u = (sector % 5 + .15 + .7 * random(cell, 1000 + attempt * 2)) / 5;
                double v = (sector / 5 + .15 + .7 * random(cell, 1001 + attempt * 2)) / 5;
                p = new Vector2((float)((cell.X + u) * REGION_METRES), (float)((cell.Y + v) * REGION_METRES));
            }
            // Half the separation on each side of a region boundary gives the
            // same lower bound across independently discovered neighbouring regions.
            var local = p - regionOrigin;
            float margin = minimumSeparation * .5f;
            if(local.X < margin || local.Y < margin || local.X > REGION_METRES-margin || local.Y > REGION_METRES-margin)continue;
            if (nodes.Any(v=>v.AsGodotDictionary()["level"].AsInt32()==-1 && Xz(v.AsGodotDictionary()["point"].AsVector3()).DistanceSquaredTo(p)<minimumSeparation*minimumSeparation))continue;
            if (!CaveHeightSampler.TrySamplePair(height, water, p.X, p.Y, out double terrain, out double wet))
            { terrain = Height(p.X, p.Y); wet = Water(p.X, p.Y); }
            if (!double.IsFinite(terrain) || !double.IsFinite(wet) || terrain <= Math.Max(wet,OceanLevel) + 3) continue;
            double low = terrain, high = terrain;
            foreach (var offset in new[] { new Vector2(8, 0), new Vector2(-8, 0), new Vector2(0, 8), new Vector2(0, -8) }) { double h = Height((double)p.X + offset.X, (double)p.Y + offset.Y); low = Math.Min(low, h); high = Math.Max(high, h); }
            if (low <= Math.Max(wet,OceanLevel)+2 || high - low > headroom*.85) continue;
            var entry = new D { ["id"] = FormattableString.Invariant($"{cell.X}:{cell.Y}:entrance:{attempt}"), ["point"] = new Vector3(p.X, (float)(low - Math.Min(headroom*.25,1.5)), p.Y), ["level"] = -1 };
            D access=new();
            foreach(var destination in nodes.Select(v=>v.AsGodotDictionary())
                .Where(n=>Get(n,"entry_anchor",false).AsBool())
                .OrderBy(n=>Xz(n["point"].AsVector3()).DistanceSquaredTo(p)).Take(5))
            {
                var q=Xz(destination["point"].AsVector3());var delta=q-p;
                var middle=(p+q)*.5f+delta.Orthogonal()*.12f;
                var proposals=new List<Vector2[]>();
                if(geological_morphology)proposals.Add(AccessControls(cell,attempt,p,q));
                proposals.Add(new[]{p,middle,q});proposals.Add(new[]{p,(p+q)*.5f-delta.Orthogonal()*.19f,q});
                foreach(var controls in proposals)
                {
                    var candidate=route(entry,destination,controls,true);
                    if(candidate.Count==0 || !supported_join(candidate,edges) || candidate["points"].AsVector3Array().Any(v=>!Inside(Xz(v),12)))continue;
                    if(access_admission.Target is CaveInsectEntryGuard guard&&access_admission.Method==nameof(CaveInsectEntryGuard.clear_access))
                    {if(!guard.clear_access(candidate))continue;}
                    else if(Valid(access_admission)&&!access_admission.Call(candidate).AsBool())continue;
                    access=candidate;break;
                }
                if(access.Count>0)break;
            }
            if(access.Count==0)continue;
            // Buried confluences become destinations for subsequent entrances.
            // Split the solved route at an existing station to preserve its grade.
            var stations = access["points"].AsVector3Array();
            if (geological_morphology && stations.Length > 32 && random(cell, 41000 + attempt) < .7)
            {
                int split = (int)((stations.Length - 1) * (.78 + .09 * random(cell, 42000 + attempt)));
                var junction = stations[split];
                var id = entry["id"].AsString() + ":confluence";
                nodes.Add(new D { ["id"]=id, ["confluence"]=true, ["entry_anchor"]=true, ["level"]=0, ["point"]=junction,
                    ["half_width"]=half_width, ["headroom"]=headroom,
                    ["chamber_radius"]=half_width+1, ["chamber_height"]=headroom });
                var downstream = access.Duplicate();
                downstream["from"]=id; downstream["points"]=stations[split..]; downstream["entrance"]=false;
                edges.Add(downstream);
                access["to"]=id; access["points"]=stations[..(split+1)];
            }
            nodes.Add(entry); edges.Add(access); entrances.Add(entry["id"]);
            if(entrances.Count>=entranceBudget)break;
        }
        // A region can contain a buried network without a local surface mouth.
        // Neighbour links are built canonically after both local graphs exist.
        var result = new D { ["id"] = cell, ["center"] = center, ["nodes"] = nodes, ["edges"] = edges, ["entrances"] = entrances, ["valid"] = true, ["reason"] = "", ["default_biome_id"] = 0, ["geology"] = Math.Min(5, (int)(random(cell, 102) * 6)), ["target_floor_y"]=targetY, ["morphology_seed"]=seed_id };
        if(geological_morphology)
        {
            result["cross_section_style"]=result["geology"];
            result["fracture_passages"]=BuildBypasses(cell,edges);
            int ordinal=0;
            foreach(var raw in edges)
            {
                var edge=raw.AsGodotDictionary();
                edge["profile_phase"]=random(cell, 52000 + ordinal++) * Math.Tau;
                edge["procedural_profile"]=true;
            }
        }
        if(region_decorator.Target is CaveHiveNetwork decoration&&region_decorator.Method==nameof(CaveHiveNetwork.decorate))result=decoration.decorate(result,_active_context);else if(Valid(region_decorator))result=region_decorator.Call(result,_active_context).AsGodotDictionary();
        if (chamber_variety && !result.ContainsKey("pockets")) { result["pockets"] = Profiles.make(result, height, seed_id, max_depth, minimum_roof); result["pocket_passages"] = Profiles.passages(result, result["pockets"].AsGodotArray()); }
        if(seepage_density>0)result["pools"]=Basins.make(result,seed_id,seepage_density);if(region_finalizer.Target is CaveBiomeRegions finalizer&&region_finalizer.Method==nameof(CaveBiomeRegions.decorate))result=finalizer.decorate(result);else if(Valid(region_finalizer))result=region_finalizer.Call(result).AsGodotDictionary();return result;
    }
    public D region(Vector2I cell)
    {
        if (_regions.ContainsKey(cell)) return _regions[cell].AsGodotDictionary(); double width = half_width, room = headroom, flat = flat_radius;
        _active_context=region_context.Target is CaveHiveNetwork context&&region_context.Method==nameof(CaveHiveNetwork.context)?context.context(cell):Valid(region_context)?region_context.Call(cell).AsGodotDictionary():new D();half_width=Number(_active_context,"half_width",half_width);headroom=Number(_active_context,"headroom",headroom);flat_radius=Number(_active_context,"flat_radius",flat_radius);
        D data; try { data = _build(cell); } finally { half_width = width; headroom = room; flat_radius = flat; }
        if (_active_context.ContainsKey("render_style")) data["render_style"] = _active_context["render_style"]; if (_active_context.ContainsKey("hive_region")) data["hive_region"] = _active_context["hive_region"]; _active_context = new D();
        if (_ring.Count >= 32) _regions.Remove(_ring.Dequeue()); _ring.Enqueue(cell); _regions[cell] = data; return data;
    }
    public D connection(Vector2I first,Vector2I second)
    {
        var result=connections(first,second);
        return result.Count>0?result[0].AsGodotDictionary():new D();
    }
    public A connections(Vector2I first,Vector2I second)
    {
        var result=new A();
        if(Math.Abs((long)first.X-second.X)+Math.Abs((long)first.Y-second.Y)!=1)return result;
        if(first.X>second.X||first.X==second.X&&first.Y>second.Y)(first,second)=(second,first);
        var a=region(first);var b=region(second);
        if(!a["valid"].AsBool()||!b["valid"].AsBool())return result;
        var protectedEdges=Items(a,"edges").Duplicate();protectedEdges.AddRange(Items(b,"edges"));
        foreach(var data in new[]{a,b})
        {
            protectedEdges.AddRange(Items(data,"pocket_passages"));protectedEdges.AddRange(Profiles.protected_edges(Items(data,"pockets")));
            var beds=new A();
            foreach(var value in Items(data,"pools"))
            {
                var pool=value.AsGodotDictionary();var guard=pool["bed"].AsGodotDictionary().Duplicate();
                guard["chamber_radius"]=pool["radius"];beds.Add(guard);beds.AddRange(Items(pool,"bank_lobes"));protectedEdges.AddRange(Items(pool,"stream_edges"));
            }
            protectedEdges.AddRange(Profiles.protected_edges(beds));
        }
        var left=Items(a,"nodes").Select(v=>v.AsGodotDictionary()).Where(n=>n["level"].AsInt32()>=0).ToArray();
        var right=Items(b,"nodes").Select(v=>v.AsGodotDictionary()).Where(n=>n["level"].AsInt32()>=0).ToArray();
        double reserve=Get(a,"cave_family",-1).AsInt32()==7||Get(b,"cave_family",-1).AsInt32()==7?2:0;
        void Link(bool deep,bool unrestricted=false)
        {
            var candidates=new List<(D From,D To,double Score)>();
            foreach(var from in left)foreach(var to in right)
            {
                var p=from["point"].AsVector3();var q=to["point"].AsVector3();
                if(!unrestricted&&(deep?(p.Y>-250||q.Y>-250):(!Get(from,"entry_anchor",false).AsBool()||!Get(to,"entry_anchor",false).AsBool())))continue;
                double distance=Xz(p).DistanceTo(Xz(q)),drop=Math.Abs(p.Y-q.Y);
                if(distance<100||distance>2600||drop>(distance-2*flat_radius)*maximum_grade*.9)continue;
                candidates.Add((from,to,distance+drop*3+(deep?(p.Y+q.Y)*.25:0)));
            }
            foreach(var candidate in candidates.OrderBy(c=>c.Score).Take(unrestricted?16:10))
            {
                var p=Xz(candidate.From["point"].AsVector3());var q=Xz(candidate.To["point"].AsVector3());
                var delta=q-p;
                foreach(double offset in new[]{.08,-.08,.19,-.19,0.0})
                {
                    var mid=(p+q)*.5f+delta.Orthogonal()*(float)offset;
                    var solved=route(candidate.From,candidate.To,new[]{p,mid,q},false,reserve);
                    if(solved.Count==0||!supported_join(solved,protectedEdges))continue;
                    // Pair-owned links must not spill into a third region,
                    // whose independently compiled halo would omit the link.
                    var lo=(Vector2)first*(float)REGION_METRES;
                    var hi=((Vector2)second+Vector2.One)*(float)REGION_METRES;
                    if(solved["points"].AsVector3Array().Any(v=>v.X<lo.X+8||v.Z<lo.Y+8||v.X>hi.X-8||v.Z>hi.Y-8))continue;
                    solved["id"]=FormattableString.Invariant($"{first.X}:{first.Y}>{second.X}:{second.Y}")+(deep?":deep":"");
                    solved["growth_role"]=deep?"deep_region_link":"region_link";
                    if(geological_morphology){solved["cross_section_style"]=Get(a,"cross_section_style",0);solved["profile_phase"]=random(first,deep?86002:86001)*Math.Tau;solved["procedural_profile"]=true;}
                    result.Add(solved);protectedEdges.Add(solved);return;
                }
            }
        }
        Link(false);Link(true);
        // A buried region without shallow admission still gets an opportunity
        // to connect through any compatible pair of reachable interior nodes.
        if(result.Count==0)Link(false,true);
        return result;
    }
}
