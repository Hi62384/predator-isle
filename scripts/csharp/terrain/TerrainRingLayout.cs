using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

/// <summary>
/// World-aligned ternary rings. Partial coarse cells retain a rectangular fine-coverage mask;
/// independently snapped rings never assume that the next finer footprint fits one parent.
/// </summary>
public sealed class TerrainRingLayout
{
    public readonly record struct Mask(int MinX,int MinZ,int MaxX,int MaxZ)
    {
        public bool Empty=>MinX>=MaxX||MinZ>=MaxZ;
        public bool Full=>MinX==0&&MinZ==0&&MaxX==3&&MaxZ==3;
        public static Mask None=>default;
    }
    public readonly record struct Patch(Vector3I Key,double Size,Mask Hole)
    {
        public double OriginX=>Key.X*Size;
        public double OriginZ=>Key.Y*Size;
        public Rect2 Bounds=>new(new Vector2((float)OriginX,(float)OriginZ),Vector2.One*(float)Size);
        public Rect2[] OwnedRegions()
        {
            if(Hole.Empty)return new[]{new Rect2(Vector2.Zero,Vector2.One*(float)Size)};var regions=new List<Rect2>(8);double size=Size/3;for(int z=0;z<3;z++)for(int x=0;x<3;x++)if(x<Hole.MinX||x>=Hole.MaxX||z<Hole.MinZ||z>=Hole.MaxZ)regions.Add(new Rect2(new Vector2((float)(x*size),(float)(z*size)),Vector2.One*(float)size));return regions.ToArray();
        }
        public bool Contains(double x,double z)
        {
            double u=(x-OriginX)/Size,v=(z-OriginZ)/Size;
            return u>=0&&u<1&&v>=0&&v<1&&(Hole.Empty||u<Hole.MinX/3.0||u>=Hole.MaxX/3.0||v<Hole.MinZ/3.0||v>=Hole.MaxZ/3.0);
        }
    }
    public sealed record Plan(Patch[] Patches,Rect2 Bounds,Vector2 Camera,double BaseSize,int OuterRings)
    {
        public Vector2[] CollisionInterests{get;init;}=Array.Empty<Vector2>();
        public Patch? Owner(double x,double z){foreach(var patch in Patches)if(patch.Contains(x,z))return patch;return null;}
    }
    public sealed record Delta(Patch[] Retained,Patch[] Required,Patch[] Replaced,Patch[] Retired);
    public double BaseSize{get;}
    public int OuterRings{get;}
    public TerrainRingLayout(double baseSize=16,int outerRings=6)
    {
        if(!double.IsFinite(baseSize)||baseSize<=0||outerRings<0||outerRings>12)throw new ArgumentOutOfRangeException(nameof(baseSize),"Ring sizes must be finite and positive; supported outer ring count is 0–12.");BaseSize=baseSize;OuterRings=outerRings;
    }
    public double Size(int level)
    {
        if(level<0||level>OuterRings)throw new ArgumentOutOfRangeException(nameof(level));double size=BaseSize;for(int i=0;i<level;i++)size*=3;return size;
    }
    private static int Cell(double coordinate,double size)
    {
        double cell=Math.Floor(coordinate/size);if(cell<int.MinValue+2.0||cell>int.MaxValue-2.0)throw new ArgumentOutOfRangeException(nameof(coordinate),"The camera exceeds supported terrain cell coordinates.");return (int)cell;
    }
    public Plan Select(Vector2 camera)
    {
        if(!camera.IsFinite())throw new ArgumentException("Terrain ring focus must be finite.",nameof(camera));var patches=new List<Patch>(9*(OuterRings+1));
        for(int level=0;level<=OuterRings;level++)
        {
            double size=Size(level);int cx=Cell(camera.X,size),cz=Cell(camera.Y,size);
            // Fine bounds are integer thirds of a coarse cell, including negative coordinates.
            double fineSize=size/3;int fx=level>0?Cell(camera.X,fineSize):0,fz=level>0?Cell(camera.Y,fineSize):0;
            for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
            {
                int px=cx+x,pz=cz+z;var hole=Mask.None;
                if(level>0){long ox=(long)px*3,oz=(long)pz*3;hole=new Mask((int)Math.Clamp((long)fx-1-ox,0,3),(int)Math.Clamp((long)fz-1-oz,0,3),(int)Math.Clamp((long)fx+2-ox,0,3),(int)Math.Clamp((long)fz+2-oz,0,3));if(hole.Full)continue;if(hole.Empty)hole=Mask.None;}
                patches.Add(new Patch(new Vector3I(px,pz,level),size,hole));
            }
        }
        double outerSize=Size(OuterRings);int outerX=Cell(camera.X,outerSize),outerZ=Cell(camera.Y,outerSize);var bounds=new Rect2(new Vector2((float)((outerX-1)*outerSize),(float)((outerZ-1)*outerSize)),Vector2.One*(float)(outerSize*3));
        return new Plan(patches.ToArray(),bounds,camera,BaseSize,OuterRings);
    }
    public static Vector3I Parent(Vector3I key)=>new(FloorThird(key.X),FloorThird(key.Y),checked(key.Z+1));
    private static int FloorThird(int value)=>value/3-(value%3<0?1:0);
    public static Vector3I[] Children(Vector3I key)
    {
        if(key.Z<=0)throw new ArgumentException("Finest terrain patches have no child level.");var children=new Vector3I[9];int index=0;for(int z=0;z<3;z++)for(int x=0;x<3;x++)children[index++]=new Vector3I(checked(key.X*3+x),checked(key.Y*3+z),key.Z-1);return children;
    }
    public static Delta Compare(Plan? previous,Plan current)
    {
        if(previous is null)return new Delta(Array.Empty<Patch>(),current.Patches,Array.Empty<Patch>(),Array.Empty<Patch>());var old=previous.Patches.ToDictionary(p=>p.Key);var required=new List<Patch>();var retained=new List<Patch>();var replaced=new List<Patch>();foreach(var patch in current.Patches){if(old.Remove(patch.Key,out var prior)){if(prior==patch)retained.Add(patch);else{required.Add(patch);replaced.Add(prior);}}else required.Add(patch);}return new Delta(retained.ToArray(),required.ToArray(),replaced.ToArray(),old.Values.ToArray());
    }
}
