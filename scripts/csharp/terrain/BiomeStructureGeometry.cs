using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Worker-owned structures with half-open root ownership and conservative shared terrain footings.</summary>
public partial class BiomeStructureGeometry : RefCounted,IStructureGeometry
{
    protected readonly List<Vector3> Vertices=new(),Normals=new();
    protected readonly List<Color> Colors=new();
    protected readonly List<Vector2> UVs=new();
    internal List<Rect2> RefinementRegions{get;}=new();
    internal int VertexCount=>Vertices.Count;
    List<Vector3> IStructureGeometry.VertexBuffer=>Vertices;
    List<Vector3> IStructureGeometry.NormalBuffer=>Normals;
    public Vector3[] vertices {get=>Vertices.ToArray();set{Vertices.Clear();Vertices.AddRange(value);}}
    public Vector3[] normals {get=>Normals.ToArray();set{Normals.Clear();Normals.AddRange(value);}}
    public Color[] colors {get=>Colors.ToArray();set{Colors.Clear();Colors.AddRange(value);}}
    public Vector2[] uvs {get=>UVs.ToArray();set{UVs.Clear();UVs.AddRange(value);}}
    public Vector3 origin {get;set;}
    public bool conduit_aprons {get;set;}=true;
    public bool conduit_shoulders {get;set;}=true;
    public bool conduit_grounded_shoulders {get;set;}=true;
    public bool crystal_grounded_roots {get;set;}
    public bool crystal_bulk_material {get;set;}
    public bool nest_construction_profiles {get;set;}
    public bool conduit_cache_enabled {get;set;}=true;
    public bool lazy_hive_portal_queries {get;set;}=true;
    public D _conduit_memo {get;set;}=new();
    public long _conduit_byte_budget {get;set;}
    public double[] _support_steps {get;set;}=System.Array.Empty<double>();
    public D _support_heights {get;set;}=new();
    public D _footing_vertices {get;set;}=new();
    public D _conduit_uvs {get;set;}=new();
    public A _protected_sites {get;set;}=new();
    public bool _skip_degenerate {get;set;}
    public string CONDUIT_MEMO_KEY {get;}="conduit_geometry_memo_v1";
    private readonly InsectVentGeometry _vent=new();
    private readonly InsectMoundProfiles _mound=new();
    protected static Variant Get(D data,string key,Variant fallback=default)=>data.ContainsKey(key)?data[key]:fallback;
    protected static double Number(GodotObject resource,string key)=>resource.Get(key).AsDouble();
    protected static double Height(GodotObject builder,Vector2 p)=>builder.Call("_get_height",p.X,p.Y).AsDouble();
    protected static double Water(GodotObject builder,Vector2 p)=>builder.Call("get_water_surface_height",p.X,p.Y).AsDouble();
    protected static double Smooth(double a,double b,double value)=>StructureGeometryAccess.Smooth(a,b,value);
    protected static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    protected static bool Valid(Callable c)=>c.Delegate!=null||GodotObject.IsInstanceValid(c.Target)&&c.Target.HasMethod(c.Method);
    protected virtual BiomeStructureGeometry NewGeometry()=>new();
    public double[] support_grids()=>support_grids(256,128,16,6);
    public double[] support_grids(double baseline)=>support_grids(baseline,128,16,6);
    public double[] support_grids(double baseline,long close)=>support_grids(baseline,close,16,6);
    public double[] support_grids(double baseline,long close,long middle)=>support_grids(baseline,close,middle,6);
    public double[] support_grids(double baseline,long close,long middle,long maximum_lod)
    {
        var unique=new SortedSet<double>();for(int level=0;level<=maximum_lod;level++){long resolution=level==0?close:level==1?Math.Max(middle,32):middle;double span=baseline*(1L<<level);unique.Add(span/resolution);if(level>0)foreach(int r in new[]{4,8,16,32,64,128})if(r>=resolution)unique.Add(span/r);}return unique.ToArray();
    }
    public double _grid_height(GodotObject builder,long x,long z,long index,double step)
    {
        bool cacheable=Math.Abs((double)x)<=int.MaxValue&&Math.Abs((double)z)<=int.MaxValue;var key=cacheable?new Vector3I((int)x,(int)z,(int)index):Vector3I.Zero;
        if(cacheable&&_support_heights.ContainsKey(key))return _support_heights[key].AsDouble();double height=builder.Call("_sample_normal_height",x*step,z*step).AsDouble();if(cacheable){if(_support_heights.Count>=16384)_support_heights.Clear();_support_heights[key]=height;}return height;
    }
    public virtual double footing_height(GodotObject builder,Vector2 p)
    {
        double lowest=Height(builder,p);for(int i=0;i<_support_steps.Length;i++){double step=_support_steps[i],gx=p.X/step,gz=p.Y/step;long x=(long)Math.Floor(gx),z=(long)Math.Floor(gz);double fx=gx-x,fz=gz-z,a=_grid_height(builder,x,z,i,step),b=_grid_height(builder,x+1,z,i,step),c=_grid_height(builder,x,z+1,i,step),d=_grid_height(builder,x+1,z+1,i,step),chord=fx+fz<=1?a+(b-a)*fx+(c-a)*fz:d+(c-d)*(1-fx)+(b-d)*(1-fz);lowest=Math.Min(lowest,chord);}return lowest-32;
    }
    public void triangle(Vector3 a,Vector3 b,Vector3 c,Color color)
    {
        var cross=(c-a).Cross(b-a);if(_skip_degenerate&&cross.LengthSquared()<.00000001)return;var normal=cross.Normalized();
        foreach(var p in new[]{a,b,c}){var local=p-origin;var tint=color;if(_footing_vertices.TryGetValue(local,out var marker))tint.A=(float)marker.AsDouble();Vertices.Add(local);Normals.Add(normal);Colors.Add(tint);UVs.Add(_conduit_uvs.TryGetValue(local,out var uv)?uv.AsVector2():new Vector2((float)((double)p.X+p.Z),p.Y)*.15f);}
    }
    public void quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Color color){triangle(a,b,c,color);triangle(a,c,d,color);}
    public void prism(GodotObject builder,Vector3 anchor,double width,double height,int habit,double angle,Vector2 tilt,bool broken,Color color)
    {
        int first=Vertices.Count,count=habit<2||habit==3?6:4;var rings=new Vector3[3][];double[] levels={0,.76,1};
        for(int level=0;level<3;level++)
        {
            double t=levels[level],radius=width*(level<2||broken||habit==4?1:.04);var ring=new Vector3[count];
            for(int i=0;i<count;i++){double a=angle+i*Math.Tau/count;var p=new Vector3((float)(Math.Cos(a)*radius),(float)(height*t),(float)(Math.Sin(a)*radius*(habit==2?.14:1)));p.X=(float)(p.X+tilt.X*height*t);p.Z=(float)(p.Z+tilt.Y*height*t);var v=anchor+p;if(level==0){double support=crystal_grounded_roots?footing_height(builder,new Vector2(v.X,v.Z)):Height(builder,new Vector2(v.X,v.Z))-8;v.Y=(float)Math.Min(v.Y,support);}ring[i]=v;}rings[level]=ring;
        }
        for(int level=0;level<2;level++)for(int i=0;i<count;i++){int j=(i+1)%count;quad(rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i],color);}
        var top=anchor+new Vector3((float)(tilt.X*height),(float)height,(float)(tilt.Y*height));for(int i=0;i<count;i++)triangle(rings[2][i],rings[2][(i+1)%count],top,color);
        if(crystal_bulk_material){double thickness=2*width*(habit==2?.14:1);for(int i=first;i<Vertices.Count;i++){double growth=Math.Clamp(((double)Vertices[i].Y+origin.Y-anchor.Y)/Math.Max(height,.001),0,1);UVs[i]=new Vector2((float)(habit+growth*.25),(float)thickness);}}
    }
    public void mound(GodotObject builder,Vector3 anchor,double width,double height,int archetype,double phase,Color color)=>mound(builder,anchor,width,height,archetype,phase,color,0,false);
    public void mound(GodotObject builder,Vector3 anchor,double width,double height,int archetype,double phase,Color color,double vent_depth)=>mound(builder,anchor,width,height,archetype,phase,color,vent_depth,false);
    public void mound(GodotObject builder,Vector3 anchor,double width,double height,int archetype,double phase,Color color,double vent_depth,bool broad_dome)
    {
        if(broad_dome&&archetype!=3)throw new ArgumentException("Broad mound domes require archetype 3.");int first=Vertices.Count;var rings=new Vector3[25][];
        for(int row=0;row<=24;row++)
        {
            double t=row/24.0;var ring=new Vector3[42];for(int i=0;i<42;i++)
            {
                double a=i*Math.Tau/42,flute=1+.18*Math.Sin(a*5+phase+t*.9)+.1*Math.Sin(a*3-phase-t*1.4)+.045*Math.Sin(a*13+t*18+phase),radius=width*Math.Pow(Math.Max(.015,1-t),.65)*flute;
                if(archetype==3)radius=width*Math.Sqrt(Math.Max(.005,1-t*t));if(broad_dome)radius*=1+.10*Math.Sin(a*3+phase)+.04*Math.Sin(a*7-phase+t*.4);if(archetype is 0 or 4)radius*=.84+.16*Math.Sin(t*14+a*3+phase)+.06*Math.Sin(a*19+t*35);if(archetype==4)radius*=1-.15*Smooth(.4,1,t)*(.5+.5*Math.Sin(a*7+phase));
                var p=new Vector3((float)(Math.Cos(a)*radius),(float)(height*t),(float)(Math.Sin(a)*radius*(broad_dome?.82:archetype==2?.22:1)));p.X=(float)(p.X+width*.16*Math.Sin(t*2+phase)*t);p.Z=(float)(p.Z+width*.12*t*t);var v=anchor+p;if(row==0)v.Y=(float)Math.Min(v.Y,Height(builder,new Vector2(v.X,v.Z))-8);ring[i]=v;
            }
            rings[row]=ring;
        }
        for(int row=0;row<24;row++)for(int i=0;i<42;i++){int j=(i+1)%42;quad(rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],color);}
        var top=Vector3.Zero;foreach(var v in rings[24])top+=v/42;if(vent_depth>0)_vent.emit(this,rings[24],vent_depth,color);else for(int i=0;i<42;i++)triangle(rings[24][i],rings[24][(i+1)%42],top,color);
        if(nest_construction_profiles&&archetype!=3){_mound.apply(this,first,anchor,width,height,archetype,phase);return;}StructureGeometryAccess.SmoothRange(this,first,.15);
    }
    public D _conduit_config_values(Resource resource)
    {
        var values=new D();foreach(var property in resource.GetPropertyList()){string name=property["name"].AsString();if((property["usage"].AsInt64()&(long)PropertyUsageFlags.Storage)==0||name is "script" or "resource_path")continue;var value=resource.Get(name);values[name]=value.VariantType==Variant.Type.Object&&value.AsGodotObject() is Resource nested?Variant.From(_conduit_config_values(nested)):value;}return values;
    }
    public void _evict_conduit_memo(){var entries=_conduit_memo["entries"].AsGodotDictionary();var key=entries.Keys.First();_conduit_memo["bytes"]=_conduit_memo["bytes"].AsInt64()-entries[key].AsGodotDictionary()["bytes"].AsInt64();entries.Remove(key);}
    public void _prepare_conduit_memo(GodotObject builder)
    {
        _conduit_memo=new();_conduit_byte_budget=0;var extras=builder.Get("_extras").AsGodotArray();var settings=builder.Get("settings").As<Resource>();if(conduit_cache_enabled&&extras[7].AsGodotObject()!=null)_conduit_byte_budget=Math.Clamp(settings.Get("alien_infected").AsGodotObject().Get("conduit_cache_mib").AsInt64(),0,16)*1024*1024;
        if(_conduit_byte_budget==0){if(builder.HasMeta(CONDUIT_MEMO_KEY))builder.RemoveMeta(CONDUIT_MEMO_KEY);return;}
        using var hash=new HashingContext();hash.Start(HashingContext.HashType.Sha256);hash.Update(GD.VarToBytes(new A{builder.Get("world_seed"),builder.Get("water_level"),_conduit_config_values(settings)}));var signature=hash.Finish();
        _conduit_memo=builder.GetMeta(CONDUIT_MEMO_KEY,new D()).AsGodotDictionary();if(_conduit_memo.Count==0||!_conduit_memo["signature"].AsByteArray().SequenceEqual(signature)){_conduit_memo=new D{["signature"]=signature,["entries"]=new D(),["bytes"]=0,["hits"]=0,["misses"]=0,["validations"]=0};builder.SetMeta(CONDUIT_MEMO_KEY,_conduit_memo);}
        _conduit_memo["validations"]=Get(_conduit_memo,"validations",0).AsInt64()+1;var entries=_conduit_memo["entries"].AsGodotDictionary();while(entries.Count>0&&(_conduit_memo["bytes"].AsInt64()>_conduit_byte_budget||entries.Count>32))_evict_conduit_memo();
    }
    public A _conduit_relevant_sites(Vector2 a,Vector2 b,double width)
    {
        var sites=new A();var direction=b-a;double denominator=Math.Max(direction.LengthSquared(),.000001),magnitude=Math.Max(Math.Max(Math.Abs((double)a.X),Math.Abs((double)a.Y)),Math.Max(Math.Abs((double)b.X),Math.Abs((double)b.Y))),pad=1+magnitude*.000002;
        foreach(var value in _protected_sites){var site=value.AsGodotDictionary();var p=site["position"].AsVector2();var nearest=a+direction*(float)Math.Clamp((p-a).Dot(direction)/denominator,0,1);if(nearest.DistanceTo(p)<=Math.Max(320,site["half"].AsDouble()*1.2)+208+5.8*width+pad)sites.Add(site);}return sites;
    }
    protected virtual A ConduitKey(Vector2 a,Vector2 b,double width,double phase,Color color,A sites,GodotObject builder)=>new(){a,b,width,phase,color,conduit_aprons,conduit_shoulders,conduit_grounded_shoulders,_support_steps,sites};
    protected virtual string ConduitKeyPrefix(Vector2 a,Vector2 b,double width,GodotObject builder)=>"";
    public virtual void conduit(GodotObject builder,Vector2 a,Vector2 b,double width,double phase,Color color)
    {
        if(_conduit_memo.Count==0){_conduit_uncached(builder,a,b,width,phase,color);return;}var sites=_conduit_relevant_sites(a,b,width);string key=ConduitKeyPrefix(a,b,width,builder)+Convert.ToHexString(GD.VarToBytes(ConduitKey(a,b,width,phase,color,sites,builder))).ToLowerInvariant();var entries=_conduit_memo["entries"].AsGodotDictionary();D entry;
        if(entries.ContainsKey(key)){entry=entries[key].AsGodotDictionary();_conduit_memo["hits"]=_conduit_memo["hits"].AsInt64()+1;}
        else
        {
            _conduit_memo["misses"]=_conduit_memo["misses"].AsInt64()+1;using var g=NewGeometry();g.origin=Vector3.Zero;g._support_steps=_support_steps;g._support_heights=_support_heights;g._protected_sites=sites;g.conduit_aprons=conduit_aprons;g.conduit_shoulders=conduit_shoulders;g.conduit_grounded_shoulders=conduit_grounded_shoulders;g._conduit_uncached(builder,a,b,width,phase,color);
            entry=new D{["vertices"]=g.vertices,["normals"]=g.normals,["colors"]=g.colors,["uvs"]=g.uvs,["bytes"]=g.Vertices.Count*48};
            if(entry["bytes"].AsInt64()<=_conduit_byte_budget){while(entries.Count>0&&(_conduit_memo["bytes"].AsInt64()+entry["bytes"].AsInt64()>_conduit_byte_budget||entries.Count>=32))_evict_conduit_memo();entries[key]=entry;_conduit_memo["bytes"]=_conduit_memo["bytes"].AsInt64()+entry["bytes"].AsInt64();}
        }
        foreach(var vertex in entry["vertices"].AsVector3Array())Vertices.Add(vertex-origin);Normals.AddRange(entry["normals"].AsVector3Array());Colors.AddRange(entry["colors"].AsColorArray());UVs.AddRange(entry["uvs"].AsVector2Array());_footing_vertices.Clear();_conduit_uvs.Clear();_skip_degenerate=false;
    }
    public virtual void _conduit_uncached(GodotObject builder,Vector2 a,Vector2 b,double width,double phase,Color color)=>EmitConduit(builder,a,b,width,phase,color,1,false);
    protected void EmitConduit(GodotObject builder,Vector2 a,Vector2 b,double width,double phase,Color color,int stride,bool retainContacts)
    {
        if(stride<=0)throw new ArgumentOutOfRangeException(nameof(stride));
        _footing_vertices.Clear();_conduit_uvs.Clear();_skip_degenerate=conduit_aprons;int first=Vertices.Count,originalSegments=Math.Clamp((int)Math.Ceiling(a.DistanceTo(b)/96.0),16,64);var selected=new List<int>();for(int i=0;i<originalSegments;i+=retainContacts?1:stride)selected.Add(i);selected.Add(originalSegments);int segments=selected.Count-1;
        var direction=(b-a).Normalized();var side=new Vector2(-direction.Y,direction.X);var rings=new List<Vector3[]>();var sampler=conduit_aprons?builder.Get("_extras").AsGodotArray()[7].AsGodotObject():null;
        for(int row=0;row<=segments;row++)
        {
            double t=(double)selected[row]/originalSegments;var p=a.Lerp(b,(float)t)+side*(float)Math.Sin(t*Math.PI)*(float)width*.8f;double h=Height(builder,p),radius=width*(.7+.2*Math.Sin(t*9+phase)+.1*Math.Sin(t*23-phase));var ring=new List<Vector3>();var controls=conduit_aprons?StructureGeometryAccess.Controls(sampler!,p):Vector2.Zero;
            var left=p+side*(float)radius;var right=p-side*(float)radius;double leftH=Height(builder,left),rightH=Height(builder,right),shoulder=conduit_aprons&&conduit_shoulders&&conduit_grounded_shoulders?Smooth(9,15,radius):0;
            if(shoulder>0)foreach(var value in _protected_sites){var site=value.AsGodotDictionary();double reserve=Math.Max(320,site["half"].AsDouble()*1.2)+radius+64;shoulder*=Smooth(reserve,reserve+128,p.DistanceTo(site["position"].AsVector2()));}
            for(int i=0;i<9;i++)
            {
                double angle=i*Math.PI/8,cos=Math.Cos(angle),ground=Lerp(h,cos>0?leftH:rightH,Math.Abs(cos)),rise=Math.Sin(angle);if(conduit_aprons&&conduit_shoulders)rise*=rise;var v=new Vector3((float)(p.X+side.X*cos*radius),(float)(ground-2+rise*radius*.35),(float)(p.Y+side.Y*cos*radius));
                if(i is 0 or 8)v.Y=(float)(ground-(conduit_aprons&&conduit_shoulders?2:3));if(shoulder>0){double floor=Height(builder,new Vector2(v.X,v.Z)),grown=floor-.02+Math.Max(0,radius*.35-1.98)*Math.Pow(Math.Sin(angle),4);v.Y=(float)Lerp(v.Y,grown,shoulder);}ring.Add(v);if(conduit_aprons)_conduit_uvs[v-origin]=controls;
            }
            if(conduit_aprons)
            {
                double reach=128+radius*4,factor=1;foreach(var value in _protected_sites){var site=value.AsGodotDictionary();double clearance=p.DistanceTo(site["position"].AsVector2())-Math.Max(320,site["half"].AsDouble()*1.2)-64-radius-16;factor=Math.Min(factor,Math.Clamp(clearance/reach,0,1));}
                var profile=new List<Vector3>();foreach(int sign in new[]{1,-1})
                {
                    var outer=p+side*sign*(float)(radius+reach*factor);double outerGround=Height(builder,outer),foot=factor>0?footing_height(builder,outer):outerGround-3,extra=Math.Max(0,outerGround-3-foot);var apron=new List<Vector3>();
                    for(int station=0;station<3;station++){double u=(3-station)/3.0;var q=p+side*sign*(float)(radius+reach*factor*u);double y=Height(builder,q)-3-extra*Smooth(.35,1,u);var v=new Vector3(q.X,(float)y,q.Y);apron.Add(v);_footing_vertices[v-origin]=factor>0?(station==0?0.0:.25):.5;_conduit_uvs[v-origin]=StructureGeometryAccess.Controls(sampler!,q);}
                    if(sign>0){profile.AddRange(apron);profile.AddRange(ring);}else{apron.Reverse();profile.AddRange(apron);}
                }
                ring=profile;
            }
            rings.Add(ring.ToArray());
        }
        if(retainContacts)new AlienConduitContactLod().Triangulate(this,rings,color,stride);else for(int row=0;row<segments;row++)for(int i=0;i<rings[row].Length-1;i++)quad(rings[row][i],rings[row][i+1],rings[row+1][i+1],rings[row+1][i],color);
        var capA=new Vector3(a.X,(float)(Height(builder,a)-width*4),a.Y);var capB=new Vector3(b.X,(float)(Height(builder,b)-width*4),b.Y);
        if(conduit_aprons){capA.Y=(float)Math.Min(capA.Y,Math.Min(rings[0][0].Y,rings[0][^1].Y)-8.0);capB.Y=(float)Math.Min(capB.Y,Math.Min(rings[segments][0].Y,rings[segments][^1].Y)-8.0);_conduit_uvs[capA-origin]=_conduit_uvs[rings[0][3]-origin];_conduit_uvs[capB-origin]=_conduit_uvs[rings[segments][3]-origin];}
        for(int i=0;i<rings[0].Length-1;i++){triangle(rings[0][i+1],rings[0][i],capA,color);triangle(rings[segments][i],rings[segments][i+1],capB,color);}if(conduit_aprons)StructureGeometryAccess.SmoothRange(this,first,.15);_footing_vertices.Clear();_conduit_uvs.Clear();_skip_degenerate=false;
    }
    public bool can_place_carapace(GodotObject builder,Vector2 p,double width,double height)
    {
        foreach(var value in _protected_sites){var site=value.AsGodotDictionary();if(p.DistanceTo(site["position"].AsVector2())<Math.Max(320,site["half"].AsDouble()*1.2)+width*1.8+64)return false;}var heights=new double[9];var offsets=new Vector2[9];
        for(int i=0;i<9;i++){double angle=i*Math.Tau/8;var q=p+(i<8?new Vector2((float)Math.Cos(angle),(float)Math.Sin(angle))*(float)width*1.6f:Vector2.Zero);double h=Height(builder,q),amount=builder.Get("_last_extras").AsVector4Array()[7].X;if(amount<.8||h<=Math.Max(Number(builder,"water_level"),Water(builder,q))+4)return false;heights[i]=h;offsets[i]=q-p;}
        double radius=width*1.6;var grade=new Vector2((float)((heights[0]-heights[4])/(radius*2)),(float)((heights[2]-heights[6])/(radius*2)));if(grade.Length()>.7)return false;for(int i=0;i<8;i++)if(Math.Abs(heights[i]-(heights[8]+grade.Dot(offsets[i])))>=height*.75)return false;return true;
    }
    public A build(GodotObject builder,Vector2I coordinate)=>build(builder,coordinate,System.Array.Empty<double>(),default);
    public A build(GodotObject builder,Vector2I coordinate,double[] support_steps)=>build(builder,coordinate,support_steps,default);
    public virtual A build(GodotObject builder,Vector2I coordinate,double[] support_steps,Callable portal_provider)
    {
        _conduit_memo=new();_conduit_byte_budget=0;bool memoChecked=false;var settings=builder.Get("settings").AsGodotObject();var alien=settings.Get("alien_infected").AsGodotObject();var crystal=settings.Get("crystal_wastes").AsGodotObject();var insect=settings.Get("insect_colony").AsGodotObject();var extras=builder.Get("_extras").AsGodotArray();
        conduit_grounded_shoulders=alien.Get("hive_grounded_shoulders").AsBool();crystal_grounded_roots=crystal.Get("crystal_grounded_roots").AsBool();crystal_bulk_material=crystal.Get("crystal_bulk_material").AsBool();nest_construction_profiles=insect.Get("nest_construction_profiles").AsBool();long budget=conduit_cache_enabled&&extras[7].AsGodotObject()!=null?Math.Clamp(alien.Get("conduit_cache_mib").AsInt64(),0,16)*1024*1024:0;
        if(builder.HasMeta(CONDUIT_MEMO_KEY)){var previous=builder.GetMeta(CONDUIT_MEMO_KEY).AsGodotDictionary();if(budget==0||Get(previous,"bytes",0).AsInt64()>budget)builder.RemoveMeta(CONDUIT_MEMO_KEY);}
        var output=new A();output.Resize(3);RefinementRegions.Clear();double size=Number(builder,"chunk_size");origin=new Vector3((float)(coordinate.X*size),0,(float)(coordinate.Y*size));var bounds=new Rect2(new Vector2(origin.X,origin.Z),Vector2.One*(float)size);_support_steps=support_steps.Length>0?(double[])support_steps.Clone():support_grids();_support_heights.Clear();_protected_sites.Clear();bool hiveReady=false,insectReady=false;var insectPortals=new A();
        if(!lazy_hive_portal_queries&&extras[7].AsGodotObject()!=null&&Valid(portal_provider)){_protected_sites=portal_provider.Call(bounds.Grow((float)(8192*Number(extras[7].AsGodotObject().Get("settings").AsGodotObject(),"feature_scale")+512))).AsGodotArray();hiveReady=true;}
        try
        {
            foreach(int family in new[]{5,6,7})
            {
                Vertices.Clear();Normals.Clear();Colors.Clear();UVs.Clear();var sampler=extras[family].AsGodotObject();if(sampler==null)continue;var config=sampler.Get("settings").AsGodotObject();double span=(family==7?4096:family==5?1700:2100)*Number(config,"feature_scale");var start=new Vector2I((int)Math.Floor(bounds.Position.X/span)-1,(int)Math.Floor(bounds.Position.Y/span)-1);var end=new Vector2I((int)Math.Ceiling(bounds.End.X/span),(int)Math.Ceiling(bounds.End.Y/span));
                for(int z=start.Y;z<=end.Y;z++)for(int x=start.X;x<=end.X;x++)
                {
                    var cell=new Vector2I(x,z);var d=sampler.Call("descriptor",cell,span).AsGodotDictionary();var p=family==7?sampler.Call("hive_node",cell).AsVector2():d["position"].AsVector2();if(!bounds.HasPoint(p)||(builder is TerrainMeshBuilder native&&native.RingOwns is not null&&!native.RingOwns(p)))continue;builder.Call("_biome_weights",p.X,p.Y);double weight=builder.Get("_extra_weights").AsFloat64Array()[family];if(family==7)weight=Math.Max(weight,sampler.Call("network",p).AsGodotDictionary()["influence"].AsDouble()*Number(config,"overlay_strength"));
                    if(weight<.55||builder.Call("_island_mask",p.X,p.Y).AsDouble()<.03||d["chance"].AsDouble()>Number(config,"structure_density"))continue;double ground=Height(builder,p),water=Water(builder,p);if(ground<water+2)continue;var anchor=new Vector3(p.X,(float)(ground-8),p.Y);int type=Math.Clamp((int)Math.Round(sampler.Call("region",p).AsDouble(),MidpointRounding.AwayFromZero),0,5);double age=d["age"].AsDouble(),angle=d["angle"].AsDouble();
                    int firstRootVertex=Vertices.Count;
                    if(family==5)
                    {
                        var palette=new[]{new Color(.59f,.61f,.58f),new Color(.41f,.27f,.49f),new Color(.76f,.77f,.68f),new Color(.25f,.23f,.22f),new Color(.23f,.46f,.37f),new Color(.63f,.56f,.43f)};
                        for(int i=0;i<5;i++){double a=angle+i*2.4,scale=i==0?1:.22+sampler.Call("random",x,z,i+70).AsDouble()*.4;var center=anchor+new Vector3((float)Math.Cos(a),0,(float)Math.Sin(a))*(float)d["radius"].AsDouble()*.15f*Math.Min(i,1);center.Y=(float)Math.Min(anchor.Y,Height(builder,new Vector2(center.X,center.Z))-8);double height=Number(config,"crystal_height")*(.4+age*1.4)*scale;prism(builder,center,height*(type!=4?.14:.4),height,type,a,new Vector2((float)Math.Cos(a),(float)Math.Sin(a))*(float)(.05+.18*sampler.Call("random",x,z,i+90).AsDouble()),sampler.Call("random",x,z,i+80).AsDouble()<Number(config,"broken_fraction"),palette[type]);}
                    }
                    else if(family==6)
                    {
                        if(type==1)continue;var color=new Color(.44f,.27f,.14f).Lerp(new Color(.55f,.48f,.36f),type/5f);double scale=Number(config,"nest_height")*(.45+age)*(1-.35*(type==4?1:0));bool broad=type==3&&config.Get("nest_broad_domes").AsBool();
                        if((broad||config.Get("nest_protect_burrows").AsBool())&&!insectReady){if(Valid(portal_provider))insectPortals=portal_provider.Call(bounds.Grow((float)(Number(config,"nest_height")*1.45*1.344+512))).AsGodotArray();insectReady=true;}
                        if(config.Get("nest_protect_burrows").AsBool()){double footprint=scale*(broad?.84*1.6:.8);bool blocked=insectPortals.Any(v=>p.DistanceTo(v.AsGodotDictionary()["position"].AsVector2())<footprint+Math.Max(320,v.AsGodotDictionary()["half"].AsDouble()*1.2));if(blocked)continue;}
                        if(broad)foreach(var v in insectPortals){var site=v.AsGodotDictionary();if(p.DistanceTo(site["position"].AsVector2())<scale*.84*1.6+Math.Max(320,site["half"].AsDouble()*1.2)){broad=false;break;}}
                        double width=scale*(broad?.84:.4),height=broad?Math.Max(scale*.42,Math.Min(scale,18)):scale,depth=0;if(type is 0 or 3 or 5&&height>=40&&sampler.Call("random",x,z,178).AsDouble()<Number(config,"nest_vent_frequency"))depth=_vent.admitted_depth(builder,anchor,width,height,angle,Math.Min(height*.18,24));mound(builder,anchor,width,height,type,angle,color,depth,broad);
                        if(type is 0 or 4 or 5)for(int i=0;i<5;i++){double a=angle+i*1.31;var root=anchor+new Vector3((float)Math.Cos(a),0,(float)Math.Sin(a))*(float)scale*.23f;mound(builder,root,scale*.19,scale*(.4+sampler.Call("random",x,z,110+i).AsDouble()*.5),0,a,color);}
                    }
                    else
                    {
                        if(!hiveReady&&Valid(portal_provider)){_protected_sites=portal_provider.Call(bounds.Grow((float)(8192*Number(config,"feature_scale")+512))).AsGodotArray();hiveReady=true;}if(!memoChecked){_prepare_conduit_memo(builder);memoChecked=true;}
                        EmitHive(builder,sampler,config,cell,d,p,weight,type);
                    }
                    if(builder is TerrainMeshBuilder{RingOwns:not null}&&Vertices.Count>firstRootVertex)
                    {
                        var rootBounds=new Aabb(Vertices[firstRootVertex],Vector3.Zero);for(int vertex=firstRootVertex+1;vertex<Vertices.Count;vertex++)rootBounds=rootBounds.Expand(Vertices[vertex]);var min=new Vector2(rootBounds.Position.X+origin.X,rootBounds.Position.Z+origin.Z);var max=new Vector2(rootBounds.End.X+origin.X,rootBounds.End.Z+origin.Z);min=(min/32).Floor()*32-Vector2.One*32;max=(max/32).Ceil()*32+Vector2.One*32;RefinementRegions.Add(new Rect2(min,max-min));
                    }
                }
                if(Vertices.Count>0)output[family-5]=arrays();
            }
            return output;
        }
        finally{_conduit_memo=new();_conduit_byte_budget=0;}
    }
    private void EmitHive(GodotObject builder,GodotObject sampler,GodotObject config,Vector2I cell,D descriptor,Vector2 a,double weight,int type)
    {
        var color=new Color(.34f,.28f,.26f);double age=descriptor["age"].AsDouble(),angle=descriptor["angle"].AsDouble();bool junction=false;
        foreach(var direction in new[]{Vector2I.Right,Vector2I.Down}){var b=sampler.Call("hive_node",cell+direction).AsVector2();var delta=b-a;var middle=(a+b)*.5f+new Vector2(-delta.Y,delta.X)*(float)(.08*Math.Sin((cell.X+(double)cell.Y)*1.71));conduit(builder,a,middle,12+age*16,angle,color);conduit(builder,middle,b,12+age*16,angle,color);conduit(builder,middle,middle+new Vector2(-delta.Y,delta.X)*.23f,8,angle,color);}
        if(weight>=.92&&Number(config,"hive_junction_frequency")>0&&sampler.Call("random",cell.X,cell.Y,246).AsDouble()<Number(config,"hive_junction_frequency"))
        {
            double width=Number(config,"hive_junction_width")*Number(config,"feature_scale");bool clear=true;foreach(var v in _protected_sites){var site=v.AsGodotDictionary();if(a.DistanceTo(site["position"].AsVector2())<Math.Max(320,site["half"].AsDouble()*1.2)+width*4+64){clear=false;break;}}
            if(clear){var edges=sampler.Call("network_edges",cell).AsVector2Array();var directions=new Godot.Collections.Array<Vector2>{(edges[1]-a).Normalized(),(edges[5]-a).Normalized()};double height=Number(config,"hive_junction_height")*(.65+age*.7)*Number(config,"relief")*Math.Max(Number(builder.Get("settings").AsGodotObject(),"height_multiplier"),.01);using var geometry=new AlienJunctionGeometry{longitudinal_ribs=config.Get("hive_longitudinal_ribs").AsBool(),surface_guide_enabled=config.Get("hive_surface_guided_roots").AsBool()};geometry.emit(this,builder,a,directions,width,height,angle);if(Number(config,"hive_membrane_frequency")>0&&sampler.Call("random",cell.X,cell.Y,248).AsDouble()<Number(config,"hive_membrane_frequency")){using var membrane=new AlienMembraneGeometry{surface_guide_enabled=config.Get("hive_surface_guided_roots").AsBool()};membrane.emit(this,builder,a,directions[0],width,height,angle);}junction=true;}
        }
        if(!junction&&weight>=.92&&type is 2 or 5&&Number(config,"hive_carapace_frequency")>0&&sampler.Call("random",cell.X,cell.Y,247).AsDouble()<Number(config,"hive_carapace_frequency"))
        {double width=Number(config,"hive_carapace_width")*Number(config,"feature_scale")*(.75+age*.5),height=Number(config,"hive_carapace_height")*(.7+age*.6)*Number(config,"relief")*Math.Max(Number(builder.Get("settings").AsGodotObject(),"height_multiplier"),.01);if(can_place_carapace(builder,a,width,height)){var edges=sampler.Call("network_edges",cell).AsVector2Array();using var geometry=new AlienCarapaceGeometry();geometry.emit(this,builder,a,(edges[1]-a).Normalized(),width,height,angle,type);}}
    }
    public A arrays(){var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices;arrays[(int)Mesh.ArrayType.Normal]=normals;arrays[(int)Mesh.ArrayType.Color]=colors;arrays[(int)Mesh.ArrayType.TexUV]=uvs;return arrays;}
}
