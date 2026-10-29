extends "res://tools/caves/check_frozen_features.gd"
const Candidate=preload("res://scripts/caves/magma_intrusions.gd")
const Original=preload("res://tools/caves/references/magma_pre_lava_drip_intrusions.gd")
const Private=preload("res://tools/caves/candidate_magma_drip_intrusions.gd")
func run()->void:
	var guards:Dictionary={}
	guards["res://tools/caves/references/magma_pre_lava_drip_intrusions.gd"]=FileAccess.get_sha256("res://tools/caves/references/magma_pre_lava_drip_intrusions.gd")
	for path:String in [get_script().resource_path,"res://tools/caves/candidate_magma_drip_intrusions.gd","res://scripts/caves/magma_intrusions.gd","res://scripts/caves/magma_geometry.gd","res://scripts/caves/measured_formation.gd","res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://tools/caves/check_frozen_features.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],flat,[],region.cave_biome_regions),"Same original volcanic room compiles")
	var rooms:Dictionary={"A":region.nodes[0]};var forms:int=0;var first:Dictionary={};var cases:Array=[]
	for seed_id in range(16):
		var prior:Dictionary=Original.new().build(field,Vector3i.ZERO,seed_id,rooms,.65,8);var disabled:Dictionary=Candidate.new().build(field,Vector3i.ZERO,seed_id,rooms,.65,8,{"lava_drip_frequency":0.0})
		check(var_to_bytes(prior)==var_to_bytes(disabled),"Entire old wall-intrusion payload byte-exact when roof drips are OFF")
		var enabled:Dictionary=Candidate.new().build(field,Vector3i.ZERO,seed_id,rooms,.65,8,{"intrusion_frequency":0.0,"lava_drip_frequency":1.0});forms+=enabled.placements.size();cases.append({"seed":seed_id,"drips":enabled.placements.size()})
		check(var_to_bytes(enabled)==var_to_bytes(Private.new().build(field,Vector3i.ZERO,seed_id,rooms,.65,8,{"intrusion_frequency":0.0,"lava_drip_frequency":1.0})),"Entire actual adopted geometry/collision payload equals independently validated private candidate")
		check(enabled.placements.size()<=2 and enabled.prototype_count<=1,"Only one bounded reused tapered basalt template and two candidate roof drips")
		for placement:Dictionary in enabled.placements:
			check(placement.kind=="basaltic_lava_stalactite" and placement.axis==Vector3.DOWN and placement.height<=2.4 and placement.width<=.45,"Gravity-oriented finite basalt drip,not a glass prism")
			for point:Vector3 in placement.attachments:check(field.sample(point)>=.15,"Whole roof attachment buried in actual solid rock")
		if first.is_empty() and not enabled.placements.is_empty():first=enabled
	check(forms>0,"Positive measured hanging basalt drips across declared16seed ensemble")
	var world:=Node3D.new();root.add_child(world);var body:=StaticBody3D.new();body.name="CaveCollision";var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(Mesher.new().build(field,Vector3i.ZERO,2)[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision);world.add_child(body)
	if not first.is_empty():
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=first.vertices;arrays[Mesh.ARRAY_NORMAL]=first.normals;arrays[Mesh.ARRAY_COLOR]=first.colors;arrays[Mesh.ARRAY_TEX_UV]=first.uv
		check(Renderer.attach(world,[{"biome_id":"magma","kind":"cooled_volcanic","arrays":arrays,"collision_faces":first.collision}],Config.new().biome_regions,false,true),"Actual native opaque basalt material and full hanging-form collision")
	await physics_frame;await physics_frame;await walk([Vector3(12,20.95,32),Vector3(52,20.95,32),Vector3(12,20.95,32)],"Same ordinary protected passage under measured volcanic roof drips")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private lava-drip source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_lava_drip_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"forms":forms,"cases":cases,"walks":walks,"scope":"Adopted bounded numeric roof-drip provider versus independent private candidate;16fixed seeds,explicit drip chance1/intrusion0 mechanism,whole buried roof feet,gravity direction,exact independent original OFF payload and native opaque material/collider/protected return. Normal-world frequency and native artistic certification separate."},"  "));print("MAGMA_LAVA_DRIPS ",checks," forms=",forms," failures=",failures);world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
