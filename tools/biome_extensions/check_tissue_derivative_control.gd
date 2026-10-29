extends SceneTree
func outlier(image:Image,pixel:Vector2i)->float:
	var values:Array=[]
	for offset:Vector2i in [Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2),Vector2i(-2,-2),Vector2i(2,-2),Vector2i(-2,2),Vector2i(2,2)]:values.append(image.get_pixelv(pixel+offset).get_luminance())
	values.sort();return maxf(0,(values[3]+values[4])*.5-image.get_pixelv(pixel).get_luminance())
func _initialize()->void:
	var guards:Dictionary={};var captures:Dictionary={};var reports:Array=[]
	for name:String in ["diagnose_tissue_flow_contacts","tissue_derivative_negative"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed);reports.append(report);guards[path]=FileAccess.get_sha256(path)
		for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source]);guards[source]=report.source_sha256[source]
		for image_path:String in report.capture_sha256:assert(FileAccess.get_sha256(image_path)==report.capture_sha256[image_path]);captures[image_path]=report.capture_sha256[image_path]
	var current:Image=Image.load_from_file("res://tools/biome_extensions/artifacts/tissue_contacts_0_both.png");var negative:Image=Image.load_from_file("res://tools/biome_extensions/artifacts/tissue_derivative_negative_0_both.png")
	var points:Array[Vector2i]=[Vector2i(607,260),Vector2i(606,298),Vector2i(602,312),Vector2i(600,339),Vector2i(592,358),Vector2i(586,373),Vector2i(580,385)];var records:Array=[];var detected:int=0;var failures:Array=[]
	for point:Vector2i in points:
		var a:float=outlier(current,point);var b:float=outlier(negative,point)
		if b>.05:detected+=1
		if a>.02:failures.append("Corrected fixed streak point still has a>.02 local luminance dip "+str(point))
		records.append({"pixel":point,"corrected_luminance_dip":a,"prior_derivative_luminance_dip":b})
	if detected<3:failures.append("Intentional prior derivative control did not reproduce at least three>.05 fixed local dips;do not infer a causal fix from this run")
	guards["res://tools/biome_extensions/check_tissue_derivative_control.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_tissue_derivative_control.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_derivative_control.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"capture_sha256":captures,"cases":records,"detected_prior_derivative_outliers":detected,"scope":"Same frozen seed17/context camera and all seven originally identified dark-streak points. Predeclared corrected local luminance dip<=.02;intentional prior-method control must reproduce>.05 at at least three points. Eight surrounding pixels at two-pixel offsets define the local median. This is a bounded causal streak diagnostic,not an exclusion mask,universal texture/image-equivalence or whole-world artistic certificate."},"  "));print("TISSUE_DERIVATIVE_CONTROL negatives=",detected," failures=",failures);quit(0 if failures.is_empty() else 1)
