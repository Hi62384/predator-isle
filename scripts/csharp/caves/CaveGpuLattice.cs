using Godot;
using System;
using System.Collections.Generic;
using PredatorIsle.Terrain;

namespace PredatorIsle.Caves;

/// <summary>Experimental GPU SDF screening for the shared cave lattice.
/// CPU evaluates every uncertain sample, chunk boundary and actual tetrahedron
/// crossing. Collision, winding, protected shores and normals stay canonical.</summary>
internal static class CaveGpuLattice
{
    private const int Columns=256,BinsPerAxis=5,BinCount=125,Header=3;
    private const float CpuRequired=5,Guard=.25f,ParityTolerance=.025f;
    internal const string ShaderPath="res://shaders/cave_lattice_gpu.gdshader";
    internal const string TopologyShaderPath="res://shaders/cave_topology_gpu.gdshader";
    internal const int UncertainCase=1<<24;
    internal static readonly int[][] Tets={new[]{0,5,1,6},new[]{0,1,2,6},new[]{0,2,3,6},
        new[]{0,3,7,6},new[]{0,7,4,6},new[]{0,4,5,6}};
    internal static int PackCases(int cubeMask)
    {
        int packed=0;
        for(int t=0;t<Tets.Length;t++)
        for(int j=0;j<4;j++)
            packed|=((cubeMask>>Tets[t][j])&1)<<(t*4+j);
        return packed;
    }
    private static bool Bounded(Vector3 p)=>p.IsFinite()&&Math.Abs(p.X)<=8192&&Math.Abs(p.Y)<=8192&&Math.Abs(p.Z)<=8192;
    private static bool Finite(double x)=>double.IsFinite(x)&&Math.Abs(x)<=1000000;
    private sealed record Plan(Vector4[] Inputs,int InputRows,int OutputRows,double[]? Top);

    private static Plan? Create(CaveField f,Vector3 origin,int row,float step)
    {
        if(f.GetType()!=typeof(CaveField)&&f.GetType()!=typeof(PortalCaveField))return null;
        if(!Bounded(origin)||!Bounded(origin+Vector3.One*64)||!Finite(f.maximum_depth)||
            !Finite(f.minimum_roof)||!Finite(f.opening_rock_cover))return null;
        if(!f.cache_height_samples)return null; // custom per-query callbacks retain exact semantics
        bool portal=f is PortalCaveField {include_surface_air:true};
        int plane=row*row,count=checked(row*plane),groundStart=Header+BinCount;
        var data=new List<Vector4>(groundStart+plane+1024);
        for(int i=0;i<groundStart+plane;i++)data.Add(Vector4.Zero);
        data[0]=new Vector4(origin.X,origin.Y,origin.Z,step);
        data[1]=new Vector4(row,(float)f.maximum_depth,(float)f.minimum_roof,(float)f.opening_rock_cover);
        data[2]=new Vector4(groundStart,portal?1:0,f.floor_relief.Count>0?1:0,0);
        var first=f.bin_cell(origin);
        var active=new bool[BinsPerAxis*BinsPerAxis];
        int references=0;
        for(int z=0;z<BinsPerAxis;z++)
        for(int y=0;y<BinsPerAxis;y++)
        for(int x=0;x<BinsPerAxis;x++)
        {
            if(!f.Bins.TryGetValue(first+new Vector3I(x,y,z),out var features)||features.Count==0)continue;
            if(features.Count>64||references+features.Count>8192)return null;
            references+=features.Count;active[x+z*BinsPerAxis]=true;
            int bin=Header+x+y*BinsPerAxis+z*BinsPerAxis*BinsPerAxis;
            data[bin]=new Vector4(data.Count,features.Count,0,0);
            foreach(int i in features)
            {
                var a=f.Begins[i];var b=f.Ends[i];var size=f.Dimensions[i];var dir=f.Directions[i];
                if(!Bounded(a)||!Bounded(b)||!size.IsFinite()||size.X<=0||size.X>512||
                   !Finite(f.ArchHeight[i])||f.ArchHeight[i]<=0||f.ArchHeight[i]>512||
                   !Finite(f.ArchCenter[i])||!Finite(f.ArchScale[i])||
                   !Finite(f.SpanLength[i])||f.SpanLength[i]>512||!Finite(f.SpanSquared[i])||
                   (f.Kinds[i]!=2&&f.SpanSquared[i]<.01))return null;
                double firstGrade=double.PositiveInfinity,lastGrade=double.PositiveInfinity;
                if(f.continuous_route_floors)
                {
                    if(f.EndpointGrades.Count<=i*2+1)return null;
                    firstGrade=f.EndpointGrades[i*2];lastGrade=f.EndpointGrades[i*2+1];
                }
                if(double.IsFinite(firstGrade)&&Math.Abs(firstGrade)>4||
                   double.IsFinite(lastGrade)&&Math.Abs(lastGrade)>4)return null;
                a-=origin;b-=origin;
                data.Add(new Vector4(a.X,a.Y,a.Z,f.Kinds[i]));
                data.Add(new Vector4(b.X,b.Y,b.Z,f.Styles[i]));
                data.Add(new Vector4(size.X,(float)f.ArchHeight[i],(float)f.ArchCenter[i],(float)f.ArchScale[i]));
                data.Add(new Vector4(dir.X,dir.Y,(float)f.SpanSquared[i],(float)f.SpanLength[i]));
                data.Add(new Vector4(double.IsFinite(firstGrade)?(float)firstGrade:0,
                    double.IsFinite(lastGrade)?(float)lastGrade:0,
                    double.IsFinite(firstGrade)?1:0,double.IsFinite(lastGrade)?1:0));
            }
        }
        // Tiny/no-feature cells are cheaper to evaluate directly.
        if(references<4)return null;
        double[]? top=portal?new double[plane]:null;
        int perBin=(int)(16/step);
        for(int z=0;z<row;z++)
        for(int x=0;x<row;x++)
        {
            int at=x+z*row;
            var p=origin+new Vector3(x,0,z)*step;
            double ground=active[x/perBin+(z/perBin)*BinsPerAxis]?f.ground_height(p):double.NaN;
            double surface=portal?((PortalCaveField)f).SurfaceHeight(new Vector2(p.X,p.Z)):double.NaN;
            if(top is not null)top[at]=surface;
            if(double.IsFinite(ground)&&!Finite(ground-origin.Y)||double.IsFinite(surface)&&!Finite(surface-origin.Y))return null;
            data[groundStart+at]=new Vector4(double.IsFinite(ground)?(float)(ground-origin.Y):0,
                double.IsFinite(surface)?(float)(surface-origin.Y):0,
                double.IsFinite(ground)?1:0,double.IsFinite(surface)?1:0);
        }
        int inputRows=(data.Count+Columns-1)/Columns,outputRows=(count+Columns-1)/Columns;
        var inputs=new Vector4[inputRows*Columns];data.CopyTo(inputs);
        return new Plan(inputs,inputRows,outputRows,top);
    }

