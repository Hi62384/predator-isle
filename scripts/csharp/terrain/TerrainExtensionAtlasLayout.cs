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

    internal int PackedWeightSlot(int family)
    {
        if(family<0||family>7)throw new ArgumentOutOfRangeException(nameof(family));
        return FamilyCount+family/4;
    }
}
