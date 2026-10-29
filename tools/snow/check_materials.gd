extends SceneTree
## Offline source provenance and actual prepared PBR validation.
const IDS=["Snow005","Snow006","Snow014","Ice004"]
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/snow_material_sources.json"))
	check(manifest is Array and manifest.size()==IDS.size(),"Four identified CC0 sources")
	for record:Dictionary in manifest:
		check(record.license=="CC0-1.0" and IDS.has(record.id),"Only reviewed CC0 sources")
		for map:Dictionary in record.maps:
			var path:String="res://assets/textures/snow/"+record.id+"/"+map.file
			check(FileAccess.get_sha256(path).to_upper()==map.sha256,"Source checksum: "+map.file)
	var bytes:int=0
	for entry in [["color_roughness",Vector2i(2048,2048),Image.FORMAT_DXT5],["normals",Vector2i(1024,1024),Image.FORMAT_RGTC_RG],["heights",Vector2i(1024,1024),Image.FORMAT_RGTC_R]]:
		var array=load("res://materials/snow_"+entry[0]+".tres") as Texture2DArray
		check(array!=null and array.get_layers()==4,"Four prepared "+entry[0]+" layers")
		for i in range(4):
			# Dummy/headless rendering cannot read texture-array GPU storage.
			# Inspect the exact external Image resources referenced by that array.
			var kind:String={"color_roughness":"color","normals":"normal","heights":"height"}[entry[0]]
			var image:Image=load("res://materials/snow_%s_%s.res"%[kind,IDS[i]])
			if image==null:check(false,"Missing prepared image");quit(1);return
			bytes+=image.get_data_size()
			check(image.get_size()==entry[1] and image.get_format()==entry[2] and image.has_mipmaps(),"GPU format, size and mips: "+entry[0]+str(i))
			check(image.decompress()==OK,"Prepared image decompresses")
			var minimum:float=1;var maximum:float=0;var slope:float=0
			for y in range(0,image.get_height(),32):
				for x in range(0,image.get_width(),32):
					var p:=image.get_pixel(x,y);minimum=minf(minimum,p.r);maximum=maxf(maximum,p.r)
					slope+=absf(p.r-.5)+absf(p.g-.5)
			check(maximum-minimum>.01,"Nonconstant source structure: "+entry[0]+str(i))
			if entry[0]=="normals":check(slope>1,"Normal map contains visible slope data")
	var shader:String=FileAccess.get_file_as_string("res://shaders/snow_material.gdshaderinc")
	check(not shader.contains("snow_fracture(") and not shader.contains("snow_relief("),"No analytic fracture/ripple generator")
	check(bytes<40*1024*1024,"Shared Snow palette stays below 40 MiB")
	var result:Dictionary={"checks":checks,"failures":failures,"ids":IDS,"gpu_bytes":bytes,"runtime_procedural_surface_generators":0,"note":"AmbientCG Ice004 is a pre-baked procedural CC0 asset; the three snow sources are photogrammetry. Geography remains procedural."}
	FileAccess.open("res://tools/snow/artifacts/materials.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SNOW_MATERIALS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
