using Godot;
using System;

namespace PredatorIsle.Checks;

/// <summary>The shared terrain GPU trail shader may cull an edge only if the
/// former exact segment-distance admission cannot possibly accept it.
/// Tests random endpoint jitter, line positions, signed world coordinates,
/// scales, widths and far points without trusting the shader optimization.</summary>
internal static class TerrainTrailBoundsChecks
{
    private static bool Admits(Vector2 p,Vector2 id,float size,float width,int edge)
    {
        float radius=size*.65f+width*4f;
        if(radius<=0)return false;
        var low=(id+new Vector2(.20f,.20f))*size;
        var high=(id+(edge==0?new Vector2(1.80f,.80f):new Vector2(.80f,1.80f)))*size;
        float scale=MathF.Max(MathF.Max(MathF.Abs(p.X),MathF.Abs(p.Y)),
            MathF.Max(MathF.Max(MathF.Abs(low.X),MathF.Abs(low.Y)),
                      MathF.Max(MathF.Abs(high.X),MathF.Abs(high.Y))));
        float reach=radius+size*.02f+scale*.00001f;
        return !(p.X<low.X-reach||p.X>high.X+reach||
                 p.Y<low.Y-reach||p.Y>high.Y+reach);
    }

    internal static void Run(Action<bool,string> require)
    {
        var random=new Random(18237);
        int admitted=0,rejected=0;
        foreach(float size in new[]{40f,160f,450f,1100f,4800f})
        foreach(float width in new[]{.5f,2.5f,7f,24f})
        foreach(float origin in new[]{-1000000f,-10000f,0f,10000f,1000000f})
        foreach(int edge in new[]{0,1})
        for(int trial=0;trial<40;trial++)
        {
            var cell=new Vector2(MathF.Floor(origin/size),MathF.Floor(-origin/size));
            var start=cell+new Vector2(.22f+.56f*(float)random.NextDouble(),.22f+.56f*(float)random.NextDouble());
            var end=cell+(edge==0?Vector2.Right:Vector2.Down)+
                new Vector2(.22f+.56f*(float)random.NextDouble(),.22f+.56f*(float)random.NextDouble());
            var a=start*size;var b=end*size;var ab=b-a;
            float t=(float)random.NextDouble();
            var along=a+ab*t;
            var tangent=ab.Normalized();
            var orthogonal=new Vector2(-tangent.Y,tangent.X);
            float radius=size*.65f+width*4f;
            // Sample the original acceptance threshold and both distant
            // sides, not only positions known to be within the AABB.
            var point=along+orthogonal*radius*(float)(random.NextDouble()*3.0-.7);
            float segmentT=Math.Clamp((point-a).Dot(ab)/Math.Max(ab.LengthSquared(),.001f),0f,1f);
            bool original=point.DistanceTo(a+ab*segmentT)<radius;
            bool bounded=Admits(point,cell,size,width,edge);
            require(!original||bounded,
                "GPU trail bounding gate rejected an original valid segment at "+point+
                " scale "+size+" edge "+edge+" origin "+origin);
            if(original)admitted++;else if(!bounded)rejected++;
            var far=along+orthogonal*radius*8;
            require(!Admits(far,cell,size,width,edge),
                "GPU trail gate failed to skip a far-away path segment");
        }
        require(admitted>1000&&rejected>1000,
            "GPU trail bounds test failed to exercise both acceptance and early rejection");
    }
}
