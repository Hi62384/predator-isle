using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

public partial class SnowSettings
{
    public D uniforms()=>new(){["snow_master_strength"]=master_normal_strength,["snow_ground_strength"]=ground_normal_strength,["snow_powder_metres"]=powder_metres,["snow_crust_metres"]=crust_metres,["snow_ground_metres"]=ground_metres,["snow_rock_metres"]=rock_metres,["snow_crust_strength"]=crust_normal_strength,["snow_rock_strength"]=rock_normal_strength,["snow_ice_strength"]=ice_normal_strength,["snow_albedo_gain"]=albedo_gain,["snow_powder_strength"]=powder_strength,["snow_compacted_coverage"]=compacted_coverage,["snow_ice_metres"]=ice_metres,["snow_wind_metres"]=wind_texture_metres,["snow_color_variation"]=color_variation,["snow_ice_roughness"]=ice_roughness,["snow_macro_strength"]=macro_strength,["snow_normal_strength"]=normal_strength,["snow_slope_influence"]=slope_influence,["snow_exposed_ice"]=exposed_ice,["snow_glacier_snow"]=glacier_snow_coverage,["snow_ice_snow"]=snow_on_ice,["snow_wind_angle"]=wind_degrees*Math.PI/180,["snow_wind_variation"]=wind_variation};
}
