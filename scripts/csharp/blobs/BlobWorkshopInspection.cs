using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobWorkshop
{
    private Godot.Environment LabEnvironment=>GetParent().GetNode<WorldEnvironment>("Environment").Environment;
    private void EnvironmentSlider(Control rows,string title,double min,double max,double value,Action<double> callback)
    {
        rows.AddChild(new Label{Text=title});var slider=new HSlider{MinValue=min,MaxValue=max,Step=(max-min)/100,Value=value};slider.ValueChanged+=v=>callback(v);rows.AddChild(slider);
    }
    private void InspectionControls(CanvasLayer ui)
    {
        var panel=new PanelContainer{Position=new Vector2(16,112)};ui.AddChild(panel);var scroll=new ScrollContainer{CustomMinimumSize=new Vector2(215,480)};panel.AddChild(scroll);var rows=new VBoxContainer{CustomMinimumSize=new Vector2(195,0)};scroll.AddChild(rows);
        var light=new OptionButton();foreach(string title in new[]{"Studio","Daylight","Overcast","Low sun","Dark / rim","Clay"})light.AddItem(title);light.ItemSelected+=i=>Lighting((int)i);rows.AddChild(light);
        rows.AddChild(new Label{Text="Exposure"});var exposure=new HSlider{MinValue=.25,MaxValue=2,Step=.05,Value=1,TooltipText="Exposure"};exposure.ValueChanged+=v=>LabEnvironment.TonemapExposure=(float)v;rows.AddChild(exposure);
        var background=new ColorPickerButton{Color=new Color(.13f,.145f,.15f),Text="Background",TooltipText="Background color"};background.ColorChanged+=color=>LabEnvironment.BackgroundColor=color;rows.AddChild(background);
        var play=new Button{Text="Play / pause"};play.Pressed+=()=>{if(HasCreature)creature!.simulation_enabled=!creature.simulation_enabled;};rows.AddChild(play);
        var step=new Button{Text="Step 1/60 s"};step.Pressed+=()=>{if(!HasCreature)return;creature!.simulation_enabled=false;((BaseButton)runtimeWidgets["Exact rest mesh"]).ButtonPressed=false;double rate=creature.playback_rate;creature.playback_rate=1;try{creature.simulate(1.0/60);}finally{creature.playback_rate=rate;}};rows.AddChild(step);
        foreach(string name in new[]{"Playback rate","Travel speed"}){rows.AddChild(new Label{Text=name});var slider=new HSlider{MinValue=name=="Playback rate"?0:-1,MaxValue=2,Step=.05,Value=name=="Playback rate"?1:.65};slider.ValueChanged+=v=>{if(!HasCreature)return;if(name=="Playback rate")creature!.playback_rate=v;else creature!.speed=v;};rows.AddChild(slider);runtimeWidgets[name]=slider;}
        modeSelector=new OptionButton();foreach(string mode in Blueprint.MODES)modeSelector.AddItem(mode.Capitalize());modeSelector.ItemSelected+=i=>{if(HasCreature)creature!.set_locomotion(Blueprint.MODES[(int)i].AsString());};rows.AddChild(modeSelector);
        foreach(string name in new[]{"Idle tissue","Secondary chains","Contact gait","Feature colors","Contact / cage debug","Exact rest mesh","Strain colors"})
        {
            var toggle=new CheckButton{Text=name,ButtonPressed=name is "Idle tissue" or "Secondary chains" or "Contact gait"};toggle.Toggled+=on=>{if(!HasCreature)return;switch(name){case "Idle tissue":creature!.solver.idle_enabled=on;break;case "Secondary chains":creature!.solver.secondary_enabled=on;break;case "Contact gait":creature!.gait_enabled=on;break;case "Feature colors":creature!.debug_features=on;break;case "Contact / cage debug":creature!.debug_contacts=on;break;case "Strain colors":creature!.debug_strain=on;break;default:creature!.rest_pose_enabled=on;if(on)creature.simulation_enabled=false;break;}creature.UpdateUniforms();};rows.AddChild(toggle);runtimeWidgets[name]=toggle;
        }
        rows.AddChild(new Label{Text="Scrub replay (seconds)"});var timeline=new HSlider{MinValue=0,MaxValue=12,Step=.1};rows.AddChild(timeline);timeline.DragEnded+=_=>{if(HasCreature){((BaseButton)runtimeWidgets["Exact rest mesh"]).ButtonPressed=false;creature!.seek(timeline.Value);}};
        var follow=new CheckButton{Text="Follow creature",ButtonPressed=true};follow.Toggled+=on=>{if(camera is BlobLabCamera lab)lab.follow_enabled=on;};rows.AddChild(follow);
        EnvironmentSlider(rows,"Travel heading",-180,180,0,v=>{if(HasCreature)creature!.direction=Vector3.Forward.Rotated(Vector3.Up,(float)(v*Math.PI/180));});
        var feature=new SpinBox{MinValue=0,MaxValue=1000,Prefix="Feature "};rows.AddChild(feature);var focusButton=new Button{Text="Focus feature"};focusButton.Pressed+=()=>{if(HasCreature&&camera is BlobLabCamera lab)lab.focus_feature(creature!,Math.Clamp((int)feature.Value,0,creature!.anatomy["features"].AsGodotArray().Count-1));};rows.AddChild(focusButton);
        var metadata=new Label{AutowrapMode=TextServer.AutowrapMode.WordSmart,CustomMinimumSize=new Vector2(185,90)};rows.AddChild(metadata);feature.ValueChanged+=value=>{if(!HasCreature)return;var features=creature!.anatomy["features"].AsGodotArray();var f=features[Math.Clamp((int)value,0,features.Count-1)].AsGodotDictionary();string role=f.TryGetValue("animation_role",out var r)?r.AsString():f["locomotion_relevance"].AsString(),omission=f.TryGetValue("omission_reason",out var o)?o.AsString():f.TryGetValue("fused_path",out var fused)&&fused.AsBool()?"Integrated":"Surface/curve attached";metadata.Text=$"{f["feature_type"].AsString()}\nTissue: {f["tissue"].AsString()} · parent {f["parent"].AsInt32()}\n{role}\n{omission}";};
        var views=new OptionButton();foreach(string title in new[]{"Front","Back","Left","Right","Top","Bottom","Three-quarter"})views.AddItem(title);views.Selected=6;views.ItemSelected+=i=>{if(camera is BlobLabCamera lab)lab.quick_view((int)i);};rows.AddChild(views);
        var floorToggle=new CheckButton{Text="Show ground",ButtonPressed=true};floorToggle.Toggled+=on=>GetParent().GetNode<Node3D>("Floor").Visible=on;rows.AddChild(floorToggle);
        var key=GetParent().GetNode<DirectionalLight3D>("Key");var environment=LabEnvironment;
        EnvironmentSlider(rows,"Light intensity",0,4,1.5,v=>key.LightEnergy=(float)v);
        EnvironmentSlider(rows,"Light azimuth",-180,180,-35,v=>{var rotation=key.RotationDegrees;rotation.Y=(float)v;key.RotationDegrees=rotation;});
        EnvironmentSlider(rows,"Light elevation",-85,5,-45,v=>{var rotation=key.RotationDegrees;rotation.X=(float)v;key.RotationDegrees=rotation;});
        EnvironmentSlider(rows,"Warm / cool light",0,1,.5,v=>key.LightColor=new Color(1,.65f,.38f).Lerp(new Color(.65f,.8f,1),(float)v));
        EnvironmentSlider(rows,"Ambient light",0,2,.6,v=>environment.AmbientLightEnergy=(float)v);
        EnvironmentSlider(rows,"Sky reflections",0,2,.4,v=>{if(environment.Sky?.SkyMaterial is ProceduralSkyMaterial sky)sky.EnergyMultiplier=(float)v;});
        EnvironmentSlider(rows,"Shadow softness",0,4,.5,v=>key.LightAngularDistance=(float)v);
        var groundColor=new ColorPickerButton{Color=new Color(.21f,.225f,.22f),TooltipText="Ground color"};groundColor.ColorChanged+=color=>{var floor=GetParent().GetNode<GeometryInstance3D>("Floor");if(floor.MaterialOverride is ShaderMaterial mat)mat.SetShaderParameter("base_color",color);};rows.AddChild(groundColor);
        var tone=new OptionButton();foreach(string title in new[]{"Linear","Reinhard","Filmic","ACES"})tone.AddItem(title);tone.Selected=2;tone.ItemSelected+=i=>environment.TonemapMode=(Godot.Environment.ToneMapper)i;rows.AddChild(tone);
    }
    private void Lighting(int index)
    {
        lighting_preset=index;var environment=LabEnvironment;var key=GetParent().GetNode<DirectionalLight3D>("Key");var fill=GetParent().GetNode<DirectionalLight3D>("Fill");
        if(environment.Sky is null){environment.Sky=new Sky{SkyMaterial=new ProceduralSkyMaterial{SkyTopColor=new Color(.23f,.31f,.42f),SkyHorizonColor=new Color(.65f,.7f,.72f),EnergyMultiplier=.4f}};environment.ReflectedLightSource=Godot.Environment.ReflectionSource.Sky;}
        key.LightAngularDistance=.5f;key.LightEnergy=new[]{1.5f,1.9f,.65f,2,.7f,1.2f}[index];fill.LightEnergy=new[]{.8f,.35f,.5f,.25f,.9f,.6f}[index];environment.AmbientLightEnergy=new[]{.6f,.55f,.9f,.3f,.12f,.65f}[index];key.LightColor=index==3?new Color(1,.63f,.35f):new Color(1,.92f,.82f);key.RotationDegrees=new Vector3(index==3?-12:-45,-35,0);fill.LightColor=index==4?new Color(.5f,.65f,1):new Color(.75f,.85f,1);if(HasCreature)foreach(var mat in creature!.materials)mat.SetShaderParameter("tissue_enabled",index!=5);
    }
}
