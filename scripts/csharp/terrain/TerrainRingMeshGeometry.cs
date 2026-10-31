using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using PredatorIsle.Biomes;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Small ring meshes from the canonical field, retaining every existing terrain material bank.</summary>
public sealed class TerrainRingMeshGeometry
{
    public sealed record Data(TerrainRingLayout.Patch Patch,TerrainRingTopology.Grid Topology,A Arrays,byte[] ExtensionData,int ExtensionRows,int ExtensionMask,int BadlandsSlot,byte[] AlienFlow,int AlienFlowRows)
    {
        public bool HasMountain{get;init;}
        public A Structures{get;init;}=new();
        public D Features{get;init;}=new();
        public D StructureFlow{get;init;}=new();
        public long AdditionalBytes{get;init;}
        public bool WaterEnabled{get;init;}
        public bool BeachesEnabled{get;init;}
        public double WaterLevel{get;init;}
        public D Collision{get;init;}=new();
        // A fixed one-metre CPU grid, independent of the client's visual profile and edge morphs.
        public A AuthoritativeGround{get;init;}=new();
        public A LocalWater{get;init;}=new();
        public string GeometryFingerprint{get;init;}="";
        public Rect2[] RefinementRegions{get;init;}=Array.Empty<Rect2>();
    }
    private readonly TerrainRingTopology topology;
    private readonly bool filterDistant;
    private static readonly double[] SupportSteps=CreateSupportSteps();
    private static double[] CreateSupportSteps(){var steps=new SortedSet<double>();for(int level=0;level<=8;level++)foreach(double nearSpacing in new[]{.5,1.0,2.0})steps.Add(nearSpacing*Math.Pow(3,level));return steps.ToArray();}
    private readonly ConditionalWeakTable<TerrainMeshBuilder,TerrainRingHeightFilter> filters=new();
    public TerrainRingMeshGeometry(TerrainRingTopology sharedTopology,bool filteredDistantHeights=true){topology=sharedTopology;filterDistant=filteredDistantHeights;}
    private readonly record struct Sample(float Height,Vector4 Weights,Vector2 Surface,Vector3 Geology,float Jungle,Vector4 Forest,Vector4 Savanna,Vector4 Swamp,Vector4 Mountain,Vector4 Coast,Vector3 Tropical,Vector3 Badlands,Vector4 Palette,Vector4 E0,Vector4 E1,Vector4 E2,Vector4 E3,Vector4 E4,Vector4 E5,Vector4 E6,Vector4 E7,float Water)
    {
        public Vector4 Extra(int family)=>family switch{0=>E0,1=>E1,2=>E2,3=>E3,4=>E4,5=>E5,6=>E6,_=>E7};
    }
    private static Vector4 Four(float[] values)=>new(values[0],values[1],values[2],values[3]);
    private static int Round(double x)=>(int)Math.Round(x,MidpointRounding.AwayFromZero);
    private static byte Byte(double x)=>(byte)Round(Math.Clamp(x,0,1)*255);
    private static Sample Capture(TerrainMeshBuilder builder,double x,double z,out double canonicalHeight)
    {
        var f=builder._native_height;canonicalHeight=f.grid_height(x,z);float h=(float)canonicalHeight;var e=f.last_extras;return new Sample(h,f.last_weights==Vector4.Zero?builder._native_regions.weights(x,z):f.last_weights,f.last_surface,f.last_geology,(float)f.last_jungle,Four(f.last_forest),Four(f.last_savanna),Four(f.last_swamp),Four(f.last_mountain),f.last_coast,f.last_tropical,f.last_badlands,f.last_badlands_palette,e[0],e[1],e[2],e[3],e[4],e[5],e[6],e[7],(float)f.last_water);
    }
    public Data Build(TerrainMeshBuilder builder,TerrainRingLayout.Patch patch,int resolution,Func<bool>? cancelled=null,Action<string>? stage=null)
    {
        builder.RingOwns=p=>patch.Contains(p.X,p.Y);
        try
        {
            stage?.Invoke("surface samples");var data=BuildSurface(builder,patch,resolution,cancelled,stage);if(cancelled?.Invoke()==true)throw new OperationCanceledException();stage?.Invoke("feature geometry");
            using var featuresBuilder=new TerrainFeatureMeshes();bool enabled=builder._extras_enabled||(builder._tropical is not null&&builder._tropical.settings.Get("waterfall_frequency").AsDouble()>0&&builder.settings.Get("water_enabled").AsBool());var features=enabled?featuresBuilder.build(builder,new Vector2I(patch.Key.X,patch.Key.Y)):new D();if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            stage?.Invoke("structure geometry");using var structuresBuilder=new LodBiomeStructureGeometry();var structures=builder._extras_enabled?structuresBuilder.build(builder,new Vector2I(patch.Key.X,patch.Key.Y),SupportSteps,new Callable(featuresBuilder,"portal_sites")):new A();var flow=new D();if(structures.Count>2&&structures[2].VariantType!=Variant.Type.Nil){using var coordinates=new AlienTissueCoordinates();flow=coordinates.structure_atlas(builder,structures[2].AsGodotArray(),new Vector2((float)patch.OriginX,(float)patch.OriginZ));}
            // Sidecar payloads are bounded by the same numerical cache budget as the surface mesh.
            var detail=structuresBuilder.RefinementRegions.ToList();if(features.TryGetValue("waterfalls",out var falls))foreach(var value in falls.AsGodotArray()){var fall=value.AsGodotDictionary();if(fall.TryGetValue("position",out var p))detail.Add(new Rect2(p.AsVector2()-Vector2.One*160,Vector2.One*320));}
            detail.AddRange(ShapeRefinement(builder,data,cancelled));
            stage?.Invoke("collision");var ground=BuildAuthoritativeGround(builder,patch,cancelled);
            using var collision=new TerrainCollision();var collisionData=collision.prepare_irregular(ground,ground.Count>0,structures,features,true);
            long bytes=GD.VarToBytes(structures).LongLength+GD.VarToBytes(features).LongLength+GD.VarToBytes(flow).LongLength+detail.Count*16L+GD.VarToBytes(ground).LongLength+GD.VarToBytes(collisionData).LongLength;return data with{Structures=structures,Features=features,StructureFlow=flow,AuthoritativeGround=ground,Collision=collisionData,AdditionalBytes=bytes,WaterEnabled=builder.settings.Get("water_enabled").AsBool(),BeachesEnabled=builder.settings.Get("beaches_enabled").AsBool(),WaterLevel=builder.water_level,RefinementRegions=detail.ToArray()};
        }
        finally{builder.RingOwns=null;}
    }
    private A BuildAuthoritativeGround(TerrainMeshBuilder builder,TerrainRingLayout.Patch patch,Func<bool>? cancelled)
    {
        var arrays=new A();if(patch.Key.Z>1)return arrays;
        int resolution=checked((int)Math.Ceiling(patch.Size));var grid=topology.Get(resolution,patch.Key.Z>0,patch.Hole);var axis=grid.Axis.Span;int row=axis.Length;var vertices=new Vector3[grid.VertexCount];
        for(int z=0;z<row;z++)
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            for(int x=0;x<row;x++){double lx=patch.Size*axis[x]/grid.Denominator,lz=patch.Size*axis[z]/grid.Denominator;vertices[z*row+x]=new Vector3((float)lx,(float)builder._native_height.normal_height(patch.OriginX+lx,patch.OriginZ+lz),(float)lz);}
        }
        arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices;arrays[(int)Mesh.ArrayType.Index]=grid.Indices.ToArray();return arrays;
    }
    private static IEnumerable<Rect2> ShapeRefinement(TerrainMeshBuilder builder,Data data,Func<bool>? cancelled)
    {
        // Only near/middle terrain can request local geometry. Never refine the horizon for noise.
        if(data.Patch.Key.Z is <1 or >2)return Array.Empty<Rect2>();
        var patch=data.Patch;var regions=new HashSet<Vector2I>();const int cells=6;double step=patch.Size/cells;
        for(int z=0;z<cells;z++)
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            for(int x=0;x<cells;x++)
            {
                double wx=patch.OriginX+(x+.5)*step,wz=patch.OriginZ+(z+.5)*step;if(!patch.Contains(wx,wz))continue;var field=builder._native_height;
                double a=field.normal_height(wx-step*.5,wz-step*.5),b=field.normal_height(wx+step*.5,wz-step*.5),c=field.normal_height(wx-step*.5,wz+step*.5),d=field.normal_height(wx+step*.5,wz+step*.5),center=field.normal_height(wx,wz);
                double error=Math.Abs(center-(a+b+c+d)*.25),rise=Math.Max(Math.Max(a,b),Math.Max(c,d))-Math.Min(Math.Min(a,b),Math.Min(c,d));
                if(error>Math.Max(.75,step*.08)||rise>step*2)regions.Add(new Vector2I((int)Math.Floor(wx/32),(int)Math.Floor(wz/32)));
            }
        }
        return regions.Select(cell=>new Rect2((Vector2)cell*32,Vector2.One*32));
    }
    private Data BuildSurface(TerrainMeshBuilder builder,TerrainRingLayout.Patch patch,int resolution,Func<bool>? cancelled,Action<string>? stage)
    {
        builder.chunk_size=patch.Size;builder.PrepareRing();builder._native_height.select_normal_cache_capacity(patch.Size);
        var filter=filterDistant&&patch.Key.Z>=2?filters.GetValue(builder,key=>new TerrainRingHeightFilter(key._native_height)):null;double footprint=patch.Size/resolution;
        var grid=topology.Get(resolution,patch.Key.Z>0,patch.Hole);var axis=grid.Axis.Span;int row=axis.Length,count=grid.VertexCount;var samples=new Sample[count];var vertices=new Vector3[count];var normals=new Vector3[count];var colors=new Color[count];var uv=new Vector2[count];var surface=new Vector2[count];var geology=new float[count*4];var forest=new float[count*4];var savanna=new float[count*4];var swamp=new float[count*4];bool jungle=false,mountain=false,coast=false,tropical=false,badlands=false;var field=builder._native_height;
        for(int z=0;z<row;z++)
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();for(int x=0;x<row;x++){int i=z*row+x;double lx=patch.Size*axis[x]/grid.Denominator,lz=patch.Size*axis[z]/grid.Denominator;var sample=Capture(builder,patch.OriginX+lx,patch.OriginZ+lz,out double canonicalHeight);if(filter is not null)sample=sample with{Height=(float)filter.Sample(patch.OriginX+lx,patch.OriginZ+lz,footprint,builder.water_level,canonicalHeight)};samples[i]=sample;vertices[i]=new Vector3((float)lx,sample.Height,(float)lz);jungle|=sample.Jungle>=65536;mountain|=sample.Mountain.X>=65536;coast|=sample.Coast.X>1.0/255;tropical|=sample.Tropical.X>1.0/255;badlands|=sample.Badlands.X>0;}
        }
        stage?.Invoke("filtered normals");
        // Height-only probes never request material payloads. Canonical positions are independent of ring level.
        // Match the filtered grid footprint. Off-grid 32 m probes repeated entire
        // nine-tap filters four times per far vertex and sampled unresolved relief.
        double derivative=Math.Max(1,footprint);
        for(int z=0;z<row;z++)
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();for(int x=0;x<row;x++)
            {
                int i=z*row+x;var v=vertices[i];double wx=patch.OriginX+v.X,wz=patch.OriginZ+v.Z;double Height(double px,double pz)=>filter?.Sample(px,pz,footprint,builder.water_level)??field.normal_height(px,pz);double left=Height(wx-derivative,wz),right=Height(wx+derivative,wz),back=Height(wx,wz-derivative),front=Height(wx,wz+derivative),curvature=(left+right+back+front-4*samples[i].Height)/derivative;normals[i]=new Vector3((float)(left-right),(float)(2*derivative),(float)(back-front)).Normalized();var s=samples[i];colors[i]=new Color(s.Weights.X,s.Weights.Y,s.Weights.Z,s.Weights.W);uv[i]=new Vector2(s.Water,(float)curvature);surface[i]=s.Surface;int at=i*4;geology[at]=s.Geology.X;geology[at+1]=s.Geology.Y;geology[at+2]=s.Geology.Z;geology[at+3]=jungle?s.Jungle:0;Store(forest,at,s.Forest);Store(savanna,at,s.Savanna);Store(swamp,at,s.Swamp);
                if(mountain){var m=s.Mountain;geology[at]=(float)(-field.pack(s.Geology.X,s.Geology.Y,s.Geology.Z)-1);geology[at+1]=m.X;geology[at+2]=m.Y;int q=(int)m.Z;surface[i]=new Vector2((float)field.pack(surface[i].X,surface[i].Y,(q&255)/255.0),(float)field.pack(((q>>8)&255)/255.0,((q>>16)&255)/255.0,m.W));}
                if(coast){var c=s.Coast;double forestWater=forest[at+3];forest[at+2]=(float)(-field.pack(forest[at+2],c.X,c.Y)-1);forest[at+3]=(float)field.pack(forest[at+3],c.Z,c.W);if(c.W<0){int sand=(int)(-c.W-1);forest[at+3]=(float)(-field.pack(forestWater,(sand&255)/255.0,((sand>>8)&255)/255.0)-1);}}
                if(tropical){var t=s.Tropical;forest[at]=(float)(-(((int)forest[at]&65535)+Round(t.Z*255.0)*65536.0)-1);savanna[at]=(float)(-(((int)savanna[at]&65535)+Round(t.X*255.0)*65536.0)-1);swamp[at]=(float)(-(((int)swamp[at]&65535)+Round(t.Y*255.0)*65536.0)-1);}
                if(badlands){int curvatureByte=Round(Math.Clamp(curvature,-.5,.5)*254)+127;uv[i]=new Vector2(uv[i].X,(float)(Round(s.Badlands.X*255.0)+Round(s.Badlands.Z*255.0)*256+curvatureByte*65536));geology[at+3]=-(jungle?s.Jungle:0)-1;}
            }
        }
        // GPU atlases remain uniformly sampled even where geometry has inserted third-boundary knots.
        int atlasRow=resolution+1,mask=0;bool extras=builder._extras_enabled,any=false;var extension=extras?new byte[atlasRow*atlasRow*8*4]:Array.Empty<byte>();var palette=badlands?new byte[atlasRow*atlasRow*4]:Array.Empty<byte>();var mapping=new int[atlasRow];for(int i=0;i<atlasRow;i++)mapping[i]=axis.BinarySearch(i*3);
        for(int z=0;z<atlasRow;z++)for(int x=0;x<atlasRow;x++)
        {
            var s=samples[mapping[z]*row+mapping[x]];if(extras)for(int family=0;family<8;family++){var e=s.Extra(family);int offset=(z*atlasRow*8+family*atlasRow+x)*4;extension[offset]=Byte(e.X);if(extension[offset]>0)mask|=1<<family;extension[offset+1]=Byte((double)e.Z*e.X);extension[offset+2]=Byte((double)e.Y*e.X);extension[offset+3]=Byte((double)e.W*e.X);any|=e.X>.5/255;}
            if(badlands){var p=s.Badlands.X>0?s.Palette:builder._badlands!.material_palette(new Vector2((float)(patch.OriginX+patch.Size*x/resolution),(float)(patch.OriginZ+patch.Size*z/resolution)));for(int channel=0;channel<4;channel++)palette[(z*atlasRow+x)*4+channel]=Byte(p[channel]);}
        }
        int rows=atlasRow,slot=-1;if(!any){extension=Array.Empty<byte>();rows=0;mask=0;}if(badlands){if(extension.Length==0){extension=palette;rows=atlasRow;slot=0;}else{var combined=new byte[atlasRow*atlasRow*9*4];for(int z=0;z<atlasRow;z++){Array.Copy(extension,z*atlasRow*8*4,combined,z*atlasRow*9*4,atlasRow*8*4);Array.Copy(palette,z*atlasRow*4,combined,(z*atlasRow*9+atlasRow*8)*4,atlasRow*4);}extension=combined;slot=8;}}
        byte[] flow=Array.Empty<byte>();int flowRows=0;if((mask&128)!=0&&builder.settings.Get("alien_infected").AsGodotObject().Get("nerve_flow_texturing").AsBool()){using var tissue=new AlienTissueCoordinates();var payload=tissue.atlas(builder._extras[7].AsGodotObject(),new Vector2((float)patch.OriginX,(float)patch.OriginZ),patch.Size,resolution);flow=payload["data"].AsByteArray();flowRows=payload["rows"].AsInt32();}
        var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices;arrays[(int)Mesh.ArrayType.Normal]=normals;arrays[(int)Mesh.ArrayType.Color]=colors;arrays[(int)Mesh.ArrayType.TexUV]=uv;arrays[(int)Mesh.ArrayType.TexUV2]=surface;arrays[(int)Mesh.ArrayType.Custom0]=geology;arrays[(int)Mesh.ArrayType.Custom1]=forest;arrays[(int)Mesh.ArrayType.Custom2]=savanna;arrays[(int)Mesh.ArrayType.Custom3]=swamp;arrays[(int)Mesh.ArrayType.Index]=grid.Indices.ToArray();return new Data(patch,grid,arrays,extension,rows,mask,slot,flow,flowRows){HasMountain=mountain};
    }
    private static void Store(float[] target,int at,Vector4 value){target[at]=value.X;target[at+1]=value.Y;target[at+2]=value.Z;target[at+3]=value.W;}
}
