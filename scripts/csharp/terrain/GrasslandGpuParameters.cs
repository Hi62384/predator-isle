using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>Immutable numerical snapshot; no engine object crosses into the render queue.</summary>
internal sealed record GrasslandGpuParameters(int Seed,long SourceSeed,string[] Names, float[] Values,
    int[] NoiseSeeds,int[] Octaves,Vector4[] NoiseConfig,Vector2[] NoiseOffsets,double[] CanonicalValues)
{
    internal static readonly string[] ParameterNames =
    [
        "cliff_width",
        "erosion_strength",
        "escarpment_strength",
        "field_spacing",
        "foothill_size",
        "fractal_strength",
        "geographic_scale",
        "geographic_variety",
        "hill_frequency",
        "hill_height",
        "lake_depth",
        "lake_frequency",
        "lake_size",
        "landform_size",
        "local_detail",
        "macro_height",
        "mountain_frequency",
        "mountain_height",
        "mountain_ruggedness",
        "plains_flatness",
        "plains_frequency",
        "plateau_erosion",
        "plateau_frequency",
        "plateau_height",
        "ridge_strength",
        "river_depth",
        "river_frequency",
        "river_width",
        "rolling_strength",
        "talus_relief",
        "talus_width",
        "valley_strength",
];
    public static GrasslandGpuParameters? Capture(GrasslandField field)
    {
        FastNoiseLite[] noises=[field.region,field.macro,field.forms,field.ridges,field.fractal,field.detail,field.water];
        var seeds=new int[7];var octaves=new int[7];var config=new Vector4[7];var offsets=new Vector2[7];
        for(int i=0;i<noises.Length;i++)
        {
            var noise=noises[i];
            if(noise.NoiseType!=FastNoiseLite.NoiseTypeEnum.SimplexSmooth||noise.FractalType!=FastNoiseLite.FractalTypeEnum.Fbm||noise.DomainWarpEnabled||noise.FractalWeightedStrength!=0||noise.FractalOctaves<1||noise.FractalOctaves>32)return null;
            seeds[i]=noise.Seed;octaves[i]=noise.FractalOctaves;
            float gain=Math.Abs(noise.FractalGain),sum=1,amplitude=gain;
            for(int j=1;j<octaves[i];j++){sum+=amplitude;amplitude*=gain;}
            config[i]=new Vector4(noise.Frequency,noise.FractalGain,noise.FractalLacunarity,1/sum);
            var offset=noise.Offset;offsets[i]=new Vector2(offset.X,offset.Y);
            if(!float.IsFinite(config[i].X)||!float.IsFinite(config[i].Y)||!float.IsFinite(config[i].Z)||!float.IsFinite(config[i].W)||!float.IsFinite(offset.X)||!float.IsFinite(offset.Y))return null;
        }
        var values=new float[ParameterNames.Length];var canonicalValues=new double[ParameterNames.Length];
        for(int i=0;i<values.Length;i++){double value=field.settings.Get("grass_"+ParameterNames[i]).AsDouble();if(!double.IsFinite(value)||!float.IsFinite((float)value))return null;canonicalValues[i]=value;values[i]=(float)value;}
        if(field.settings.Get("grass_field_spacing").AsDouble()<=0)return null;
        return new(unchecked((int)field.world_seed),field.world_seed,ParameterNames,values,seeds,octaves,config,offsets,canonicalValues);
    }
    public void Apply(ShaderMaterial material)
    {
        material.SetShaderParameter("world_seed",Seed);
        for(int i=0;i<Names.Length;i++)material.SetShaderParameter("g_"+Names[i],Values[i]);
        material.SetShaderParameter("noise_seed",NoiseSeeds);material.SetShaderParameter("noise_octaves",Octaves);
        material.SetShaderParameter("noise_config",NoiseConfig);material.SetShaderParameter("noise_offset",NoiseOffsets);
    }
    public bool Equivalent(GrasslandGpuParameters other)=>Seed==other.Seed&&SourceSeed==other.SourceSeed&&
        CanonicalValues.AsSpan().SequenceEqual(other.CanonicalValues)&&NoiseSeeds.AsSpan().SequenceEqual(other.NoiseSeeds)&&
        Octaves.AsSpan().SequenceEqual(other.Octaves)&&NoiseConfig.AsSpan().SequenceEqual(other.NoiseConfig)&&
        NoiseOffsets.AsSpan().SequenceEqual(other.NoiseOffsets);
}
