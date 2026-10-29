extends SceneTree
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_previews.json"))
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/tropical/artifacts/render_review.json"))
	assert(report.actual_render and report.renderer=="gl_compatibility" and not report.foliage_rendered)
	for path:String in report.source_sha256:assert(FileAccess.get_sha256(path)==report.source_sha256[path],"Stale render source: "+path)
	var coverage:Dictionary={};var checks:int=0
	var expression:=RegEx.new();assert(expression.compile("[-+]?[0-9]+(?:\\.[0-9]+)?")==OK)
	for capture:Dictionary in report.captures:
		assert(manifest.features.has(capture.feature));var item:Dictionary=manifest.features[capture.feature]
		var position:Array=expression.search_all(capture.focus);assert(position.size()==3)
		assert(absf(float(position[0].get_string())-item.x)<.3 and absf(float(position[2].get_string())-item.z)<.3,"Manifest focus mismatch")
		assert(capture.leaves>0 and capture.committed_revision==capture.partition_revision,"Uncommitted capture")
		var path:String="res://tools/tropical/artifacts/views/"+capture.feature+"_"+capture.view+".png"
		assert(FileAccess.get_sha256(path)==capture.png_sha256,"Changed capture pixels")
		var im:=Image.load_from_file(path);assert(im!=null and im.get_width()==1280 and im.get_height()==720)
		if not coverage.has(capture.feature):coverage[capture.feature]=[]
		assert(not coverage[capture.feature].has(capture.view),"Duplicate review view");coverage[capture.feature].append(capture.view);checks+=1
	for name:String in manifest.features:
		assert(coverage.has(name))
		for view:String in ["ground","medium","aerial","materials","normals","water"]:assert(coverage[name].has(view),"Missing "+name+" "+view)
	assert(checks==manifest.features.size()*6)
	print("TROPICAL_REVIEW_AUDIT_PASS ",checks," current-source native captures at ",manifest.features.size()," actual locations");quit()
