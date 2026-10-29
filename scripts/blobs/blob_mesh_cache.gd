extends RefCounted
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const DIRECTORY="res://.godot/blob_organisms_v4"
const SOURCES=["blob_blueprint.gd","blob_anatomical_growth.gd","blob_organism_pipeline.gd","blob_deformation_bindings.gd","blob_surface_attachments.gd","blob_curve_frames.gd","blob_stable_extractor.gd","blob_mesh_integrity.gd","blob_surface_circulation.gd"]
static func key(seed_value: int, quality: int, mode: String, last_pass: int, options: Dictionary) -> String:
	var fingerprint: Array=[]
	for source in SOURCES: fingerprint.append(FileAccess.get_sha256("res://scripts/blobs/"+source))
	return (JSON.stringify([seed_value,quality,mode,last_pass,options],"",true)+str(fingerprint)).sha256_text()
static func build(seed_value: int, quality: int, mode: String, last_pass: int, job: RefCounted, options: Dictionary) -> Dictionary:
	var digest:=key(seed_value,quality,mode,last_pass,options)
	var path:=DIRECTORY.path_join(digest+".bin")
	if job!=null and job.is_cancelled(): return {"cancelled":true}
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file!=null and file.get_length()<67108864:
			var packet: Variant=bytes_to_var(file.get_buffer(file.get_length()))
			file.close()
			if packet is Dictionary and packet.get("key","")==digest and packet.get("data") is Dictionary:
				packet.data["cache_hit"]=true
				return packet.data
	var data:=Pipeline.new().build(seed_value,quality,mode,last_pass,job,options)
	if data.has("error") or data.get("cancelled",false): return data
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var directory:=DirAccess.open(DIRECTORY)
	# Only generator-owned SHA-named files in this fixed .godot directory are
	# evicted. Preserve unrelated files and keep caching useful after 32 seeds.
	if directory!=null and directory.get_files().size()>=32:
		var pattern:=RegEx.new()
		pattern.compile("^[0-9a-f]{64}\\.bin$")
		var oldest: String=""
		var oldest_time: int=9223372036854775807
		for name in directory.get_files():
			if pattern.search(name)==null: continue
			var modified:=FileAccess.get_modified_time(DIRECTORY.path_join(name))
			if modified<oldest_time: oldest=name; oldest_time=modified
		if not oldest.is_empty(): directory.remove(oldest)
	if directory!=null:
		var bytes:=var_to_bytes({"key":digest,"data":data})
		if bytes.size()<67108864:
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file!=null: file.store_buffer(bytes); file.close()
	data["cache_hit"]=false
	return data
