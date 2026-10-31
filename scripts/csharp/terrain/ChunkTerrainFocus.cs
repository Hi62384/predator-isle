using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private static Vector2 Angle(double angle){float a=(float)angle;return new Vector2((float)Math.Cos(a),(float)Math.Sin(a));}
    private Vector3 FindLand(string biome,int id,bool localWater)
    {
        if(P(biome+"_coverage")<=0)return Vector3.Inf;
        var origin=Valid(target)&&target!.IsInsideTree()?new Vector2(target.GlobalPosition.X,target.GlobalPosition.Z):Vector2.Zero;
        double step=Math.Max(P(biome+"_region_size")*P("biome_size"),500);
        for(int ring=0;ring<28;ring++)for(int index=0;index<12;index++)
        {
            double radius=ring==0?0:step*Math.Pow(1.55,ring-1);var p=origin+Angle(index*Math.Tau/12+.17)*(float)radius;var w=_sampler._biome_weights(p.X,p.Y);
            double amount=id<4?w[id]:id==4?_sampler._jungle_weight:id==5?_sampler._mountain_weight:id==6?_sampler._tropical_weight:_sampler._badlands_weight;
            if(amount<.98||_sampler._island_mask(p.X,p.Y)<.025)continue;
            double h=_get_height(p.X,p.Y);if(_sampler._last_coast.X>.35)continue;
            double level=localWater?_sampler.get_water_surface_height(p.X,p.Y):water_level;
            if(h>level+(localWater ? .2 : 3))return new Vector3(p.X,(float)h,p.Y);
        }
        return Vector3.Inf;
    }
    public Vector3 find_jungle_focus()=>FindLand("jungle",4,false);
    public Vector3 find_forest_focus()=>FindLand("forest",1,false);
    public Vector3 find_savanna_focus()=>FindLand("savanna",2,false);
    public Vector3 find_swamp_focus()=>FindLand("swamp",3,true);
    public Vector3 find_mountain_focus()=>FindLand("mountain",5,true);
    public Vector3 find_tropical_focus()=>FindLand("tropical",6,true);
    public Vector3 find_badlands_focus()=>FindLand("badlands",7,true);
    private bool JumpLand(Vector3 focus,string name,double altitude)
    {if(!focus.IsFinite()){GD.PushWarning("No "+name+" land found; enable "+name+" Coverage in Terrain Settings.");return false;}request_teleport(focus+new Vector3(0,(float)altitude,0));return true;}
    public bool jump_to_jungle()=>JumpLand(find_jungle_focus(),"Jungle",80);
    public bool jump_to_forest()=>JumpLand(find_forest_focus(),"Forest",80);
    public bool jump_to_savanna()=>JumpLand(find_savanna_focus(),"Savanna",80);
    public bool jump_to_swamp()=>JumpLand(find_swamp_focus(),"Swamp",45);
    public bool jump_to_mountain()=>JumpLand(find_mountain_focus(),"Mountain Range",140);
    public bool jump_to_tropical()=>JumpLand(find_tropical_focus(),"Tropical",100);
    public bool jump_to_badlands()=>JumpLand(find_badlands_focus(),"Badlands",100);
    public Vector3 find_coast_focus()=>find_coast_focus(false);
    public Vector3 find_coast_focus(bool sandy)
    {
        if(!B("rocky_coast_enabled")&&!B("beaches_enabled"))return Vector3.Inf;
        var origin=Valid(target)&&target!.IsInsideTree()?new Vector2(target.GlobalPosition.X,target.GlobalPosition.Z):Vector2.Zero;double radius=Math.Max(P("island_size")*.5,1000);
        for(int ring=0;ring<12;ring++)for(int index=0;index<16;index++)
        {
            var p=origin+Angle(index*Math.Tau/16+.17)*(float)radius*ring/3;
            for(int iteration=0;iteration<24;iteration++){var f=_sampler._coast!.coast_frame(p);p-=new Vector2(f.Y,f.Z)*(float)Math.Clamp(f.X*.25,-radius*.25,radius*.25);}
            var frame=_sampler._coast!.coast_frame(p);p+=new Vector2(frame.Y,frame.Z)*80;double h=_get_height(p.X,p.Y);var c=_sampler._last_coast;double sand=c.W<0?((long)(-(double)c.W-1)&255)/255.0:0;
            if(c.X>.75&&h>water_level+.5&&(sandy?sand>.7:sand<.3))return new Vector3(p.X,(float)h,p.Y);
        }
        return Vector3.Inf;
    }
    public bool jump_to_coast()=>JumpLand(find_coast_focus(),"Rocky Coast",150);
    public bool jump_to_beach()=>JumpLand(find_coast_focus(true),"sandy coast",100);
    public Vector3 find_extension_focus(string biome)
    {
        int index=System.Array.IndexOf(TerrainBiomeCatalog.ExtensionKeys,biome);if(index<0||_sampler._extras[index].VariantType==Variant.Type.Nil)return Vector3.Inf;
        double span=P(biome+"_region_size")*P("biome_size");
        for(int ring=1;ring<45;ring++)foreach(var direction in new[]{new Vector2(1,.37f),new Vector2(-.51f,1),new Vector2(-1,-.61f),new Vector2(.29f,-1)})
        {var p=direction*(float)span*ring;_sampler._biome_weights(p.X,p.Y);if(_sampler._extra_weights[index]>.98&&_sampler._island_mask(p.X,p.Y)>.03)return new Vector3(p.X,(float)_get_height(p.X,p.Y),p.Y);}
        return Vector3.Inf;
    }
    public bool jump_to_extension(string biome){var focus=find_extension_focus(biome);if(!focus.IsFinite())return false;request_teleport(focus+new Vector3(0,500,0));return true;}
    public D get_extension_descriptor_at(Vector3 p,string biome)
    {int i=System.Array.IndexOf(TerrainBiomeCatalog.ExtensionKeys,biome);return i<0||_sampler._extras[i].VariantType==Variant.Type.Nil?new D():_sampler._extras[i].AsGodotObject().Call("describe",new Vector2(p.X,p.Z)).AsGodotDictionary();}
    public D get_jungle_habitat_at(Vector3 p)=>JunglePlacement.habitat(_sampler,p.X,p.Z);
    public D get_jungle_spawn_candidates(Rect2 bounds)=>get_jungle_spawn_candidates(bounds,24,128,0);
    public D get_jungle_spawn_candidates(Rect2 bounds,double spacing)=>get_jungle_spawn_candidates(bounds,spacing,128,0);
    public D get_jungle_spawn_candidates(Rect2 bounds,double spacing,long count)=>get_jungle_spawn_candidates(bounds,spacing,count,0);
    public D get_jungle_spawn_candidates(Rect2 bounds,double spacing,long count,long offset)=>JunglePlacement.candidates(_sampler,bounds,spacing,count,offset);
    public void set_swamp_flood_stage(double stage){stage=Math.Clamp(stage,0,1);foreach(var m in _material_variants())Obj<ShaderMaterial>(m).SetShaderParameter("swamp_flood_stage",stage);_swamp_water_material?.SetShaderParameter("swamp_flood_stage",stage);}
    private bool OldPreview()=>grass_preview||jungle_preview||forest_preview||savanna_preview||swamp_preview||mountain_preview||coast_preview;
    private void PositionInitialTarget()
    {
        if(!Valid(target))return;
        if(extension_preview.Length>0){var f=find_extension_focus(extension_preview);if(extension_preview_position.IsFinite())f=new Vector3(extension_preview_position.X,0,extension_preview_position.Y);if(f.IsFinite()){f.Y=(float)(_get_height(f.X,f.Z)+600);target!.GlobalPosition=f;}return;}
        if((_badlands_feature_active||badlands_preview||start_in_badlands)&&P("badlands_coverage")>0){Feature(_badlands_feature_active?new Vector3(_badlands_feature_position.X,0,_badlands_feature_position.Y):find_badlands_focus(),new Vector3(-800,500,-1000));return;}
        if((_tropical_feature_active||tropical_preview||start_in_tropical)&&P("tropical_coverage")>0){Feature(_tropical_feature_active?new Vector3(_tropical_feature_position.X,0,_tropical_feature_position.Y):find_tropical_focus(),new Vector3(-800,500,-1000),true);return;}
        if(_coast_feature_active){var f=new Vector3(_coast_feature_position.X,0,_coast_feature_position.Y);f.Y=(float)Math.Max(get_height_at(f),water_level);Place(f,new Vector3(_coast_outward.X*500,220,_coast_outward.Y*500),30);return;}
        if(start_in_beach&&B("beaches_enabled")&&!beach_preview&&!OldPreview()){Place(find_coast_focus(true),new Vector3(0,100,0),0,new Vector3(200,-10,200));return;}
        if(start_in_coast&&!OldPreview()&&B("rocky_coast_enabled")){Place(find_coast_focus(),new Vector3(0,150,0),0,new Vector3(200,-20,200));return;}
        if(_mountain_feature_active){Feature(new Vector3(_mountain_feature_position.X,0,_mountain_feature_position.Y),new Vector3(-500,320,-700),false,60);return;}
        if(start_in_mountain&&!OldPreview()&&P("mountain_coverage")>0){Place(find_mountain_focus(),new Vector3(0,140,0),0,new Vector3(400,-30,400));return;}
        if(_swamp_feature_active){Feature(new Vector3(_swamp_feature_position.X,0,_swamp_feature_position.Y),new Vector3(-220,90,-300),true);return;}
        if(start_in_swamp&&!OldPreview()&&P("swamp_coverage")>0){Place(find_swamp_focus(),new Vector3(0,45,0),0,new Vector3(180,0,180));return;}
        if(_savanna_feature_active){Feature(new Vector3(_savanna_feature_position.X,0,_savanna_feature_position.Y),new Vector3(-220,150,-300),false,40);return;}
        if(start_in_savanna&&!OldPreview()&&P("savanna_coverage")>0){Place(find_savanna_focus(),new Vector3(0,80,0),0,new Vector3(180,0,180));return;}
        if(_forest_feature_active){Feature(new Vector3(_forest_feature_position.X,0,_forest_feature_position.Y),new Vector3(-220,150,-300),false,40);return;}
        if(_jungle_feature_active){Feature(new Vector3(_jungle_feature_position.X,0,_jungle_feature_position.Y),new Vector3(-220,150,-300),false,40);return;}
        if(start_in_forest&&!OldPreview()&&P("forest_coverage")>0){Place(find_forest_focus(),new Vector3(0,80,0),0,new Vector3(180,0,180));return;}
        if(start_in_jungle&&!OldPreview()&&P("jungle_coverage")>0)Place(find_jungle_focus(),new Vector3(0,80,0),0,new Vector3(180,0,180));
    }
    private void Feature(Vector3 focus,Vector3 offset,bool water=false,double clearance=0)
    {if(!focus.IsFinite())return;focus.Y=(float)(water?Math.Max(get_height_at(focus),_sampler.get_water_surface_height(focus.X,focus.Z)):get_height_at(focus));Place(focus,offset,clearance);}
    private void Place(Vector3 focus,Vector3 offset,double clearance=0,Vector3 lookOffset=default)
    {if(!focus.IsFinite())return;var p=focus+offset;if(clearance>0)p.Y=(float)Math.Max(p.Y,get_height_at(p)+clearance);target!.GlobalPosition=p;if(target is Camera3D)target.LookAt(focus+lookOffset);}
}
