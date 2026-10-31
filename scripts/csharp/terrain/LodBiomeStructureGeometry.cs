using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Only simplifies bounded distant conduit roofs; contact geometry remains conservative.</summary>
public partial class LodBiomeStructureGeometry : BiomeStructureGeometry
{
    public string CONTEXT {get;}="alien_conduit_lod_context_v1";
    public double split_ratio {get;set;}=.5;
    public int _row_stride {get;set;}=1;
    public double _foundation_floor {get;set;}=double.PositiveInfinity;
    protected override BiomeStructureGeometry NewGeometry()=>new LodBiomeStructureGeometry();
    public bool supported_noise(FastNoiseLite noise)=>noise.NoiseType==FastNoiseLite.NoiseTypeEnum.SimplexSmooth&&noise.FractalType==FastNoiseLite.FractalTypeEnum.Fbm&&!noise.DomainWarpEnabled&&noise.FractalWeightedStrength==0&&noise.FractalGain>=0;
    public double global_floor(GodotObject builder)
    {
        // The original analytic noise bound does not include authored signed height changes.
        if(builder is TerrainMeshBuilder native&&native.settings is TerrainConfiguration{terrain_changes.Length:>0})return double.PositiveInfinity;
        if(builder.GetType()!=typeof(TerrainMeshBuilder)&&builder.GetScript().As<Script>()!=GD.Load<Script>("res://scripts/terrain_mesh_builder.gd"))return double.PositiveInfinity;
        if(builder.Get("_extra_coverage").AsFloat64Array()[7]!=1||builder.Get("_coast").AsGodotObject()!=null)return double.PositiveInfinity;
        var field=builder.Get("_extras").AsGodotArray()[7].AsGodotObject();var config=field.Get("settings").AsGodotObject();if(Number(config,"relief")<0||Number(config,"nerve_height")<0||Number(config,"overlay_strength")<0)return double.PositiveInfinity;
        foreach(var noise in new[]{field.Get("_macro").As<FastNoiseLite>(),field.Get("_meso").As<FastNoiseLite>(),builder.Get("_detail_noise").As<FastNoiseLite>()})if(!supported_noise(noise))return double.PositiveInfinity;
        var settings=builder.Get("settings").AsGodotObject();double land=Math.Min(60-2*280-2*5,60-2*100-2*4-Math.Max(Number(config,"breach_depth"),0))*Number(config,"relief"),ocean=-Math.Max(Number(settings,"ocean_depth"),1)-2*Math.Abs(Number(settings,"seabed_relief"));return Number(builder,"water_level")+Math.Min(land,ocean)*Math.Max(Number(settings,"height_multiplier"),.01)-32;
    }
    public override A build(GodotObject builder,Vector2I coordinate,double[] support_steps,Callable portal_provider)
    {
        bool had=builder.HasMeta(CONTEXT);var previous=builder.GetMeta(CONTEXT,new D());double size=Number(builder,"chunk_size");bool enabled=builder.Get("settings").AsGodotObject().Get("alien_infected").AsGodotObject().Get("hive_structure_lod_enabled").AsBool();
        builder.SetMeta(CONTEXT,new D{["bounds"]=new Rect2((Vector2)coordinate*(float)size,Vector2.One*(float)size),["ratio"]=split_ratio,["enabled"]=enabled,["floor"]=enabled?global_floor(builder):double.PositiveInfinity});
        try{return base.build(builder,coordinate,support_steps,portal_provider);}finally{if(had)builder.SetMeta(CONTEXT,previous);else builder.RemoveMeta(CONTEXT);}
    }
    public int select_stride(Vector2 a,Vector2 b,double width,D context)
    {
        if(context.Count==0||!Get(context,"enabled",true).AsBool())return 1;double floor=Get(context,"floor",double.PositiveInfinity).AsDouble();if(!conduit_aprons&&!double.IsFinite(floor))return 1;
        var leaf=context["bounds"].AsRect2();var geometry=new Rect2(a,Vector2.Zero).Expand(b).Grow((float)(128+5.8*width));double outside=0;
        foreach(var q in new[]{geometry.Position,geometry.End,new Vector2(geometry.Position.X,geometry.End.Y),new Vector2(geometry.End.X,geometry.Position.Y)})outside=Math.Max(outside,q.DistanceTo(q.Clamp(leaf.Position,leaf.End)));
        double clearance=leaf.Size.X*context["ratio"].AsDouble()-outside;return clearance>6000?4:clearance>2000?2:1;
    }
    protected override A ConduitKey(Vector2 a,Vector2 b,double width,double phase,Color color,A sites,GodotObject builder)
    {var context=builder.GetMeta(CONTEXT,new D()).AsGodotDictionary();var result=base.ConduitKey(a,b,width,phase,color,sites,builder);result.Add(select_stride(a,b,width,context));result.Add(Get(context,"floor",double.PositiveInfinity));return result;}
    protected override string ConduitKeyPrefix(Vector2 a,Vector2 b,double width,GodotObject builder)
    {var context=builder.GetMeta(CONTEXT,new D()).AsGodotDictionary();return select_stride(a,b,width,context)>1&&!double.IsFinite(Get(context,"floor",double.PositiveInfinity).AsDouble())?"retained_contact_v1/":"";}
    public override void _conduit_uncached(GodotObject builder,Vector2 a,Vector2 b,double width,double phase,Color color)
    {
        var context=builder.GetMeta(CONTEXT,new D()).AsGodotDictionary();_row_stride=select_stride(a,b,width,context);if(_row_stride==1){base._conduit_uncached(builder,a,b,width,phase,color);return;}
        _foundation_floor=context["floor"].AsDouble();try{EmitConduit(builder,a,b,width,phase,color,_row_stride,!double.IsFinite(_foundation_floor));}finally{_foundation_floor=double.PositiveInfinity;_row_stride=1;}
    }
    public override double footing_height(GodotObject builder,Vector2 p)=>double.IsFinite(_foundation_floor)?_foundation_floor:base.footing_height(builder,p);
    public void emit_far_conduit(GodotObject builder,Vector2 a,Vector2 b,double width,double phase,Color color)=>EmitConduit(builder,a,b,width,phase,color,_row_stride,!double.IsFinite(_foundation_floor));
}
