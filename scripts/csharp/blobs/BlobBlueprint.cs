using Godot;
using System;
using System.Globalization;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

public partial class BlobBlueprint : RefCounted
{
    public int VERSION {get;}=4;
    public A PLANS {get;}=new A{"compact","flattened","tower","multilobe","elongated","lopsided","cluster","muscular","sagging","asymmetric"};
    public A PROFILES {get;}=new A{"swollen","porous","mimic","tendril","membranous","sensory","muscular","clustered","hollow","rooted","smooth_mimic","abnormal"};
    public A FAMILIES {get;}=new A{"sac","lattice","face","tendril","membrane","stalk","limb","nodule","cavity","fold"};
    public A MODES {get;}=new A{"roll","vine","limb","contractile","peristaltic","hybrid","drag","pulse","multicontact","undulate"};
    public A PRIORS {get;}=new A{new A{1.0,0.12,0.05,0.12,0.25,0.04,0.2,0.6,0.15,0.7},new A{0.2,1.0,0.08,0.4,0.4,0.12,0.15,0.18,0.7,0.25},new A{0.35,0.3,1.0,0.4,0.35,0.0,0.25,0.2,0.2,0.8},new A{0.12,0.15,0.0,1.0,0.45,0.2,0.2,0.15,0.12,0.35},new A{0.25,0.5,0.1,0.55,1.0,0.12,0.1,0.15,0.25,0.6},new A{0.45,0.25,0.0,0.25,0.12,1.0,0.15,0.2,0.15,0.2},new A{0.2,0.0,0.07,0.12,0.05,0.0,1.0,0.1,0.06,0.8},new A{0.6,0.2,0.05,0.15,0.2,0.12,0.25,1.0,0.15,0.4},new A{0.1,0.8,0.12,0.4,0.55,0.15,0.2,0.25,1.0,0.5},new A{0.15,0.2,0.05,1.0,0.25,0.07,0.65,0.2,0.15,0.35},new A{0.06,0.0,1.0,0.15,0.15,0.05,0.04,0.04,0.05,0.25},new A{0.6,0.7,0.45,0.7,0.55,0.55,0.35,0.7,0.6,0.6}};
    public A PREFERRED_PLANS {get;}=new A{new A{"multilobe","tower","sagging"},new A{"compact","tower","asymmetric"},new A{"tower","lopsided","multilobe"},new A{"elongated","sagging","asymmetric"},new A{"lopsided","elongated","sagging"},new A{"flattened","compact","cluster"},new A{"muscular","tower","lopsided"},new A{"cluster","multilobe","asymmetric"},new A{"tower","sagging","asymmetric"},new A{"flattened","elongated","lopsided"},new A{"compact","elongated","lopsided"},new A{"asymmetric","cluster","tower"}};
    public D CONTROL_DEFAULTS {get;}=new D{["width"]=1.0,["height"]=1.0,["length"]=1.0,["asymmetry"]=1.0,["mass_count"]=0,["mass_variation"]=1.0,["fusion"]=1.0,["contact"]=1.0,["stiffness"]=0.45,["diversity"]=0.25,["sacs"]=1.0,["lattice"]=1.0,["faces"]=1.0,["limbs"]=1.0,["tentacles"]=1.0,["branches"]=1.0,["membranes"]=1.0,["cavities"]=1.0,["stalks"]=1.0,["fibers"]=1.0,["folds"]=1.0,["detail"]=1.0,["combinations"]=1.0,["palette"]=-1,["wetness"]=0.45,["roughness"]=1.0,["veins"]=1.0,["translucency"]=0.5,["microdetail"]=0.6,["circulation"]=1.0,["softness"]=0.6,["gravity"]=0.65,["flattening"]=0.6,["recovery"]=0.6,["volume"]=0.85,["wobble"]=0.45,["follow_through"]=0.6,["deformation_quality"]=1.0};
    public BlobBlueprint()
    {foreach(var value in new Variant[]{PLANS,PROFILES,FAMILIES,MODES,PRIORS,PREFERRED_PLANS,CONTROL_DEFAULTS})Freeze(value);}
    private static void Freeze(Variant value)
    {
        if(value.VariantType==Variant.Type.Array){var array=value.AsGodotArray();foreach(var item in array)Freeze(item);array.MakeReadOnly();}
        else if(value.VariantType==Variant.Type.Dictionary){var dictionary=value.AsGodotDictionary();foreach(var item in dictionary.Values)Freeze(item);dictionary.MakeReadOnly();}
    }
    private static double N(D d,string key)=>d[key].AsDouble();
    private static Variant Get(D d,string key,Variant fallback)=>d.TryGetValue(key,out var value)?value:fallback;
    private static bool Has(A a,string value)=>a.Contains(value);
    public D plan(long seed,string mode,D options)
    {
        using var rng=new RandomNumberGenerator{Seed=("predator_blob_v2:"+seed.ToString(CultureInfo.InvariantCulture)).Hash()};var c=CONTROL_DEFAULTS.Duplicate();
        foreach(var key in c.Keys)if(options.TryGetValue(key,out var option)){string name=key.AsString();c[key]=Math.Clamp(option.AsDouble(),name=="palette"?-1:0,name=="mass_count"?12:name=="palette"?4:2);}
        string profile=Get(options,"profile","auto").AsString();if(!Has(PROFILES,profile))profile=PROFILES[rng.RandiRange(0,PROFILES.Count-1)].AsString();int primary=PROFILES.IndexOf(profile),secondary=rng.RandiRange(0,PROFILES.Count-1);
        double mix=rng.RandfRange(0,.3f)*N(c,"diversity");var weights=new D();double[] multipliers={N(c,"sacs"),N(c,"lattice"),N(c,"faces"),N(c,"tentacles"),N(c,"membranes"),N(c,"stalks"),N(c,"limbs"),1,N(c,"cavities"),N(c,"folds")};
        var first=PRIORS[primary].AsGodotArray();var second=PRIORS[secondary].AsGodotArray();for(int i=0;i<FAMILIES.Count;i++)weights[FAMILIES[i]]=(first[i].AsDouble()+(second[i].AsDouble()-first[i].AsDouble())*mix)*multipliers[i];
        string plan=Get(options,"body_plan","auto").AsString();if(!Has(PLANS,plan)){var choices=PREFERRED_PLANS[primary].AsGodotArray();plan=(rng.Randf()<.8?choices[rng.RandiRange(0,choices.Count-1)]:PLANS[rng.RandiRange(0,PLANS.Count-1)]).AsString();}
        var dimensions=plan switch{"compact"=>new Vector3(1,.86f,.95f),"flattened"=>new Vector3(1.65f,.43f,1.25f),"tower"=>new Vector3(.78f,1.65f,.8f),"multilobe"=>new Vector3(1.35f,.84f,1.22f),"elongated"=>new Vector3(.82f,.66f,1.95f),"lopsided"=>new Vector3(1.35f,1.05f,.86f),"cluster"=>new Vector3(1.2f,1.1f,1.05f),"muscular"=>new Vector3(1.26f,1.03f,1.15f),"sagging"=>new Vector3(1.25f,.73f,1.5f),"asymmetric"=>new Vector3(1.1f,1.32f,1.5f),_=>Vector3.One};
        dimensions*=new Vector3((float)(rng.RandfRange(.8f,1.2f)*N(c,"width")),(float)(rng.RandfRange(.82f,1.18f)*N(c,"height")),(float)(rng.RandfRange(.8f,1.2f)*N(c,"length")));dimensions=dimensions.Max(Vector3.One*.22f);
        string locomotion=mode=="creep"?"limb":mode;
        if(!Has(MODES,locomotion))locomotion=plan is "compact" or "multilobe" or "lopsided"?"roll":profile=="muscular"?"limb":new[]{"drag","undulate","hybrid"}[rng.RandiRange(0,2)];
        if(mode=="auto"&&(profile is "rooted" or "tendril"))locomotion="vine";if(locomotion is "vine" or "multicontact")weights["tendril"]=Math.Max(N(weights,"tendril"),.85);if(locomotion=="limb")weights["limb"]=Math.Max(N(weights,"limb"),.65);
        if(locomotion=="roll")dimensions.Z=(float)Math.Max(dimensions.Z,dimensions.Y*.8);
        double size=rng.RandfRange(1.05f,1.55f);int count=plan is "cluster" or "multilobe" or "asymmetric"?rng.RandiRange(4,8):rng.RandiRange(2,5);if((int)N(c,"mass_count")>0)count=Math.Clamp((int)N(c,"mass_count"),1,12);
        var dna=new D{["version"]=VERSION,["seed"]=seed,["controls"]=c,["body_plan"]=plan,["profile"]=profile,["secondary_profile"]=PROFILES[secondary],["mix"]=mix,["weights"]=weights,["size"]=size,["core_radii"]=dimensions*(float)size,["locomotion"]=locomotion,["mass_count"]=count,["squishiness"]=c["softness"],["irregularity"]=rng.RandfRange(.25f,.65f),["asymmetry"]=rng.RandfRange(.18f,.75f)*N(c,"asymmetry"),["wetness"]=c["wetness"],["palette"]=(int)N(c,"palette")<0?rng.RandiRange(0,4):(int)N(c,"palette"),["center_of_mass"]=Vector3.Zero,["rolling_axis"]=Vector3.Right,["ground_contact"]=new Vector3(0,(float)(-dimensions.Y*size),0),["detail_intensity"]=rng.RandfRange(.55f,1)*N(c,"detail")};
        dna["descriptor"]=descriptor(dna);return dna;
    }
    public float[] descriptor(D dna)
    {
        var r=dna["core_radii"].AsVector3();var v=new float[6+FAMILIES.Count];v[0]=(float)(r.X/(double)r.Y/5);v[1]=(float)(r.Z/(double)r.Y/5);v[2]=(float)(dna["mass_count"].AsDouble()/12);v[3]=(float)dna["asymmetry"].AsDouble();v[4]=(float)(PLANS.IndexOf(dna["body_plan"])/10.0);
        var weights=dna["weights"].AsGodotDictionary();for(int i=0;i<FAMILIES.Count;i++)v[5+i]=(float)weights[FAMILIES[i]].AsDouble();v[^1]=(float)(MODES.IndexOf(dna["locomotion"])/5.0);return v;
    }
    public double distance(float[] a,float[] b){double total=0;for(int i=0;i<Math.Min(a.Length,b.Length);i++)total+=Math.Abs((double)a[i]-b[i]);return total/Math.Max(a.Length,1);}
}
