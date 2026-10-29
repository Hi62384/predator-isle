extends SceneTree
func _initialize()->void:
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/render_all.json"));var count:int=0;var families:Dictionary={}
	assert(report.actual_render and report.captures.size()==32 and report.view_distance==50000)
	for path:String in report.source_sha256:assert(FileAccess.get_sha256(path)==report.source_sha256[path],"Stale source: "+path)
	for record:Dictionary in report.captures:
		var path:String="res://tools/biome_extensions/artifacts/"+record.biome+"_"+record.view+".png";assert(record.committed and record.leaves>0)
		assert(FileAccess.get_sha256(path)==record.sha256,"Capture hash: "+path)
		var image:=Image.load_from_file(path);assert(image.get_width()==1280 and image.get_height()==720)
		families[record.biome]=true;count+=1
		if record.biome in ["crystal_wastes","insect_colony","alien_infected"]:assert(record.structure_batches>0)
	assert(families.size()==8)
	var mixed=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/render_mixed.json"));assert(mixed.actual_render and mixed.all_sixteen_owners_enabled and mixed.captures.size()==2)
	for record:Dictionary in mixed.captures:
		var path:String="res://tools/biome_extensions/artifacts/mixed_"+record.view+".png";assert(record.committed and record.sha256==FileAccess.get_sha256(path));count+=1
	FileAccess.open("res://tools/biome_extensions/artifacts/check_review.json",FileAccess.WRITE).store_string(JSON.stringify({"captures_audited":count,"families":families.keys(),"current_core_source_hashes":true,"all_committed_cuts":true,"mixed_world":true,"artistic_success_claimed":false},"\t"))
	print("EXTENSION_REVIEW_PASS ",count," native captures, eight families, source hashes, committed cuts, dimensions, structure batches and mixed-world hashes; not an artistic sign-off");quit()
