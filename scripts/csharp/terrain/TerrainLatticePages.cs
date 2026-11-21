using System;
using System.Collections.Generic;
using System.Threading;
namespace PredatorIsle.Terrain;

/// <summary>Sparse 16x16 numerical pages; no request generates an entire page. Each stream owns its source scope.</summary>
internal sealed class TerrainLatticePages<T>(int capacity)
{
    private sealed class Page
    {
        internal readonly object Sync=new();
        internal readonly T[] Values=new T[256];
        internal readonly bool[] Ready=new bool[256];
        internal int Users,Count;
    }
    private sealed record Interest(double X,double Z,double Radius);
    private Interest interest=new(double.PositiveInfinity,double.PositiveInfinity,0);
    private readonly object sync=new();
    private readonly Dictionary<(int X,int Z),Page> pages=new();
    private readonly Queue<(int X,int Z)> order=new();
    internal int Count{get{lock(sync){int result=0;foreach(var page in pages.Values)result+=Volatile.Read(ref page.Count);return result;}}}
    internal void Protect(double x,double z,double radius)=>Volatile.Write(ref interest,new(x,z,radius));
    private static ((int X,int Z) Key,int Index) Address(double x,double z)
    {int px=(int)Math.Floor(x/16),pz=(int)Math.Floor(z/16);return((px,pz),((int)z-pz*16)*16+(int)x-px*16);}
    private Page Acquire((int X,int Z) key,bool create)
    {
        lock(sync)
        {
            if(pages.TryGetValue(key,out var existing)){existing.Users++;return existing;}
            if(!create)return null!;
            if(pages.Count>=capacity&&!Evict(false))Evict(true);
            var page=new Page{Users=1};
            // All resident pages may be leased under oversubscription. Keep the resident
            // bound; ordinary terrain has at most 16 workers and at least 32 pages.
            if(pages.Count<capacity){pages[key]=page;order.Enqueue(key);}return page;
        }
    }
    private bool Evict(bool protectedToo)
    {
        int attempts=order.Count;var focus=Volatile.Read(ref interest);
        while(attempts-->0)
        {
            var key=order.Dequeue();var page=pages[key];bool near=Math.Abs(key.X*16+8-focus.X)<=focus.Radius+8&&Math.Abs(key.Z*16+8-focus.Z)<=focus.Radius+8;
            if(page.Users>0||near&&!protectedToo){order.Enqueue(key);continue;}pages.Remove(key);return true;
        }
        return false;
    }
    private void Release(Page page){lock(sync)page.Users--;}
    internal bool TryGet(double x,double z,out T value)
    {
        var (key,at)=Address(x,z);var page=Acquire(key,false);if(page is null){value=default!;return false;}
        try{lock(page.Sync){value=page.Values[at];return page.Ready[at];}}finally{Release(page);}
    }
    internal T Get(double x,double z,Func<T> produce,out bool hit)
    {
        var (key,at)=Address(x,z);var page=Acquire(key,true);
        try{lock(page.Sync){hit=page.Ready[at];if(hit)return page.Values[at];T value=produce();page.Values[at]=value;page.Ready[at]=true;Interlocked.Increment(ref page.Count);return value;}}finally{Release(page);}
    }
    internal void Remember(double x,double z,T value)
    {
        var (key,at)=Address(x,z);var page=Acquire(key,true);
        try{lock(page.Sync){if(page.Ready[at])return;page.Values[at]=value;page.Ready[at]=true;Interlocked.Increment(ref page.Count);}}finally{Release(page);}
    }
}
