using Godot;
using System;
using System.Threading;

namespace PredatorIsle.Terrain;

/// <summary>
/// Canonical province/plateau placement and affine noise inputs. Geographic
/// placement keeps its authoritative double intermediates because tiny macro-noise
/// differences otherwise become centimetres along cliffs. Local noise and detailed
/// landform shaping remain on the GPU.
/// </summary>
internal static class GrasslandGpuCoordinates
{
    internal const int Bands=5;

    internal static Vector4[] Capture(GrasslandField field,GrasslandGpuParameters config,Vector2[] positions,CancellationToken cancellation=default)
    {
        cancellation.ThrowIfCancellationRequested();
        double Parameter(string name)=>config.CanonicalValues[Array.IndexOf(config.Names,name)];
        double landform=Parameter("landform_size"),plateauFrequency=Parameter("plateau_frequency"),variety=Parameter("geographic_variety");
        static double Smooth(double a,double b,double v){double t=Math.Clamp((v-a)/(b-a),0,1);return t*t*(3-2*t);}
        var result=new Vector4[checked(positions.Length*Bands)];
        for(int i=0;i<positions.Length;i++)
        {
            if((i&127)==0)cancellation.ThrowIfCancellationRequested();
            double x=positions[i].X,z=positions[i].Y;int at=i*Bands;
            var province=field.geographic_identity(x,z);
            double region=field.region.GetNoise2D((float)x,(float)z)*.5+.5;
            double geology=field.region.GetNoise2D((float)(x+17391),(float)(z-9137));
            double plateau=(geology-(.42-plateauFrequency*.9))*landform*.6;
            plateau-=(1-Smooth(.46,.65,province.Y))*landform*.65*variety;
            result[at]=new Vector4((float)region,(float)plateau,province.X,province.Y);
            result[at+1]=new Vector4((float)(x+17391),(float)(z-9137),(float)x,(float)(z*.7));
            result[at+2]=new Vector4((float)(x*3.8+917),(float)(z*2.1-371),(float)(x*.22+7103),(float)(z*.22-2911));
            result[at+3]=new Vector4((float)(x*.45-3191),(float)(z*.45+7319),(float)(x+7113),(float)(z-3719));
            result[at+4]=new Vector4((float)(x*1.5),(float)(z*1.5),(float)(x*1.8),0);
        }
        return result;
    }
}
