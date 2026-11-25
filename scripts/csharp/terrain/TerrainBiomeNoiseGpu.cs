using Godot;
using System;
using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace PredatorIsle.Terrain;

/// <summary>Bounded renderer-independent numerical pass for every specialized
/// biome. Render queue owns only immutable float inputs, never worker resources.</summary>
public partial class TerrainBiomeNoiseGpu:Node
{
    private sealed record Request(Vector4[] Input,int Count,int Columns,int Rows)
    {
        internal readonly TaskCompletionSource<float[]?> Completion=new(TaskCreationOptions.RunContinuationsAsynchronously);
    }
    private readonly ConcurrentQueue<Request> pending=new();
    private readonly object lifecycle=new();
    private Shader? shader;
    private SubViewport? viewport;
    private ColorRect? rect;
    private ShaderMaterial? material;
    private ImageTexture? texture;
    private Request? active;
    private long drawVersion,activeVersion,completed,hitCount,rejected;
    private int available;
    private bool subscribed;
    internal bool Available=>Volatile.Read(ref available)!=0;
    internal double RequestTimeoutSeconds{get;set;}=30;
    internal long CompletedScalars=>Interlocked.Read(ref completed);
    internal long CacheHits=>Interlocked.Read(ref hitCount);
    internal long Rejected=>Interlocked.Read(ref rejected);
    internal string LastFailure{get;private set;}="";

    public override void _Ready()
    {
        ProcessMode=ProcessModeEnum.Always;
        if(DisplayServer.GetName()=="headless")return;
        shader=GD.Load<Shader>("res://shaders/terrain_biome_noise_gpu.gdshader");
        if(shader is null)return;
        RenderingServer.FramePostDraw+=OnDraw;subscribed=true;
        Volatile.Write(ref available,1);
    }
    private void OnDraw()=>Interlocked.Increment(ref drawVersion);
    internal async Task<TerrainBiomeNoiseCache?> BakeAsync(TerrainBiomeNoisePlan plan,CancellationToken cancellation=default)
    {
        if(!Available||plan.Count==0||cancellation.IsCancellationRequested)return null;
        int columns=Math.Min(256,Math.Max(2,plan.Count)),rows=Math.Max(2,(plan.Count+columns-1)/columns);
        var request=new Request(plan.Inputs(columns,rows),plan.Count,columns,rows);
        lock(lifecycle)
        {
            if(!Available||pending.Count>=8)return null;
            pending.Enqueue(request);
        }
        try
        {
            var values=await request.Completion.Task.WaitAsync(TimeSpan.FromSeconds(RequestTimeoutSeconds),cancellation).ConfigureAwait(false);
            if(values is null||cancellation.IsCancellationRequested)return null;
            var cache=plan.Accept(values,hits=>Interlocked.Add(ref hitCount,hits),cancellation,out _);
            if(cache is null)Interlocked.Increment(ref rejected);
            return cache;
        }
        catch(TimeoutException){return null;}
        catch(OperationCanceledException){return null;}
        finally{request.Completion.TrySetResult(null);}
    }

    public override void _Process(double delta)
    {
        if(!Available)return;
        if(active is Request flight)
        {
            if(flight.Completion.Task.IsCompleted)
            {
                if(viewport is not null)viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled;
                active=null;
            }
            else if(Interlocked.Read(ref drawVersion)>activeVersion)
            {
                try
                {
                    using var image=viewport!.GetTexture().GetImage();
                    if(image is null||image.IsEmpty()||image.GetFormat()!=Image.Format.Rgba8||
                       image.GetWidth()!=flight.Columns||image.GetHeight()!=flight.Rows)
                        throw new InvalidOperationException("Unexpected biome noise readback layout.");
                    var bytes=image.GetData();
                    if(bytes.Length!=checked(flight.Columns*flight.Rows*4))
                        throw new InvalidOperationException("Unexpected biome noise readback size.");
                    var values=new float[flight.Count];
                    for(int i=0;i<values.Length;i++)
                    {
                        values[i]=BitConverter.Int32BitsToSingle(BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(i*4,4)));
                        if(!float.IsFinite(values[i]))throw new InvalidOperationException("Non-finite biome noise result.");
                    }
                    if(flight.Completion.TrySetResult(values))Interlocked.Add(ref completed,values.Length);
                }
                catch(Exception ex){LastFailure=ex.Message;flight.Completion.TrySetResult(null);}
                finally{viewport!.RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled;active=null;}
            }
        }
        if(active is not null)return;
        while(pending.TryDequeue(out var request))
        {
            if(request.Completion.Task.IsCompleted)continue;
            try{Dispatch(request);break;}
            catch(Exception ex){LastFailure=ex.Message;request.Completion.TrySetResult(null);ReleaseTarget();}
        }
    }
    private void Dispatch(Request request)
    {
        if(viewport is null)
        {
            viewport=new SubViewport{Name="BiomeNoiseNumerics",Disable3D=true,TransparentBg=true,
                UseHdr2D=false,UseDebanding=false,Msaa2D=Viewport.Msaa.Disabled,GuiDisableInput=true,
                RenderTargetClearMode=SubViewport.ClearMode.Always,RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled,
                CanvasItemDefaultTextureFilter=Viewport.DefaultCanvasItemTextureFilter.Nearest};
            AddChild(viewport);
            material=new ShaderMaterial{Shader=shader};
            rect=new ColorRect{Color=Colors.White,Material=material,MouseFilter=Control.MouseFilterEnum.Ignore};
            viewport.AddChild(rect);
        }
        viewport.Size=new Vector2I(request.Columns,request.Rows);
        rect!.Size=new Vector2(request.Columns,request.Rows);
        using var input=Image.CreateFromData(request.Columns,request.Rows*2,false,Image.Format.Rgbaf,
            MemoryMarshal.AsBytes(request.Input.AsSpan()).ToArray());
        if(texture is not null&&texture.GetWidth()==request.Columns&&texture.GetHeight()==request.Rows*2)texture.Update(input);
        else
        {
            var previous=texture;
            texture=ImageTexture.CreateFromImage(input);
            material!.SetShaderParameter("numeric_inputs",texture);
            previous?.Dispose();
        }
        material!.SetShaderParameter("sample_count",request.Count);
        material.SetShaderParameter("sample_columns",request.Columns);
        material.SetShaderParameter("sample_rows",request.Rows);
        activeVersion=Interlocked.Read(ref drawVersion);active=request;
        viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Once;
    }
    private void ReleaseTarget()
    {
        if(viewport is not null&&GodotObject.IsInstanceValid(viewport))viewport.Free();
        viewport=null;rect=null;material?.Dispose();material=null;texture?.Dispose();texture=null;
    }
    internal void Shutdown()
    {
        lock(lifecycle)
        {
            Volatile.Write(ref available,0);
            while(pending.TryDequeue(out var request))request.Completion.TrySetResult(null);
        }
        active?.Completion.TrySetResult(null);active=null;ReleaseTarget();
    }
    public override void _ExitTree()
    {
        Shutdown();
        if(subscribed){RenderingServer.FramePostDraw-=OnDraw;subscribed=false;}
    }
}
