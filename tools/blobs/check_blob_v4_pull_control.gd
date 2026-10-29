extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var rows:Array=[];var failed:=false
	for index in [1,2]:
		for enabled in [true,false]:
			var file:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%index,FileAccess.READ);var data:Dictionary=file.get_var(false);file.close()
			var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false;actor.travel_enabled=true;actor.speed=.6;actor.gait_enabled=enabled
			var phases:Dictionary={};var length:=.0;var total:=0
			for frame in 240:
				var before:=actor.position;actor.simulate(1.0/60);length+=actor.position.distance_to(before);total+=actor.last_simulation_usec
				for c:Dictionary in actor.contacts.chains:
					if c.active:phases[c.motion_phase]=true
			var cycles:=0
			for c:Dictionary in actor.contacts.chains:cycles+=c.cycles
			rows.append({"seed":data.dna.seed,"gait_enabled":enabled,"mode":actor.locomotion,"path_length":length,"net_position":str(actor.position),"contact_cycles":cycles,"phases":phases.keys(),"mean_step_us":float(total)/240})
			if enabled and (length<.12 or cycles==0 or actor.locomotion!=("vine" if index==1 else "limb")):failed=true
			# Disabling the gait must suppress its motor, not silently switch modes.
			if not enabled and length>.02:failed=true
			print(rows[-1]);actor.free()
	var file:=FileAccess.open("res://data/blobs_v4/pull_control_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"failed":failed,"runs":rows},"\t"));file.close()
	print("PULL_CONTROL_COMPLETE failed=",failed);quit(1 if failed else 0)
