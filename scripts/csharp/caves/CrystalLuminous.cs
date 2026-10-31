using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CrystalLuminous : RefCounted
{
    private static readonly CaveBiomeRegions Regions=new();
    private static Variant Get(D d,string key,Variant fallback=default)=>d.ContainsKey(key)?d[key]:fallback;
    private static A Items(D d,string key)=>Get(d,key,new A()).AsGodotArray();
    public D apply(D payload,A regions,long seed_id,D settings)
    {
        double regionChance=Get(settings,"luminous_region_chance",.005).AsDouble(),formChance=Get(settings,"luminous_form_chance",.12).AsDouble();
        if(!Get(settings,"luminous_minerals",false).AsBool()||regionChance<=0||formChance<=0)return payload;
        var themes=new Dictionary<string,string>();
        foreach(var value in regions)
        {
            var region=value.AsGodotDictionary();long family=Get(region,"cave_family",-1).AsInt64();
            if(!Get(region,"valid",false).AsBool()||family is 6 or 7)continue;
            var assignment=Get(region,"cave_biome_regions",new D()).AsGodotDictionary();var rare=new HashSet<string>();
            foreach(var item in Items(assignment,"candidates"))
            {
                var candidate=item.AsGodotDictionary();string id=candidate["id"].AsString();
                if(candidate["biome_id"].AsString()=="crystal"&&Regions.random(id,seed_id,"crystal/fictional_region")<regionChance)rare.Add(id);
            }
            if(rare.Count==0)continue;
            foreach(var item in Items(region,"nodes").Concat(Items(region,"pockets")))
            {
                var room=item.AsGodotDictionary();string id=room["id"].AsString();var sample=Regions.along_edge(assignment,id,id,0,0);
                string theme=Get(sample["candidate_ids"].AsGodotDictionary(),"crystal","").AsString();
                if(Get(sample["weights"].AsGodotDictionary(),"crystal",0).AsDouble()>=.8&&rare.Contains(theme))themes[id]=theme;
            }
        }
        if(themes.Count==0)return payload;
        var placements=Items(payload,"placements");var choices=new List<(int Index,string Theme,double Priority)>();int total=0;
        for(int index=0;index<placements.Count;index++)
        {
            var form=placements[index].AsGodotDictionary();if(Get(form,"kind","").AsString()!="crystal")continue;total++;
            if(Get(form,"thin_transmission",false).AsBool()||Get(form,"batch","").AsString()!="mineral_opaque")continue;
            string id=form["id"].AsString(),theme="";
            foreach(var room in themes)if(id.StartsWith(room.Key+"/",StringComparison.Ordinal)){theme=room.Value;break;}
            if(theme.Length==0||Regions.random(id,seed_id,"crystal/fictional_prism")>=formChance)continue;
            choices.Add((index,theme,Regions.random(id,seed_id,"crystal/fictional_priority")));
        }
        choices.Sort((a,b)=>a.Priority!=b.Priority?a.Priority.CompareTo(b.Priority):a.Index.CompareTo(b.Index));int maximum=(int)Math.Floor(total*.1);
        if(choices.Count>maximum)choices.RemoveRange(maximum,choices.Count-maximum);if(choices.Count==0)return payload;
        var result=payload.Duplicate(true);var forms=result["placements"].AsGodotArray();
        foreach(var choice in choices)
        {
            var form=forms[choice.Index].AsGodotDictionary();form["fictional_emission"]=true;form["fictional_region"]=choice.Theme;
            foreach(var item in Items(result,"batches"))
            {
                var batch=item.AsGodotDictionary();if(Get(batch,"kind","").AsString()!=form["batch"].AsString())continue;
                var arrays=batch["arrays"].AsGodotArray();var uv=arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();int first=form["first_vertex"].AsInt32(),count=form["vertex_count"].AsInt32();
                for(int vertex=first;vertex<first+count;vertex++)uv[vertex].Y=-uv[vertex].Y;
                arrays[(int)Mesh.ArrayType.TexUV]=uv;
            }
        }
        return result;
    }
}
