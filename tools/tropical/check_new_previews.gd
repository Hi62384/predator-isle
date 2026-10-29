extends SceneTree
func _initialize()->void:
	var path:String="res://tools/tropical/artifacts/render_review_rocky_cascade,volcanic_tropical_transition.json"
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.actual_render and report.captures.size()==12)
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale preview source: "+source)
	var coverage:Dictionary={};var checks:int=0
	for capture:Dictionary in report.captures:
		assert(capture.leaves>0 and capture.committed_revision==capture.partition_revision)
		var image_path:String="res://tools/tropical/artifacts/views/"+capture.feature+"_"+capture.view+".png"
		assert(FileAccess.get_sha256(image_path)==capture.png_sha256,"Changed preview pixels")
		var image:=Image.load_from_file(image_path);assert(image.get_width()==1280 and image.get_height()==720)
		if capture.feature=="rocky_cascade":assert(capture.tropical_owner_at_focus>.999 and capture.volcanic_owner_at_focus==0 and capture.foam_batches>0)
		else:assert(capture.feature=="volcanic_tropical_transition" and capture.tropical_owner_at_focus>.25 and capture.volcanic_owner_at_focus>.25 and absf(capture.tropical_owner_at_focus+capture.volcanic_owner_at_focus-1)<.00001)
		if capture.view=="normals":assert(capture.shader_debug==8)
		if not coverage.has(capture.feature):coverage[capture.feature]=[]
		assert(not coverage[capture.feature].has(capture.view));coverage[capture.feature].append(capture.view);checks+=1
	for key:String in ["rocky_cascade","volcanic_tropical_transition"]:
		for view:String in ["ground","medium","aerial","materials","normals","water"]:assert(coverage[key].has(view))
	var result:Dictionary={"passed":true,"audited_captures":checks,"actual_owner_weights_verified":true,"actual_foam_batches_verified":true,"common_mapped_normal_view_verified":true,"source_sha256":report.source_sha256,"scope":"Two preview paths, twelve current-source native captures with actual bound owners and foam. Not a full Tropical artistic or all-world route certificate."}
	FileAccess.open("res://tools/tropical/artifacts/check_new_previews.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TROPICAL_NEW_PREVIEW_AUDIT ",checks);quit()
