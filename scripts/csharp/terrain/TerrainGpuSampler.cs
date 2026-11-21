using Godot;
using System;
using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace PredatorIsle.Terrain;

/// <summary>
/// Bounded Compatibility-renderer numerical generation queue. Workers submit immutable
/// plans; only the main thread creates resources or reads the finished render target.
/// A failed, cancelled or unsupported request returns null so the canonical CPU path runs.
/// </summary>
public partial class TerrainGpuSampler : Node
{
    public const int ScalarsPerSample = 8;
    private const int RawScalarsPerSample = 9;
    public const int MaximumSamples = 65536;
    // Above this validated range, float evaluation can differ by centimetres from
    // the canonical double-coordinate terrain. Use the CPU there, even on fast GPUs.
    public const float MaximumCoordinate = 32768;
    public int MaximumInFlight { get; set; } = 2;
    public int MaximumReadbacksPerFrame { get; set; } = 1;
    public int MaximumQueuedRequests { get; set; } = 16;
    public double RequestTimeoutSeconds { get; set; } = 30;
    public bool Available => Volatile.Read(ref available) != 0;
    public int QueuedRequests => Volatile.Read(ref queued);
    public long CompletedRequests { get; private set; }
    public long CompletedSamples { get; private set; }
    public long FailedRequests { get; private set; }
    public long ReadbackBytes { get; private set; }
    public long Readbacks { get; private set; }
    public long GeneratedRawSamples { get; private set; }
    /// <summary>GPU GetImage/GetData transfer time; excludes CPU decode and demultiplexing.</summary>
    public double ReadbackMilliseconds { get; private set; }
    public string LastFailure { get; private set; } = "";

    private sealed class Request : IDisposable
    {
        public readonly GrasslandGpuParameters Parameters;
        public readonly Vector2[] Positions;
        public readonly GrasslandGpuHydrology Hydrology;
        public readonly Vector4[] Coordinates;
        public readonly TaskCompletionSource<float[]?> Completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public readonly CancellationToken Cancellation;
        public readonly CancellationTokenSource Lifetime;
        public CancellationTokenRegistration Registration;
        public Request(GrasslandGpuParameters parameters,Vector2[] positions,GrasslandGpuHydrology hydrology,Vector4[] coordinates,CancellationToken cancellation,double timeoutSeconds)
        {
            Parameters=parameters;Positions=positions;Hydrology=hydrology;Coordinates=coordinates;
            Lifetime=CancellationTokenSource.CreateLinkedTokenSource(cancellation);
            Lifetime.CancelAfter(TimeSpan.FromSeconds(Math.Clamp(timeoutSeconds,1,120)));
            Cancellation=Lifetime.Token;
            Registration=Cancellation.Register(()=>Completion.TrySetResult(null));
        }
        public void Dispose(){Registration.Dispose();Lifetime.Dispose();}
    }
    private sealed class Flight
    {
        public required Request[] Requests;
        public required int[][] SampleIndices;
        public required int SampleCount;
        public required SubViewport Viewport;
        public required ShaderMaterial Material;
        public required ImageTexture Input;
        public required ImageTexture Rivers;
        public required ImageTexture Lakes;
        public required int Columns;
        public required int Rows;
        public required long DrawVersion;
    }
    private readonly ConcurrentQueue<Request> pending = new();
    private readonly List<Flight> flights = new();
    private readonly object lifecycle = new();
    private Shader? shader;
    private bool subscribed;
    private int available,queued;
    private long drawVersion;

    public override void _Ready()
    {
        ProcessMode=ProcessModeEnum.Always;
        // Headless authority always uses the canonical CPU generator and never awaits a draw.
        if(DisplayServer.GetName()=="headless")return;
        shader=GD.Load<Shader>("res://shaders/grassland_gpu.gdshader");
        if(shader is null){LastFailure="Grassland GPU shader could not be loaded.";return;}
        RenderingServer.FramePostDraw+=OnPostDraw;
        subscribed=true;
        Volatile.Write(ref available,1);
    }
    private void OnPostDraw()=>Interlocked.Increment(ref drawVersion);

