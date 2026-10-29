extends SceneTree
const IDS=["Ground023","Ground048","Ground031","Gravel020","Rock030","Rock064","Ground037"]
const ROLES=["leaf_litter","organic_soil","mud_silt","river_gravel","exposed_rock","mossy_rock","moss_ground"]
func _initialize()->void:
	var colors:Array[String]=[];var normals:Array[String]=[];var records:Array=[]
	for i in range(IDS.size()):
		var id:String=IDS[i]
		var folder:String="jungle" if id in ["Ground023","Rock064"] else ("desert" if id=="Ground031" else "ambientcg")
		var prefix:String="res://assets/textures/%s/%s/%s_2K-JPG_"%[folder,id,id]
		var color:=Image.load_from_file(prefix+"Color.jpg");var rough:=Image.load_from_file(prefix+"Roughness.jpg");var normal:=Image.load_from_file(prefix+"NormalGL.jpg")
		assert(color!=null and rough!=null and normal!=null)
		color.convert(Image.FORMAT_RGBA8)
		for y in range(color.get_height()):
			for x in range(color.get_width()):
				var p:=color.get_pixel(x,y);p.a=rough.get_pixel(x,y).r;color.set_pixel(x,y,p)
		color.generate_mipmaps();assert(color.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		normal.resize(1024,1024,Image.INTERPOLATE_LANCZOS);normal.convert(Image.FORMAT_RG8);normal.generate_mipmaps()
		assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		var cp:String="res://materials/jungle_color_"+id+".res";var np:String="res://materials/jungle_normal_"+id+".res"
		assert(ResourceSaver.save(color,cp)==OK and ResourceSaver.save(normal,np)==OK);colors.append(cp);normals.append(np)
		var maps:Array=[]
		for kind in ["Color","NormalGL","Roughness"]:
			var source:String=prefix+kind+".jpg";maps.append({"path":source,"sha256":FileAccess.get_sha256(source)})
		records.append({"id":id,"role":ROLES[i],"source":"https://ambientcg.com/a/"+id,"license":"CC0-1.0","license_url":"https://docs.ambientcg.com/license/","maps":maps,"gpu_bytes":color.get_data_size()+normal.get_data_size(),"normal_convention":"OpenGL positive Y XY BC5","roughness":"linear alpha; albedo sRGB"})
	write_array("res://materials/jungle_colors.tres",colors);write_array("res://materials/jungle_normals.tres",normals)
	FileAccess.open("res://data/jungle_material_sources.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("JUNGLE_PBR_PACKED seven shared CC0 sources, no runtime conversion");quit()
func write_array(path:String,images:Array[String])->void:
	var text:String="[gd_resource type=\"Texture2DArray\" load_steps=%d format=3]\n\n"%(images.size()+1);var refs:Array[String]=[]
	for i in range(images.size()):
		text+="[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n"%[images[i],i+1];refs.append("ExtResource(\"%d\")"%(i+1))
	text+="\n[resource]\n_images = Array[Image](["+", ".join(refs)+"])\n";FileAccess.open(path,FileAccess.WRITE).store_string(text)
