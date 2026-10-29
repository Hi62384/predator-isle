extends SceneTree
## Offline PBR packing only; no runtime download, texture synthesis or baking.
func _initialize()->void:
	var roles:Array=[
	 ["Grass003","dry_grass","savanna","dry"],["Ground030","sparse_grassy_soil","savanna","natural"],
	 ["Grass003","green_grass","savanna","natural"],["Ground105","warm_red_weathered_soil","savanna","red"],
	 ["Ground026","clay_hardpan","savanna","natural"],["Rock042L","weathered_kopje_bedrock","savanna","natural"],
	 ["Rock055","warm_layered_bedrock","savanna","natural"],["Ground031","cracked_basin_soil","desert","natural"]]
	var colors:Array[String]=[];var normals:Array[String]=[];var records:Array=[]
	for item:Array in roles:
		var id:String=item[0];var role:String=item[1];var prefix:String="res://assets/textures/%s/%s/%s_2K-JPG_"%[item[2],id,id]
		var c:=Image.load_from_file(prefix+"Color.jpg");var r:=Image.load_from_file(prefix+"Roughness.jpg");var n:=Image.load_from_file(prefix+"NormalGL.jpg")
		assert(c!=null and r!=null and n!=null);c.convert(Image.FORMAT_RGBA8)
		# Normalize the rectangular cliff source to the shared array dimensions.
		c.resize(2048,2048,Image.INTERPOLATE_LANCZOS);r.resize(2048,2048,Image.INTERPOLATE_LANCZOS)
		for y in range(c.get_height()):
			for x in range(c.get_width()):
				var p:Color=c.get_pixel(x,y)
				if item[3]=="dry":
					var l:float=p.r*.3+p.g*.5+p.b*.2;p=Color(l*1.7,l*1.22,l*.6,1)
				if item[3]=="red":p=Color(p.r*.94,p.g*.58,p.b*.56,1)
				p.a=.7+r.get_pixel(x,y).r*.28 if item[3]=="dry" else r.get_pixel(x,y).r;c.set_pixel(x,y,p)
		c.generate_mipmaps();assert(c.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		n.resize(1024,1024,Image.INTERPOLATE_LANCZOS);n.convert(Image.FORMAT_RG8);n.generate_mipmaps();assert(n.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		var cp:String="res://materials/savanna_color_"+role+".res";var np:String="res://materials/savanna_normal_"+id+".res"
		assert(ResourceSaver.save(c,cp)==OK and ResourceSaver.save(n,np)==OK);colors.append(cp);normals.append(np)
		var maps:Array=[]
		for kind in ["Color","NormalGL","Roughness"]:
			var source:String=prefix+kind+".jpg";maps.append({"path":source,"sha256":FileAccess.get_sha256(source)})
		records.append({"id":id,"role":role,"source":"https://ambientcg.com/a/"+id,"license":"CC0-1.0","creation_method":"PBRProcedural" if id=="Grass003" else ("PBRApproximated" if id=="Ground031" else "PBRPhotogrammetry"),"maps":maps,"color_resource":cp,"normal_resource":np,"gpu_bytes":c.get_data_size()+n.get_data_size(),"treatment":item[3],"note":"Dry grass is a color-graded Grass003 PBR variant; red soil is a graded dry-earth scan, not a certified laterite sample. Rock042L provides photographed weathered bedrock appearance, not verified mineral classification. Rectangular sources are resampled to square array dimensions."})
	write_array("res://materials/savanna_colors.tres",colors);write_array("res://materials/savanna_normals.tres",normals)
	FileAccess.open("res://data/savanna_material_sources.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"));print("SAVANNA_PBR_PACKED eight layers, seven unique CC0 sources, shared base palette for gravel/organic/sediment");quit()
func write_array(path:String,images:Array[String])->void:
	var result:String="[gd_resource type=\"Texture2DArray\" load_steps=%d format=3]\n\n"%(images.size()+1);var refs:Array[String]=[]
	for i in range(images.size()):
		result+="[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n"%[images[i],i+1];refs.append("ExtResource(\"%d\")"%(i+1))
	result+="\n[resource]\n_images = Array[Image](["+", ".join(refs)+"])\n";FileAccess.open(path,FileAccess.WRITE).store_string(result)
