extends SceneTree
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocky_coast_previews.json"));var captures:Array=[];var reports:int=0
	for filename:String in DirAccess.get_files_at("res://tools/rocky_coast/artifacts"):
		if not filename.begins_with("render_review_batch_") or not filename.ends_with(".json"):continue
		var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/rocky_coast/artifacts/"+filename))
		assert(report.actual_render);reports+=1;captures.append_array(report.captures)
		for item:Dictionary in report.captures:assert(item.leaves>0,"Capture had no committed terrain")
		var batch:String=filename.trim_prefix("render_review_batch_").trim_suffix(".json")
		for kind:String in ["ground","medium","aerial","materials","normals","water"]:
			var sheet_path:String="res://tools/rocky_coast/artifacts/views/contact_"+kind+"_batch_"+batch+".png"
			var sheet:=Image.load_from_file(sheet_path);assert(sheet!=null)
			# Compact only the generated QA contact sheet; original captures stay intact.
			assert(sheet.get_region(Rect2i(0,0,2560,720)).save_png(sheet_path)==OK)
	var verified:Array=[]
	for name:String in manifest.features:
		for view:String in ["ground","medium","aerial","materials","normals","water"]:
			var found:bool=false
			for item:Dictionary in captures:
				if item.feature==name and item.view==view:found=true;break
			assert(found,"Missing actual native capture metadata: "+name+" / "+view)
			var path:String="res://tools/rocky_coast/artifacts/views/"+name+"_"+view+".png";var pixels:=Image.load_from_file(path)
			assert(pixels!=null and pixels.get_width()==1280 and pixels.get_height()==720)
			verified.append({"feature":name,"view":view,"sha256":FileAccess.get_sha256(path)})
	var close_views:Array=[]
	for name:String in ["tide_pools","connected_pools"]:
		var path:String="res://tools/rocky_coast/artifacts/views/"+name+"_pool_close.png";var pixels:=Image.load_from_file(path)
		assert(pixels!=null and pixels.get_width()==1280 and pixels.get_height()==720)
		close_views.append({"feature":name,"view":"pool_close","sha256":FileAccess.get_sha256(path)})
	assert(verified.size()==192 and reports==4 and close_views.size()==2)
	FileAccess.open("res://tools/rocky_coast/artifacts/render_review.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"actual_render":true,"capture_count":verified.size(),"batch_reports":reports,"captures":verified,"close_views":close_views},"\t"))
	print("COAST_COMPLETE_VISUAL_REVIEW 192 verified captures plus two close pool views");quit()
