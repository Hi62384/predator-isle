using Godot;
using System;
using System.Collections.Generic;
using System.Threading;

namespace PredatorIsle.Terrain;

/// <summary>
/// Enumerates the actual canonical queries used by a ring, including filter/normal
/// support and the independent one-metre physics grid. This is a sparse union, not
/// a large rectangular texture with unused samples between the ternary knots.
/// </summary>
internal static class TerrainGpuSamplePlan
{
    internal const int MaximumPoints=GrasslandField.GpuSampleCapacity;
    internal static Vector2[] Create(TerrainMeshBuilder builder,TerrainRingTopology topology,
        TerrainRingLayout.Patch patch,int resolution,bool filterDistant,CancellationToken cancellation)
    {
        double scale=Math.Max(builder.settings.Get("terrain_shape_scale").AsDouble(),.01);
        var positions=new List<Vector2>();
        var visited=new HashSet<(double X,double Z)>();
        var field=builder._native_grass;
        double footprint=patch.Size/resolution,derivative=Math.Max(1,footprint);
        bool filtered=filterDistant&&patch.Key.Z>=2;
        var grid=topology.Get(resolution,patch.Key.Z>0,patch.Hole);
        var axis=grid.Axis.Span;
        for(int z=0;z<axis.Length;z++)
        {
            cancellation.ThrowIfCancellationRequested();
            for(int x=0;x<axis.Length;x++)
            {
                double lx=patch.Size*axis[x]/grid.Denominator,lz=patch.Size*axis[z]/grid.Denominator;
                AddFiltered(patch.OriginX+lx,patch.OriginZ+lz);
                // Normals use the stored float local vertex position in the existing builder.
                double wx=patch.OriginX+(float)lx,wz=patch.OriginZ+(float)lz;
                AddFiltered(wx-derivative,wz);AddFiltered(wx+derivative,wz);
                AddFiltered(wx,wz-derivative);AddFiltered(wx,wz+derivative);
            }
        }
        if(patch.Key.Z<=1)
        {
            var ground=topology.Get(checked((int)Math.Ceiling(patch.Size)),patch.Key.Z>0,patch.Hole);
            var groundAxis=ground.Axis.Span;
            for(int z=0;z<groundAxis.Length;z++)
            {
                cancellation.ThrowIfCancellationRequested();
                for(int x=0;x<groundAxis.Length;x++)
                    Add(patch.OriginX+patch.Size*groundAxis[x]/ground.Denominator,patch.OriginZ+patch.Size*groundAxis[z]/ground.Denominator);
            }
        }
        if(patch.Key.Z is 1 or 2)
        {
            double step=patch.Size/6;
            for(int z=0;z<6;z++)for(int x=0;x<6;x++)
            {
                double wx=patch.OriginX+(x+.5)*step,wz=patch.OriginZ+(z+.5)*step;
                if(!patch.Contains(wx,wz))continue;
                Add(wx-step*.5,wz-step*.5);Add(wx+step*.5,wz-step*.5);
                Add(wx-step*.5,wz+step*.5);Add(wx+step*.5,wz+step*.5);Add(wx,wz);
            }
        }
        return positions.ToArray();

        void AddFiltered(double x,double z)
        {
            Add(x,z);
            if(!filtered)return;
            double offset=footprint*.5;
            for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++)if(dx!=0||dz!=0)Add(x+dx*offset,z+dz*offset);
        }
        void Add(double x,double z)
        {
            if(positions.Count>=MaximumPoints||!visited.Add((x,z)))return;
            double gx=x/scale,gz=z/scale;
            var point=new Vector2((float)gx,(float)gz);
            // Unsupported world magnitudes and non-exact coordinates keep CPU evaluation.
            if((double)point.X!=gx||(double)point.Y!=gz||Math.Abs(gx)>TerrainGpuSampler.MaximumCoordinate||Math.Abs(gz)>TerrainGpuSampler.MaximumCoordinate||field.HasGpuSample(point))return;
            // Ownership remains CPU authoritative. Don't spend a GPU batch on regions
            // where the grassland function cannot contribute to the final height.
            if(builder._native_regions.weights(x,z).X<=0)return;
            positions.Add(point);
        }
    }
}
