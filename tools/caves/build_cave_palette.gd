extends SceneTree
## Offline native2K normal-map packing from existing verified photographs.
## Does not alter any surface texture,source photograph or runtime downloader.
const Palette=preload("res://scripts/caves/material_palette.gd")
func _initialize()->void:
	var guards:Dictionary={};var records:Array=[];var bytes:int=0
	for path:String in ["res://scripts/caves/material_palette.gd","res://tools/caves/build_cave_palette.gd",Palette.COLORS,Palette.NORMALS]:guards[path]=FileAccess.get_sha256(path)
	for source:Array in Palette.RECORDS:
		var manifest=JSON.parse_string(FileAccess.get_file_as_string(source[1]));guards[source[1]]=FileAccess.get_sha256(source[1]);var record:Dictionary={}
		for candidate:Dictionary in manifest:
			if candidate.id==source[0]:record=candidate.duplicate(true);break
		assert(not record.is_empty() and record.license=="CC0-1.0");var normal_path:String=""
		for map:Dictionary in record.maps:
			assert(FileAccess.get_sha256(map.path)==map.sha256)
			if str(map.path).contains("NormalGL"):normal_path=map.path;guards[normal_path]=map.sha256
		assert(not normal_path.is_empty());var image:Image=Image.load_from_file(normal_path);assert(image!=null and maxi(image.get_width(),image.get_height())==2048 and mini(image.get_width(),image.get_height())>=1024);var source_size:Vector2i=image.get_size()
		# Rock055 is a real rectangular2K source,as its existing provenance
		# already notes. Match its square color packing;record interpolation
		# honestly rather than claiming new native detail on the shorter axis.
		if source_size!=Vector2i(2048,2048):image.resize(2048,2048,Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RG8);image.generate_mipmaps();assert(image.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK);assert(image.get_format()==Image.FORMAT_RGTC_RG and image.get_mipmap_count()==11)
		var output:String="res://materials/cave_normal_"+str(source[0])+".res";assert(ResourceSaver.save(image,output)==OK);guards[output]=FileAccess.get_sha256(output);record["normal_resource"]=output;record["color_resource"]="res://materials/"+source[3]+".res";record["cave_role"]=source[2];record["normal_source_dimensions"]=[source_size.x,source_size.y];record["normal_square_resampled"]=source_size!=Vector2i(2048,2048);record["normal_packing"]="OpenGL XY BC5,2048square/full11mips. Rectangular sources resampled to match existing square color;no new source detail claimed. Existing1024packed surface normals unchanged.";record["color_packing"]="Exact existing2048color+roughness image resource;no regrading";records.append(record);bytes+=image.get_data_size();print("CAVE_NORMAL_2K ",source[0]," source=",source_size," bytes=",image.get_data_size())
	for path:String in guards:assert(FileAccess.get_sha256(path)==guards[path])
	var result:Dictionary={"passed":true,"failures":[],"source_sha256":guards,"records":records,"normal_array_compressed_bytes":bytes,"scope":"Offline packing only,eight preexisting verified nominal2KOpenGL source maps into cave-only2048squareBC5XY/fullmip resources. Original dimensions and any rectangular-to-square interpolation explicitly recorded;not new native detail on an interpolated axis. No new photography,semantic image edits,downloads,surface texture changes or whole-cave completion claim."};FileAccess.open("res://data/cave_material_sources.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));FileAccess.open("res://tools/biome_extensions/artifacts/build_cave_palette.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("CAVE_PALETTE_BUILD eight2K normal maps bytes=",bytes);quit()