    /// <summary>
    /// Thread-safe submission from the owner of the worker-local field. Capture reads only
    /// configuration and canonical geographic planning; no graphics object is created on
    /// that worker. Results are sample-major:
    /// value.xyz, surface.xy, geology.xyz. Coordinates must match CPU float input positions.
    /// </summary>
    public async Task<float[]?> SampleAsync(GrasslandField field,Vector2[] positions,CancellationToken cancellation=default)
    {
        if(!Available||positions.Length==0||positions.Length>MaximumSamples||cancellation.IsCancellationRequested)
            return null;
        foreach(var point in positions)if(!SupportedPosition(point))return null;
        var parameters=GrasslandGpuParameters.Capture(field);
        if(parameters is null)return null;
        double step=Math.Min(field.settings.Get("grass_field_spacing").AsDouble(),Math.Max(1,field.settings.Get("grass_river_width").AsDouble()*.25));
        positions=(Vector2[])positions.Clone();
        var result=new float[checked(positions.Length*ScalarsPerSample)];
        // Each interpolated query needs at most four coarse corners and one exact
        // relief point. Split before expansion so every graphics job stays bounded.
        const int queryBatch=MaximumSamples/5;
        try
        {
            for(int offset=0;offset<positions.Length;offset+=queryBatch)
            {
                if(cancellation.IsCancellationRequested)return null;
                int length=Math.Min(queryBatch,positions.Length-offset);
                var plan=GrasslandGpuSamplePlan.Create(positions.AsSpan(offset,length),step,cancellation);
                if(plan is null)return null;
                // Network/site placement is CPU planning. Its cached columns use double
                // intermediates before publishing floats, exactly like the canonical field.
                var hydrology=GrasslandGpuHydrology.Capture(field,plan.RawPositions,cancellation);
                var raw=await Enqueue(field,parameters,plan.RawPositions,hydrology,cancellation).ConfigureAwait(false);
                if(raw is null||cancellation.IsCancellationRequested)return null;
                var values=plan.Interpolate(raw);values.CopyTo(result,offset*ScalarsPerSample);
            }
            return result;
        }
        catch(OperationCanceledException) when(cancellation.IsCancellationRequested){return null;}
        catch(OverflowException){return null;}
    }
    private static bool SupportedPosition(Vector2 point)=>float.IsFinite(point.X)&&float.IsFinite(point.Y)&&Math.Abs(point.X)<=MaximumCoordinate&&Math.Abs(point.Y)<=MaximumCoordinate;
    private Task<float[]?> Enqueue(GrasslandField field,GrasslandGpuParameters parameters,Vector2[] positions,GrasslandGpuHydrology hydrology,CancellationToken cancellation)
    {
        var coordinates=GrasslandGpuCoordinates.Capture(field,parameters,positions,cancellation);
        lock(lifecycle)
        {
            // Shutdown cannot drain the queue between the availability check and enqueue.
            if(!Available||queued>=MaximumQueuedRequests)return Task.FromResult<float[]?>(null);
            Interlocked.Increment(ref queued);
            var request=new Request(parameters,positions,hydrology,coordinates,cancellation,RequestTimeoutSeconds);
            pending.Enqueue(request);return request.Completion.Task;
        }
    }

    public override void _Process(double delta)
    {
        if(!Available)return;
        int remaining=Math.Max(0,MaximumReadbacksPerFrame);
        for(int i=flights.Count-1;i>=0;i--)
        {
            var flight=flights[i];
            if(flight.Requests.All(request=>request.Completion.Task.IsCompleted)){Retire(i);continue;}
            if(remaining==0||Interlocked.Read(ref drawVersion)<=flight.DrawVersion)continue;
            remaining--;
            try
            {
                ulong start=Time.GetTicksUsec();
                using var image=flight.Viewport.GetTexture().GetImage();
                if(image is null||image.IsEmpty()||image.GetFormat()!=Image.Format.Rgba8||image.GetWidth()!=flight.Columns||image.GetHeight()!=flight.Rows*RawScalarsPerSample)
                    throw new InvalidOperationException("GPU heightmap readback returned an unexpected image layout.");
                var bytes=image.GetData();
                ReadbackMilliseconds+=(Time.GetTicksUsec()-start)/1000.0;
                var values=Decode(bytes,flight.SampleCount,flight.Columns,flight.Rows);
                Readbacks++;ReadbackBytes+=bytes.LongLength;GeneratedRawSamples+=flight.SampleCount;
                for(int requestIndex=0;requestIndex<flight.Requests.Length;requestIndex++)
                {
                    var request=flight.Requests[requestIndex];
                    if(request.Cancellation.IsCancellationRequested)continue;
                    var indices=flight.SampleIndices[requestIndex];var ownValues=new float[indices.Length*RawScalarsPerSample];
                    for(int sample=0;sample<indices.Length;sample++)
                        values.AsSpan(indices[sample]*RawScalarsPerSample,RawScalarsPerSample).CopyTo(ownValues.AsSpan(sample*RawScalarsPerSample));
                    if(request.Completion.TrySetResult(ownValues)){CompletedRequests++;CompletedSamples+=request.Positions.Length;}
                }
            }
            catch(Exception error)
            {FailedRequests+=flight.Requests.Length;LastFailure=error.Message;foreach(var request in flight.Requests)request.Completion.TrySetResult(null);}
            finally{Retire(i);}
        }
        while(flights.Count<Math.Clamp(MaximumInFlight,1,4)&&pending.TryDequeue(out var request))
        {
            Interlocked.Decrement(ref queued);
            if(request.Completion.Task.IsCompleted){request.Dispose();continue;}
            var batch=new List<Request>{request};int points=request.Positions.Length;
            while(batch.Count<8&&pending.TryPeek(out var next))
            {
                if(next.Completion.Task.IsCompleted){if(pending.TryDequeue(out next)){Interlocked.Decrement(ref queued);next.Dispose();}continue;}
                if(points+next.Positions.Length>MaximumSamples||!request.Parameters.Equivalent(next.Parameters))break;
                if(!pending.TryDequeue(out next))continue;
                Interlocked.Decrement(ref queued);points+=next.Positions.Length;batch.Add(next);
            }
            try{Dispatch(batch.ToArray());}
            catch(Exception error){FailedRequests+=batch.Count;LastFailure=error.Message;foreach(var item in batch){item.Completion.TrySetResult(null);item.Dispose();}}
        }
    }