    /// <summary>Read back GPU-generated tetrahedral cases and evaluate only
    /// corners that can affect geometry. Uniform interior cubes never need
    /// their CPU SDF values, and no intermediate GPU texture is read back.</summary>
    internal static int[]? TryFillTopology(TerrainBiomeNoiseGpu gpu,CaveField field,Vector3 origin,
        int row,float step,float[] destination,out int exactSamples)
    {
        exactSamples=0;
        if(!gpu.TopologyAvailable)return null;
        var plan=Create(field,origin,row,step);
        if(plan is null)return null;
        int cells=row-1,plane=row*row,count=row*plane;
        var raw=gpu.BakeCaveTopologyAsync(plan.Inputs,row,Columns,plan.InputRows)
            .GetAwaiter().GetResult();
        if(raw is null||raw.Length!=cells*cells*cells)return null;
        var cases=new int[raw.Length];
        var ready=new bool[count];
        int checkedSamples=0;
        bool Exact(int i)
        {
            if(ready[i])return true;
            int x=i%row,y=i/row%row,z=i/plane;
            var p=origin+new Vector3(x,y,z)*step;
            float value=(float)(plan.Top is not null?
                ((PortalCaveField)field).SampleWithSurfaceHeight(p,plan.Top[x+z*row]):field.sample(p));
            if(!float.IsFinite(value))return false;
            destination[i]=value;ready[i]=true;checkedSamples++;return true;
        }
        ReadOnlySpan<int> offsets=stackalloc int[]{0,1,1+row,row,plane,1+plane,1+row+plane,row+plane};
        for(int z=0;z<cells;z++)
        for(int y=0;y<cells;y++)
        for(int x=0;x<cells;x++)
        {
            int cell=x+cells*(y+cells*z),start=x+row*y+plane*z;
            float value=raw[cell];
            if(!float.IsFinite(value)||value<0||value>UncertainCase||value!=MathF.Floor(value))return null;
            int packed=(int)value;
            // The CPU also independently requests every boundary cube, even if
            // a device failed to set the shader's uncertainty marker.
            bool boundary=x==0||y==0||z==0||x==cells-1||y==cells-1||z==cells-1;
            bool uniform=packed is 0 or 0xffffff;
            if(boundary||!uniform||cell%257==0)
            {
                int mask=0;
                for(int i=0;i<8;i++)
                {
                    int at=start+offsets[i];
                    if(!Exact(at))return null;
                    if(destination[at]<0)mask|=1<<i;
                }
                int canonical=PackCases(mask);
                if(packed!=UncertainCase&&canonical!=packed)return null;
                packed=canonical;
            }
            cases[cell]=packed;
        }
        // Compare known canonical corners against adjacent uniform cases.
        // This includes corners from uncertain cubes replaced by the CPU.
        for(int i=0;i<count;i++)
        {
            if(!ready[i])continue;
            int x=i%row,y=i/row%row,z=i/plane;
            bool air=destination[i]<0;
            for(int dz=-1;dz<=0;dz++)for(int dy=-1;dy<=0;dy++)for(int dx=-1;dx<=0;dx++)
            {
                int cx=x+dx,cy=y+dy,cz=z+dz;
                if(cx<0||cy<0||cz<0||cx>=cells||cy>=cells||cz>=cells)continue;
                int packed=cases[cx+cells*(cy+cells*cz)];
                if(packed==0&&air||packed==0xffffff&&!air)return null;
            }
        }
        if(checkedSamples==count)return null;
        exactSamples=checkedSamples;
        return cases;
    }

