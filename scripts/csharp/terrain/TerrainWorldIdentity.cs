using Godot;
using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Canonical world handshake data. Graphics profiles and residency do not participate.</summary>
internal static class TerrainWorldIdentity
{
    public static D Create(long seed,double water,Resource settings,Resource? caves)
    {
        var world=new D{["protocol"]="predator-isle-canonical-1m-v1",["generator_build"]=typeof(TerrainMeshBuilder).Assembly.ManifestModule.ModuleVersionId.ToString(),["engine"]=Engine.GetVersionInfo()["string"],["seed"]=seed,["water_level"]=water,["terrain"]=Capture(settings,0),["caves"]=caves is null?default(Variant):Variant.From(Capture(caves,0))};
        string serialized=Json.Stringify(world,"",true,true);return new D{["sha256"]=Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(serialized))).ToLowerInvariant(),["snapshot"]=world};
    }
    private static D Capture(Resource resource,int depth)
    {
        if(depth>16)throw new InvalidOperationException("Canonical world settings contain a cycle or excessive nesting.");if(resource is Script script)return new D{["script_path"]=script.ResourcePath};if(resource is Texture2D or TextureLayered or Texture3D or Material or Shader)return new D{["asset"]=resource.ResourcePath};var result=new D{["type"]=resource.GetType().FullName??resource.GetClass()};
        foreach(var item in resource.GetPropertyList().OrderBy(p=>p["name"].AsString(),StringComparer.Ordinal))
        {
            string name=item["name"].AsString();if(name=="script"||name.StartsWith("resource_",StringComparison.Ordinal)||(item["usage"].AsInt64()&(long)PropertyUsageFlags.Storage)==0)continue;result[name]=Normalize(resource.Get(name),depth+1);
        }
        return result;
    }
    private static Variant Normalize(Variant value,int depth)
    {
        if(depth>16)throw new InvalidOperationException("Canonical world settings are too deeply nested.");
        switch(value.VariantType)
        {
            case Variant.Type.Nil:case Variant.Type.Bool:case Variant.Type.Int:case Variant.Type.Float:case Variant.Type.String:return value;
            case Variant.Type.StringName:return value.AsStringName().ToString();
            case Variant.Type.Object:return value.AsGodotObject() is Resource resource?Capture(resource,depth):throw new InvalidOperationException("World settings must not reference scene objects.");
            case Variant.Type.Vector2:{var v=value.AsVector2();return new A{v.X,v.Y};}
            case Variant.Type.Vector3:{var v=value.AsVector3();return new A{v.X,v.Y,v.Z};}
            case Variant.Type.Vector4:{var v=value.AsVector4();return new A{v.X,v.Y,v.Z,v.W};}
            case Variant.Type.Vector2I:{var v=value.AsVector2I();return new A{v.X,v.Y};}
            case Variant.Type.Vector3I:{var v=value.AsVector3I();return new A{v.X,v.Y,v.Z};}
            case Variant.Type.Vector4I:{var v=value.AsVector4I();return new A{v.X,v.Y,v.Z,v.W};}
            case Variant.Type.Rect2:{var v=value.AsRect2();return new A{v.Position.X,v.Position.Y,v.Size.X,v.Size.Y};}
            case Variant.Type.Aabb:{var v=value.AsAabb();return new A{v.Position.X,v.Position.Y,v.Position.Z,v.Size.X,v.Size.Y,v.Size.Z};}
            case Variant.Type.Color:{var v=value.AsColor();return new A{v.R,v.G,v.B,v.A};}
            case Variant.Type.Array:{var source=value.AsGodotArray();if(source.Count>65536)throw new InvalidOperationException("Canonical settings array is too large.");var result=new A();foreach(var item in source)result.Add(Normalize(item,depth+1));return result;}
            case Variant.Type.Dictionary:{var source=value.AsGodotDictionary();var result=new D();foreach(var key in source.Keys.OrderBy(k=>k.AsString(),StringComparer.Ordinal))result[key.AsString()]=Normalize(source[key],depth+1);return result;}
            case Variant.Type.PackedVector4Array:{var result=new A();foreach(var item in value.AsVector4Array())result.Add(new A{item.X,item.Y,item.Z,item.W});return result;}
            case Variant.Type.PackedFloat32Array:{var result=new A();foreach(var item in value.AsFloat32Array())result.Add(item);return result;}
            case Variant.Type.PackedFloat64Array:{var result=new A();foreach(var item in value.AsFloat64Array())result.Add(item);return result;}
            case Variant.Type.PackedInt32Array:{var result=new A();foreach(var item in value.AsInt32Array())result.Add(item);return result;}
            case Variant.Type.PackedStringArray:{var result=new A();foreach(var item in value.AsStringArray())result.Add(item);return result;}
            case Variant.Type.PackedByteArray:{var result=new A();foreach(var item in value.AsByteArray())result.Add((int)item);return result;}
            case Variant.Type.PackedInt64Array:{var result=new A();foreach(var item in value.AsInt64Array())result.Add(item);return result;}
            case Variant.Type.PackedVector2Array:{var result=new A();foreach(var item in value.AsVector2Array())result.Add(new A{item.X,item.Y});return result;}
            case Variant.Type.PackedVector3Array:{var result=new A();foreach(var item in value.AsVector3Array())result.Add(new A{item.X,item.Y,item.Z});return result;}
            case Variant.Type.PackedColorArray:{var result=new A();foreach(var item in value.AsColorArray())result.Add(new A{item.R,item.G,item.B,item.A});return result;}
            default:throw new InvalidOperationException("Unsupported canonical world setting: "+value.VariantType);
        }
    }
}
