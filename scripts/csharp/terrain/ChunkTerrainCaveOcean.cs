using Godot;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

public partial class ChunkTerrain
{
    private Godot.Collections.Dictionary? oceanCaveColumns;
    private readonly Queue<Vector2I> oceanColumnsToSample=new();
    private Vector2I oceanMinColumn;
    private Image? oceanLand;
    private ImageTexture? oceanLandTexture;

    private void UpdateCaveOceanMask()
    {
        if(_water?.Mesh is not PlaneMesh plane || plane.Material is not ShaderMaterial material || _cave_streamer is null)return;
        var columns=_cave_streamer._surface_columns;
        if(!ReferenceEquals(oceanCaveColumns,columns) || columns.Count==0 && oceanLand is not null)
        {
            if(columns.Count==0 && oceanCaveColumns is null)return;
            oceanCaveColumns=columns;
            oceanColumnsToSample.Clear();
            material.SetShaderParameter("cave_ground_bounds",Vector4.Zero);
            if(columns.Count==0){oceanLand=null;oceanLandTexture=null;return;}
            var cells=columns.Keys.Select(key=>key.AsVector2I()).ToArray();
            var low=new Vector2I(cells.Min(p=>p.X),cells.Min(p=>p.Y));
            var high=new Vector2I(cells.Max(p=>p.X),cells.Max(p=>p.Y));
            var size=(high-low+Vector2I.One)*8;
            oceanMinColumn=low;
            oceanLand=Image.CreateEmpty(size.X,size.Y,false,Image.Format.Rf);
            oceanLand.Fill(new Color(float.MinValue,0,0));
            oceanLandTexture=ImageTexture.CreateFromImage(oceanLand);
            material.SetShaderParameter("cave_ground_height",oceanLandTexture);
            material.SetShaderParameter("cave_ground_bounds",new Vector4(low.X*64,low.Y*64,size.X*8,size.Y*8));
            foreach(var cell in cells.OrderBy(p=>((Vector2)p*64+Vector2.One*32-new Vector2(target!.GlobalPosition.X,target.GlobalPosition.Z)).LengthSquared()))oceanColumnsToSample.Enqueue(cell);
        }
        if(!oceanColumnsToSample.TryDequeue(out var column))return;
        // Sample the original surface above the opened cave. The ocean can still
        // draw in coastal cells where the original land lies below the waves.
        var offset=(column-oceanMinColumn)*8;
        for(int z=0;z<8;z++)for(int x=0;x<8;x++)
        {
            var height=_get_height(column.X*64+x*8+4,column.Y*64+z*8+4);
            oceanLand!.SetPixel(offset.X+x,offset.Y+z,new Color((float)height,0,0));
        }
        oceanLandTexture!.Update(oceanLand!);
    }
}
