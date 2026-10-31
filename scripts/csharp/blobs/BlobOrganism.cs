using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>One deformable tissue frame, three render groups and a bounded anatomical collision cage.</summary>
public partial class BlobOrganism : CharacterBody3D
{
    [Signal] public delegate void SeekCompletedEventHandler();
    public BlobAppendageContacts contacts{get;set;}=new();
    public BlobSurfaceCirculation solver{get;set;}=new();
    public double playback_rate{get;set;}=1;
    public bool debug_features{get;set;}
    public bool debug_strain{get;set;}
    public bool rest_pose_enabled{get;set;}
    public Transform3D initial_transform{get;set;}=Transform3D.Identity;
    public double rest_height{get;set;}=1;
    public int seek_token{get;set;}
    public string gait_fallback_reason{get;set;}="";
    public bool debug_contacts{get;set;}
    public bool gait_enabled{get;set;}=true;
    public double body_contact_slip{get;set;}
    public D anatomy{get;set;}=new();
    private string locomotion="roll";
    public override Variant _Get(StringName property)=>property=="locomotion"?(Variant)locomotion:default(Variant);
    public override Godot.Collections.Array<D> _GetPropertyList()=>new(){new D{["name"]="locomotion",["type"]=(int)Variant.Type.String,["usage"]=(int)PropertyUsageFlags.Default}};
    public override bool _Set(StringName property,Variant value){if(property=="locomotion"){locomotion=value.AsString();return true;}return false;}
    public double speed{get;set;}
    public Vector3 direction{get;set;}=Vector3.Forward;
    public double ground_height{get;set;}
    public Node3D body{get;set;}=new();
    public Godot.Collections.Array<D> attachments{get;set;}=new();
    public Godot.Collections.Array<ShaderMaterial> materials{get;set;}=new();
    public Godot.Collections.Array<MeshInstance3D> render_instances{get;set;}=new();
    public Skeleton3D skeleton{get;set;}=new();
    public Node? terrain{get;set;}
    public bool travel_enabled{get;set;}
    public bool simulation_enabled{get;set;}=true;
    public bool debug_circulation{get;set;}
    public double phase{get;set;}
    public double roll_angle{get;set;}
    public int lod_count{get;set;}
    public ulong last_simulation_usec{get;set;}
    private double stallTime,strokeTime,rearLag,rearLagVelocity;
    private int lastCycles;
    private readonly MeshInstance3D debugMesh=new();
    private readonly List<int> bodyVertexIds=new();
    private readonly Dictionary<int,Vector3> bodyGrips=new();
    private readonly List<CollisionShape3D> collisionNodes=new();
    private readonly BlobCurveFrames Frames=new();
    private D Dna=>anatomy["dna"].AsGodotDictionary();
    private D Rig=>anatomy["rig"].AsGodotDictionary();
    private static bool Is(string v,params string[] choices)=>Array.IndexOf(choices,v)>=0;
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Mod(double value,double modulus)=>value-Math.Floor(value/modulus)*modulus;
    public void configure(D data)
    {
        anatomy=data;initial_transform=GlobalTransform;var bodyMesh=data["body"].AsGodotDictionary();var features=data["features"].AsGodotArray();var appendages=data["appendages"].AsGodotArray();var vertices=bodyMesh["vertices"].AsVector3Array();double lowest=0;
        foreach(var p in vertices)lowest=Math.Min(lowest,p.Y);foreach(var item in appendages)foreach(var p in item.AsGodotDictionary()["mesh"].AsGodotDictionary()["vertices"].AsVector3Array())lowest=Math.Min(lowest,p.Y);rest_height=-lowest+.01;
        if(!Rig.ContainsKey("obstacle_volumes"))
        {
            var volumes=new A();Rig["obstacle_volumes"]=volumes;foreach(var value in features){var f=value.AsGodotDictionary();var radii=f["radii"].AsVector3();if(f.ContainsKey("points")||f["subtract"].AsBool()||radii[(int)radii.MaxAxisIndex()]<Dna["size"].AsDouble()*.18)continue;volumes.Add(new D{["center"]=f["center"],["radii"]=radii,["basis"]=(f.TryGetValue("inverse_basis",out var basis)?basis.AsBasis():Basis.Identity).Transposed(),["feature_id"]=f["id"]});}
        }
        locomotion=Dna["locomotion"].AsString();var core=Dna["core_radii"].AsVector3();
        for(int cell=0;cell<3;cell++)foreach(double edge in new[]{-1.0,1.0}){var target=new Vector3(0,(float)(-core.Y*.85),(float)((cell-1.0)*core.Z*.45+edge*core.Z*.24));double best=double.PositiveInfinity;int selected=0;for(int i=0;i<vertices.Length;i++){double score=vertices[i].DistanceSquaredTo(target);if(score<best){best=score;selected=i;}}bodyVertexIds.Add(selected);}
        solver.configure(Dna,Rig,bodyMesh);AddChild(body);body.Name="DeformableShell";
        var coupled=EmptyGroup();var membranes=EmptyGroup();foreach(var value in appendages){var item=value.AsGodotDictionary();var f=item["feature"].AsGodotDictionary();Merge(f["tissue"].AsString()=="membrane"?membranes:coupled,item["mesh"].AsGodotDictionary());attachments.Add(new D{["feature"]=f});}
        var groups=new[]{bodyMesh,coupled,membranes};for(int index=0;index<groups.Length;index++){var group=groups[index];if(group["vertices"].AsVector3Array().Length==0)continue;var instance=MakeInstance(group,MakeMaterial(index==2));body.AddChild(instance);render_instances.Add(instance);}
        skeleton.Name="AnatomicalCage";body.AddChild(skeleton);var bones=Rig["bone_positions"].AsGodotArray();for(int i=0;i<bones.Count;i++){skeleton.AddBone($"mass_{i}");if(i>0)skeleton.SetBoneParent(i,0);var parent=i>0?bones[0].AsVector3():Vector3.Zero;skeleton.SetBoneRest(i,new Transform3D(Basis.Identity,bones[i].AsVector3()-parent));}skeleton.ResetBonePoses();
        foreach(var value in Rig["collision_proxies"].AsGodotArray().Take(5)){var proxy=value.AsGodotDictionary();var radii=proxy["radii"].AsVector3();var collision=new CollisionShape3D{Shape=new SphereShape3D{Radius=(float)Math.Max(.12,Math.Min(radii.X,Math.Min(radii.Y,radii.Z))*.9)},Position=solver.map_point(proxy["center"].AsVector3())+Vector3.Up*(float)solver.height};AddChild(collision);collisionNodes.Add(collision);}
        SetMeta("blob_dna",Dna);SetMeta("blob_rig",Rig);AddChild(debugMesh);
        if(!Dna.ContainsKey("roll_compatibility"))Dna["roll_compatibility"]=features.Any(v=>v.AsGodotDictionary()["feature_type"].AsString()=="embedded_face")?.28:Rig["chains"].AsGodotArray().Any(v=>v.AsGodotDictionary()["kind"].AsString()=="leg")?.5:1.0;
        contacts.configure(this,Rig["chains"].AsGodotArray());set_locomotion(locomotion);UpdateUniforms();
    }
    private ShaderMaterial MakeMaterial(bool membrane)
    {
        var mat=new ShaderMaterial{Shader=GD.Load<Shader>(membrane?"res://shaders/blob_membrane.gdshader":"res://shaders/blob_organism.gdshader")};var stages=anatomy["stages"].AsGodotArray();mat.SetShaderParameter("tissue_enabled",stages[^1].AsGodotDictionary()["pass"].AsInt32()==7);var controls=Dna["controls"].AsGodotDictionary();
        if(membrane)mat.SetShaderParameter("translucency",controls["translucency"]);else{mat.SetShaderParameter("roughness_scale",controls["roughness"]);mat.SetShaderParameter("vein_visibility",controls["veins"]);mat.SetShaderParameter("microdetail",controls["microdetail"]);}mat.SetShaderParameter("follow_through",controls["follow_through"]);mat.SetShaderParameter("wobble",controls["wobble"]);materials.Add(mat);return mat;
    }
    private MeshInstance3D MakeInstance(D data,Material material)
    {
        var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);foreach(var pair in new[]{("vertices",Mesh.ArrayType.Vertex),("normals",Mesh.ArrayType.Normal),("indices",Mesh.ArrayType.Index),("colors",Mesh.ArrayType.Color),("uvs",Mesh.ArrayType.TexUV),("uvs2",Mesh.ArrayType.TexUV2),("anchors",Mesh.ArrayType.Custom0),("binds",Mesh.ArrayType.Custom1),("chain_binds",Mesh.ArrayType.Custom2)})arrays[(int)pair.Item2]=data[pair.Item1];
        ulong flags=((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom0Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom1Shift)|((ulong)Mesh.ArrayCustomFormat.RgbaFloat<<(int)Mesh.ArrayFormat.FormatCustom2Shift);
        using var importer=new ImporterMesh();importer.AddSurface(Mesh.PrimitiveType.Triangles,arrays,new Godot.Collections.Array<A>(),new D(),material,"anatomical_surface",flags);
        // Simplified LODs remain withheld until deformation attributes can be certified.
        lod_count+=importer.GetSurfaceLodCount(0);var core=Dna["core_radii"].AsVector3();return new MeshInstance3D{Mesh=importer.GetMesh(),MaterialOverride=material,ExtraCullMargin=(float)(Math.Max(core.Y,core.Z)*1.5),LodBias=.8f};
    }
    private static D EmptyGroup()=>new(){["vertices"]=Array.Empty<Vector3>(),["normals"]=Array.Empty<Vector3>(),["indices"]=Array.Empty<int>(),["colors"]=Array.Empty<Color>(),["uvs"]=Array.Empty<Vector2>(),["uvs2"]=Array.Empty<Vector2>(),["anchors"]=Array.Empty<float>(),["mechanics"]=Array.Empty<float>(),["binds"]=Array.Empty<float>(),["chain_binds"]=Array.Empty<float>()};
    private static void Merge(D group,D mesh)
    {
        int offset=group["vertices"].AsVector3Array().Length;
        foreach(string key in new[]{"vertices","normals"})group[key]=group[key].AsVector3Array().Concat(mesh[key].AsVector3Array()).ToArray();
        group["colors"]=group["colors"].AsColorArray().Concat(mesh["colors"].AsColorArray()).ToArray();foreach(string key in new[]{"uvs","uvs2"})group[key]=group[key].AsVector2Array().Concat(mesh[key].AsVector2Array()).ToArray();foreach(string key in new[]{"anchors","mechanics","binds","chain_binds"})group[key]=group[key].AsFloat32Array().Concat(mesh[key].AsFloat32Array()).ToArray();group["indices"]=group["indices"].AsInt32Array().Concat(mesh["indices"].AsInt32Array().Select(i=>i+offset)).ToArray();
    }
    public override void _PhysicsProcess(double delta){if(simulation_enabled&&!rest_pose_enabled)simulate(delta);}
    public void simulate(double delta)
    {
        if(anatomy.Count==0)return;ulong started=Time.GetTicksUsec();double dt=Math.Clamp(delta*playback_rate,0,.04);if(dt<=0)return;
        if(direction.LengthSquared()>.01){double desired=Math.Atan2(-direction.X,-direction.Z);solver.heading+=Math.Clamp(Mathf.AngleDifference(solver.heading,desired),-dt*.65,dt*.65);}var steering=Vector3.Forward.Rotated(Vector3.Up,(float)solver.heading);SampleGround();double traction=gait_enabled?contacts.traction(locomotion):0,drive=1;
        if(Is(locomotion,"limb","vine","drag","multicontact"))drive=traction;else if(locomotion=="hybrid")drive=.55+.45*traction;
        var previous=BodyContactPoints();strokeTime+=dt*Math.Abs(speed);solver.strain=Vector3.Zero;
        if(Is(locomotion,"contractile","peristaltic","undulate","pulse")){double stroke=Mod(strokeTime,1.4)/1.4;var strain=Vector3.Zero;for(int chamber=0;chamber<3;chamber++){double t=Mod(stroke-chamber*(Is(locomotion,"peristaltic","undulate")?.22:0),1),envelope=Smooth(0,.3,t)*(1-Smooth(.55,.95,t));strain[chamber]=(float)(envelope*(locomotion=="pulse"?.13:.22));}solver.strain=strain;drive=.25+.75*Smooth(0,.35,stroke)*(1-Smooth(.6,.95,stroke));}
        double dragTarget=locomotion=="drag"?.12*Math.Min(Math.Abs(speed),1)*traction:0;rearLagVelocity+=((dragTarget-rearLag)*12-rearLagVelocity*6)*dt;rearLag+=rearLagVelocity*dt;var strainValue=solver.strain;strainValue.Z+=(float)rearLag;solver.strain=strainValue;if(locomotion=="drag")drive*=.45;
        solver.step(dt,speed*drive,locomotion);bool muscle=Is(locomotion,"contractile","peristaltic","undulate","pulse");var muscleDelta=muscle?BodyContactDrive(previous):Vector3.Zero;if(!muscle)bodyGrips.Clear();double distance=solver.current_speed*dt;
        if(travel_enabled){var before=GlobalPosition;var displacement=steering*(float)distance;if(Is(locomotion,"vine","limb","drag","multicontact"))displacement=contacts.pull_displacement(dt,steering,solver.current_speed,locomotion);if(muscle)displacement=muscleDelta;if(IsInsideTree())MoveAndCollide(displacement);else Position+=displacement;distance=(GlobalPosition-before).Dot(steering);if(IsInstanceValid(terrain))ground_height=terrain!.Call("get_height_at",GlobalPosition).AsDouble();var p=GlobalPosition;p.Y=(float)(p.Y+(ground_height-p.Y)*(1-Math.Exp(-dt*14)));GlobalPosition=p;}
        solver.advance_distance(distance);solver._solve_support(0,false);phase=solver.phase;roll_angle=solver.circulation;contacts.gait_enabled=gait_enabled;contacts.secondary_enabled=solver.secondary_enabled;contacts.step(dt,locomotion,steering,solver.current_speed);
        int cycles=contacts.chains.Sum(c=>c.AsGodotDictionary()["cycles"].AsInt32());if(cycles>lastCycles)stallTime=0;else if(travel_enabled&&gait_enabled&&Math.Abs(speed)>.2&&Is(locomotion,"vine","limb","drag","multicontact"))stallTime+=dt;if(!gait_enabled)stallTime=0;lastCycles=cycles;
        if(stallTime>1.8){string previousMode=locomotion;set_locomotion("contractile");gait_fallback_reason=$"{previousMode.Capitalize()} could not establish a safe grip; using contraction";}
        UpdateUniforms();var bones=Rig["bone_positions"].AsGodotArray();for(int i=0;i<skeleton.GetBoneCount();i++){var parent=i>0?solver.map_point(bones[0].AsVector3()):Vector3.Zero;skeleton.SetBonePosePosition(i,solver.map_point(bones[i].AsVector3())-parent);}var proxies=Rig["collision_proxies"].AsGodotArray();for(int i=0;i<collisionNodes.Count;i++)collisionNodes[i].Position=solver.map_point(proxies[i].AsGodotDictionary()["center"].AsVector3())+Vector3.Up*(float)solver.height;DrawDebug();last_simulation_usec=Time.GetTicksUsec()-started;
    }
    private void SampleGround()
    {
        if(!IsInstanceValid(terrain))return;float extent=Math.Max(solver.footprint.X,solver.footprint.Y);solver.footprint=Vector2.One*extent;
        for(int z=0;z<3;z++)for(int x=0;x<3;x++){var sample=GlobalPosition+new Vector3((x-1)*extent,0,(z-1)*extent);solver.ground[z*3+x]=(float)(terrain!.Call("get_height_at",sample).AsDouble()-GlobalPosition.Y);}
    }
    public void UpdateUniforms()
    {
        var p=body.Position;p.Y=(float)(rest_pose_enabled?rest_height:solver.height);body.Position=p;var uniforms=solver.uniforms();uniforms.Merge(contacts.uniforms(),true);foreach(var material in materials){foreach(var pair in uniforms)material.SetShaderParameter(pair.Key.AsStringName(),pair.Value);material.SetShaderParameter("debug_circulation",debug_circulation);material.SetShaderParameter("debug_features",debug_features);material.SetShaderParameter("debug_strain",debug_strain);material.SetShaderParameter("rest_pose",rest_pose_enabled);}
    }
    public void _update_uniforms()=>UpdateUniforms();
    public Vector3 attachment_position(int featureId)
    {
        var features=anatomy["features"].AsGodotArray();var f=features[featureId].AsGodotDictionary();var ids=Rig["chain_ids"].AsGodotDictionary();int id=featureId;
        for(int steps=0;id>=0;steps++){if(id>=features.Count||steps>=features.Count)throw new ArgumentException("Anatomical attachments require an acyclic hierarchy.");if(ids.TryGetValue(id,out var chainId)){var c=contacts.chains[chainId.AsInt32()].AsGodotDictionary();var points=c["points"].AsVector3Array();if(id==featureId)return points[0];if(Is(f["feature_type"].AsString(),"sensory_bulb","gripping_digit"))return points[^1];return Frames.point(points,f.TryGetValue("parent_along",out var along)?along.AsDouble():.5);}id=features[id].AsGodotDictionary()["parent"].AsInt32();}return GlobalPosition+Vector3.Up*(float)solver.height+solver.map_point(f["center"].AsVector3());
    }
    public void set_locomotion(string mode)
    {
        if(mode=="creep")mode="limb";if(!solver.MODES.Contains(mode))return;gait_fallback_reason="";stallTime=0;string requested=mode;
        bool Reachable(D c,string kind,double fraction){var root=contacts._root(c);return c["kind"].AsString()==kind&&root.Y-contacts._terrain_target(root).Y<c["length"].AsDouble()*fraction;}
        bool legs=contacts.chains.Any(c=>Reachable(c.AsGodotDictionary(),"leg",.94)),vines=contacts.chains.Any(c=>Reachable(c.AsGodotDictionary(),"vine",.82));if(mode=="hybrid"&&solver.roll_safe)mode="roll";if(Is(mode,"roll","hybrid")&&!solver.roll_safe)mode=legs?"limb":vines?"vine":"contractile";if(mode=="limb"&&!legs)mode=vines?"vine":"contractile";if(Is(mode,"vine","drag")&&!vines)mode=legs?"limb":"contractile";if(mode=="multicontact"&&!(legs||vines))mode="peristaltic";if(mode!=requested)gait_fallback_reason=$"{requested.Capitalize()} is incompatible with this anatomy; using {mode}";solver.use_leg_support=mode=="limb";if(mode!=locomotion){locomotion=mode;contacts.force_release=true;bodyGrips.Clear();}
    }
    private void DrawDebug()
    {
        debugMesh.Visible=debug_contacts;if(!debug_contacts)return;var mesh=new ImmediateMesh();var mat=new StandardMaterial3D{ShadingMode=BaseMaterial3D.ShadingModeEnum.Unshaded,VertexColorUseAsAlbedo=true};mesh.SurfaceBegin(Mesh.PrimitiveType.Lines,mat);
        foreach(var value in contacts.chains){var c=value.AsGodotDictionary();mesh.SurfaceSetColor(c["state"].AsString()=="stance"&&c["active"].AsBool()?Colors.Green:Colors.Orange);var points=c["points"].AsVector3Array();for(int i=0;i<7;i++){mesh.SurfaceAddVertex(points[i]-GlobalPosition);mesh.SurfaceAddVertex(points[i+1]-GlobalPosition);}var target=c["target"].AsVector3()-GlobalPosition;foreach(var axis in new[]{Vector3.Right,Vector3.Up,Vector3.Forward}){mesh.SurfaceAddVertex(target-axis*.07f);mesh.SurfaceAddVertex(target+axis*.07f);}}
        mesh.SurfaceSetColor(Colors.Cyan);foreach(var sample in solver.support_samples){var point=solver.map_bound(sample["p"].AsVector3(),sample["group"].AsInt32(),sample["weight"].AsDouble())+Vector3.Up*(float)solver.height;mesh.SurfaceAddVertex(point);mesh.SurfaceAddVertex(point+Vector3.Up*.05f);}mesh.SurfaceEnd();debugMesh.Mesh=mesh;
    }
    private Vector3[] BodyContactPoints()
    {
        var mesh=anatomy["body"].AsGodotDictionary();var vertices=mesh["vertices"].AsVector3Array();var binds=mesh["binds"].AsFloat32Array();return bodyVertexIds.Select(i=>solver.map_bound(vertices[i],(int)binds[i*4]-1,binds[i*4+1])+Vector3.Up*(float)solver.height).ToArray();
    }
    private Vector3 BodyContactDrive(Vector3[] previous)
    {
        var current=BodyContactPoints();var correction=Vector3.Zero;int count=0;var used=new HashSet<int>();double stroke=Mod(strokeTime,1.4)/1.4;
        for(int cell=0;cell<3;cell++){double t=Mod(stroke-cell*(Is(locomotion,"peristaltic","undulate")?.22:0),1);int index=cell*2+(speed<0?(t<.5?1:0):(t<.5?0:1));used.Add(index);if(!bodyGrips.ContainsKey(index))bodyGrips[index]=GlobalPosition+previous[index];var residual=bodyGrips[index]-(GlobalPosition+current[index]);residual.Y=0;correction+=residual;count++;}
        foreach(int index in bodyGrips.Keys.ToArray())if(!used.Contains(index))bodyGrips.Remove(index);correction/=Math.Max(count,1);body_contact_slip=0;foreach(int index in used){var residual=bodyGrips[index]-(GlobalPosition+current[index]+correction);residual.Y=0;body_contact_slip=Math.Max(body_contact_slip,residual.Length());}return correction.LimitLength(.04f);
    }
    public Signal seek(double seconds)
    {
        int token=++seek_token;Callable.From(()=>SeekPlayback(seconds,token)).CallDeferred();return new Signal(this,SignalName.SeekCompleted);
    }
    private async void SeekPlayback(double seconds,int token)
    {
        try
        {
            if(token!=seek_token||!IsInsideTree()||IsQueuedForDeletion())return;simulation_enabled=false;rest_pose_enabled=false;GlobalTransform=initial_transform;solver=new BlobSurfaceCirculation();solver.configure(Dna,Rig,anatomy["body"].AsGodotDictionary());contacts=new BlobAppendageContacts();contacts.configure(this,Rig["chains"].AsGodotArray());strokeTime=0;rearLag=0;rearLagVelocity=0;bodyGrips.Clear();phase=0;roll_angle=0;stallTime=0;lastCycles=0;set_locomotion(locomotion);
            for(int frame=0;frame<(int)Math.Ceiling(Math.Clamp(seconds,0,12)*30);frame++){if(token!=seek_token||!IsInstanceValid(this)||IsQueuedForDeletion())return;simulate(1.0/30);if(frame%8==0)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);}if(token==seek_token&&IsInstanceValid(this)&&!IsQueuedForDeletion())UpdateUniforms();
        }
        catch(Exception error){if(IsInstanceValid(this)&&!IsQueuedForDeletion()){simulation_enabled=false;GD.PushError("Organism replay stopped: "+error.Message);}}
        finally{if(IsInstanceValid(this)&&!IsQueuedForDeletion())EmitSignal(SignalName.SeekCompleted);}
    }
}
