extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://.godot/blob_validation_v4")
	for index in 3:
		var started:=Time.get_ticks_msec()
		var options:Dictionary={"profile":["swollen","membranous","sensory"][index],"body_plan":["compact","lopsided","multilobe"][index]}
		var data:=Pipeline.new().build(5100+index,0,"roll" if index==0 else "auto",7,null,options)
		if data.has("error"):print(data);quit(1);return
		print("V4_BUILT ",index," ms=",Time.get_ticks_msec()-started," body=",data.mesh_integrity," stats=",data.statistics," roll=",data.rig.roll_safe)
		for item:Dictionary in data.appendages:
			if item.feature.mesh_integrity.inconsistent_edges>0 or item.feature.mesh_integrity.nonmanifold_edges>0:print("BAD_FEATURE ",item.feature.id," ",item.feature.feature_type," ",item.feature.mesh_integrity)
		var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false
		for frame in 60:actor.speed=.5;actor.simulate(1.0/60.0)
		print("V4_POSE ",actor.locomotion," ",actor.contacts.maximum_lock_error)
		actor.free()
		var file:=FileAccess.open("res://.godot/blob_validation_v4/model_%02d.bin"%index,FileAccess.WRITE);file.store_var(data);file.close()
	print("V4_PROBE_COMPLETE");quit()
