using Godot;
namespace PredatorIsle.Terrain;
internal static class TerrainPayloadMemory
{
    // Conservative owned numerical storage estimate, never a serialization pass.
    internal static long Estimate(Variant value,int depth=0)
    {
        if(depth>32)return 1L<<40;
        return value.VariantType switch
        {
            Variant.Type.Array=>Array(value.AsGodotArray(),depth),
            Variant.Type.Dictionary=>Dictionary(value.AsGodotDictionary(),depth),
            Variant.Type.PackedByteArray=>64+value.AsByteArray().LongLength,
            Variant.Type.PackedInt32Array=>64+4*value.AsInt32Array().LongLength,
            Variant.Type.PackedInt64Array=>64+8*value.AsInt64Array().LongLength,
            Variant.Type.PackedFloat32Array=>64+4*value.AsFloat32Array().LongLength,
            Variant.Type.PackedFloat64Array=>64+8*value.AsFloat64Array().LongLength,
            Variant.Type.PackedVector2Array=>64+8*value.AsVector2Array().LongLength,
            Variant.Type.PackedVector3Array=>64+12*value.AsVector3Array().LongLength,
            Variant.Type.PackedVector4Array=>64+16*value.AsVector4Array().LongLength,
            Variant.Type.PackedColorArray=>64+16*value.AsColorArray().LongLength,
            Variant.Type.String=>64+2L*value.AsString().Length,
            _=>64
        };
    }
    private static long Array(Godot.Collections.Array items,int depth){long bytes=64+32L*items.Count;foreach(var item in items)bytes+=Estimate(item,depth+1);return bytes;}
    private static long Dictionary(Godot.Collections.Dictionary items,int depth){long bytes=128+64L*items.Count;foreach(var item in items){bytes+=Estimate(item.Key,depth+1)+Estimate(item.Value,depth+1);}return bytes;}
}
