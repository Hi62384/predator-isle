extends SceneTree
func _initialize()->void:
	var guards:Dictionary={};var images:Dictionary={}
	for name:String in ["check_alien_tissue_flow_gpu","tissue_flow_sample_reference"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed);guards[path]=FileAccess.get_sha256(path)
		for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source]);guards[source]=report.source_sha256[source]
		for image_path:String in report.capture_sha256:assert(FileAccess.get_sha256(image_path)==report.capture_sha256[image_path]);images[image_path]=report.capture_sha256[image_path]
	var failures:Array=[];var records:Array=[]
	for seed_id:int in [73921,17,92881]:
		for phase in range(3):
			var first:Image=Image.load_from_file("res://tools/biome_extensions/artifacts/tissue_flow_gpu_%d_%d.png"%[seed_id,phase]);var last:Image=Image.load_from_file("res://tools/biome_extensions/artifacts/tissue_flow_sample_reference_%d_%d.png"%[seed_id,phase]);var a:PackedByteArray=first.get_data();var b:PackedByteArray=last.get_data();var changed:int=0
			for index in range(a.size()):
				if a[index]!=b[index]:changed+=1
			if changed!=0:failures.append("Exact sample-skip reference differs "+str([seed_id,phase,changed]))
			records.append({"seed":seed_id,"phase":phase,"different_bytes":changed})
	guards["res://tools/biome_extensions/check_tissue_sample_equivalence.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_tissue_sample_equivalence.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_sample_equivalence.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"capture_sha256":images,"cases":records,"scope":"All decoded image bytes under nine actual GPU panels:skip empty/duplicate sampler groups versus held frozen four-sample analytic helper,three seeds,child/rectangular-parent projections,wrong-UV negative and exact disabled returns. No tolerance for this optimization,not whole-scene or frame-time acceptance."},"  "));print("TISSUE_SAMPLE_EQUIVALENCE failures=",failures);quit(0 if failures.is_empty() else 1)
