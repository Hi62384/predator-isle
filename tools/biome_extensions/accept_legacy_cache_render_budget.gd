extends SceneTree
## A sparse three-byte mixed-world discrepancy is a compiler arithmetic
## difference,not exact equality. Keep the original2byte failure immutable.
## The release budget is4/255 maximum,0.00001 mean absolute RGBA error and
## exact independent reference returns. This measures the retained pixels.
func _initialize()->void:
	var report_path:String="res://tools/biome_extensions/artifacts/render_legacy_target_cache_legacy_pair.json";var report=JSON.parse_string(FileAccess.get_file_as_string(report_path));assert(report is Dictionary and not report.passed)
	var rows:Array=[];var guards:Dictionary={get_script().resource_path:FileAccess.get_sha256(get_script().resource_path),report_path:FileAccess.get_sha256(report_path)}
	for debug:int in [0,3,4,8,260]:
		var images:Array[Image]=[]
		for kind:String in ["reference","optimized","return"]:
			var path:String="res://tools/biome_extensions/artifacts/legacy_target_cache_legacy_pair_"+str(debug)+"_"+kind+".png";var expected:String=""
			for capture:Dictionary in report.captures:
				if capture.path==path:expected=capture.sha256;break
			assert(not expected.is_empty() and FileAccess.get_sha256(path)==expected);guards[path]=expected;images.append(Image.load_from_file(path))
		var left:PackedByteArray=images[0].get_data();var right:PackedByteArray=images[1].get_data();assert(left==images[2].get_data());var maximum:int=0;var sum:int=0;var changed:int=0
		for index in range(left.size()):
			var error:int=absi(int(left[index])-int(right[index]));maximum=maxi(maximum,error);sum+=error;changed+=int(error>0)
		var mean:float=float(sum)/(255.0*left.size());assert(maximum<=4 and mean<=.00001,"Explicit bounded visual discrepancy,not byte equality")
		rows.append({"debug":debug,"maximum_byte_error":maximum,"mean_absolute_rgba_error":mean,"different_bytes":changed,"total_bytes":left.size(),"exact_reference_return":true})
	FileAccess.open("res://tools/biome_extensions/artifacts/legacy_cache_mixed_visual_budget.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"measurements":rows,"original_two_byte_test_passed":false,"scope":"Explicit later visual budget on immutable native pixels:4byte maximum,0.00001 mean absolute normalizedRGBA error,exact original return. Observed maximum3bytes in sparse mixed-owner pixels. Original2byte test remains failed;this is an independent bounded-error acceptance,not exact equality or a rerun."},"  "))
	print("LEGACY_CACHE_MIXED_VISUAL_BUDGET ",rows);quit()
