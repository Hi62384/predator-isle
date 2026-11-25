using System;

namespace PredatorIsle.Terrain;

/// <summary>One canonical compact RGBA8 atlas layout shared by worker packing,
/// main-thread shader binding and validation. A family with no quantized
/// ownership has no physical control strip; two packed weight strips follow
/// the occupied family strips, and the optional palette is last.</summary>
internal sealed class TerrainExtensionAtlasLayout
{
    internal int Mask{get;}
    internal int[] FamilySlots{get;}=new int[8];
    internal int FamilyCount{get;}
    internal int ExtensionStrips=>Mask==0?0:FamilyCount+2;
    internal int PaletteSlot=>ExtensionStrips==0?0:ExtensionStrips;

    private TerrainExtensionAtlasLayout(int mask)
    {
        Mask=mask;
        Array.Fill(FamilySlots,-1);
        int slot=0;
        for(int family=0;family<8;family++)
            if((mask&(1<<family))!=0)FamilySlots[family]=slot++;
        FamilyCount=slot;
    }

    internal static TerrainExtensionAtlasLayout FromMask(int mask)
    {
        if((mask&~255)!=0)
            throw new ArgumentOutOfRangeException(nameof(mask),
                "Extension ownership mask must have exactly eight possible family bits.");
        return new TerrainExtensionAtlasLayout(mask);
    }

    /// <summary>Exactly one fully owned family can bypass both packed weight reads.
    /// Check the actual RGBA8 bytes, including the other bank. Mixed ownership,
    /// fractional weights, missing data, and unexpected layouts stay on texture lookup.</summary>
    internal int PureFamily(byte[] data,int rows,bool palette)
    {
        if(FamilyCount!=1||rows<=0)return -1;
        int strips=ExtensionStrips+(palette?1:0);
        if(data.Length%(4L*rows)!=0||data.Length/(4L*rows)!=(long)rows*strips)return -1;
        int family=System.Numerics.BitOperations.TrailingZeroCount((uint)Mask);
        uint expectedA=family<4?255u<<(family*8):0u;
        uint expectedB=family>=4?255u<<((family-4)*8):0u;
        int stride=data.Length/rows;
        for(int z=0;z<rows;z++)
        for(int x=0;x<rows;x++)
        {
            int a=z*stride+(FamilyCount*rows+x)*4,b=a+rows*4;
            if(System.Buffers.Binary.BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(a,4))!=expectedA||
               System.Buffers.Binary.BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(b,4))!=expectedB)
                return -1;
        }
        return family;
    }

    internal int PackedWeightSlot(int family)
    {
        if(family<0||family>7)throw new ArgumentOutOfRangeException(nameof(family));
        return FamilyCount+family/4;
    }
}