    private void Dispatch(Request[] requests)
    {
        // Neighboring chunks share coarse field corners. Share those texels across
        // submitted workers too, and retrieve the whole batch with one GPU readback.
        var points=new List<Vector4>();var lookup=new Dictionary<Vector2,int>();var maps=new int[requests.Length][];
        var pointSources=new List<(Request Request,int Index)>();
        var riverValues=new List<Vector4>{Vector4.Zero,Vector4.Zero,Vector4.Zero};
        var lakeValues=new List<Vector4>{Vector4.Zero};
        var riverIndices=new Dictionary<GrasslandGpuHydrology.RiverKey,int>();
        var lakeIndices=new Dictionary<Vector2I,int>();
        for(int requestIndex=0;requestIndex<requests.Length;requestIndex++)
        {
            var positions=requests[requestIndex].Positions;var map=new int[positions.Length];maps[requestIndex]=map;
            for(int i=0;i<positions.Length;i++)
            {
                if(!lookup.TryGetValue(positions[i],out int index))
                {
                    index=points.Count;lookup.Add(positions[i],index);int riverIndex=0,lakeIndex=0;
                    var river=requests[requestIndex].Hydrology.Rivers[i];
                    if(river is not null&&!riverIndices.TryGetValue(river.Key,out riverIndex))
                    {
                        riverIndex=riverValues.Count;riverIndices.Add(river.Key,riverIndex);
                        foreach(var column in river.Columns)riverValues.Add(new Vector4(column.X,column.Y,column.Z,river.Key.Lane));
                    }
                    var lake=requests[requestIndex].Hydrology.Lakes[i];
                    if(lake is not null&&!lakeIndices.TryGetValue(lake.Key,out lakeIndex))
                    {
                        lakeIndex=lakeValues.Count;lakeIndices.Add(lake.Key,lakeIndex);lakeValues.Add(new Vector4(lake.Sites.Length,0,0,0));
                        lakeValues.AddRange(lake.Sites);
                    }
                    points.Add(new Vector4(positions[i].X,positions[i].Y,riverIndex,lakeIndex));
                    pointSources.Add((requests[requestIndex],i));
                }
                map[i]=index;
            }
        }
        int columns=Math.Min(512,Math.Max(2,points.Count));
        int rows=Math.Max(1,(points.Count+columns-1)/columns);
        // A SubViewport must be at least 2 pixels in both dimensions. Output has nine bands.
        int positionRows=Math.Max(2,rows),plane=columns*positionRows;
        var bytes=new byte[checked(plane*(1+GrasslandGpuCoordinates.Bands)*16)];
        var coordinates=MemoryMarshal.Cast<byte,Vector4>(bytes);
        for(int i=0;i<points.Count;i++)
        {
            coordinates[i]=points[i];var source=pointSources[i];
            for(int band=0;band<GrasslandGpuCoordinates.Bands;band++)coordinates[(band+1)*plane+i]=source.Request.Coordinates[source.Index*GrasslandGpuCoordinates.Bands+band];
        }
        using var image=Image.CreateFromData(columns,positionRows*(1+GrasslandGpuCoordinates.Bands),false,Image.Format.Rgbaf,bytes);
        ImageTexture? input=null,rivers=null,lakes=null;ShaderMaterial? material=null;SubViewport? viewport=null;
        try
        {
            input=ImageTexture.CreateFromImage(image);material=new ShaderMaterial{Shader=shader};
            requests[0].Parameters.Apply(material);
            (rivers,int riverColumns)=DataTexture(riverValues);(lakes,int lakeColumns)=DataTexture(lakeValues);
            material.SetShaderParameter("planned_rivers",rivers);material.SetShaderParameter("planned_lakes",lakes);
            material.SetShaderParameter("river_columns",riverColumns);material.SetShaderParameter("lake_columns",lakeColumns);
            material.SetShaderParameter("sample_positions",input);material.SetShaderParameter("sample_count",points.Count);
            material.SetShaderParameter("sample_columns",columns);material.SetShaderParameter("sample_rows",rows);
            material.SetShaderParameter("position_rows",positionRows);
            viewport=new SubViewport
            {
                Name="GrasslandHeightBake",Size=new Vector2I(columns,rows*RawScalarsPerSample),
                Disable3D=true,TransparentBg=true,UseHdr2D=false,UseDebanding=false,
                Msaa2D=Viewport.Msaa.Disabled,GuiDisableInput=true,
                RenderTargetClearMode=SubViewport.ClearMode.Always,
                RenderTargetUpdateMode=SubViewport.UpdateMode.Disabled,
                CanvasItemDefaultTextureFilter=Viewport.DefaultCanvasItemTextureFilter.Nearest
            };
            viewport.AddChild(new ColorRect{Size=new Vector2(columns,rows*RawScalarsPerSample),Color=Colors.White,Material=material,MouseFilter=Control.MouseFilterEnum.Ignore});
            AddChild(viewport);viewport.RenderTargetUpdateMode=SubViewport.UpdateMode.Once;
            flights.Add(new Flight{Requests=requests,SampleIndices=maps,SampleCount=points.Count,Viewport=viewport,Material=material,Input=input,Rivers=rivers,Lakes=lakes,Columns=columns,Rows=rows,DrawVersion=Interlocked.Read(ref drawVersion)});
        }
        catch{viewport?.Free();material?.Dispose();input?.Dispose();rivers?.Dispose();lakes?.Dispose();throw;}
    }

