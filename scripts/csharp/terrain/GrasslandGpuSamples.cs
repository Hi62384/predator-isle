using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

public partial class GrasslandField
{
    // Worker-owned numerical data. No texture, viewport or scene object enters this cache.
    internal readonly record struct GpuSample(Vector3 Value,Vector2 Surface,Vector3 Geology);
    private readonly Dictionary<Vector2,GpuSample> gpuSamples=new();
    private readonly Queue<Vector2> gpuSampleOrder=new();
    private bool cpuReferenceSample;
    internal const int GpuSampleCapacity=16384;
    internal long GpuSampleHits{get;private set;}
    internal long GpuSampleMisses{get;private set;}

    private void ClearGpuSamples()
    {
        gpuSamples.Clear();gpuSampleOrder.Clear();cpuReferenceSample=false;
        GpuSampleHits=GpuSampleMisses=0;
    }

    private bool TryGpuSample(double x,double z,out Vector3 value)
    {
        value=default;
        if(cpuReferenceSample)return false;
        // Rounding an arbitrary authority/cave coordinate to a nearby baked sample
        // would change the field. Only exact coordinates may reuse a GPU result.
        var position=new Vector2((float)x,(float)z);
        if((double)position.X==x&&(double)position.Y==z&&gpuSamples.TryGetValue(position,out var sample))
        {
            last_surface=sample.Surface;last_geology=sample.Geology;value=sample.Value;
            GpuSampleHits++;return true;
        }
        GpuSampleMisses++;return false;
    }

    internal bool HasGpuSample(Vector2 position)=>gpuSamples.ContainsKey(position);

    internal GpuSample CpuReference(Vector2 position)
    {
        cpuReferenceSample=true;
        try{var value=sample(position.X,position.Y);return new(value,last_surface,last_geology);}
        finally{cpuReferenceSample=false;}
    }

    internal void InstallGpuSamples(Vector2[] positions,float[] values)
    {
        if(values.Length!=checked(positions.Length*8))throw new ArgumentException("GPU sample count does not match its request.",nameof(values));
        // Validate the whole readback before changing the worker's cache.
        foreach(float value in values)if(!float.IsFinite(value))throw new ArgumentException("GPU grassland readback contains a non-finite value.",nameof(values));
        for(int i=0;i<positions.Length;i++)
        {
            var key=positions[i];int at=i*8;
            if(!gpuSamples.ContainsKey(key))
            {
                while(gpuSamples.Count>=GpuSampleCapacity&&gpuSampleOrder.TryDequeue(out var oldest))gpuSamples.Remove(oldest);
                gpuSampleOrder.Enqueue(key);
            }
            gpuSamples[key]=new(new(values[at],values[at+1],values[at+2]),new(values[at+3],values[at+4]),new(values[at+5],values[at+6],values[at+7]));
        }
    }
}
