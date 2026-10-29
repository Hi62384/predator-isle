extends SceneTree
func _initialize()->void:
	var reports:Array[String]=["render_all","render_mixed","render_features"]
	for key:String in TerrainSettings.EXTENSION_KEYS:reports.append("render_regions_"+key)
	var total:int=0;var families:Dictionary={};var views:Dictionary={}
	for name:String in reports:
		var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/"+name+".json"));assert(report.actual_render)
		assert(report.captures.size()==(32 if name=="render_all" else (2 if name=="render_mixed" else (13 if name=="render_features" else 12))))
		if report.has("source_sha256"):
			for path:String in report.source_sha256:assert(FileAccess.get_sha256(path)==report.source_sha256[path],"Stale core source: "+path)
		for record:Dictionary in report.captures:
			var path:String="res://tools/biome_extensions/artifacts/"+record.biome+"_"+record.view+".png";assert(record.committed and record.leaves>0);assert(FileAccess.get_sha256(path)==record.sha256)
			var image:=Image.load_from_file(path);assert(image.get_width()==1280 and image.get_height()==720);total+=1;families[record.biome]=true;views[record.view]=true
	assert(total==143)
	var output:Dictionary={"captures_audited":total,"source_hashes_current":true,"png_hashes_dimensions_and_committed_cuts":true,"regional_day_night_captures":96,"feature_captures":13,"artistic_signoff":false,"infinite_cave_system_complete":false}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_completion_review.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"));print("COMPLETION_REVIEW_PASS ",total," current-source native captures; NOT full reference-quality or infinite cave acceptance");quit()
