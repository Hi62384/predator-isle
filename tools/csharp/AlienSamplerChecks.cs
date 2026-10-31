using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class AlienSamplerChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var originalScript=GD.Load<GDScript>("res://scripts/alien_infected_sampler.gd");var tissue=GD.Load<GDScript>("res://scripts/alien_tissue_coordinates.gd");using var coordinates=new AlienTissueCoordinates();using var host=new RefCounted();bool positiveFibre=false,positiveAtlas=false;
        foreach(long seed in new[]{-17L,73921L})foreach(double scale in new[]{.45,1.0,2.0})foreach(bool cache in new[]{false,true})foreach(double fibres in new[]{0.0,24.0})
        {
            var config=GD.Load<Resource>("res://config/biomes/alien_infected_settings.tres").Duplicate(true);config.Set("feature_scale",scale);config.Set("network_query_cache_enabled",cache);config.Set("nerve_fibre_height",fibres);
            using var original=originalScript.New().AsGodotObject();using var native=new AlienInfectedSampler();original.Call("configure",config,seed,host,7);native.configure(config,seed,host,7);
            foreach(var cell in new[]{new Vector2I(-3,2),Vector2I.Zero,new Vector2I(16,-17)})
            {
                var expectedEdges=original.Call("network_edges",cell);var edges=native.network_edges(cell);require(GD.VarToBytes(expectedEdges).SequenceEqual(GD.VarToBytes(edges)),"Alien hive path geometry differs");
                var edgeStart=edges[0];var edgeEnd=edges[1];var delta=edgeEnd-edgeStart;var side=new Vector2(-delta.Y,delta.X).Normalized();
                for(int station=0;station<12;station++)foreach(double offset in new[]{0.0,45.0,210.0})
                {
                    var p=edgeStart.Lerp(edgeEnd,(float)((station+.5)/12))+side*(float)(offset*scale);var expected=original.Call("network",p);var actual=native.network(p);
                    require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Alien finite network payload differs: "+MigrationComparison.FirstDifference(expected,actual));
                    double a=original.Call("nerve_fibre_relief",p).AsDouble(),b=native.nerve_fibre_relief(p);Equal(a,b,"Alien measured nerve fibre relief");positiveFibre|=b>0;
                    var parent=new Vector2I((int)Math.Floor(p.X/(4096*scale)),(int)Math.Floor(p.Y/(4096*scale)));var expectedTile=original.Call("query_tile",p,parent);var tile=native.query_tile(p,parent);
                    require(GD.VarToBytes(expectedTile).SequenceEqual(GD.VarToBytes(tile)),"Alien query tile pruning/schema differs: "+MigrationComparison.FirstDifference(expectedTile,tile));
                    foreach(bool tiled in new[]{false,true})
                    {
                        require(GD.VarToBytes(tissue.Call("sample",original,p,tiled)).SequenceEqual(GD.VarToBytes(tissue.Call("sample",native,p,tiled))),"Alien tissue projection differs");
                        var expectedCoordinates=tissue.Call("sample",original,p,tiled);var actualCoordinates=coordinates.sample(native,p,tiled);require(GD.VarToBytes(expectedCoordinates).SequenceEqual(GD.VarToBytes(actualCoordinates)),"Native Alien tissue projection differs: "+MigrationComparison.FirstDifference(expectedCoordinates,actualCoordinates));
                    }
                    if(station%4==0&&offset==0)
                    {
                        var expectedDescription=original.Call("describe",p).AsGodotDictionary();var description=native.describe(p);
                        foreach(string field in new[]{"height","water_level","wetness","region","feature"}){require(expectedDescription[field].VariantType==description[field].VariantType,"Alien description scalar type differs");Equal(expectedDescription[field].AsDouble(),description[field].AsDouble(),"Alien description "+field);description[field]=expectedDescription[field];}
                        require(GD.VarToBytes(expectedDescription).SequenceEqual(GD.VarToBytes(description)),"Alien infection/source description differs: "+MigrationComparison.FirstDifference(expectedDescription,description));
                    }
                }
                var origin=edgeStart.Lerp(edgeEnd,.45f)-new Vector2(32,32);var expectedAtlas=tissue.Call("atlas",original,origin,64.0,8);var atlas=tissue.Call("atlas",native,origin,64.0,8);
                require(GD.VarToBytes(expectedAtlas).SequenceEqual(GD.VarToBytes(atlas)),"Alien tissue-coordinate atlas bytes differ");positiveAtlas|=atlas.AsGodotDictionary()["data"].AsByteArray().Length>0;
                require(GD.VarToBytes(tissue.Call("atlas",original,origin,64.0,8)).SequenceEqual(GD.VarToBytes(coordinates.atlas(native,origin,64,8))),"Native Alien atlas bytes differ");
            }
            foreach(string counter in new[]{"tile_hits","tile_builds","probe_resets","uncached_queries"})require(original.Get(counter).AsInt64()==native.Get(counter).AsInt64(),"Alien query-cache counter behavior differs: "+counter);
            require(native.NetworkCacheCount<=8192&&native.TileCacheCount<=512&&native.ProbeCacheCount<=512,"Alien query caches exceed original bounds");
            require(original.Get("_network_cache").AsGodotDictionary().Count==native.NetworkCacheCount&&original.Get("_query_tiles").AsGodotDictionary().Count==native.TileCacheCount&&original.Get("_tile_probes").AsGodotDictionary().Count==native.ProbeCacheCount,"Alien bounded cache occupancy differs");
            var resetPoint=new Vector2(123,-456);original.Call("configure",config,seed+1,host,7);native.configure(config,seed+1,host,7);require(GD.VarToBytes(original.Call("network",resetPoint)).SequenceEqual(GD.VarToBytes(native.network(resetPoint))),"Alien reconfigure retained a previous network");
        }
        require(positiveFibre&&positiveAtlas,"Alien fixtures did not exercise actual fibre relief and nonempty tissue atlas");
        using var builder=GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();var terrain=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);
        foreach(var item in terrain.GetPropertyList()){string name=item["name"].AsString();if(name.EndsWith("_coverage",StringComparison.Ordinal))terrain.Set(name,name=="alien_infected_coverage"?100:0);}builder.Set("settings",terrain);builder.Set("world_seed",73921);builder.Set("water_level",0.0);builder.Call("_configure_noise");
        var structureField=builder.Get("_extras").AsGodotArray()[7].As<AlienInfectedSampler>();var structureEdges=structureField.network_edges(new Vector2I(-2,1));var structureOrigin=structureEdges[0].Lerp(structureEdges[1],.4f);var arrays=new Godot.Collections.Array();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=new[]{new Vector3(-512,0,-64),new Vector3(512,20,128),new Vector3(256,0,-64)};
        var expectedStructure=tissue.Call("structure_atlas",builder,arrays,structureOrigin);var actualStructure=coordinates.structure_atlas(builder,arrays,structureOrigin);require(GD.VarToBytes(expectedStructure).SequenceEqual(GD.VarToBytes(actualStructure)),"Native whole-structure tissue atlas differs: "+MigrationComparison.FirstDifference(expectedStructure,actualStructure));require(actualStructure.ContainsKey("span")&&actualStructure["span"].AsVector2().X>1024,"Alien structure atlas fixture did not cover its full out-of-tile shell");
        builder.Set("chunk_size",64.0);var chunkKey=new Vector2I((int)Math.Floor(structureOrigin.X/64.0),(int)Math.Floor(structureOrigin.Y/64.0));var chunk=builder.Call("build",chunkKey,8).AsGodotArray();
        require(chunk.Count==(int)Mesh.ArrayType.Max&&chunk[(int)Mesh.ArrayType.Vertex].AsVector3Array().Length>0&&(builder.Get("built_extension_mask").AsInt64()&128)!=0,"Alien production chunk fixture did not build a positive terrain/material payload");
        var expectedChunkAtlas=tissue.Call("atlas",structureField,(Vector2)chunkKey*64,64.0,8).AsGodotDictionary();require(expectedChunkAtlas["data"].AsByteArray().Length>0,"Alien production chunk atlas fixture was empty");
        require(GD.VarToBytes(expectedChunkAtlas["data"]).SequenceEqual(GD.VarToBytes(builder.Get("built_alien_tissue_flow")))&&expectedChunkAtlas["rows"].AsInt64()==builder.Get("built_alien_tissue_flow_rows").AsInt64(),"Actual terrain builder stored different Alien tissue atlas bytes/rows");
        terrain.Get("alien_infected").AsGodotObject().Set("nerve_flow_texturing",false);require(coordinates.structure_atlas(builder,arrays,structureOrigin).Count==0,"Alien disabled structure texturing emitted an atlas");require(coordinates.structure_atlas(builder,new(),structureOrigin).Count==0,"Alien empty structure emitted an atlas");
        void Equal(double a,double b,string scope)=>require(Math.Abs(a-b)<=1e-12&&(float)a==(float)b,$"{scope}: {a:R} / {b:R}");
    }
}