    internal static bool TryFill(TerrainBiomeNoiseGpu gpu,CaveField field,Vector3 origin,int row,
        float step,float[] destination,out int exactSamples)
    {
        exactSamples=0;
        if(!gpu.Available)return false;
        var plan=Create(field,origin,row,step);
        if(plan is null)return false;
        int plane=row*row,count=checked(row*plane);
        // The producer is a worker; graphics calls and readback remain on the
        // main thread. The queue always has a finite deadline and shutdown drain.
        var values=gpu.BakeRawAsync(plan.Inputs,count,Columns,plan.OutputRows,plan.InputRows)
            .GetAwaiter().GetResult();
        if(values is null||values.Length!=count)return false;
        var exact=new bool[count];int checkedSamples=0;
        bool Check(int i)
        {
            if(exact[i])return true;
            int z=i/plane,y=i/row%row,x=i%row;
            var p=origin+new Vector3(x,y,z)*step;
            float canonical=(float)(plan.Top is not null?
                ((PortalCaveField)field).SampleWithSurfaceHeight(p,plan.Top[x+z*row]):field.sample(p));
            float candidate=values[i];
            if(!float.IsFinite(canonical)||!float.IsFinite(candidate))return false;
            // The shader's out-of-range sentinel selects the exact floor-relief
            // calculation. Every other checked value must meet parity and
            // cannot disagree in sign outside the conservative crossing band.
            if(candidate!=CpuRequired&&
                (Math.Abs((double)canonical-candidate)>ParityTolerance||
                 (Math.Abs(candidate)>Guard&&(candidate<0)!=(canonical<0))))return false;
            values[i]=canonical;exact[i]=true;checkedSamples++;return true;
        }

        // All chunk borders are exact, not only borders requested by frontier
        // capture. Every near-zero or floor-relief value is also recomputed.
        for(int z=0;z<row;z++)
        for(int y=0;y<row;y++)
        for(int x=0;x<row;x++)
        {
            int i=x+y*row+z*plane;
            if(x==0||y==0||z==0||x==row-1||y==row-1||z==row-1||
                i%257==0||values[i]==CpuRequired||Math.Abs(values[i])<=Guard)
                if(!Check(i))return false;
        }
        ReadOnlySpan<int> offsets=stackalloc int[]{0,1,1+row,row,plane,1+plane,1+row+plane,row+plane};
        for(int z=0;z<row-1;z++)
        for(int y=0;y<row-1;y++)
        for(int x=0;x<row-1;x++)
        {
            int at=x+y*row+z*plane;bool air=false,rock=false;
            foreach(int offset in offsets){air|=values[at+offset]<0;rock|=values[at+offset]>=0;}
            if(!air||!rock)continue;
            // All emitted edge interpolation and tetrahedron case decisions
            // consume the same float scalars as the canonical CPU extractor.
            foreach(int offset in offsets)if(!Check(at+offset))return false;
        }
        if(checkedSamples==count)return false; // no work saved
        values.AsSpan().CopyTo(destination);
        exactSamples=checkedSamples;
        return true;
    }
}
