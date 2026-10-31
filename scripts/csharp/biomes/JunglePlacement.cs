using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class JunglePlacement : RefCounted
{
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Height(GodotObject builder,double x,double z)=>builder.Call("_get_height",x,z).AsDouble();
    private static Vector2 Direction(double dx,double dz){var value=new Vector2((float)-dx,(float)-dz);return value.LengthSquared()==0?value:value.Normalized();}
    public D habitat(GodotObject builder,double x,double z)
    {
        double h=Height(builder,x,z);long packed=builder.Get("_last_jungle").AsInt64();double weight=(double)((packed>>16)&255)/255;
        var sampler=builder.Get("_jungle").AsGodotObject();if(weight<=0||sampler==null)return new D {["jungle"]=0.0,["canopy"]=0.0,["understory"]=0.0,["ground_cover"]=0.0,["emergent"]=0.0,["waterfall_candidate"]=false};
        var config=sampler.Get("settings").As<Resource>();long region=sampler.Get("region").AsInt64();double wet=sampler.Get("wetness").AsDouble(),drainage=sampler.Get("drainage").AsDouble(),water=Math.Max(sampler.Get("river").AsDouble(),sampler.Get("lake").AsDouble());
        double dx=(builder.Call("_get_height",x+4,z,false).AsDouble()-builder.Call("_get_height",x-4,z,false).AsDouble())/8,dz=(builder.Call("_get_height",x,z+4,false).AsDouble()-builder.Call("_get_height",x,z-4,false).AsDouble())/8,slope=1-1/Math.Sqrt(1+dx*dx+dz*dz);
        var noise=sampler is JungleSampler native?native._macro:sampler.Get("_macro").As<FastNoiseLite>();double field=Math.Clamp(noise.GetNoise2D((float)(x*.8),(float)(z*.8))*1.4+.5,0,1),frequency=config.Get("clearing_frequency").AsDouble(),opening=frequency>0?Smooth(1-frequency,.999,field):0;
        double suitable=weight*(1-Smooth(.18,.55,slope))*(1-water)*(1-opening);if(h<=builder.Get("water_level").AsDouble()+.5)suitable=0;
        string label=sampler is JungleSampler current?current.NAMES[(int)region]:sampler.Get("NAMES").AsGodotArray()[(int)region].AsString();
        return new D {["jungle"]=weight,["height"]=h,["region"]=label,["wetness"]=wet,["drainage"]=drainage,["slope"]=slope,["water"]=water,["clearing"]=opening,["canopy"]=suitable*config.Get("canopy_density").AsDouble(),["understory"]=suitable*config.Get("understory_density").AsDouble(),["ground_cover"]=suitable*config.Get("ground_cover_density").AsDouble(),["emergent"]=suitable*config.Get("emergent_frequency").AsDouble(),["downhill_direction"]=Direction(dx,dz),["drop_over_8m"]=Math.Max(Math.Abs(dx),Math.Abs(dz))*8,["waterfall_candidate"]=false,["waterfall_note"]="Terrain drainage/drop data only. No elevated water or waterfall renderer."};
    }
    public D candidates(GodotObject builder,Rect2 bounds)=>candidates(builder,bounds,24,128,0);
    public D candidates(GodotObject builder,Rect2 bounds,double spacing)=>candidates(builder,bounds,spacing,128,0);
    public D candidates(GodotObject builder,Rect2 bounds,double spacing,long max_candidates)=>candidates(builder,bounds,spacing,max_candidates,0);
    public D candidates(GodotObject builder,Rect2 bounds,double spacing,long max_candidates,long scan_offset)
    {
        spacing=Math.Max(spacing,4);max_candidates=Math.Clamp(max_candidates,1,256);scan_offset=Math.Max(scan_offset,0);
        var first=new Vector2I((int)Math.Floor(bounds.Position.X/spacing),(int)Math.Floor(bounds.Position.Y/spacing));var last=new Vector2I((int)Math.Ceiling(bounds.End.X/spacing),(int)Math.Ceiling(bounds.End.Y/spacing));long width=Math.Max((long)last.X-first.X,0),depth=Math.Max((long)last.Y-first.Y,0),total=width*depth,cursor=scan_offset,scanned=0;var result=new A();
        while(cursor<total&&scanned<512&&result.Count<max_candidates)
        {
            var cell=first+new Vector2I((int)(cursor%width),(int)(cursor/width));cursor++;scanned++;
            double x=(cell.X+.12+Random(cell,31)*.76)*spacing,z=(cell.Y+.12+Random(cell,37)*.76)*spacing;if(!bounds.HasPoint(new Vector2((float)x,(float)z)))continue;
            var mask=habitat(builder,x,z);if(Random(cell,41)>=mask["canopy"].AsDouble())continue;
            result.Add(new D {["cell"]=cell,["position"]=new Vector3((float)x,(float)mask["height"].AsDouble(),(float)z),["rotation"]=Random(cell,43)*Math.Tau,["scale"]=.75+(1.35-.75)*Random(cell,47),["habitat"]=mask});
        }
        return new D {["candidates"]=result,["next_offset"]=cursor,["complete"]=cursor>=total,["cells_probed"]=scanned};
        double Random(Vector2I cell,long channel)=>builder.Call("_region_random",cell.X,cell.Y,107,channel).AsDouble();
    }
}
