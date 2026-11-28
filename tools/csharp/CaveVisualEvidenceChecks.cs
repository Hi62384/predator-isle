using Godot;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Actual generated, undecorated mesh evidence (not preset concept art).
/// Render local high-resolution caves from inside and outside, and chart the
/// corresponding complete, cross-region solved route networks.</summary>
internal static class CaveVisualEvidenceChecks
{
    internal static async Task<D> Run(Node owner,Action<bool,string> require)
    {
        const int width=400,height=280;
        using var sheet=Image.CreateEmpty(width*4,height*3,false,Image.Format.Rgba8);
        sheet.Fill(Colors.Black);
        var report=new A();
        var surface=Callable.From<double,double,double>((x,z)=>100+8*Math.Sin(x*.001)+5*Math.Sin(z*.002));
        var water=Callable.From<double,double,double>((x,z)=>-1000);
        var material=new StandardMaterial3D{AlbedoColor=new Color(.62f,.60f,.56f),Roughness=1,
            CullMode=BaseMaterial3D.CullModeEnum.Disabled};
        var viewport=new SubViewport{Size=new Vector2I(width,height),OwnWorld3D=true,
            RenderTargetUpdateMode=SubViewport.UpdateMode.Always};
        owner.AddChild(viewport);
        var stage=new Node3D();viewport.AddChild(stage);
        var env=new WorldEnvironment{Environment=new Godot.Environment{
            BackgroundMode=Godot.Environment.BGMode.Color,BackgroundColor=new Color(.10f,.12f,.15f),
            AmbientLightSource=Godot.Environment.AmbientSource.Color,AmbientLightColor=new Color(.7f,.7f,.7f),
            AmbientLightEnergy=.28f}};
        stage.AddChild(env);
        var camera=new Camera3D{Current=true,Near=.08f,Far=500,Fov=78};
        stage.AddChild(camera);
        var lamp=new OmniLight3D{OmniRange=150,LightEnergy=3.5f,OmniAttenuation=.65f};
        camera.AddChild(lamp);
        var fill=new DirectionalLight3D{RotationDegrees=new Vector3(-45,-38,0),LightEnergy=.55f};stage.AddChild(fill);
        try
        {
            long[] seeds={17,73921,2063,118};
            for(int index=0;index<seeds.Length;index++)
            {
                long seed=seeds[index];
                using var network=new CaveNetwork{activity=1,EntrancesPerRegion=4,OceanLevel=0,geological_morphology=true,chamber_variety=true};
                network.configure(surface,water,seed,1200);
                var region=network.region(Vector2I.Zero);var neighbor=network.region(Vector2I.Right);
                require(region["valid"].AsBool()&&neighbor["valid"].AsBool(),"Visual evidence fixture has no regional network");
                var links=network.connections(Vector2I.Zero,Vector2I.Right);
                using var field=new CaveField{maximum_depth=1200,minimum_roof=10};
                require(field.compile(new A{region},surface),"Visual evidence field rejected");
                var nodes=region["nodes"].AsGodotArray().Select(x=>x.AsGodotDictionary()).Where(x=>x["level"].AsInt32()>=0).ToArray();
                var room=nodes.OrderByDescending(x=>x["chamber_radius"].AsDouble()*x["chamber_height"].AsDouble()).First();
                var point=room["point"].AsVector3();
                var edge=region["edges"].AsGodotArray().Select(x=>x.AsGodotDictionary()).First(x=>x["from"].AsString()==room["id"].AsString()||x["to"].AsString()==room["id"].AsString());
                var route=edge["points"].AsVector3Array();
                bool reverse=route[^1].DistanceSquaredTo(point)<route[0].DistanceSquaredTo(point);
                if(reverse)Array.Reverse(route);
                var tube=route[Math.Clamp(route.Length/4,1,route.Length-2)];
                var cells=new HashSet<Vector3I>();
                foreach(var focus in new[]{point,tube})
                {
                    var key=field.cell(focus+Vector3.Up*5);
                    for(int z=-1;z<=1;z++)for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++)
                    {
                        var cell=key+new Vector3I(x,y,z);
                        if(field.has_chunk(cell))cells.Add(cell);
                    }
                }
                var geometry=new Node3D();stage.AddChild(geometry);
                int triangles=0;
                using var mesher=new CaveMesher();
                foreach(var cell in cells.OrderBy(k=>k.X).ThenBy(k=>k.Y).ThenBy(k=>k.Z))
                {
                    var arrays=mesher.build(field,cell,2);
                    if(arrays.Count==0)continue;
                    var vertices=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
                    if(vertices.Length<3)continue;
                    require(vertices.All(p=>p.IsFinite()),"Non-finite visual mesh vertices");
                    var mesh=new ArrayMesh();mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles,arrays);
                    geometry.AddChild(new MeshInstance3D{Mesh=mesh,MaterialOverride=material,
                        Position=(Vector3)cell*64-point,CastShadow=GeometryInstance3D.ShadowCastingSetting.Off});
                    triangles+=vertices.Length/3;
                }
                require(triangles>100,"Visual evidence lacks actual mesh");
                var aim=(route[Math.Min(5,route.Length-1)]-point);aim.Y=0;
                if(aim.LengthSquared()<.01f)aim=Vector3.Forward;
                var interior=point+Vector3.Up*2.5f;
                require(field.sample(interior)<0,"Cavern camera is not in excavated air");
                await Capture(interior-point,interior-point+aim.Normalized()*20,index,0);
                int station=Math.Clamp(route.Length/4,1,route.Length-2);
                var view=tube+Vector3.Up*2;
                var next=route[Math.Min(station+4,route.Length-1)]+Vector3.Up*2;
                require(field.sample(view)<0,"Tunnel camera is not in excavated air");
                await Capture(view-point,next-point,index,1);
                // Exterior view uses exactly the same mesh from an oblique
                // position outside the rock volume, with no surface terrain.
                await Capture(new Vector3(155,118,145),Vector3.Zero,index,2);
                geometry.Free();
                string graphPath=$"res://data/cave_visual_network_{index}.svg";
                using(var file=Godot.FileAccess.Open(graphPath,Godot.FileAccess.ModeFlags.Write))
                {
                    require(file!=null,"Cannot save actual network plot");
                    file!.StoreString(Graph(region,neighbor,links,seed));
                }
                report.Add(new D{["seed"]=seed,["triangles"]=triangles,["cells"]=cells.Count,["regional_links"]=links.Count,
                    ["room_radius"]=room["chamber_radius"],["room_height"]=room["chamber_height"],["room_floor"]=point.Y,
                    ["graph"]=graphPath});
            }
            require(sheet.SavePng("res://data/cave_visual_contact_sheet.png")==Error.Ok,"Cannot save generated geometry contact sheet");
            return new D{["contact_sheet"]="res://data/cave_visual_contact_sheet.png",["views"]=12,["generated_regions"]=report};
        }
        finally{viewport.Free();material.Dispose();}

        async Task Capture(Vector3 eye,Vector3 target,int column,int row)
        {
            camera.Position=eye;
            camera.LookAt(target,Vector3.Up);
            fill.Visible=row==2;
            await owner.ToSignal(owner.GetTree(),SceneTree.SignalName.ProcessFrame);
            await owner.ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            using var image=viewport.GetTexture().GetImage();
            require(!image.IsEmpty()&&image.GetWidth()==width&&image.GetHeight()==height,"Generated mesh capture missing");
            image.Convert(Image.Format.Rgba8);
            var center=image.GetPixel(width/2,height/2);
            bool varied=false;
            for(int y=20;y<height&&!varied;y+=20)for(int x=20;x<width;x+=20)
                if(Math.Abs(image.GetPixel(x,y).R-center.R)+Math.Abs(image.GetPixel(x,y).G-center.G)+Math.Abs(image.GetPixel(x,y).B-center.B)>.025f){varied=true;break;}
            require(varied,"Rendered cave capture is uniform");
            sheet.BlitRect(image,new Rect2I(0,0,width,height),new Vector2I(column*width,row*height));
        }
    }
    private static string Graph(D a,D b,A links,long seed)
    {
        var s=new StringBuilder();
        s.Append("<svg xmlns='http://www.w3.org/2000/svg' width='1000' height='780' viewBox='0 0 1000 780'><rect width='1000' height='780' fill='#111820'/><g fill='#dfe6ee' font-family='sans-serif' font-size='18'>");
        s.Append($"<text x='24' y='30'>Seed {seed} — actual two-region routes</text><text x='24' y='412'>Side profile — world elevation</text></g>");
        string F(double x)=>x.ToString("0.00",CultureInfo.InvariantCulture);
        var edges=new A();edges.AddRange(a["edges"].AsGodotArray());edges.AddRange(b["edges"].AsGodotArray());edges.AddRange(links);
        foreach(var raw in edges)
        {
            var edge=raw.AsGodotDictionary();var points=edge["points"].AsVector3Array();
            string color=edge["entrance"].AsBool()?"#f4be63":links.Contains(raw)?"#79e7aa":"#7baecf";
            foreach(bool side in new[]{false,true})
            {
                s.Append($"<polyline fill='none' stroke='{color}' stroke-width='1.5' opacity='.8' points='");
                foreach(var p in points)
                    s.Append($"{F(24+p.X/3072*952)},{F(side?440+(150-p.Y)/1200*310:56+p.Z/1536*310)} ");
                s.Append("'/>");
            }
        }
        foreach(var raw in new[]{a,b})
        {
            if(!raw.TryGetValue("vertical_links",out var vertical))continue;
            foreach(var item in vertical.AsGodotArray())
            {
                var shaft=item.AsGodotDictionary();var low=shaft["bottom"].AsVector3();var high=shaft["top"].AsVector3();
                s.Append($"<line x1='{F(24+low.X/3072*952)}' x2='{F(24+high.X/3072*952)}' y1='{F(440+(150-low.Y)/1200*310)}' y2='{F(440+(150-high.Y)/1200*310)}' stroke='#eb8dca' stroke-width='2'/>");
            }
        }
        s.Append("</svg>");return s.ToString();
    }
}
