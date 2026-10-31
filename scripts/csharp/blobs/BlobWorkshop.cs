using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobWorkshop : Node3D
{
    [Export] public bool laboratory{get;set;}
    [Export] public long seed_value{get;set;}=22;
    [Export(PropertyHint.Range,"0,2")] public int quality{get;set;}=1;
    public int last_pass{get;set;}=7;
    public D options{get;set;}=new();
    public BlobOrganism? creature{get;set;}
    public BlobBuildControls? job{get;set;}
    public Label status{get;set;}=null!;
    public Vector3 pending_position{get;set;}
    public Node? terrain{get;set;}
    public Camera3D? camera{get;set;}
    public double elapsed{get;set;}
    public string requested_mode{get;set;}="auto";
    public int lighting_preset{get;set;}
    private Task<D>? worker;
    private readonly BlobBlueprint Blueprint=new();
    private readonly BlobMeshCache Cache=new();
    private readonly List<BaseButton> buildWidgets=new();
    private readonly Dictionary<string,Control> controlWidgets=new(),runtimeWidgets=new();
    private OptionButton modeSelector=null!;
    private static readonly string[] PassNames={"Mass composition","Weight-bearing anatomy","Primary biology","Organic integration","Regional geometry","Connected anatomy","Tissue materials"};
    private bool HasCreature=>IsInstanceValid(creature)&&!creature!.IsQueuedForDeletion();
    public override void _Ready()
    {
        status=new Label();camera=GetViewport().GetCamera3D();terrain=GetParent().GetNodeOrNull("Terrain");var ui=new CanvasLayer();if(!laboratory){ui.AddToGroup("terrain_debug_overlay");ui.Visible=false;}AddChild(ui);
        var panel=new PanelContainer();panel.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.BottomLeft);panel.Position=new Vector2(16,laboratory?-115:-65);ui.AddChild(panel);var stack=new VBoxContainer();panel.AddChild(stack);status.Text="B: grow blob at view  |  Shift+B: next seed  |  M: roll/creep  |  X: remove";stack.AddChild(status);
        if(!laboratory){panel.MouseFilter=Control.MouseFilterEnum.Ignore;stack.MouseFilter=Control.MouseFilterEnum.Ignore;status.MouseFilter=Control.MouseFilterEnum.Ignore;return;}
        var buttons=new HBoxContainer();stack.AddChild(buttons);Button(buttons,"Previous seed",()=>{seed_value--;generate();});Button(buttons,"Next seed",()=>{seed_value++;generate();});Button(buttons,"Next gait",ToggleMode);
        var passes=new OptionButton();foreach(string label in PassNames)passes.AddItem(label);passes.Selected=6;passes.ItemSelected+=i=>{last_pass=(int)i+1;generate();};buttons.AddChild(passes);buildWidgets.Add(passes);
        var mode=new OptionButton();var modes=new[]{"auto"}.Concat(Blueprint.MODES.Select(v=>v.AsString())).ToArray();foreach(string value in modes)mode.AddItem(value=="auto"?"DNA movement":value.Capitalize());mode.ItemSelected+=i=>{requested_mode=modes[(int)i];generate();};buttons.AddChild(mode);buildWidgets.Add(mode);
        Button(buttons,"Surface markers",()=>{if(HasCreature)creature!.debug_circulation=!creature.debug_circulation;});Lighting(0);InspectionControls(ui);Controls(ui);generate();
    }
    private void Button(Control parent,string title,Action action){var button=new Button{Text=title};button.Pressed+=action;parent.AddChild(button);buildWidgets.Add(button);}
    public void generate()
    {
        if(worker is not null)return;
        if(!laboratory)
        {
            camera=GetViewport().GetCamera3D();if(camera is null||!IsInstanceValid(terrain))return;var ray=-camera.GlobalBasis.Z;double distance=0;bool found=false;
            for(int i=1;i<513;i++){var point=camera.GlobalPosition+ray*i*4;if(point.Y<=Height(point)){double low=distance,high=i*4.0;for(int j=0;j<12;j++){double mid=(low+high)*.5;var sample=camera.GlobalPosition+ray*(float)mid;if(sample.Y>Height(sample))low=mid;else high=mid;}pending_position=camera.GlobalPosition+ray*(float)high;found=true;break;}distance=i*4.0;}
            if(!found)pending_position=camera.GlobalPosition+new Vector3(ray.X,0,ray.Z).Normalized()*10;var p=pending_position;p.Y=(float)Height(p);pending_position=p;
        }
        job=new BlobBuildControls();foreach(var widget in buildWidgets)widget.Disabled=true;elapsed=0;var snapshot=options.Duplicate(true);long seed=seed_value;int detail=quality,pass=last_pass;string movement=requested_mode;var controls=job;var cache=Cache;
        try{worker=Task.Run(()=>cache.build(seed,detail,movement,pass,controls,snapshot));}
        catch(Exception error){status.Text=$"Blob worker could not start: {error.Message}";foreach(var widget in buildWidgets)widget.Disabled=false;}
    }
    private double Height(Vector3 point)=>terrain!.Call("get_height_at",point).AsDouble();
    public override void _Process(double delta)
    {
        if(worker is null){if(laboratory&&HasCreature&&creature!.gait_fallback_reason.Length>0){status.Text=$"Seed {seed_value} / {creature.Get("locomotion").AsString()} / {creature.gait_fallback_reason}";modeSelector.Selected=Blueprint.MODES.IndexOf(creature.Get("locomotion").AsString());}return;}
        elapsed+=delta;if(!worker.IsCompleted){var progress=job!.snapshot();status.Text=$"Seed {seed_value} · {progress["message"].AsString()} · {elapsed:F1} s";return;}
        D result;try{result=worker.GetAwaiter().GetResult();}catch(Exception error){result=new D{["error"]=$"Organism generation failed: {error.Message}"};}finally{worker=null;foreach(var widget in buildWidgets)widget.Disabled=false;}
        if(result.ContainsKey("error")||(result.TryGetValue("cancelled",out var cancelled)&&cancelled.AsBool())){status.Text=result.ContainsKey("error")?result["error"].AsString():"Blob build cancelled";return;}
        var previous=HasCreature?creature:null;var candidate=new BlobOrganism{Name=$"Blob_{seed_value}",Visible=false};
        try{AddChild(candidate);candidate.GlobalPosition=pending_position;candidate.terrain=terrain;candidate.ground_height=pending_position.Y;candidate.configure(result);candidate.GlobalPosition=pending_position;candidate.speed=laboratory?((Godot.Range)runtimeWidgets["Travel speed"]).Value:.65;}
        catch(Exception error){candidate.QueueFree();status.Text=$"Organism setup failed; previous creature retained: {error.Message}";return;}
        creature=candidate;creature.Visible=true;previous?.QueueFree();
        if(laboratory){creature.playback_rate=((Godot.Range)runtimeWidgets["Playback rate"]).Value;creature.solver.idle_enabled=((BaseButton)runtimeWidgets["Idle tissue"]).ButtonPressed;creature.solver.secondary_enabled=((BaseButton)runtimeWidgets["Secondary chains"]).ButtonPressed;creature.gait_enabled=((BaseButton)runtimeWidgets["Contact gait"]).ButtonPressed;creature.debug_features=((BaseButton)runtimeWidgets["Feature colors"]).ButtonPressed;creature.debug_contacts=((BaseButton)runtimeWidgets["Contact / cage debug"]).ButtonPressed;modeSelector.Selected=Blueprint.MODES.IndexOf(creature.Get("locomotion").AsString());Lighting(lighting_preset);}
        creature.travel_enabled=true;if(laboratory&&camera is BlobLabCamera labCamera){labCamera.frame_creature(result,creature.solver.height);labCamera.follow_actor(creature);}var dna=result["dna"].AsGodotDictionary();status.Text=$"Seed {seed_value} · {creature.Get("locomotion").AsString()} / {dna["profile"].AsString()} / {dna["body_plan"].AsString()} · {result["features"].AsGodotArray().Count} features · {elapsed:F1} s  |  B: grow  Shift+B: seed  M: mode  X: clear";
    }
    private void ToggleMode()
    {
        if(!HasCreature)return;string original=creature!.Get("locomotion").AsString();var modes=new[]{"roll","vine","limb","contractile","peristaltic","drag","pulse","multicontact"};int start=Array.IndexOf(modes,original);for(int offset=1;offset<=modes.Length;offset++){creature.set_locomotion(modes[(start+offset+modes.Length)%modes.Length]);if(creature.Get("locomotion").AsString()!=original)break;}status.Text=$"Seed {seed_value} · {creature.Get("locomotion").AsString()}  |  B: grow  Shift+B: seed  M: mode  X: clear";
    }
    public override void _UnhandledInput(InputEvent input)
    {
        if(input is not InputEventKey key||!key.Pressed||key.Echo)return;switch(key.PhysicalKeycode){case Key.B:if(worker is not null)return;if(key.ShiftPressed)seed_value++;generate();break;case Key.M:ToggleMode();break;case Key.X:job?.cancel();if(HasCreature)creature!.QueueFree();break;case Key.Escape:if(worker is not null)job?.cancel();break;}
    }
    public override void _ExitTree(){if(worker is null)return;job?.cancel();try{worker.GetAwaiter().GetResult();}catch(Exception error){GD.PushWarning($"Cancelled organism worker: {error.Message}");}finally{worker=null;}}
    private void Controls(CanvasLayer ui)
    {
        var panel=new PanelContainer();panel.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.TopRight);panel.Position=new Vector2(-310,105);panel.CustomMinimumSize=new Vector2(294,465);ui.AddChild(panel);var scroll=new ScrollContainer{CustomMinimumSize=new Vector2(294,465)};panel.AddChild(scroll);var rows=new VBoxContainer{SizeFlagsHorizontal=Control.SizeFlags.ExpandFill};scroll.AddChild(rows);
        Select(rows,"Biology",new[]{"auto"}.Concat(Blueprint.PROFILES.Select(v=>v.AsString())).ToArray(),"profile");Select(rows,"Body plan",new[]{"auto"}.Concat(Blueprint.PLANS.Select(v=>v.AsString())).ToArray(),"body_plan");Select(rows,"Quality",new[]{"Draft","Detailed","High"},"quality");
        foreach(var group in new[]{("Body",new[]{"width","height","length","asymmetry","mass_count","mass_variation","fusion","contact","stiffness"}),("Biology",new[]{"diversity","sacs","lattice","faces","limbs","tentacles","branches","membranes","cavities","stalks","fibers","folds","detail","combinations"}),("Materials",new[]{"wetness","roughness","veins","translucency","microdetail"}),("Movement",new[]{"circulation","softness","gravity"})}){rows.AddChild(new Label{Text=group.Item1});foreach(string name in group.Item2)Slider(rows,name);}
        Select(rows,"Palette",new[]{"DNA palette","Ochre","Gray flesh","Muted olive","Sickly flesh","Bruised"},"palette");Button(rows,"Grow with these settings",generate);Button(rows,"Reset settings",()=>{foreach(var pair in controlWidgets){if(pair.Value is HSlider slider)slider.Value=Blueprint.CONTROL_DEFAULTS[pair.Key].AsDouble();else if(pair.Value is OptionButton choice)choice.Selected=pair.Key=="quality"?1:0;}options.Clear();quality=1;generate();});
    }
    private void Select(Control parent,string title,string[] values,string name)
    {
        parent.AddChild(new Label{Text=title});var select=new OptionButton();foreach(string value in values)select.AddItem(value.Capitalize());if(name=="quality")select.Selected=quality;select.ItemSelected+=i=>{if(name=="quality")quality=(int)i;else if(name=="palette")options[name]=(int)i-1;else options[name]=values[(int)i];};parent.AddChild(select);buildWidgets.Add(select);controlWidgets[name]=select;
    }
    private void Slider(Control parent,string name)
    {
        var row=new HBoxContainer();parent.AddChild(row);row.AddChild(new Label{Text=name.Replace("_"," ").Capitalize(),CustomMinimumSize=new Vector2(150,0)});var slider=new HSlider{CustomMinimumSize=new Vector2(85,0),MinValue=0,MaxValue=name=="mass_count"?12:2,Step=name=="mass_count"?1:.05,Value=Blueprint.CONTROL_DEFAULTS[name].AsDouble()};slider.TooltipText=$"{slider.Value:F2}";slider.ValueChanged+=value=>{options[name]=value;slider.TooltipText=$"{value:F2}";};row.AddChild(slider);controlWidgets[name]=slider;
    }
}