    private static (ImageTexture Texture,int Columns) DataTexture(List<Vector4> values)
    {
        int columns=Math.Min(512,Math.Max(2,values.Count));int rows=Math.Max(2,(values.Count+columns-1)/columns);
        var bytes=new byte[checked(columns*rows*16)];CollectionsMarshal.AsSpan(values).CopyTo(MemoryMarshal.Cast<byte,Vector4>(bytes));
        using var image=Image.CreateFromData(columns,rows,false,Image.Format.Rgbaf,bytes);
        return (ImageTexture.CreateFromImage(image),columns);
    }

    internal static float[] Decode(byte[] bytes,int count,int columns,int rows)
    {
        if(bytes.Length!=checked(columns*rows*RawScalarsPerSample*4))throw new ArgumentException("Invalid numerical texture byte count.",nameof(bytes));
        var result=new float[checked(count*RawScalarsPerSample)];
        for(int band=0;band<RawScalarsPerSample;band++)for(int sample=0;sample<count;sample++)
        {
            float value=BitConverter.Int32BitsToSingle(BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan((band*rows*columns+sample)*4,4)));
            if(!float.IsFinite(value))throw new InvalidOperationException("GPU heightmap contained a non-finite sample.");
            result[sample*RawScalarsPerSample+band]=value;
        }
        return result;
    }
    private void Retire(int index)
    {
        var flight=flights[index];flights.RemoveAt(index);foreach(var request in flight.Requests)request.Dispose();
        flight.Viewport.Free();flight.Material.Dispose();flight.Input.Dispose();flight.Rivers.Dispose();flight.Lakes.Dispose();
    }
    /// <summary>Main-thread shutdown; call before waiting for terrain worker disposal.</summary>
    public void Shutdown()
    {
        lock(lifecycle)
        {
            Volatile.Write(ref available,0);
            while(pending.TryDequeue(out var request)){Interlocked.Decrement(ref queued);request.Completion.TrySetResult(null);request.Dispose();}
        }
        for(int i=flights.Count-1;i>=0;i--){foreach(var request in flights[i].Requests)request.Completion.TrySetResult(null);Retire(i);}
    }
    public override void _ExitTree(){Shutdown();if(subscribed){RenderingServer.FramePostDraw-=OnPostDraw;subscribed=false;}}
}
