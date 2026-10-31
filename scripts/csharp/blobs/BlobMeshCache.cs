using Godot;
using System;
using System.Text.RegularExpressions;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Bounded generator-owned cache; source fingerprints invalidate data after implementation changes.</summary>
public partial class BlobMeshCache : RefCounted
{
    public string DIRECTORY=>OS.HasFeature("editor")?"res://.godot/blob_organisms_v4":"user://blob_organisms_v4";

    private static readonly string[] Sources={"res://scripts/blobs/blob_blueprint.gd","res://scripts/blobs/blob_anatomical_growth.gd","res://scripts/blobs/blob_organism_pipeline.gd","res://scripts/blobs/blob_deformation_bindings.gd","res://scripts/blobs/blob_surface_attachments.gd","res://scripts/blobs/blob_curve_frames.gd","res://scripts/blobs/blob_stable_extractor.gd","res://scripts/blobs/blob_mesh_integrity.gd","res://scripts/blobs/blob_surface_circulation.gd","res://scripts/csharp/blobs/BlobCurveFrames.cs","res://scripts/csharp/blobs/BlobCurveGuard.cs","res://scripts/csharp/blobs/BlobMeshCache.cs","res://scripts/csharp/blobs/OrganicMeshExtractor.cs","res://scripts/csharp/blobs/BlobStableExtractor.cs","res://scripts/csharp/blobs/OrganicCurveGeometry.cs","res://scripts/csharp/blobs/BlobSurfaceCirculation.cs","res://scripts/csharp/blobs/BlobVolumeCalibration.cs","res://scripts/csharp/blobs/BlobSurfaceAttachments.cs","res://scripts/csharp/blobs/BlobBlueprint.cs","res://scripts/csharp/blobs/BlobMeshIntegrity.cs","res://scripts/csharp/blobs/BlobDeformationBindings.cs","res://scripts/csharp/blobs/BlobOrganismPipeline.cs","res://scripts/csharp/blobs/BlobOrganismField.cs","res://scripts/csharp/blobs/BlobOrganismGeometry.cs","res://scripts/csharp/blobs/BlobAnatomicalGrowth.cs","res://scripts/csharp/blobs/BlobAnatomicalDetails.cs"};
    private static readonly Regex OwnedName=new("^[0-9a-f]{64}\\.bin$",RegexOptions.CultureInvariant);
    private const long MaximumBytes=67108864;
    private static bool Complete(D result)
    {
        foreach(string name in new[]{"dna","body","rig","finalization"})if(!result.TryGetValue(name,out var value)||value.VariantType!=Variant.Type.Dictionary)return false;
        foreach(string name in new[]{"features","appendages"})if(!result.TryGetValue(name,out var value)||value.VariantType!=Variant.Type.Array)return false;
        var body=result["body"].AsGodotDictionary();return body.TryGetValue("vertices",out var vertices)&&vertices.VariantType==Variant.Type.PackedVector3Array&&vertices.AsVector3Array().Length>0&&body.TryGetValue("indices",out var indices)&&indices.VariantType==Variant.Type.PackedInt32Array&&indices.AsInt32Array().Length>0;
    }
    public string key(long seed,int quality,string mode,int lastPass,D options)
    {
        var fingerprint=new A{typeof(BlobOrganismPipeline).Assembly.ManifestModule.ModuleVersionId.ToString()};foreach(string path in Sources)fingerprint.Add(FileAccess.FileExists(path)?FileAccess.GetSha256(path):"packed");
        return (Json.Stringify(new A{seed,quality,mode,lastPass,options},"",true)+fingerprint.ToString()).Sha256Text();
    }
    public D build(long seed,int quality,string mode,int lastPass,RefCounted? job,D options)
    {
        string digest=key(seed,quality,mode,lastPass,options),path=DIRECTORY+"/"+digest+".bin";
        if(job is not null&&job.Call("is_cancelled").AsBool())return new D{["cancelled"]=true};
        if(FileAccess.FileExists(path))
        {
            using var file=FileAccess.Open(path,FileAccess.ModeFlags.Read);
            if(file is not null&&file.GetLength()<MaximumBytes)
            {
                var packet=GD.BytesToVar(file.GetBuffer((long)file.GetLength()));
                if(packet.VariantType==Variant.Type.Dictionary)
                {
                    var value=packet.AsGodotDictionary();if(value.TryGetValue("key",out var saved)&&saved.AsString()==digest&&value.TryGetValue("data",out var data)&&data.VariantType==Variant.Type.Dictionary){var result=data.AsGodotDictionary();if(Complete(result)){result["cache_hit"]=true;return result;}}
                }
            }
        }
        using var pipeline=new BlobOrganismPipeline();
        Variant generated=pipeline.build(seed,quality,mode,lastPass,job,options);
        if(generated.VariantType!=Variant.Type.Dictionary)return new D{["error"]="Organism generation did not return a result."};
        var built=generated.AsGodotDictionary();
        if(built.ContainsKey("error")||(built.TryGetValue("cancelled",out var cancelled)&&cancelled.AsBool()))return built;
        if(!Complete(built))return new D{["error"]="Organism generation returned incomplete anatomy."};
        DirAccess.MakeDirRecursiveAbsolute(DIRECTORY);using var directory=DirAccess.Open(DIRECTORY);
        if(directory is not null)
        {
            var files=directory.GetFiles();if(files.Length>=32)
            {
                string oldest="";ulong oldestTime=long.MaxValue;
                foreach(string name in files){if(!OwnedName.IsMatch(name))continue;ulong modified=FileAccess.GetModifiedTime(DIRECTORY+"/"+name);if(modified<oldestTime){oldest=name;oldestTime=modified;}}
                if(oldest.Length>0)directory.Remove(oldest);
            }
            var bytes=GD.VarToBytes(new D{["key"]=digest,["data"]=built});
            if(bytes.Length<MaximumBytes){using var file=FileAccess.Open(path,FileAccess.ModeFlags.Write);file?.StoreBuffer(bytes);}
        }
        built["cache_hit"]=false;return built;
    }
}
