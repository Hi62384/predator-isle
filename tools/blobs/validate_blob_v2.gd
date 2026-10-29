extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
const Blueprint=preload("res://scripts/blobs/blob_blueprint.gd")
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const Cache=preload("res://scripts/blobs/blob_mesh_cache.gd")
const Workshop=preload("res://scripts/blobs/blob_workshop.gd")
const OUTPUT="res://.godot/blob_validation_v2_release"
var failures: Array[String]=[]
var checks:=0
var rows: Array[Dictionary]=[]
class Ground extends Node3D:
	func get_height_at(p: Vector3) -> float: return .12*p.x+.09*sin(p.z*1.4)

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)

static func settings(index: int) -> Dictionary:
	if index>=12: return {}
	return {"profile":Blueprint.PROFILES[index],"body_plan":Blueprint.PLANS[index%Blueprint.PLANS.size()]}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	if FileAccess.file_exists(OUTPUT.path_join("batch.complete")): DirAccess.remove_absolute(OUTPUT.path_join("batch.complete"))
	var ratios: Array[float]=[]
	var families: Dictionary={}
	var descriptors: Array=[]
	for i in 24:
		var started:=Time.get_ticks_msec()
		var data: Dictionary=Pipeline.new().build(3000+i,0,"auto",7,null,settings(i))
		check(not data.has("error") and not data.get("cancelled",false),"Build %d completes" % i)
		check(data.stages.size()==8,"All eight biological passes retained")
		check(data.body.vertices.size()>100,"Implicit body extracted")
		check(data.statistics.triangles<90000,"Draft triangle budget under 90k")
		_validate_mesh(data.body)
		for item: Dictionary in data.appendages:
			_validate_mesh(item.mesh)
			var limit: float=data.dna.core_radii.length()*3.0+float(data.dna.size)*3.0
			var bounded:=true
			for point: Vector3 in item.mesh.vertices:
				if point.length()>limit: bounded=false
			check(bounded,"Detail projection has no runaway geometry")
		for f: Dictionary in data.features:
			check(f.parent<f.id,"Acyclic anatomical parent graph")
			families[f.feature_type]=int(families.get(f.feature_type,0))+1
			if f.get("sheet",false): check(f.support_ids.size()==2,"Membrane anchored to two real appendages")
		var radius: Vector3=data.dna.core_radii
		ratios.append(radius.x/radius.y)
		descriptors.append(data.descriptor)
		var model_path:=OUTPUT.path_join("clay_%02d.bin" % i)
		var file:=FileAccess.open(model_path+".partial",FileAccess.WRITE)
		file.store_var(data); file.close()
		check(DirAccess.rename_absolute(model_path+".partial",model_path)==OK,"Packed evidence published atomically")
		var summary: Dictionary=data.statistics.duplicate(true)
		summary.merge({"seed":3000+i,"profile":data.dna.profile,"body_plan":data.dna.body_plan,"locomotion":data.dna.locomotion,"generation_ms":Time.get_ticks_msec()-started,"radii":[radius.x,radius.y,radius.z]},true)
		rows.append(summary)
		print("BLOB_BATCH ",i+1,"/24 ",data.dna.profile," / ",data.dna.body_plan," triangles=",summary.triangles," ms=",summary.generation_ms)
	check(ratios.max()/ratios.min()>3.0,"Body proportion diversity exceeds 3x")
	for kind in ["embedded_face","muscular_limb","major_vine","lattice_arch","lattice_opening","sensory_bulb","supported_membrane","vascular_branch","anatomical_fold"]:
		check(int(families.get(kind,0))>0,"Batch demonstrates "+kind)
	var a: Dictionary=Pipeline.new().build(3002,0,"auto",7,null,settings(2))
	var b: Dictionary=Pipeline.new().build(3002,0,"auto",7,null,settings(2))
	check(var_to_bytes(a)==var_to_bytes(b),"Same seed/options regenerate byte-identical data")
	var clay: Dictionary=Pipeline.new().build(3002,0,"auto",6,null,settings(2))
	check(a.body.vertices==clay.body.vertices and a.body.indices==clay.body.indices,"Material pass preserves geometry")
	var smooth: Dictionary=Pipeline.new().build(3010,0,"auto",7,null,settings(10))
	check(smooth.statistics.feature_types.get("inflated_sac",0)==0,"Smooth mimic does not receive mandatory sacs")
	check(smooth.rig.active_legs.is_empty(),"A legless body plan is supported")
	var cached: Dictionary=Cache.build(3002,0,"auto",7,null,settings(2))
	var cached_again: Dictionary=Cache.build(3002,0,"auto",7,null,settings(2))
	check(cached_again.cache_hit,"Mesh cache reads back the same packed organism")
	check(cached.body.vertices==cached_again.body.vertices,"Cache geometry parity")
	var mechanics:=await _mechanics(a)
	var cancellation:=Workshop.BuildControls.new()
	cancellation.cancel()
	check(Pipeline.new().build(1,0,"auto",7,cancellation).get("cancelled",false),"Pre-cancelled build stops")
	await _workshop()
	var report: Dictionary={"schema":"predator_blob_v2_validation","checks":checks,"failures":failures,"seeds":rows,"feature_families":families,"mechanics":mechanics,"note":"Generation timings include validation-host contention. Detailed GPU rendering is measured separately."}
	var file:=FileAccess.open("res://data/blob_v2_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	var complete:=FileAccess.open(OUTPUT.path_join("batch.complete"),FileAccess.WRITE)
	complete.store_string("complete"); complete.close()
	print("BLOB_V2_VALIDATION ",JSON.stringify({"checks":checks,"failures":failures,"mechanics":mechanics}))
	quit(0 if failures.is_empty() else 1)

func _validate_mesh(mesh: Dictionary) -> void:
	check(mesh.vertices.size()==mesh.normals.size(),"Vertex/normal count parity")
	check(mesh.anchors.size()==mesh.vertices.size()*4 and mesh.mechanics.size()==mesh.vertices.size()*4,"Complete material-coordinate deformation bindings")
	check(mesh.colors.size()==mesh.vertices.size() and mesh.uvs2.size()==mesh.vertices.size(),"Complete blended tissue masks")
	var valid:=true
	for point: Vector3 in mesh.vertices:
		if not point.is_finite(): valid=false
	for normal: Vector3 in mesh.normals:
		if not normal.is_finite() or normal.length_squared()<.1: valid=false
	for index: int in mesh.indices:
		if index<0 or index>=mesh.vertices.size(): valid=false
	check(valid,"Finite mesh geometry and valid indices")

func _mechanics(data: Dictionary) -> Dictionary:
	var organism:=Organism.new()
	root.add_child(organism)
	organism.configure(data)
	organism.simulation_enabled=false
	organism.set_locomotion("roll")
	organism.speed=.8
	var r: Vector3=data.dna.core_radii
	var marker:=Vector3(0,r.y,0)
	var before: Vector3=organism.solver.map_point(marker)
	var started:=Time.get_ticks_usec()
	var worst_jump:=.0
	var previous:=before
	for frame in 360:
		if frame==120: organism.speed=.0
		if frame==180: organism.speed=-.65
		organism.simulate(1.0/60.0)
		var point: Vector3=organism.solver.map_point(marker)
		worst_jump=maxf(worst_jump,point.distance_to(previous))
		previous=point
	check(organism.body.basis.is_equal_approx(Basis.IDENTITY),"Body frame does not rigidly rotate")
	check(before.distance_to(previous)>.1,"Actual geometry material point circulates")
	check(worst_jump<.18,"Stopping/reversal preserve continuous tissue trajectories")
	check(organism.solver.spread>1.0 and organism.solver.compression>.0,"Gravity visibly compresses and spreads tissue")
	var determinant: float=(1.0-organism.solver.compression)*pow(organism.solver.spread,2.0)
	check(absf(determinant-1.0)<.12,"Gravity correction approximately preserves volume")
	check(organism.lod_count>0,"Real index-buffer LODs generated")
	check(organism.skeleton.get_bone_count()>1,"Procedural anatomical armature generated")
	check(organism.render_instances.size()<=3,"Anatomy is batched into at most three draws")
	var terrain:=Ground.new()
	root.add_child(terrain)
	organism.terrain=terrain
	organism.travel_enabled=true
	organism.speed=.8
	var origin:=organism.global_position
	for frame in 120: organism.simulate(1.0/60.0)
	check(organism.global_position.distance_to(origin)>.5,"Body translates while tissue circulates")
	check(absf(organism.solver.ground[0]-organism.solver.ground[2])>.05,"Contact probes detect terrain slope")
	var penetration:=.0
	for i in 32:
		var angle:=TAU*float(i)/32.0
		var p: Vector3=organism.solver.map_point(Vector3(0,cos(angle)*r.y,sin(angle)*r.z))
		penetration=maxf(penetration,organism.solver.ground_at(p.x,p.z)-(p.y+organism.solver.height))
	check(penetration<.005,"Deformed contact points remain above sampled terrain")
	for mode in ["drag","undulate","limb","hybrid"]:
		organism.set_locomotion(mode)
		organism.simulate(.016)
		check(organism.locomotion==mode,"Movement profile "+mode)
	var result: Dictionary={"cpu_simulation_us_per_step":float(Time.get_ticks_usec()-started)/480.0,"max_marker_step":worst_jump,"volume_scale_determinant":determinant,"max_sampled_penetration":penetration,"render_groups":organism.render_instances.size(),"lod_buffers":organism.lod_count,"bones":organism.skeleton.get_bone_count()}
	organism.free(); terrain.free()
	return result

func _workshop() -> void:
	var world:=Node3D.new()
	var terrain:=Ground.new()
	terrain.name="Terrain"
	world.add_child(terrain)
	var camera:=Camera3D.new()
	world.add_child(camera)
	root.add_child(world)
	camera.position=Vector3(0,6,10); camera.look_at(Vector3.ZERO); camera.make_current()
	var workshop:=Workshop.new()
	workshop.quality=0
	world.add_child(workshop)
	workshop.generate()
	var deadline:=Time.get_ticks_msec()+30000
	while workshop.worker.is_started() and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(is_instance_valid(workshop.creature),"Game workshop publishes a generated creature")
	workshop.generate()
	world.queue_free()
	await process_frame
	check(not is_instance_valid(workshop),"Scene teardown cancels and joins worker")
