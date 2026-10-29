extends SceneTree
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_previews.json"));var counts:Dictionary={};var records:Array=[]
	for batch in range(1,7):
		var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/beach/artifacts/render_review_batch_%d.json"%batch))
		assert(report.actual_render and report.captures.size()>0)
		for path:String in report.source_sha256:assert(FileAccess.get_sha256("res://"+path)==report.source_sha256[path],"Review captures must match current terrain source: "+path)
		for capture:Dictionary in report.captures:
			assert(capture.leaves>0);var name:String=capture.feature;var kind:String=capture.view
			var coordinates:PackedStringArray=String(capture.focus).trim_prefix("(").trim_suffix(")").split(",")
			assert(absf(float(coordinates[0])-manifest.features[name].x)<.3 and absf(float(coordinates[2])-manifest.features[name].z)<.3,"Rendered focus must match current preview manifest: "+name)
			var path:String="res://tools/beach/artifacts/views/"+name+"_"+kind+".png";var image:=Image.load_from_file(path)
			assert(image!=null and image.get_width()==1280 and image.get_height()==720)
			counts[name+":"+kind]=true;records.append({"feature":name,"view":kind,"sha256":FileAccess.get_sha256(path)})
		# Compact review-only contact sheets; never alter the native captures.
		for kind:String in ["ground","medium","aerial"]:
			var sheet:=Image.create_empty(2560,720,false,Image.FORMAT_RGBA8);var slot:int=0
			for capture:Dictionary in report.captures:
				if capture.view!=kind:continue
				var image:=Image.load_from_file("res://tools/beach/artifacts/views/"+capture.feature+"_"+kind+".png");image.resize(640,360,Image.INTERPOLATE_LANCZOS);image.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(image,Rect2i(0,0,640,360),Vector2i((slot%4)*640,(slot/4)*360));slot+=1
			sheet.save_png("res://tools/beach/artifacts/views/contact_"+kind+"_batch_%d.png"%batch)
	for name:String in manifest.features:
		for kind:String in ["ground","medium","aerial"]:assert(counts.has(name+":"+kind),"Missing native view "+name+" "+kind)
	for name:String in ["wide_beach","high_foredunes","lagoon","mixed_rock_sand"]:
		for kind:String in ["materials","normals","water"]:assert(counts.has(name+":"+kind))
	assert(records.size()==78)
	FileAccess.open("res://tools/beach/artifacts/review_audit.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"actual_render":true,"regions":manifest.features.size(),"captures":records,"count":records.size()},"\t"));print("BEACH_REVIEW_AUDIT 22 regions, 78 current-revision native captures");quit()
