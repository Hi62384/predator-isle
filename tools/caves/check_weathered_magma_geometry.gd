extends "res://tools/caves/check_frozen_features.gd"
const Magma=preload("res://tools/caves/candidate_weathered_magma_features.gd")
const MagmaGeometry=preload("res://tools/caves/candidate_weathered_magma_geometry.gd")
const Shapes=preload("res://scripts/caves/formations.gd")
const Measured=preload("res://scripts/caves/measured_formation.gd")
func run()->void:
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://tools/caves"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://config/caves/biomes/magma_cave_definition.tres","res://shaders/cave_magma_cooled.gdshader"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");check(definition!=null and definition.validation_errors().is_empty(),"Requested independent22percent/300–1100m Magma Resource and provider contracts validate")
	check(definition.spawn_chance_percent==22 and definition.depth_preferences==PackedFloat32Array([0,5,30,80,100]) and definition.surface_preferences.volcanic==100,"Requested controls preserved;no depth-only lava")
	var geometry=MagmaGeometry.new()
	for family in range(3):
		var points:PackedVector3Array=geometry.prototype(family);check(not points.is_empty() and points.size()%3==0 and var_to_bytes(points)==var_to_bytes(geometry.prototype(family)),"Bounded deterministic volcanic habit "+str(family))
		for i in range(0,points.size(),3):check((points[i+2]-points[i]).cross(points[i+1]-points[i]).length_squared()>.000000001,"Every volcanic prototype facet finite and nondegenerate")
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var original:PackedByteArray=var_to_bytes(region)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var generator=Magma.new();var grown:Dictionary=generator.decorate_region(region,height,73921,definition.feature_configuration,400,10)
	check(var_to_bytes(region)==original and grown.nodes[0].point==region.nodes[0].point,"Cooled vault growth immutable and same original floor")
	var field=Field.new();field.include_surface_air=false;check(field.compile([grown],height,[],grown.cave_biome_regions),"Same canonical rock field compiles cooled vault")
	var forms:int=0;var batches:Array=[];var cases:Array=[];var all_kinds:Dictionary={}
	for seed_id:int in [17,73921,92881]:
		var result:Dictionary=generator.build(field,Vector3i.ZERO,seed_id,[grown],definition.feature_configuration,{})
		check(result.valid and var_to_bytes(result)==var_to_bytes(generator.build(field,Vector3i.ZERO,seed_id,[grown],definition.feature_configuration,{})),"Entire cooled payload exact repeat "+str(seed_id));check(result.placements.size()<=64 and result.prototype_count<=10,"Per-cell work and ten reused prototype bounds")
		forms+=result.placements.size();cases.append({"seed":seed_id,"forms":result.placements.size(),"rejections":result.rejections})
		for placement:Dictionary in result.placements:
			all_kinds[placement.kind]=true;check(placement.owner==Vector3i.ZERO and field.cell(placement.root)==Vector3i.ZERO,"Canonical root cell ownership")
			for contact:Vector3 in placement.attachments:check(field.sample(contact)>=.15,"Entire volcanic foot buried in measured rock")
			check(not Shapes.new().protected(field,placement.bounds.get_center(),Vector2(placement.bounds.size.x,placement.bounds.size.z).length()*.5,placement.bounds.position.y,placement.bounds.end.y),"Complete volcanic formation excludes protected walking route")
		for batch:Dictionary in result.batches:
			check(batch.arrays[Mesh.ARRAY_VERTEX].size()<=24000 and batch.arrays[Mesh.ARRAY_VERTEX].size()==batch.arrays[Mesh.ARRAY_NORMAL].size() and batch.collision_faces.size()%3==0,"Bounded native arrays and whole matching collision faces")
			if seed_id==73921:batch["biome_id"]="magma";batches.append(batch)
	var disabled:Dictionary=definition.feature_configuration.duplicate();disabled.density=0;check(generator.build(field,Vector3i.ZERO,73921,[grown],disabled,{}).batches.is_empty(),"Zero feature density exact empty")
	check(forms>0 and all_kinds.has("jointed_basalt_column") and all_kinds.has("volcanic_block"),"Positive measured basalt columns and volcanic blocks across fixed seeds")
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var parent:=Node3D.new();root.add_child(parent);var body:=StaticBody3D.new();body.name="CaveCollision";parent.add_child(body);var mesh_arrays:Array=Mesher.new().build(field,Vector3i.ZERO,2);var rock_shape:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(mesh_arrays[Mesh.ARRAY_VERTEX]);rock_shape.shape=shape;body.add_child(rock_shape)
	check(Renderer.attach(parent,batches,config.biome_regions,false,true),"Actual native renderer uploads opaque Magma material/mesh/LOD and matching collision")
	await physics_frame;await physics_frame
	await walk([Vector3(12,20.95,32),Vector3(52,20.95,32),Vector3(12,20.95,32)],"Controlled cooled basalt original protected route")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_weathered_magma_geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"forms":forms,"kinds":all_kinds.keys(),"cases":cases,"walks":walks,"scope":"Controlled native cooled-geology foundation only. Magma not registered;no actual molten pools,normal world survey,reference art or complete Magma return certified."},"  "));print("MAGMA_COOLED ",checks," forms=",forms," failures=",failures);quit(0 if failures.is_empty() else 1)
