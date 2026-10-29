extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data:=Pipeline.new().build(3004,0,"hybrid")
	if data.has("error"): print(data); quit(1); return
	print("BUILT ",data.statistics," ",data.finalization)
	var actor:=Organism.new(); root.add_child(actor); actor.configure(data); actor.simulation_enabled=false
	for i in 240: actor.speed=.6; actor.simulate(1.0/60.0)
	print("CONTACTS ",actor.contacts.planted_count," LOCK ",actor.contacts.maximum_lock_error," LENGTH ",actor.contacts.maximum_length_error)
	for i in 4: await process_frame
	print("PROBE_COMPLETE")
	quit()
