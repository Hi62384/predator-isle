using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace PredatorIsle.Terrain;

/// <summary>Choose by full worker latency, including GPU queuing, transfer,
/// preparation, validation and CPU completion. Hardware is never presumed faster.</summary>
internal sealed class TerrainGpuAdaptivePolicy
{
    internal readonly record struct Key(long Revision,int Level,int Resolution,int Families);
    internal sealed class Entry
    {
        internal double Cpu,Gpu;
        internal int CpuCount,GpuCount,SinceProbe;
        internal bool Probing;
    }
    private readonly object gate=new();
    private readonly Dictionary<Key,Entry> entries=new();
    private const int Capacity=256,ProbeInterval=24;
    internal sealed class Attempt:IDisposable
    {
        private TerrainGpuAdaptivePolicy? owner;
        private readonly Entry? entry;
        private readonly bool probe;
        private readonly long started=Stopwatch.GetTimestamp();
        internal bool UseGpu{get;}
        internal Attempt(TerrainGpuAdaptivePolicy? owner,Entry? entry,bool gpu,bool probe)
        {this.owner=owner;this.entry=entry;UseGpu=gpu;this.probe=probe;}
        internal void Complete()=>Complete(Stopwatch.GetElapsedTime(started).TotalMilliseconds);
        internal void Complete(double milliseconds)
        {
            var policy=owner;owner=null;
            if(policy is not null&&entry is not null)policy.Finish(entry,UseGpu,probe,milliseconds);
        }
        public void Dispose()=>Complete(double.NaN);
    }
    internal static Attempt Explicit(bool gpu)=>new(null,null,gpu,false);
    internal Attempt Begin(Key key)
    {
        lock(gate)
        {
            if(!entries.TryGetValue(key,out var entry))
            {
                if(entries.Count>=Capacity)entries.Clear();
                entry=new Entry();entries.Add(key,entry);
            }
            bool gpu=false,probe=false;
            if(entry.CpuCount>0)
            {
                if(entry.GpuCount==0)
                {
                    if(!entry.Probing){gpu=true;probe=true;}
                }
                else
                {
                    gpu=entry.Gpu<entry.Cpu*.95;
                    if(entry.SinceProbe>=ProbeInterval&&!entry.Probing)
                    {gpu=!gpu;probe=true;}
                }
            }
            if(probe){entry.Probing=true;entry.SinceProbe=0;}
            return new Attempt(this,entry,gpu,probe);
        }
    }
    private void Finish(Entry entry,bool gpu,bool probe,double milliseconds)
    {
        lock(gate)
        {
            if(probe)entry.Probing=false;
            if(!double.IsFinite(milliseconds)||milliseconds<0)return;
            milliseconds=Math.Max(milliseconds,.001);
            if(gpu){entry.Gpu=entry.GpuCount==0?milliseconds:entry.Gpu*.8+milliseconds*.2;entry.GpuCount++;}
            else{entry.Cpu=entry.CpuCount==0?milliseconds:entry.Cpu*.8+milliseconds*.2;entry.CpuCount++;}
            if(!probe)entry.SinceProbe=Math.Min(ProbeInterval,entry.SinceProbe+1);
        }
    }
}
