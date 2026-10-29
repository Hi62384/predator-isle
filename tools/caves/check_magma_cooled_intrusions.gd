extends "res://tools/caves/check_frozen_features.gd"
const Magma=preload("res://scripts/caves/magma_features.gd")
const Intrusions=preload("res://scripts/caves/magma_intrusions.gd")
const Original=preload("res://tools/caves/references/magma_pre_intrusion_features.gd")
const Shapes=preload("res://scripts/caves/formations.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/references/magma_pre_intrusion_features.gd","res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/biomes/magma_cave_definition.tres","res://shaders/cave_magma_cooled.gdshader"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma"
	var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],flat,[],region.cave_biome_regions),"Same controlled host compiles")
	var kinds:Dictionary={};var settings:Dictionary=load("res://config/caves/biomes/magma_cave_definition.tres").feature_configuration.duplicate();settings.cooled_intrusions=true;settings.lava_drip_frequency=0.0
	var off:Dictionary=settings.duplicate();off.cooled_intrusions=false;var forms:int=0;var all_batches:Array=[];var cases:Array=[]
	for seed_id:int in [17,19,73921,92881,1000,1001,1002,1003]:
		var old:Dictionary=Original.new().build(field,Vector3i.ZERO,seed_id,[region],off,{});var disabled:Dictionary=Magma.new().build(field,Vector3i.ZERO,seed_id,[region],off,{})
		check(var_to_bytes(old)==var_to_bytes(disabled),"Entire independent original OFF placement/LOD/collision payload exact")
		var result:Dictionary=Magma.new().build(field,Vector3i.ZERO,seed_id,[region],settings,{})
		check(result.valid and var_to_bytes(result)==var_to_bytes(Magma.new().build(field,Vector3i.ZERO,seed_id,[region],settings,{})),"All measured intrusion geometry deterministic")
		check(result.placements.size()<=64 and result.prototype_count<=10,"Shared64form/10template budget retained")
		var added:int=0
		for placement:Dictionary in result.placements:
			if not placement.has("axis"):continue
			added+=1;forms+=1;kinds[placement.kind]=true
			check(placement.owner==Vector3i.ZERO and field.cell(placement.root)==Vector3i.ZERO and placement.collider,"Complete opaque slab has canonical owner and real collider")
			for point:Vector3 in placement.attachments:check(field.sample(point)>=.15,"Whole dike/sill/solidified-flow foot buried in measured host wall")
			check(not Shapes.new().protected(field,placement.bounds.get_center(),Vector2(placement.bounds.size.x,placement.bounds.size.z).length()*.5,placement.bounds.position.y,placement.bounds.end.y),"Whole intrusion excludes mandatory walking routes")
		check(added<=8,"At most eight additional attached slabs in one cell")
		cases.append({"seed":seed_id,"intrusions":added})
		if seed_id==73921:all_batches=result.batches
	check(kinds.size()==3 and forms>0,"Actual positive dike,sill and solidified cascade across fixed ensemble")
	var world:=Node3D.new();root.add_child(world);var body:=StaticBody3D.new();body.name="CaveCollision";var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(Mesher.new().build(field,Vector3i.ZERO,2)[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);world.add_child(body)
	for batch:Dictionary in all_batches:batch["biome_id"]="magma"
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));check(Renderer.attach(world,all_batches,config.biome_regions,false,true),"Production single opaque batch and full wall-slab collision uploaded together")
	await physics_frame;await physics_frame;await walk([Vector3(12,20.95,32),Vector3(52,20.95,32),Vector3(12,20.95,32)],"Original ordinary protected passage return with attached volcanic intrusions")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable cooled intrusion source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_cooled_intrusions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"forms":forms,"kinds":kinds.keys(),"cases":cases,"walks":walks,"scope":"Controlled eight-seed positive three-kind opaque measured-wall intrusive geometry,whole attachments/protected route/budgets/determinism and byte-exact independent old OFF. Same native renderer/collision and ordinary no-jump return;not a claim of exposed molten cascades,normal-world occurrence or reference-art acceptance."},"  "));print("MAGMA_COOLED_INTRUSIONS ",checks," forms=",forms," kinds=",kinds.keys()," cases=",cases," failures=",failures);world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
