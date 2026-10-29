extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Blueprint=preload("res://scripts/blobs/blob_blueprint.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const OUTPUT="res://.godot/blob_validation_v3"
var failures:Array[String]=[]
var checks:=0
var rows:Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for seed_index in 24:
		var started:=Time.get_ticks_msec()
		var options:Dictionary={"profile":Blueprint.PROFILES[seed_index%12],"body_plan":Blueprint.PLANS[seed_index%10]}
		var data:Dictionary
		var evidence: String=OUTPUT.path_join("model_%02d.bin"%seed_index)
		if "--reuse" in OS.get_cmdline_user_args() and FileAccess.file_exists(evidence):
			var file:=FileAccess.open(evidence,FileAccess.READ); data=file.get_var(false); file.close()
		else: data=Pipeline.new().build(3000+seed_index,0,"auto",7,null,options)
		check(not data.has("error"),"Generation %d"%seed_index)
		if data.has("error"): print(data); continue
		var generation_ms:=Time.get_ticks_msec()-started
		var meshes:Array=[data.body]
		for item:Dictionary in data.appendages: meshes.append(item.mesh)
		for mesh:Dictionary in meshes:
			check(mesh.binds.size()==mesh.vertices.size()*4,"Material bindings")
			check(mesh.chain_binds.size()==mesh.vertices.size()*4,"Chain bindings")
			var finite:=true
			for p:Vector3 in mesh.vertices:
				if not p.is_finite(): finite=false
			check(finite,"Finite geometry")
		check(data.rig.attachment_validation.failures.is_empty(),"Final surface attachment")
		for f:Dictionary in data.features:
			if f.has("terminal_parent"): check(f.points[0].distance_to(data.features[f.parent].points[-1])<.0001,"Digit/bulb shares parent endpoint")
		var actor:=Organism.new(); root.add_child(actor); actor.configure(data); actor.simulation_enabled=false; actor.travel_enabled=true
		var max_cpu:=0; var max_lock:=.0; var max_length:=.0; var min_thickness:=1.0
		var modes:Array=Blueprint.MODES
		for frame in 240:
			actor.set_locomotion(modes[mini(frame/24,9)]) if frame%24==0 else null
			actor.speed=.5 if frame<180 else -.3
			actor.simulate(1.0/60.0)
			max_cpu=maxi(max_cpu,actor.last_simulation_usec)
			max_lock=maxf(max_lock,actor.contacts.maximum_lock_error)
			max_length=maxf(max_length,actor.contacts.maximum_length_error)
			check(actor.solver.height>0 and is_finite(actor.solver.height),"Stable contact height")
			for state:Dictionary in actor.solver.group_states: min_thickness=minf(min_thickness,float(state.squash))
		check(min_thickness>=.739,"Feature minimum thickness")
		check(max_lock<.12,"Reachable stance endpoint error < .12")
		check(max_length<.15,"Constrained chain segment error < .15")
		var row:Dictionary={"seed":3000+seed_index,"evidence_load_ms" if "--reuse" in OS.get_cmdline_user_args() else "generation_ms":generation_ms,"triangles":data.statistics.triangles,"max_step_us":max_cpu,"max_lock_error":max_lock,"max_segment_error":max_length,"minimum_thickness":min_thickness,"chains":data.finalization.chains,"groups":data.finalization.groups}
		rows.append(row); print("V3 ",row)
		actor.free()
		var file:=FileAccess.open(OUTPUT.path_join("model_%02d.bin"%seed_index),FileAccess.WRITE); file.store_var(data); file.close()
	var report:Dictionary={"checks":checks,"failures":failures,"models":rows}
	var file:=FileAccess.open("res://data/blob_v3_validation.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("VALIDATION_COMPLETE checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
