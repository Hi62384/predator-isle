extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	for index in [1,2,4]:
		var file:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%index,FileAccess.READ);var data:Dictionary=file.get_var(false);file.close()
		var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false;actor.travel_enabled=true;actor.speed=.6
		var time:=0
		for frame in 180:actor.simulate(1.0/60);time+=actor.last_simulation_usec
		print("GAIT ",index," mode=",actor.locomotion," position=",actor.position," mean_us=",time/180," corrected=",actor.contacts.corrected_poses," fallback=",actor.contacts.rejected_poses)
		for c:Dictionary in actor.contacts.chains:
			if c.kind!="passive":print("CHAIN ",c.feature_id," ",c.state," cycles=",c.cycles," active=",c.active," root_y=",actor.contacts._root(c).y," length=",c.length)
		actor.free()
	quit()
