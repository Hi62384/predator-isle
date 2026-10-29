extends "res://tools/caves/check_frozen_features.gd"
const Magma=preload("res://scripts/caves/magma_features.gd")
const Original=preload("res://tools/caves/references/magma_pre_intrusion_features.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://tools/caves/references/magma_pre_intrusion_features.gd","res://config/caves/biomes/magma_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";region.nodes.append({"id":"B","point":Vector3(80,20,32),"level":0,"chamber_radius":22.0,"chamber_height":24.0})
	var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var settings:Dictionary=load("res://config/caves/biomes/magma_cave_definition.tres").feature_configuration.duplicate();settings.chamber_variety=true;settings.cooled_tubes=false
	var off:Dictionary=settings.duplicate();off.chamber_variety=false;var profiles:Dictionary={};var cases:Array=[]
	for seed_id in range(32):
		check(var_to_bytes(Original.new().decorate_region(region,flat,seed_id,off,400,10))==var_to_bytes(Magma.new().decorate_region(region,flat,seed_id,off,400,10)),"Independent old chamber policy restored exactly when variety OFF")
		var grown:Dictionary=Magma.new().decorate_region(region,flat,seed_id,settings,400,10)
		check(grown.nodes[0].point==region.nodes[0].point and grown.nodes[1].point==region.nodes[1].point and var_to_bytes(grown.edges)==var_to_bytes(region.edges),"Province shapes retain original graph and exact floors")
		check(grown.nodes[0].magma_profile==grown.nodes[1].magma_profile,"One geological province coherently styles both connected rooms")
		var name:String=grown.nodes[0].magma_profile
		if profiles.has(name):continue
		profiles[name]=true;cases.append({"seed":seed_id,"profile":name,"radius":grown.nodes[0].chamber_radius,"height":grown.nodes[0].chamber_height})
		var field=Field.new();field.include_surface_air=false;check(field.compile([grown],flat,[],grown.cave_biome_regions),"Actual province shape compiles shared field")
		var world:=Node3D.new();root.add_child(world)
		for key:Vector3i in [Vector3i.ZERO,Vector3i(1,0,0)]:
			var arrays:Array=Mesher.new().build(field,key,2);var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			for i in range(faces.size()):faces[i]+=Vector3(key)*64
			var body:=StaticBody3D.new();var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);child.shape=shape;body.add_child(child);world.add_child(body)
		await physics_frame;await physics_frame;await walk([Vector3(12,20.95,32),Vector3(80,20.95,32),Vector3(12,20.95,32)],"Actual "+name+" same original protected two-way passage")
		world.queue_free();await process_frame;await physics_frame
	check(profiles.size()==5,"Fixed32seed ensemble covers all five actual volcanic province shapes")
	for family:int in [6,7]:
		var locked:Dictionary=region.duplicate(true);locked.cave_family=family;check(var_to_bytes(Magma.new().decorate_region(locked,flat,17,settings,400,10))==var_to_bytes(locked),"Biological ownership excludes every geological profile")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable province source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_provinces.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"profiles":cases,"walks":walks,"scope":"Five actual same-province volcanic chamber geometries across32seeds;original graph/floors/independent old OFF/biological locks. All five shapes meshed with native collision and ordinary protected two-way passage. Controlled ensemble,not normal frequency or reference-art acceptance."},"  "));print("MAGMA_PROVINCES ",checks," profiles=",cases," failures=",failures);quit(0 if failures.is_empty() else 1)
