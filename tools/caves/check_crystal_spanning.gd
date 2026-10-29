extends "res://tools/caves/check_crystal_features.gd"
const Previous:String="res://tools/biome_extensions/artifacts/revisions/experiment_render_cave_crystal_first_normal_geode_559e849ba054/sources/scripts/caves/crystal_features.gd.txt"
func run()->void:
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,Previous,"res://tools/caves/check_crystal_features.gd","res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var previous:=GDScript.new();previous.source_code=FileAccess.get_file_as_string(Previous);check(previous.reload()==OK,"Independent frozen complete pre-spanning generator compiles")
	var region:Dictionary=crystal_fixture();region.nodes[0].chamber_height=24.0
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Same existing protected-route field,not a new cave volume")
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var off:Dictionary=definition.feature_configuration.duplicate();off.spanning_crystals=false;off.crystal_debris=false;off.localized_veins=false;off.corridor_growth=false;off.luminous_minerals=false;off.shallow_chambers=false;off.lake_chambers=false;var mismatches:int=0
	for seed_id:int in [73921,17,92881]:
		for cell:Vector3i in [Vector3i.ZERO,Vector3i(0,1,0)]:
			mismatches+=int(var_to_bytes(previous.new().build(field,cell,seed_id,[region],off,{}))!=var_to_bytes(Crystal.new().build(field,cell,seed_id,[region],off,{})))
	check(mismatches==0,"Spanning,debris,vein localization AND corridor growth OFF complete frozen geometry/normal/UV/collider/LOD/rejection payloads remain byte exact")
	var generated:int=0;var repeat_mismatches:int=0;var zero_mismatches:int=0;var generated_records:Array=[];var seeded:Dictionary=definition.feature_configuration.duplicate();seeded.density=1.0;seeded.giant_chance=1.0;seeded.spanning_crystals=true;seeded.spanning_chance=1.0
	for seed_id:int in [73921,17,92881,1000,1001,1002,1003,1004,1005,1006,1007,1008]:
		var result:Dictionary=Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],seeded,{});var joined_count:int=0
		for placement:Dictionary in result.placements:
			if placement.get("spanning",false):joined_count+=1
		generated+=joined_count;repeat_mismatches+=int(var_to_bytes(result)!=var_to_bytes(Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],seeded,{})));var zero:Dictionary=off.duplicate();zero.spanning_crystals=true;zero.spanning_chance=0.0;zero_mismatches+=int(var_to_bytes(Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],zero,{}))!=var_to_bytes(Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],off,{})));generated_records.append({"seed":seed_id,"spanning":joined_count,"valid":result.valid})
	check(generated>0 and repeat_mismatches==0,"Existing regular patch generator emits deterministic true joined minerals in fixed12seed breadth cohort")
	check(zero_mismatches==0,"Independent zero spanning chance restores complete prior payloads")
	var generator=Crystal.new();generator.build(field,Vector3i.ZERO,73921,[],{"density":0},{});var joined:int=0;var records:Array=[]
	for family:int in range(4):
		var start:=Vector3(40+family*2,23,46);var root_point:Vector3=generator.boundary(field,start,Vector3.DOWN,8);var axis:=Vector3(.06,1,.03).normalized();var accepted:bool=generator.spanning_form(field,root_point,axis,.45,32,family,.2,"span/"+str(family),.2);check(accepted,"Real two-ended angled column positive for canonical mineral "+str(family))
		if not accepted:continue
		joined+=1;var placement:Dictionary=generator.placements[-1];check(placement.spanning and placement.height>=8 and placement.height<=32 and placement.collider and placement.importance==0,"Bounded full-silhouette joined column has real collision and stable owner")
		check(placement.far_attachments.size()>=5 and placement.attachments.size()>placement.far_attachments.size(),"Both complete cap rings and centers recorded,not a single contact point")
		for p:Vector3 in placement.attachments:check(field.sample(p)>=.15,"Every near AND far contact is buried in measured real rock")
		var bounds:AABB=placement.bounds;check(not generator.shapes.protected(field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,bounds.position.y,bounds.end.y),"Complete tilted span bounds preserve mandatory path")
		records.append({"family":family,"height_m":placement.height,"contacts":placement.attachments.size(),"far_contacts":placement.far_attachments.size()})
	check(joined==4,"All four elongated habits have true joined geometry")
	var before:int=generator.placements.size();check(not generator.spanning_form(field,Vector3(32,20,32),Vector3.UP,.6,32,0,.2,"blocked",0) and generator.placements.size()==before,"Mandatory route blocks joined column without emitting partial geometry")
	check(not generator.spanning_form(field,Vector3(40,20,46),Vector3.UP,.45,4,0,.2,"too-short",0),"Insufficient reach cannot invent a floating far attachment")
	var world:=Node3D.new();root.add_child(world);var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;world.add_child(body)
	for cell:Vector3i in [Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0)]:
		var arrays:Array=Mesher.new().build(field,cell,2)
		if not arrays.is_empty():
			var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			for index in range(faces.size()):faces[index]+=Vector3(cell)*64
			shape.set_faces(faces);collision.shape=shape;body.add_child(collision)
	for batch:Dictionary in generator.batches.values():
		var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(batch.collision_faces);collision.shape=shape;body.add_child(collision)
	await physics_frame;await physics_frame;await walk([Vector3(-12,20.95,32),Vector3(32,20.95,32),Vector3(92,20.95,32),Vector3(32,20.95,32),Vector3(-12,20.95,32)],"Ordinary capsule passes joined columns and returns by same route")
	world.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable spanning source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_spanning.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"generated_records":generated_records,"generated_spans":generated,"walks":walks,"off_mismatches":mismatches,"zero_mismatches":zero_mismatches,"scope":"Controlled positive four real two-ended mineral habits,whole near/far feet,original route exclusion,existing batched native colliders,ordinary same-way capsule return. Six complete disabled payload comparisons against frozen independent pre-spanning generator. Twelve fixed breadth seeds force giant/span chances1,not normal occurrence;normal editable chance remains.15. Not native imagery/FPS/full-user completion."},"  "));print("CRYSTAL_SPANNING ",checks," joined=",joined," generated=",generated," records=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
