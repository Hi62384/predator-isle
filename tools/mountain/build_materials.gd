extends SceneTree
## Offline PBR packing only; no runtime download, texture synthesis or baking.
func _initialize()->void:
	var roles:Array=[["Rock051","massive_rock","mountain","natural"],["Ground108","coarse_talus","mountain","natural"],["Gravel040","angular_scree","mountain","natural"]]
	var colors:Array[String]=[];var normals:Array[String]=[];var records:Array=[]
	for item:Array in roles:
		var id:String=item[0];var role:String=item[1];var prefix:String="res://assets/textures/%s/%s/%s_2K-JPG_"%[item[2],id,id]
		var c:=Image.load_from_file(prefix+"Color.jpg");var r:=Image.load_from_file(prefix+"Roughness.jpg");var n:=Image.load_from_file(prefix+"NormalGL.jpg")
		assert(c!=null and r!=null and n!=null);c.convert(Image.FORMAT_RGBA8)
		# Normalize source dimensions for the shared array without synthesizing detail.
		c.resize(2048,2048,Image.INTERPOLATE_LANCZOS);r.resize(2048,2048,Image.INTERPOLATE_LANCZOS)
		for y in range(c.get_height()):
			for x in range(c.get_width()):
				var p:Color=c.get_pixel(x,y)
				p.a=r.get_pixel(x,y).r;c.set_pixel(x,y,p)
		c.generate_mipmaps();assert(c.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		n.resize(1024,1024,Image.INTERPOLATE_LANCZOS);n.convert(Image.FORMAT_RG8);n.generate_mipmaps();assert(n.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		var cp:String="res://materials/mountain_color_"+role+".res";var np:String="res://materials/mountain_normal_"+id+".res"
		assert(ResourceSaver.save(c,cp)==OK and ResourceSaver.save(n,np)==OK);colors.append(cp);normals.append(np)
		var maps:Array=[]
		for kind in ["Color","NormalGL","Roughness"]:
			var source:String=prefix+kind+".jpg";maps.append({"path":source,"sha256":FileAccess.get_sha256(source)})
		records.append({"id":id,"role":role,"source":"https://ambientcg.com/a/"+id,"license":"CC0-1.0","creation_method":"PBRPhotogrammetry" if id=="Grass003" else ("PBRApproximated" if id=="Ground031" else "PBRPhotogrammetry"),"maps":maps,"color_resource":cp,"normal_resource":np,"gpu_bytes":c.get_data_size()+n.get_data_size(),"treatment":item[3],"note":"Photographed mountain rock, rocky river debris and slate-like gravel; appearance roles, not certified geological mineral classifications. Other Mountain roles reuse existing PBR arrays."})
	write_array("res://materials/mountain_colors.tres",colors);write_array("res://materials/mountain_normals.tres",normals)
	FileAccess.open("res://data/mountain_material_sources.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"));print("MOUNTAIN_PBR_PACKED three photographed layers plus existing bedrock/alpine/soil arrays");quit()
func write_array(path:String,images:Array[String])->void:
	var result:String="[gd_resource type=\"Texture2DArray\" load_steps=%d format=3]\n\n"%(images.size()+1);var refs:Array[String]=[]
	for i in range(images.size()):
		result+="[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n"%[images[i],i+1];refs.append("ExtResource(\"%d\")"%(i+1))
	result+="\n[resource]\n_images = Array[Image](["+", ".join(refs)+"])\n";FileAccess.open(path,FileAccess.WRITE).store_string(result)
