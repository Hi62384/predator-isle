extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Blueprint=preload("res://scripts/blobs/blob_blueprint.gd")
const Cache=preload("res://scripts/blobs/blob_mesh_cache.gd")
const Circulation=preload("res://scripts/blobs/blob_surface_circulation.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)
func _run() -> void:
	var a:=Pipeline.new().build(741,0,"auto",2,null,{"mass_count":2,"width":.6})
	var b:=Pipeline.new().build(741,0,"auto",2,null,{"mass_count":8,"width":1.6})
	check(b.dna.core_radii.x>a.dna.core_radii.x,"Width control changes actual body geometry")
	check(b.features.size()>a.features.size(),"Mass-count control changes actual anatomy")
	var detailed:=Pipeline.new().build(742,0,"auto",5,null,{"profile":"porous"})
	var plain:=Pipeline.new().build(742,0,"auto",5,null,{"profile":"porous","detail":0})
	check(detailed.features.size()>plain.features.size(),"Detail control enables genuine geometric operators")
	var faceless:=Pipeline.new().build(743,0,"drag",7,null,{"profile":"mimic","faces":0,"limbs":0,"membranes":0})
	check(not faceless.statistics.feature_types.has("embedded_face"),"Face frequency can disable faces")
	check(faceless.rig.active_legs.is_empty(),"Limb frequency can produce legless dragging anatomy")
	check(not faceless.statistics.feature_types.has("supported_membrane"),"Membrane abundance can disable membranes")
	var collection:=Pipeline.new().build_collection([941,941,941],0)
	check(collection.size()==3,"Diversity selection produces a collection")
	if collection.size()==3:
		check(collection[0].dna.seed!=collection[1].dna.seed and collection[1].dna.seed!=collection[2].dna.seed,"Repeated seeds are regenerated into distinct designs")
		check(Blueprint.distance(collection[0].descriptor,collection[1].descriptor)>=.07,"Collection uses anatomical distance rather than color")
	var cached:=Cache.build(744,0,"roll",2,null,{})
	var readback:=Cache.build(744,0,"roll",2,null,{})
	check(readback.cache_hit and cached.body.vertices==readback.body.vertices,"LRU cache preserves geometry on readback")
	var solver:=Circulation.new()
	solver.configure(faceless.dna)
	for frame in 120: solver.step(1.0/60.0,.8,"hybrid")
	check(solver.motion_mix>.5 and solver.motion_mix<.95,"Hybrid leaves motion available for limb assistance")
	var organism:=Organism.new()
	root.add_child(organism)
	organism.configure(cached)
	organism.simulation_enabled=false
	organism.simulate(.016)
	var bone_error:=.0
	for i in organism.skeleton.get_bone_count():
		var expected: Vector3=organism.solver.map_point(cached.rig.bone_positions[i])
		bone_error=maxf(bone_error,expected.distance_to(organism.skeleton.get_bone_global_pose(i).origin))
	check(bone_error<.001,"Armature poses match the deformation cage in parent-relative coordinates")
	organism.free()
	var file:=FileAccess.open("res://data/blobs_v2/control_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t")); file.close()
	print("BLOB_CONTROL_VALIDATION ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
