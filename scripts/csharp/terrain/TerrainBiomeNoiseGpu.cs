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
    private sealed record Request(Vector4[] Input,int Count,int Columns,int Rows,int InputRows,int LatticeRow=0)
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
    private Shader? topologyShader;
    private SubViewport? topologyViewport;
    private ColorRect? topologyRect;
    private ShaderMaterial? topologyMaterial;
    private bool topologyPass;
    private long drawVersion,activeVersion,completed,hitCount,rejected;
    private int available;
    private bool subscribed;
    internal string ShaderPath{get;set;}="res://shaders/terrain_biome_noise_gpu.gdshader";
    internal string? TopologyShaderPath{get;set;}
    internal bool TopologyAvailable=>Available&&topologyShader is not null;
    internal bool Available=>Volatile.Read(ref available)!=0;
    internal double RequestTimeoutSeconds{get;set;}=30;
    internal long CompletedScalars=>Interlocked.Read(ref completed);
    internal long CacheHits=>Interlocked.Read(ref hitCount);
    internal long Rejected=>Interlocked.Read(ref rejected);
    internal void ReportRejection(string? reason=null)
    {
        if(reason is not null)LastFailure=reason;
        Interlocked.Increment(ref rejected);
    }
    internal void ReportCacheHits(long hits)=>Interlocked.Add(ref hitCount,hits);
    internal string LastFailure{get;private set;}="";

    public override void _Ready()
    {
        ProcessMode=ProcessModeEnum.Always;
        if(DisplayServer.GetName()=="headless")return;
        shader=GD.Load<Shader>(ShaderPath);
        if(shader is null)return;
        if(TopologyShaderPath is not null)topologyShader=GD.Load<Shader>(TopologyShaderPath);
        RenderingServer.FramePostDraw+=OnDraw;subscribed=true;
        Volatile.Write(ref available,1);
    }
    private void OnDraw()=>Interlocked.Increment(ref drawVersion);
    internal async Task<TerrainBiomeNoiseCache?> BakeAsync(TerrainBiomeNoisePlan plan,CancellationToken cancellation=default)
    {
        if(!Available||plan.Count==0||cancellation.IsCancellationRequested)return null;
        int columns=Math.Min(256,Math.Max(2,plan.Count)),rows=Math.Max(2,(plan.Count+columns-1)/columns);
        var values=await BakeRawAsync(plan.Inputs(columns,rows),plan.Count,columns,rows,rows*2,cancellation).ConfigureAwait(false);
        if(values is null||cancellation.IsCancellationRequested)return null;
        try
        {
            var cache=plan.Accept(values,hits=>Interlocked.Add(ref hitCount,hits),cancellation,out _);
            if(cache is null)Interlocked.Increment(ref rejected);
            return cache;
        }
        catch(OperationCanceledException){return null;}
    }

    // The same bounded viewport queue also serves cave numerical screening.
    // The immutable input texture can have a different row count from the output.
    internal async Task<float[]?> BakeRawAsync(Vector4[] inputs,int count,int columns,int rows,int inputRows,
        CancellationToken cancellation=default)
    {
        if(!Available||count<1||columns<2||rows<2||inputRows<1||
            columns>1024||rows>2048||inputRows>2048||count>columns*rows||
            inputs.Length!=columns*inputRows||cancellation.IsCancellationRequested)return null;
        return await Submit(new Request(inputs,count,columns,rows,inputRows),cancellation).ConfigureAwait(false);
    }

    // SDF and topology passes remain GPU-resident between draws; the readback
    // is the final packed six-tetrahedron cases, not the intermediate SDF.
    internal Task<float[]?> BakeCaveTopologyAsync(Vector4[] inputs,int latticeRow,int columns,int inputRows,
        CancellationToken cancellation=default)
    {
        if(!TopologyAvailable||latticeRow is not (17 or 33 or 65)||columns!=256||
            inputRows<1||inputRows>2048||inputs.Length!=columns*inputRows)
            return Task.FromResult<float[]?>(null);
        int cells=latticeRow-1,count=cells*cells*cells;
        int rows=Math.Max(2,(count+columns-1)/columns);
        return Submit(new Request(inputs,count,columns,rows,inputRows,latticeRow),cancellation);
    }
    private async Task<float[]?> Submit(Request request,CancellationToken cancellation)
    {
        if(cancellation.IsCancellationRequested)return null;
        lock(lifecycle)
        {
            if(!Available||pending.Count>=8)return null;
            pending.Enqueue(request);
        }
        try
        {
            return await request.Completion.Task.WaitAsync(TimeSpan.FromSeconds(RequestTimeoutSeconds),cancellation).ConfigureAwait(false);
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
                StopFlight();
                active=null;
            }
            else if(Interlocked.Read(ref drawVersion)>activeVersion)
            {
                try
                {
                    if(flight.LatticeRow>0&&!topologyPass)
                    {
                        DispatchTopology(flight);
                        return;
                    }
                    using var image=(topologyPass?topologyViewport!:viewport!).GetTexture().GetImage();
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
                finally
                {
                    // DispatchTopology starts the second GPU draw. Retain the
                    // primary target and flight until that draw has completed.
                    if(!topologyPass||flight.Completion.Task.IsCompleted)
                    {StopFlight();active=null;}
                }
            }
        }
        if(active is not null)return;
        while(pending.TryDequeue(out var request))
        {
            if(request.Completion.Task.IsCompleted)continue;
            try{Dispatch(request);break;}
            catch(Exception ex){LastFailure=ex.Message;request.Completion.TrySetResult(null);active=null;ReleaseTarget();}
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
        int primaryCount=request.LatticeRow>0?request.LatticeRow*request.LatticeRow*request.LatticeRow:request.Count;
        int primaryRows=request.LatticeRow>0?(primaryCount+request.Columns-1)/request.Columns:request.Rows;
        viewport.Size=new Vector2I(request.Columns,primaryRows);
        rect!.Size=new Vector2(request.Columns,primaryRows);
        using var input=Image.CreateFromData(request.Columns,request.InputRows,false,Image.Format.Rgbaf,
            MemoryMarshal.AsBytes(request.Input.AsSpan()).ToArray());
        if(texture is not null&&texture.GetWidth()==request.Columns&&texture.GetHeight()==request.InputRows)texture.Update(input);
        else
        {
            var previous=texture;
            texture=ImageTexture.CreateFromImage(input);
            material!.SetShaderParameter("numeric_inputs",texture);
            previous?.Dispose();
        }
        material!.SetShaderParameter("sample_count",primaryCount);
        material.SetShaderParameter("sample_columns",request.Columns);
        material.SetShaderParameter("sample_rows",primaryRows);
        topologyPass=false;activeVersion=Interlocked.Read(ref drawVersion);active=request;
        viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Once;
    }
    private void DispatchTopology(Request request)
    {
        viewport!.RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled;
        if(topologyViewport is null)
        {
            topologyViewport=new SubViewport{Name="CaveTopologyNumerics",Disable3D=true,TransparentBg=true,
                UseHdr2D=false,UseDebanding=false,Msaa2D=Viewport.Msaa.Disabled,GuiDisableInput=true,
                RenderTargetClearMode=SubViewport.ClearMode.Always,RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled,
                CanvasItemDefaultTextureFilter=Viewport.DefaultCanvasItemTextureFilter.Nearest};
            AddChild(topologyViewport);
            topologyMaterial=new ShaderMaterial{Shader=topologyShader};
            topologyRect=new ColorRect{Color=Colors.White,Material=topologyMaterial,MouseFilter=Control.MouseFilterEnum.Ignore};
            topologyViewport.AddChild(topologyRect);
        }
        topologyViewport.Size=new Vector2I(request.Columns,request.Rows);
        topologyRect!.Size=new Vector2(request.Columns,request.Rows);
        topologyMaterial!.SetShaderParameter("lattice_values",viewport.GetTexture());
        topologyMaterial.SetShaderParameter("lattice_row",request.LatticeRow);
        topologyMaterial.SetShaderParameter("sample_count",request.Count);
        topologyMaterial.SetShaderParameter("sample_columns",request.Columns);
        topologyPass=true;activeVersion=Interlocked.Read(ref drawVersion);
        topologyViewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Once;
    }
    private void StopFlight()
    {
        if(viewport is not null)viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled;
        if(topologyViewport is not null)topologyViewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled;
        topologyPass=false;
    }
    private void ReleaseTarget()
    {
        if(topologyViewport is not null&&GodotObject.IsInstanceValid(topologyViewport))topologyViewport.Free();
        topologyViewport=null;topologyRect=null;topologyMaterial?.Dispose();topologyMaterial=null;topologyPass=false;
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
