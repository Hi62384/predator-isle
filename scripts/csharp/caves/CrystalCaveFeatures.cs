using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Measured mineral growth rooted in the shared cave field, with complete-form LODs.</summary>
public partial class CrystalCaveFeatures : RefCounted
{
    private const int MaxForms=160,MaxVertices=60000,MaxLining=32;
    public CaveFormations shapes {get;set;}=new();
    public CrystalCaveGeometry geometry {get;set;}=new();
    public A placements {get;set;}=new();
    public Vector3I key {get;set;}
    public Vector3 origin {get;set;}
    public D settings {get;set;}=new();
    public D rejections {get;set;}=new();
    private long _seed;
    private readonly CaveBiomeRegions _regions=new();
    private readonly CaveChamberProfiles _profiles=new();
    private readonly CrystalConnectedProfiles _connected=new();
    private readonly CrystalVeinExposure _veins=new();
    private readonly CrystalCorridorFeatures _corridors=new();
    private readonly CrystalLakeChambers _lakes=new();
    private readonly CrystalLuminous _luminous=new();
    private readonly CrystalShallowChambers _shallow=new();
    private readonly List<D> _lining=new(),_debris=new();
    private sealed class Batch
    {
        internal readonly List<Vector3> Vertices=new(),Normals=new(),Collision=new();
        internal readonly List<Color> Colors=new();
        internal readonly List<Vector2> UVs=new(),Growth=new();
        internal readonly List<int> Middle=new(),Far=new();
    }
    private readonly Dictionary<string,Batch> _batches=new(StringComparer.Ordinal);
    private static Variant Get(D data,string name,Variant fallback=default)=>data.ContainsKey(name)?data[name]:fallback;
    private static A Items(D data,string name)=>Get(data,name,new A()).AsGodotArray();
    private static double N(D data,string name)=>data[name].AsDouble();
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static double Sample(GodotObject field,Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
    private static Vector3 Normal(GodotObject field,Vector3 p)=>field is CaveField native?native.normal(p):field.Call("normal",p).AsVector3();
    private static Vector3I Cell(GodotObject field,Vector3 p)=>field is CaveField native?native.cell(p):field.Call("cell",p).AsVector3I();
    private double Random(string id,string salt)=>_regions.random(id,_seed,salt);
    private Batch Bucket(string kind){if(!_batches.TryGetValue(kind,out var batch)){batch=new();_batches[kind]=batch;}return batch;}
    public bool reject(string reason){rejections[reason]=Get(rejections,reason,0).AsInt64()+1;return false;}
    public double weight(GodotObject field,Vector3 p)=>field is CaveField native?native.biome_weights_at(p,new A{"crystal"}).X:field.Call("biome_weights_at",p,new A{"crystal"}).AsVector4().X;
    public Vector3 boundary(GodotObject field,Vector3 start,Vector3 direction,double reach)
    {if(Sample(field,start)>=-.01)return Vector3.Inf;var previous=start;for(int station=1;station<=Math.Ceiling(reach);station++){var next=start+direction*station;if(Sample(field,next)>=0)return shapes.boundary(field,previous,next);previous=next;}return Vector3.Inf;}
    public D decorate_region(D region,Callable height,long seed_id,D configuration,double maximum_depth,double minimum_roof)
    {
        if(!Get(configuration,"chamber_growth",true).AsBool()||!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7)return region;
        var result=region;bool changed=false;
        foreach(string table in new[]{"nodes","pockets"})
        {
            var rooms=Items(region,table).Duplicate();
            for(int i=0;i<rooms.Count;i++)
            {
                var node=rooms[i].AsGodotDictionary();if(Get(node,"level",-1).AsInt64()<0)continue;string nodeId=node["id"].AsString();var assignment=_regions.along_edge(Get(region,"cave_biome_regions",new D()).AsGodotDictionary(),nodeId,nodeId,0,0);
                if(Get(assignment["weights"].AsGodotDictionary(),"crystal",0).AsDouble()<.7)continue;
                string identity=Get(assignment["candidate_ids"].AsGodotDictionary(),"crystal",nodeId).AsString();int layout=Math.Min(5,(int)(_regions.random(identity,seed_id,"crystal/layout")*6));
                double radius=Math.Max(N(node,"chamber_radius"),22+_regions.random(nodeId,seed_id,"crystal/radius")*6),headroom=Math.Max(N(node,"chamber_height"),28+_regions.random(nodeId,seed_id,"crystal/vault")*20);var p=node["point"].AsVector3();
                if(!_profiles.compatible(p,radius,headroom,region,Items(region,"pockets")))continue;bool admitted=true;
                for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++){if(new Vector2(x,z).Length()>2.1)continue;double surface=height.Call(p.X+x*radius*.5,p.Z+z*radius*.5).AsDouble();if(!double.IsFinite(surface)||surface-p.Y>maximum_depth-4||surface-p.Y<headroom+minimum_roof+4)admitted=false;}
                if(!admitted)continue;var grown=node.Duplicate();grown["chamber_radius"]=radius;grown["chamber_height"]=headroom;grown["cross_section_style"]=layout is 0 or 3 or 4?0:layout is 1 or 2?1:3;grown["crystal_layout"]=layout;grown["crystal_region"]=identity;rooms[i]=grown;
                if(!changed){result=region.Duplicate();changed=true;}
            }
            if(changed)result[table]=rooms;
        }
        var connected=configuration;if(Get(configuration,"lake_chambers",false).AsBool()){connected=configuration.Duplicate();connected[new StringName("large_lake_frequency")]=0.0;}
        var prepared=_lakes.prepare(_connected.decorate(result,height,seed_id,connected,maximum_depth,minimum_roof),height,seed_id,configuration,maximum_depth,minimum_roof);
        var final=_shallow.prepare(prepared,height,Get(configuration,"shallow_chambers",false).AsBool(),maximum_depth,minimum_roof);
        if(Get(configuration,"floor_ridges",false).AsBool()&&(changed||!final.RecursiveEqual(region)))
        {final=final.Duplicate();var relief=Get(final,"cave_floor_relief",new D()).AsGodotDictionary().Duplicate();relief["crystal"]=Get(configuration,"floor_ridge_height",.65).AsDouble();final["cave_floor_relief"]=relief;}return final;
    }
    public bool spanning_form(GodotObject field,Vector3 root,Vector3 axis,double width,double maximum,int family,double age,string identity,double phase)
    {
        if(family>3||weight(field,root+axis*.6f)<.8)return false;var opposite=boundary(field,root+axis*2,axis,maximum-2);if(!opposite.IsFinite())return false;
        double length=root.DistanceTo(opposite);return length>=8&&length<=maximum&&weight(field,opposite-axis*.6f)>=.8&&form(field,root,axis,width,length,family,true,age,identity,0,false,phase,true,false);
    }
    public bool form(GodotObject field,Vector3 root,Vector3 axis,double width,double height,int family,bool broken,double age,string identity,int importance,bool selective,double phase)=>form(field,root,axis,width,height,family,broken,age,identity,importance,selective,phase,false,false);
    public bool form(GodotObject field,Vector3 root,Vector3 axis,double width,double height,int family,bool broken,double age,string identity,int importance,bool selective,double phase,bool spanning)=>form(field,root,axis,width,height,family,broken,age,identity,importance,selective,phase,spanning,false);
    public bool form(GodotObject field,Vector3 root,Vector3 axis,double width,double height,int family,bool broken,double age,string identity,int importance,bool selective,double phase,bool spanning,bool loose)
    {
        if(placements.Count>=MaxForms||!root.IsFinite()||Cell(field,root)!=key||height<.35||width<.10)return reject("bounds_or_size");double amount=weight(field,root+axis*.6f);if(amount<.3)return reject("transition_weight");
        double growth=spanning?1:Smooth(.15,.8,amount);height*=growth;width*=growth;if(height<.35||width<.10)return reject("transition_size");
        var tangent=(Math.Abs(axis.Y)<.9?Vector3.Up.Cross(axis):Vector3.Right.Cross(axis)).Normalized();tangent=tangent.Rotated(axis,(float)phase);var across=tangent.Cross(axis).Normalized();var basis=new Basis(tangent,axis,across);if(basis.Determinant()<0){across=-across;basis=new Basis(tangent,axis,across);}
        var points=geometry.prototype(family,broken)[(int)Mesh.ArrayType.Vertex].AsVector3Array();var vertices=new List<Vector3>(points.Length);var contacts=new Dictionary<Vector2,Vector3>();var endContacts=new Dictionary<Vector2,Vector3>();var low=Vector3.Inf;var high=-Vector3.Inf;
        foreach(var q in points)
        {
            var p=root+basis*new Vector3((float)(q.X*width),(float)(q.Y*height),(float)(q.Z*width));
            if(loose&&q.Y>.001&&Sample(field,p)>-.04)
            {var up=Normal(field,root);var back=p-up*(float)(1.5+width);var front=p+up*2;if(Sample(field,back)<0||Sample(field,front)>=0)return reject("debris_floor_bracket");p=shapes.boundary(field,back,front)+up*(float)(.04+q.Y*height*.25);}
            if(q.Y<.001)
            {
                var local=new Vector2(q.X,q.Z);if(!contacts.TryGetValue(local,out var foot))
                {double margin=2+width;var back=p-axis*(float)margin;var front=p+axis*(float)margin;if(Sample(field,back)<0||Sample(field,front)>=0)return reject("whole_foot_bracket");foot=shapes.boundary(field,back,front)-axis*1.25f;if(Sample(field,foot)<.15)return reject("whole_foot_burial");contacts[local]=foot;}p=foot;
            }
            else if(spanning&&q.Y>.999)
            {
                var local=new Vector2(q.X,q.Z);if(!endContacts.TryGetValue(local,out var foot))
                {double margin=2+width;var air=p-axis*(float)margin;var rock=p+axis*(float)margin;if(Sample(field,air)>=0||Sample(field,rock)<0)return reject("span_far_foot_bracket");foot=shapes.boundary(field,rock,air)+axis*1.25f;if(Sample(field,foot)<.15)return reject("span_far_foot_burial");endContacts[local]=foot;}p=foot;
            }
            else if(Sample(field,p)>(loose?-.015:-Math.Min(1.05,height*.2)))return reject("airspace_or_roof");
            vertices.Add(p);low=low.Min(p);high=high.Max(p);
        }
        var center=(low+high)*.5f;double horizontal=new Vector2((float)((double)high.X-low.X),(float)((double)high.Z-low.Z)).Length()*.5;
        if(shapes.@protected(field,center,horizontal,low.Y,high.Y))return reject("protected_route");
        for(int i=0;i<vertices.Count;i+=3)if((vertices[i+2]-vertices[i]).Cross(vertices[i+1]-vertices[i]).LengthSquared()==0)return reject("collapsed_facet");
        for(int i=0;i<vertices.Count;i+=3)foreach(var pair in new[]{new Vector2I(0,1),new Vector2I(1,2),new Vector2I(2,0)})
        {
            var a=vertices[i+pair.X];var b=vertices[i+pair.Y];if(spanning)
            {int intervals=(int)Math.Ceiling(a.DistanceTo(b)/.5);for(int station=1;station<intervals;station++){var p=a.Lerp(b,(float)((double)station/intervals));double along=(p-root).Dot(axis);if(along>2+width&&along<height-2-width&&Sample(field,p)>-.15)return reject("span_body_airspace");}continue;}
            if(points[i+pair.X].Y<.001||points[i+pair.Y].Y<.001)continue;double steps=Math.Ceiling(a.DistanceTo(b)/2.0);for(int station=1;station<steps;station++)if(Sample(field,a.Lerp(b,(float)(station/steps)))>(loose?-.015:-.5))return reject("face_edge_airspace");
        }
        bool thin=width<.45&&height<4&&family is 0 or 2 or 4,smallFluorite=family==4&&width<1.5&&height<3;
        bool clear=selective&&Get(settings,"selective_transmission",true).AsBool()&&(thin||smallFluorite)&&Random(identity,"crystal/selective_near_transmission")<.25;
        string kind=clear?"mineral_clear":height<1.2?"mineral_grains":"mineral_opaque";var target=Bucket(kind);int first=target.Vertices.Count;var tint=geometry.tint(family,age);tint.A=(float)age;if(first+vertices.Count>MaxVertices)return reject("vertex_budget");
        double thickness=width*(family==2?.28:family==4?Math.Sqrt(2):2);
        for(int i=0;i<vertices.Count;i+=3)
        {var normal=(vertices[i+2]-vertices[i]).Cross(vertices[i+1]-vertices[i]).Normalized();for(int j=0;j<3;j++){target.Vertices.Add(vertices[i+j]-origin);target.Normals.Add(normal);target.Colors.Add(tint);target.UVs.Add(new Vector2((float)(family+Math.Clamp((double)points[i+j].Y,0,1)*.25),(float)thickness));target.Growth.Add(new Vector2((float)(points[i+j].Y*height),(float)phase));}}
        bool collider=height>=1.5&&width>=.35||family is 4 or 5&&height>=.75&&width>=.3;
        for(int i=first;i<target.Vertices.Count;i++){if(importance==0||height>=2)target.Middle.Add(i);if(importance==0||height>=5)target.Far.Add(i);if(collider)target.Collision.Add(target.Vertices[i]);}
        var placement=new D{["id"]=identity,["kind"]="crystal",["owner"]=key,["root"]=root,["axis"]=axis,["height"]=height,["width"]=width,["family"]=family,["broken"]=broken,["age"]=age,["importance"]=importance,["thin_transmission"]=clear,["collider"]=collider,["attachments"]=contacts.Values.ToArray(),["bounds"]=new Aabb(low,high-low),["raw_weight"]=amount,["batch"]=kind,["first_vertex"]=first,["vertex_count"]=vertices.Count};
        if(spanning){placement["spanning"]=true;placement["far_attachments"]=endContacts.Values.ToArray();placement["attachments"]=contacts.Values.Concat(endContacts.Values).ToArray();}placements.Add(placement);return true;
    }
    private sealed class Emitter
    {
        internal readonly List<Vector3> Vertices=new(),Normals=new();
        internal readonly Vector3 Origin;
        internal readonly bool SkipDegenerate;
        internal Emitter(Vector3 origin,bool skip=false){Origin=origin;SkipDegenerate=skip;}
        internal void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 center)
        {if((c-a).Cross(b-a).Dot((a+b+c+d)*.25f-center)<0){Triangle(a,d,c);Triangle(a,c,b);}else{Triangle(a,b,c);Triangle(a,c,d);}}
        private void Triangle(Vector3 a,Vector3 b,Vector3 c)
        {var cross=(c-a).Cross(b-a);if(SkipDegenerate&&cross.LengthSquared()<.00000001)return;var n=cross.Normalized();Vertices.Add(a-Origin);Vertices.Add(b-Origin);Vertices.Add(c-Origin);Normals.Add(n);Normals.Add(n);Normals.Add(n);}
    }
    public bool owns_wall(GodotObject field,D room,Vector3 point)
    {
        var center=room["point"].AsVector3();
        if(field is CaveField native)
        {
            if(!native.Bins.TryGetValue(native.bin_cell(point),out var features))return false;Span<int> one=stackalloc int[1];
            foreach(int feature in features)if(native.Kinds[feature]==2&&native.Begins[feature]==center){one[0]=feature;if(Math.Abs(native.Evaluate(point,one))<=.2)return true;}return false;
        }
        var bins=field.Get("bins").AsGodotDictionary();var cell=field.Call("bin_cell",point).AsVector3I();if(!bins.ContainsKey(cell))return false;var kinds=field.Get("kinds").AsByteArray();var begins=field.Get("begins").AsVector3Array();
        foreach(int feature in bins[cell].AsInt32Array())if(kinds[feature]==2&&begins[feature]==center&&Math.Abs(field.Call("evaluate",point,new[]{feature}).AsDouble())<=.2)return true;return false;
    }
    public bool lining_patch(GodotObject field,D patch)
    {
        var root=patch["root"].AsVector3();var normal=patch["normal"].AsVector3();var tangent=Vector3.Up.Cross(normal).Normalized();var across=tangent.Cross(normal).Normalized();string id=patch["id"].AsString();double radius=1.4+Random(id,"lining/radius")*.9,stretch=.55+.3*Random(id,"lining/aspect"),phase=N(patch,"phase");
        var front=new List<Vector3>();var rear=new List<Vector3>();var attachments=new List<Vector3>();var low=Vector3.Inf;var high=-Vector3.Inf;
        for(int i=0;i<8;i++)
        {
            double angle=Math.Tau*i/8+phase,distance=radius*(.4+.6*Random(id,"lining/rim/"+i));var p=root+(tangent*(float)Math.Cos(angle)+across*(float)Math.Sin(angle)*(float)stretch)*(float)distance;
            var a=p-normal*4;var b=p+normal*4;if(Sample(field,a)<.15||Sample(field,b)>-.15)return reject("lining_surface_bracket");var contact=shapes.boundary(field,a,b);
            if(!owns_wall(field,patch["room"].AsGodotDictionary(),contact))return reject("lining_foreign_wall");var foot=contact-normal*1.25f;var face=contact+normal*(float)(.04+.08*Random(id,"lining/facet/"+i));
            if(Sample(field,foot)<.15||Sample(field,face)>-.015)return reject("lining_whole_foot");front.Add(face);rear.Add(foot);attachments.Add(foot);low=low.Min(face).Min(foot);high=high.Max(face).Max(foot);
        }
        var cap=root+normal*.24f;var back=root-normal*1.25f;attachments.Add(back);low=low.Min(cap).Min(back);high=high.Max(cap).Max(back);
        if(Sample(field,back)<.15||Sample(field,cap)>-.04)return reject("lining_center_attachment");var bounds=new Aabb(low,high-low);
        if(shapes.@protected(field,bounds.GetCenter(),new Vector2(bounds.Size.X,bounds.Size.Z).Length()*.5,low.Y,high.Y))return reject("lining_protected_route");
        var emitter=new Emitter(origin,true);var midpoint=(cap+back)*.5f;
        for(int i=0;i<8;i++){int next=(i+1)%8;emitter.Quad(cap,front[i],front[next],cap,midpoint);emitter.Quad(back,rear[next],rear[i],back,midpoint);emitter.Quad(front[i],rear[i],rear[next],front[next],midpoint);}
        var target=Bucket("mineral_opaque");int first=target.Vertices.Count,family=patch["family"].AsInt32();double age=N(patch,"age");var tint=geometry.tint(family,age).Lerp(new Color(.32f,.30f,.26f),.4f);tint.A=(float)age;
        if(first+emitter.Vertices.Count>MaxVertices)return reject("lining_vertex_budget");
        for(int i=0;i<emitter.Vertices.Count;i++){var p=emitter.Vertices[i];target.Vertices.Add(p);target.Normals.Add(emitter.Normals[i]);target.Colors.Add(tint);target.UVs.Add(new Vector2((float)(family+.08),.3f));target.Growth.Add(new Vector2((p+origin-root).Dot(normal),(float)phase));target.Middle.Add(first+i);target.Far.Add(first+i);}
        placements.Add(new D{["id"]=id,["kind"]="crystal_lining",["owner"]=key,["root"]=root,["axis"]=normal,["height"]=.24,["width"]=radius,["family"]=family,["broken"]=false,["age"]=age,["importance"]=0,["thin_transmission"]=false,["collider"]=false,["attachments"]=attachments.ToArray(),["bounds"]=bounds,["raw_weight"]=weight(field,root+normal*.3f),["batch"]="mineral_opaque",["first_vertex"]=first,["vertex_count"]=emitter.Vertices.Count,["host_room"]=patch["room"].AsGodotDictionary()["id"].AsString()});return true;
    }
    public void clusters(GodotObject field,D room,string identity,long seed_id,double density)
    {
        int family=Math.Min(5,(int)(_regions.random(identity,seed_id,"crystal/mineral")*6)),layout=Get(room,"crystal_layout",Math.Min(5,(int)(_regions.random(identity,seed_id,"crystal/layout")*6))).AsInt32();bool geode=Get(room,"crystal_profile","").AsString()=="geode",lined=geode&&Get(settings,"geode_lining",true).AsBool();string roomId=room["id"].AsString();double phase=_regions.random(roomId,seed_id,"crystal/phase")*Math.Tau;
        int patches=lined?192:geode?48:layout is 0 or 3?24:layout==2?14:7;var roomPoint=room["point"].AsVector3();double roomRadius=N(room,"chamber_radius"),roomHeight=N(room,"chamber_height");
        for(int patch=0;patch<patches;patch++)
        {
            string patchId=roomId+"/patch/"+patch;if(_regions.random(patchId,seed_id,"admit")>density)continue;double angle=phase+patch*Math.Tau/patches;var radial=new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle));
            bool floorForm=geode?patch%8==0:patch%3!=0,ceiling=geode?patch%8==1:patch%7==0;Vector3 root;
            if(floorForm){var start=roomPoint+radial*(float)roomRadius*(float)(.52+_regions.random(patchId,seed_id,"inset")*.23)+Vector3.Up*3;root=boundary(field,start,Vector3.Down,8);}
            else if(ceiling)root=boundary(field,roomPoint+radial*(float)roomRadius*.45f+Vector3.Up*3,Vector3.Up,roomHeight+4);
            else root=boundary(field,roomPoint+Vector3.Up*(float)roomHeight*(float)((geode?.15:.2)+(geode?.65:.35)*_regions.random(patchId,seed_id,"wall_height")),radial,roomRadius+12);
            if(!root.IsFinite()||Cell(field,root)!=key)continue;var normal=Normal(field,root);var tangent=(Math.Abs(normal.Y)<.9?Vector3.Up.Cross(normal):Vector3.Right.Cross(normal)).Normalized();var axis=(normal+tangent*(float)(_regions.random(patchId,seed_id,"tilt")-.5)*.8f).Normalized();
            if(lined&&!floorForm&&!ceiling&&Math.Abs(normal.Y)<.7&&owns_wall(field,room,root))_lining.Add(new D{["id"]=patchId+"/lining",["room"]=room,["root"]=root,["normal"]=normal,["family"]=family,["age"]=_regions.random(identity,seed_id,"crystal/weather")*.7,["phase"]=phase,["priority"]=_regions.random(patchId,seed_id,"lining/priority")});
            bool giant=_regions.random(patchId,seed_id,"giant")<Get(settings,"giant_chance",.18).AsDouble()*(geode?.35:1);double maximum=Get(settings,"maximum_height",32).AsDouble(),fraction=_regions.random(patchId,seed_id,"height"),size=giant?Lerp(Math.Min(8,maximum),maximum,Math.Pow(fraction,.65)):Lerp(2,8,fraction);
            if(family==4)size=giant?Lerp(3,Math.Min(8,maximum),fraction):Lerp(.6,3,fraction);else if(family==5)size=giant?Lerp(3,Math.Min(9,maximum),fraction):Lerp(.7,3.6,fraction);
            if(geode&&!giant&&family is not 4 and not 5)size=Lerp(.7,4,fraction);size=Math.Min(Math.Min(size,maximum),roomHeight*.72);
            double widthFraction=_regions.random(patchId,seed_id,"width"),width=size*(family==2?.055:.10)*Lerp(.7,1.3,widthFraction);if(family==4)width=size/Math.Sqrt(2)*Lerp(.9,1.1,widthFraction);else if(family==5)width=size*.55*Lerp(.8,1.2,widthFraction);
            double age=_regions.random(identity,seed_id,"crystal/weather")*.7;bool broken=_regions.random(patchId,seed_id,"broken")<.16;
            if(floorForm&&family<4&&normal.Y>.75&&_debris.Count<32&&Get(settings,"crystal_debris",false).AsBool()&&_regions.random(patchId,seed_id,"debris/admit")<Get(settings,"debris_chance",.35).AsDouble())
            {
                var start=root+normal*2+tangent*(float)(_regions.random(patchId,seed_id,"debris/offset")-.5)*3;var debrisRoot=boundary(field,start,-normal,6);
                if(debrisRoot.IsFinite()&&Cell(field,debrisRoot)==key)_debris.Add(new D{["id"]=patchId+"/debris",["root"]=debrisRoot,["axis"]=(normal*.45f+tangent*(patch%2==0?.85f:-.85f)).Normalized(),["width"]=.16+.16*_regions.random(patchId,seed_id,"debris/width"),["height"]=.35+.5*_regions.random(patchId,seed_id,"debris/height"),["family"]=family,["age"]=Math.Max(age,.65),["phase"]=phase,["priority"]=_regions.random(patchId,seed_id,"debris/priority")});
            }
            bool selectedClear=family==4&&_regions.random(patchId,seed_id,"clear_cleavage")<.25,joined=false;
            if(giant&&family<4&&Get(settings,"spanning_crystals",false).AsBool()&&_regions.random(patchId,seed_id,"spanning")<Get(settings,"spanning_chance",.15).AsDouble())joined=spanning_form(field,root,axis,width,maximum,family,age,patchId+"/primary",phase);
            if(!joined)form(field,root,axis,width,size,family,broken,age,patchId+"/primary",0,selectedClear,phase);
            int children=geode?3:layout is 0 or 3?8:layout==2?5:2;
            for(int child=0;child<children;child++)
            {
                string childId=patchId+"/secondary/"+child;double fan=child-(children-1)*.5,spread=fan*.6;var childStart=root+normal*2+tangent*(float)spread;var childRoot=boundary(field,childStart,-normal,6);if(!childRoot.IsFinite())continue;
                var childAxis=(normal+tangent*(float)fan*.25f).Normalized();double childSize=Math.Min(maximum,Lerp(.45,family==4?1.8:family==5?2.2:3.8,_regions.random(childId,seed_id,"height")));int childFamily=family;
                if(family is 0 or 1 or 3&&_regions.random(childId,seed_id,"secondary_mineral")<.1)childFamily=0;
                double childWidth=childSize*(family==2?.09:.16);if(childFamily==4)childWidth=childSize/Math.Sqrt(2);else if(childFamily==5)childWidth=childSize*.55;
                form(field,childRoot,childAxis,childWidth,childSize,childFamily,_regions.random(childId,seed_id,"broken")<.22,age,childId,1,true,phase+.2*child);
            }
        }
    }
    public Vector3 vein_contact(GodotObject field,D room,double angle,long band,double offset)
    {
        var radial=new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle));var center=room["point"].AsVector3();var p=center+radial*(float)N(room,"chamber_radius");
        for(int i=0;i<3;i++){double y=(band*Math.PI-.3*Math.Sin(p.X*Math.Tau/96)-.25*Math.Sin(p.Z*Math.Tau/120))*12/Math.Tau+offset;p=boundary(field,new Vector3(center.X,(float)y,center.Z),radial,N(room,"chamber_radius")+12);if(!p.IsFinite())return Vector3.Inf;}return owns_wall(field,room,p)?p:Vector3.Inf;
    }
    public void veins(GodotObject field,D room,string identity,long seed_id,double density)
    {
        string roomId=room["id"].AsString();if(_regions.random(roomId,seed_id,"crystal/vein_admit")>density)return;var point=room["point"].AsVector3();int band=(int)Math.Round((point.Y+N(room,"chamber_height")*.4)/6,MidpointRounding.AwayFromZero),family=Math.Min(5,(int)(_regions.random(identity,seed_id,"crystal/mineral")*6));double age=_regions.random(identity,seed_id,"crystal/weather")*.7;var tint=geometry.tint(family,age);tint.A=(float)age;
        for(int segment=0;segment<32;segment++)
        {
            if(placements.Count>=MaxForms)break;double a=segment*Math.Tau/32,b=(segment+1)*Math.Tau/32,widthA=.12+.3*Math.Pow(.5+.5*Math.Sin(a*7+point.X*.03),2),widthB=.12+.3*Math.Pow(.5+.5*Math.Sin(b*7+point.X*.03),2);
            if(.5+.5*Math.Sin((a+b)*1.5+point.Z*.02)<.28)continue;var directions=new[]{new Vector3((float)Math.Cos(a),0,(float)Math.Sin(a)),new Vector3((float)Math.Cos(b),0,(float)Math.Sin(b))};
            var contacts=new[]{vein_contact(field,room,a,band,-widthA),vein_contact(field,room,b,band,-widthB),vein_contact(field,room,b,band,widthB),vein_contact(field,room,a,band,widthA)};if(contacts.Any(p=>!p.IsFinite()))continue;
            var center=(contacts[0]+contacts[1]+contacts[2]+contacts[3])*.25f;if(Get(settings,"localized_veins",true).AsBool()&&_veins.amount(center)<.2)continue;if(Cell(field,center)!=key||weight(field,center-directions[0]*.5f)<.4)continue;
            var front=new Vector3[4];var rear=new Vector3[4];var low=Vector3.Inf;var high=-Vector3.Inf;bool valid=true;
            for(int i=0;i<4;i++){var direction=directions[i is 0 or 3?0:1];front[i]=contacts[i]-direction*.08f;rear[i]=contacts[i]+direction*1.25f;if(Sample(field,front[i])>-.035||Sample(field,rear[i])<.15)valid=false;low=low.Min(front[i]).Min(rear[i]);high=high.Max(front[i]).Max(rear[i]);}
            var bounds=new Aabb(low,high-low);if(!valid||shapes.@protected(field,bounds.GetCenter(),new Vector2(bounds.Size.X,bounds.Size.Z).Length()*.5,low.Y,high.Y))continue;
            var emitter=new Emitter(origin);var midpoint=(front[0]+front[2]+rear[0]+rear[2])*.25f;emitter.Quad(front[0],front[1],front[2],front[3],midpoint);emitter.Quad(rear[3],rear[2],rear[1],rear[0],midpoint);
            for(int i=0;i<4;i++){int j=(i+1)%4;emitter.Quad(front[i],rear[i],rear[j],front[j],midpoint);}
            var target=Bucket("mineral_bed");int first=target.Vertices.Count;for(int i=0;i<emitter.Vertices.Count;i++){target.Vertices.Add(emitter.Vertices[i]);target.Normals.Add(emitter.Normals[i]);target.Colors.Add(tint);target.UVs.Add(new Vector2((float)(family+.1),.7f));target.Growth.Add(Vector2.Zero);target.Middle.Add(first+i);target.Far.Add(first+i);}
            placements.Add(new D{["id"]=roomId+"/vein/"+band+"/"+segment,["kind"]="mineral_vein",["owner"]=key,["root"]=center,["axis"]=-directions[0],["height"]=2*Math.Max(widthA,widthB),["width"]=.08,["family"]=family,["broken"]=false,["age"]=age,["importance"]=0,["thin_transmission"]=false,["collider"]=false,["attachments"]=rear,["surface_contacts"]=contacts,["host_room"]=roomId,["bounds"]=bounds,["raw_weight"]=weight(field,center-directions[0]*.5f),["batch"]="mineral_bed",["first_vertex"]=first,["vertex_count"]=emitter.Vertices.Count,["fracture_band"]=band});
        }
    }
    private static int Compare(D a,D b){int result=N(a,"priority").CompareTo(N(b,"priority"));return result!=0?result:string.CompareOrdinal(a["id"].AsString(),b["id"].AsString());}
    public D build(GodotObject field,Vector3I cell,long seed_id,A regions,D configuration,D water)
    {
        key=cell;origin=(Vector3)cell*64;settings=configuration;_seed=seed_id;_batches.Clear();placements=new();rejections=new();_lining.Clear();_debris.Clear();geometry=new CrystalCaveGeometry();double density=Math.Clamp(Get(configuration,"density",.65).AsDouble(),0,1);
        if(density<=0)return new D{["valid"]=true,["batches"]=new A(),["placements"]=new A()};
        bool surfaceAir=field.Get("include_surface_air").AsBool();double cover=field.Get("opening_rock_cover").AsDouble();field.Set("include_surface_air",false);field.Set("opening_rock_cover",6);
        try
        {
            var rooms=new SortedDictionary<string,D>(StringComparer.Ordinal);
            foreach(var value in regions)
            {
                var region=value.AsGodotDictionary();if(Get(region,"cave_family",-1).AsInt64() is 6 or 7)continue;
                foreach(var roomValue in Items(region,"nodes").Concat(Items(region,"pockets")).Concat(Items(region,"pools").SelectMany(p=>Items(p.AsGodotDictionary(),"bank_lobes"))))
                {var room=roomValue.AsGodotDictionary();if(Get(room,"level",-1).AsInt64()>=0)rooms[room["id"].AsString()]=room;}
            }
            foreach(var pair in rooms)
            {
                var room=pair.Value;double reach=N(room,"chamber_radius")+6;var center=room["point"].AsVector3();var low=center-new Vector3((float)reach,4,(float)reach);var high=center+new Vector3((float)reach,(float)(N(room,"chamber_height")+4),(float)reach);
                if(high.X<origin.X||low.X>=origin.X+64||high.Z<origin.Z||low.Z>=origin.Z+64||high.Y<origin.Y||low.Y>=origin.Y+64)continue;
                string parent=Get(room,"biome_parent",pair.Key).AsString();var assignment=_regions.along_edge(field.Get("_biome_assignment").AsGodotDictionary(),parent,parent,0,0);if(Get(assignment["weights"].AsGodotDictionary(),"crystal",0).AsDouble()<.3)continue;
                string identity=Get(assignment["candidate_ids"].AsGodotDictionary(),"crystal",pair.Key).AsString();clusters(field,room,identity,seed_id,density);veins(field,room,identity,seed_id,density);
            }
            _debris.Sort(Compare);int debrisCount=0;foreach(var debris in _debris)
            {if(debrisCount>=16||placements.Count>=MaxForms)break;if(form(field,debris["root"].AsVector3(),debris["axis"].AsVector3(),N(debris,"width"),N(debris,"height"),debris["family"].AsInt32(),true,N(debris,"age"),debris["id"].AsString(),1,false,N(debris,"phase"),false,true)){placements[^1].AsGodotDictionary()[new StringName("kind")]="crystal_debris";debrisCount++;}}
            _lining.Sort(Compare);int liningCount=0;foreach(var patch in _lining){if(liningCount>=MaxLining)break;if(lining_patch(field,patch))liningCount++;}
            _corridors.append(this,field,regions,seed_id,configuration);
        }
        finally{field.Set("include_surface_air",surfaceAir);field.Set("opening_rock_cover",cover);}
        var batches=new A();int count=0;
        foreach(var pair in _batches)
        {
            string kind=pair.Key;var b=pair.Value;var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=b.Vertices.ToArray();arrays[(int)Mesh.ArrayType.Normal]=b.Normals.ToArray();arrays[(int)Mesh.ArrayType.Color]=b.Colors.ToArray();arrays[(int)Mesh.ArrayType.TexUV]=b.UVs.ToArray();arrays[(int)Mesh.ArrayType.TexUV2]=b.Growth.ToArray();var indices=Enumerable.Range(0,b.Vertices.Count).ToArray();arrays[(int)Mesh.ArrayType.Index]=indices;count+=indices.Length;var lods=new D();
            if(b.Middle.Count==0||b.Far.Count==0)
            {
                D? representative=null;foreach(var item in placements){var p=item.AsGodotDictionary();if(p["batch"].AsString()==kind&&(representative==null||N(p,"height")>N(representative,"height")))representative=p;}
                if(representative!=null){var keep=Enumerable.Range(representative["first_vertex"].AsInt32(),representative["vertex_count"].AsInt32()).ToArray();if(b.Middle.Count==0)b.Middle.AddRange(keep);if(b.Far.Count==0)b.Far.AddRange(keep);}
            }
            if(Get(configuration,"mesh_lods",true).AsBool()){if(b.Middle.Count>0&&b.Middle.Count<indices.Length)lods[.5]=b.Middle.ToArray();if(b.Far.Count>0&&b.Far.Count<Math.Min(indices.Length,b.Middle.Count))lods[1.5]=b.Far.ToArray();}
            var batch=new D{["kind"]=kind,["arrays"]=arrays,["lods"]=lods,["collision_faces"]=b.Collision.ToArray(),["shadows"]=kind!="mineral_grains"};if(kind=="mineral_clear"){batch["far_kind"]="mineral_opaque";batch["near_distance"]=32.0;}batches.Add(batch);
        }
        return _luminous.apply(new D{["valid"]=count<=MaxVertices,["reason"]=count>MaxVertices?"Crystal cell numeric vertex bound":"",["batches"]=batches,["placements"]=placements,["prototype_count"]=geometry.templates.Count,["rejections"]=rejections},regions,seed_id,configuration);
    }
}
