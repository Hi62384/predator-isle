extends SceneTree
## Offline, one source per process. Albedo RGB remains sRGB; roughness alpha linear.
const IDS=["Ground092A","Ground054","Gravel020","Rock061","Ground031","Ground033"]
static func srgb_mips(source:Image)->Image:
 # Preserve original 2K bytes. Filter only lower mips in linear half-float light.
 var bytes:PackedByteArray=source.get_data()
 var linear:Image=source.duplicate();linear.convert(Image.FORMAT_RGBAH)
 for y in range(linear.get_height()):
  for x in range(linear.get_width()):linear.set_pixel(x,y,linear.get_pixel(x,y).srgb_to_linear())
 var w:int=source.get_width();var h:int=source.get_height()
 while w>1 or h>1:
  w=maxi(w/2,1);h=maxi(h/2,1)
  linear.resize(w,h,Image.INTERPOLATE_BILINEAR)
  var encoded:=Image.create_empty(w,h,false,Image.FORMAT_RGBA8)
  for y in range(h):
   for x in range(w):encoded.set_pixel(x,y,linear.get_pixel(x,y).linear_to_srgb())
  bytes.append_array(encoded.get_data())
 return Image.create_from_data(source.get_width(),source.get_height(),true,Image.FORMAT_RGBA8,bytes)
func check_encoding()->void:
 var test:=Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
 test.fill(Color(0,0,0,0.25));test.set_pixel(0,0,Color(1,1,1,0.25));test.set_pixel(1,1,Color(1,1,1,0.25))
 var mip:Image=srgb_mips(test);var data:PackedByteArray=mip.get_data();var offset:int=mip.get_mipmap_offset(1)
 assert(absf(data[offset]/255.0-0.735357)<0.008,"sRGB mip must average in linear light")
 assert(absf(data[offset+3]/255.0-0.25)<0.008,"Roughness alpha must remain linear")
func preview(image:Image,path:String)->void:
 var p:Image=image.duplicate();p.resize(512,512,Image.INTERPOLATE_LANCZOS);assert(p.save_png(path)==OK)
func _initialize()->void:
 check_encoding()
 var args:PackedStringArray=OS.get_cmdline_user_args();assert(args.size()==2)
 var project:String=args[0];var id:String=args[1];assert(id in IDS)
 var start:int=Time.get_ticks_msec();var prefix:String=project.path_join("assets/textures/desert").path_join(id).path_join(id+"_2K-JPG_")
 var out:String="res://output/"+id;assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))==OK)
 var color:Image=Image.load_from_file(prefix+"Color.jpg");assert(color!=null and color.get_size()==Vector2i(2048,2048),"Expected original 2K albedo")
 preview(color,out+"/color_source.png");color.convert(Image.FORMAT_RGBA8)
 var rough:Image=Image.load_from_file(prefix+"Roughness.jpg");assert(rough!=null and rough.get_size()==color.get_size())
 preview(rough,out+"/roughness_source.png")
 for y in range(2048):
  for x in range(2048):
   var pixel:Color=color.get_pixel(x,y);pixel.a=rough.get_pixel(x,y).r;color.set_pixel(x,y,pixel)
 rough=null
 color=srgb_mips(color);assert(color.get_mipmap_count()==11)
 assert(color.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK);assert(color.get_format()==Image.FORMAT_DXT5)
 var cb:int=color.get_data_size();assert(ResourceSaver.save(color,out+"/color.res")==OK);color=null
 var normal:Image=Image.load_from_file(prefix+"NormalGL.jpg");assert(normal!=null and normal.get_size()==Vector2i(2048,2048))
 preview(normal,out+"/normal_source.png");normal.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
 # Normalize resized RGB vectors before generating normalized mips and retaining XY.
 for y in range(1024):
  for x in range(1024):
   var c:Color=normal.get_pixel(x,y);var n:=Vector3(c.r*2.0-1.0,c.g*2.0-1.0,c.b*2.0-1.0).normalized()
   normal.set_pixel(x,y,Color(n.x*0.5+0.5,n.y*0.5+0.5,n.z*0.5+0.5))
 assert(normal.generate_mipmaps(true)==OK);normal.convert(Image.FORMAT_RG8);assert(normal.get_mipmap_count()==10)
 assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK);assert(normal.get_format()==Image.FORMAT_RGTC_RG)
 var nb:int=normal.get_data_size();assert(ResourceSaver.save(normal,out+"/normal.res")==OK);normal=null
 var result={"id":id,"engine":Engine.get_version_info().string,"color_bytes":cb,"normal_bytes":nb,"source_size":"2048x2048","color_size":"2048x2048","normal_size":"1024x1024","color_encoding":"sRGB RGB with linear-light filtered mips; alpha linear roughness","normal_encoding":"OpenGL positive-Y normals, resized and mip-renormalized; BC5 XY; no DirectX flip","mipmaps":true,"elapsed_s":(Time.get_ticks_msec()-start)/1000.0}
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(result);quit()
