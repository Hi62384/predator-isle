extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var preview_path:String="res://tools/biome_extensions/artifacts/previews.json";var preview=JSON.parse_string(FileAccess.get_file_as_string(preview_path));var guards:Dictionary={preview_path:FileAccess.get_sha256(preview_path)}
	for path:String in ["res://scripts/biome_extension_sampler.gd","res://scripts/crystal_wastes_sampler.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/admit_crystal_bulk_styles.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(5,73921);var field=b._extras[5];var cases:Array=[]
	for kind:int in range(6):
		var original:Dictionary=preview.families.crystal_wastes.regions[str(kind)];var from:=Vector2(original.x,original.z);var cell:=Vector2i(floori(from.x/1700),floori(from.y/1700));var best:Dictionary={};var nearest:float=INF;var rejections:Dictionary={"wrong_region":0,"not_admitted":0,"wet_or_ocean":0}
		for z in range(-16,17):
			for x in range(-16,17):
				var d:Dictionary=field.descriptor(cell+Vector2i(x,z),1700);var p:Vector2=d.position
				if roundi(field.region(p))!=kind:rejections.wrong_region+=1;continue
				if d.chance>field.settings.structure_density:rejections.not_admitted+=1;continue
				var h:float=b._get_height(p.x,p.y)
				if b._island_mask(p.x,p.y)<.2 or h<=maxf(b.water_level,b.get_water_surface_height(p.x,p.y))+4:rejections.wet_or_ocean+=1;continue
				var distance:float=p.distance_to(from)
				if distance<nearest:nearest=distance;best={"kind":kind,"id":d.id,"position":[p.x,p.y],"height":h,"chance":d.chance,"regional_name":original.regional_name,"original_geographic_fixture":[from.x,from.y],"distance_from_original_m":distance,"primary_height_m":field.settings.crystal_height*(.4+d.age*1.4),"root_cell":str(cell+Vector2i(x,z))}
		check(not best.is_empty(),"Actual intended mineral root admitted BEFORE rendering")
		if not best.is_empty():best["rejections"]=rejections;cases.append(best)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable style admission source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/admit_crystal_bulk_styles.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"scope":"Six ADDITIONAL positive native-style fixtures,not replacements for the original geographic views or any failure. Nearest actual admitted dry inland root of each mineral in a separately declared fixed33x33 descriptor neighborhood of its original geographic fixture. The original9x9 search did not admit smoky quartz and its failed report remains preserved,not relabelled. Original seed73921,unchanged rarity/ownership/size/noise. Admission is fixed before optical images,not chosen by how the new material looks. Actual root identity/positive GPU habit verification required in the separate render."},"  "))
	print("CRYSTAL_STYLE_ADMISSION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
