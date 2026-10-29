extends SceneTree
const Volume=preload("res://scripts/blobs/blob_volume_calibration.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var directory:=DirAccess.open("res://.godot/blob_validation_v3")
	for name in directory.get_files():
		if not name.ends_with(".bin"): continue
		var path: String="res://.godot/blob_validation_v3/"+name
		var file:=FileAccess.open(path,FileAccess.READ); var data:Dictionary=file.get_var(false); file.close()
		if data.dna.has("volume_curve") and data.dna.has("strain_volume_curve"): continue
		if data.dna.has("volume_curve"): data.dna["strain_volume_curve"]=Volume.calibrate_strain(data)
		else: data.dna["volume_curve"]=Volume.calibrate(data)
		file=FileAccess.open(path,FileAccess.WRITE); file.store_var(data); file.close()
		print("VOLUME_CALIBRATED ",name)
	quit()
