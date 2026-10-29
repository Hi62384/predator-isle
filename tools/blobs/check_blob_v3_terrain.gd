extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
var failures:Array[String]=[]
class Ground extends Node3D:
	func get_height_at(p:Vector3)->float: return .12*p.z+.08*sin(p.z*1.8)+.06*sin(p.x)
func _initialize()->void: call_deferred("run")
func run()->void:
	var ground:=Ground.new(); root.add_child(ground)
	var rows:Array=[]
	for index in [0,3,6]:
		var file:=FileAccess.open("res://.godot/blob_validation_v3/model_%02d.bin"%index,FileAccess.READ); var data:Dictionary=file.get_var(false); file.close()
		for mode in ["roll","vine","limb","contractile","peristaltic","pulse","drag","hybrid","multicontact","undulate"]:
			var actor:=Organism.new(); root.add_child(actor); actor.position=Vector3(120,0,240); actor.position.y=ground.get_height_at(actor.position); actor.terrain=ground; actor.ground_height=actor.position.y; actor.configure(data); actor.travel_enabled=true; actor.simulation_enabled=false; actor.set_locomotion(mode); actor.speed=.55
			var min_clearance:=INF; var max_lock:=.0; var usec:=0
			for frame in 180:
				actor.simulate(1.0/60.0); usec+=actor.last_simulation_usec
				max_lock=maxf(max_lock,actor.contacts.maximum_lock_error)
				for sample:Dictionary in actor.solver.support_samples:
					var p:Vector3=actor.solver.map_bound(sample.p,int(sample.group),float(sample.weight))
					min_clearance=minf(min_clearance,p.y+actor.solver.height-actor.solver.ground_at(p.x,p.z))
			if min_clearance<-.04: failures.append("Ground penetration "+str(index)+" "+mode)
			if max_lock>.02: failures.append("Grip error "+str(index)+" "+mode)
			rows.append({"seed":data.dna.seed,"requested":mode,"effective":actor.locomotion,"travel":str(actor.position),"minimum_support_clearance":min_clearance,"maximum_stance_error":max_lock,"mean_step_us":float(usec)/180.0})
			print(rows[-1]); actor.free()
	var file:=FileAccess.open("res://data/blobs_v3/terrain_validation.json",FileAccess.WRITE); file.store_string(JSON.stringify({"failures":failures,"runs":rows},"\t")); file.close()
	print("TERRAIN_COMPLETE failures=",failures.size()); quit(0 if failures.is_empty() else 1)
