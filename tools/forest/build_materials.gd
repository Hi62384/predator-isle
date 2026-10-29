extends SceneTree
## Only two new packed scans; six roles reference already-shared Jungle images.
func _initialize()->void:
	var ids:Array[String]=["Ground077","Ground070"]
	var colors:Array[String]=[];var normals:Array[String]=[];var records:Array=[]
	for i in range(2):
		var id:String=ids[i];var prefix:String="res://assets/textures/forest/%s/%s_2K-JPG_"%[id,id]
		var c:=Image.load_from_file(prefix+"Color.jpg");var r:=Image.load_from_file(prefix+"Roughness.jpg");var n:=Image.load_from_file(prefix+"NormalGL.jpg")
		assert(c!=null and r!=null and n!=null);c.convert(Image.FORMAT_RGBA8)
		for y in range(c.get_height()):
			for x in range(c.get_width()):
				var p:Color=c.get_pixel(x,y);p.a=r.get_pixel(x,y).r;c.set_pixel(x,y,p)
		c.generate_mipmaps();assert(c.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		n.resize(1024,1024,Image.INTERPOLATE_LANCZOS);n.convert(Image.FORMAT_RG8);n.generate_mipmaps();assert(n.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		var cp:String="res://materials/forest_color_"+id+".res";var np:String="res://materials/forest_normal_"+id+".res"
		assert(ResourceSaver.save(c,cp)==OK and ResourceSaver.save(n,np)==OK);colors.append(cp);normals.append(np)
		var maps:Array=[]
		for kind in ["Color","NormalGL","Roughness"]:
			var source:String=prefix+kind+".jpg";maps.append({"path":source,"sha256":FileAccess.get_sha256(source)})
		records.append({"id":id,"role":"deciduous_litter" if i==0 else "needle_root_mixed_woodland_litter","source":"https://ambientcg.com/a/"+id,"license":"CC0-1.0","maps":maps,"color_resource":cp,"normal_resource":np,"gpu_bytes":c.get_data_size()+n.get_data_size(),"note":"Real mixed woodland litter scan, not a pure needle-only botanical sample."})
	var existing=JSON.parse_string(FileAccess.get_file_as_string("res://data/jungle_material_sources.json"))
	# Shared broadleaf litter is the dominant deciduous surface; Ground077 adds
	# decomposed warm humus. No second GPU array copy of Ground023 is needed.
	records[0]["shared_leaf_source"]="https://ambientcg.com/a/Ground023"
	records[0]["shared_leaf_maps"]=existing[0].maps
	for pair in [[1,"organic_soil"],[6,"moss_ground"],[2,"mud_silt"],[3,"gravel"],[4,"bare_rock"],[5,"mossy_rock"]]:
		var item:Dictionary=existing[pair[0]].duplicate(true);item.role=pair[1]
		var cp:String="res://materials/jungle_color_"+str(item.id)+".res";var np:String="res://materials/jungle_normal_"+str(item.id)+".res"
		colors.append(cp);normals.append(np);item["color_resource"]=cp;item["normal_resource"]=np;item["shared_with_jungle"]=true;records.append(item)
	write_array("res://materials/forest_colors.tres",colors.slice(0,2));write_array("res://materials/forest_normals.tres",normals.slice(0,2))
	FileAccess.open("res://data/forest_material_sources.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"));print("FOREST_PBR_PACKED eight roles, two new scans, six shared; no runtime conversion");quit()
func write_array(path:String,images:Array[String])->void:
	var result:String="[gd_resource type=\"Texture2DArray\" load_steps=%d format=3]\n\n"%(images.size()+1);var refs:Array[String]=[]
	for i in range(images.size()):
		result+="[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n"%[images[i],i+1];refs.append("ExtResource(\"%d\")"%(i+1))
	result+="\n[resource]\n_images = Array[Image](["+", ".join(refs)+"])\n";FileAccess.open(path,FileAccess.WRITE).store_string(result)
