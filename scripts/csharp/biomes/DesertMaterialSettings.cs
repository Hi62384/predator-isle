using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

public partial class DesertSettings
{
    public override void _ValidateProperty(D property)
    {
        string name=property["name"].AsString();long usage=property["usage"].AsInt64();
        if(name is "dune_frequency" or "canyon_frequency" or "dry_lake_frequency")property["usage"]=usage&~(long)PropertyUsageFlags.Editor;
        else if(name is "dune_relief_strength" or "canyon_incision_strength" or "dry_lake_floor_strength")property["usage"]=usage&~(long)PropertyUsageFlags.Storage;
    }
    public Vector4 bedding_parameters(long worldSeed)
    {
        double angle=(worldSeed%6151)*.011,phase=(worldSeed%8191)*.017;return new Vector4((float)(Math.Cos(angle)*.009),(float)(Math.Sin(angle)*.009),(float)Math.Clamp(sedimentary_bed_height,12,48),(float)phase);
    }
    public D shader_uniforms()=>new(){["desert_albedo_gain"]=albedo_gain,["desert_color_variation"]=sand_color_variation,["desert_ripple_strength"]=ripple_strength,["desert_ripple_wavelength"]=ripple_wavelength,["desert_gravel_coverage"]=gravel_coverage,["desert_weathering"]=weathering,["desert_macro_strength"]=macro_detail_intensity,["desert_rock_form_strength"]=broad_rock_relief,["desert_normal_strength"]=micro_normal_strength,["desert_salt_coverage"]=salt_coverage,["desert_sediment_variation"]=sediment_variation,["desert_fracture_strength"]=fracture_strength};
}
