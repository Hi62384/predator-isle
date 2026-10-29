extends "res://tools/blobs/check_blob_v3_volume.gd"
func run()->void:
	var rows:Array=[]
	var maximum_error:=.0
	for index in 24:
		var file:=FileAccess.open("res://.godot/blob_validation_v3/model_%02d.bin"%index,FileAccess.READ); var data:Dictionary=file.get_var(false); file.close()
		if data.dna.get("strain_volume_curve",PackedFloat32Array()).size()!=8: push_error("Missing strain volume calibration"); quit(1); return
		var solver:=Solver.new(); solver.configure(data.dna,data.rig,data.body)
		var rest:=volume(data.body)
		var ratios:Array=[]
		for strain:Vector3 in [Vector3(.22,0,0),Vector3(.11,.17,.03),Vector3.ONE*.22,Vector3.ONE*.13]:
			solver.strain=strain; solver._update_groups(.0); solver._update_volume()
			var ratio:=volume(data.body,solver)/rest; ratios.append(ratio); maximum_error=maxf(maximum_error,absf(ratio-1.0))
		rows.append({"seed":data.dna.seed,"ratios":ratios})
	var report:Dictionary={"maximum_error":maximum_error,"models":rows}
	var file:=FileAccess.open("res://data/blobs_v3/strain_volume_validation.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("STRAIN_VOLUME_COMPLETE max_error=",maximum_error); quit(0 if maximum_error<.06 else 1)
