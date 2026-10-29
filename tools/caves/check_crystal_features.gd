extends "res://tools/caves/check_frozen_features.gd"
const Crystal=preload("res://scripts/caves/crystal_features.gd")
const CrystalGeometry=preload("res://scripts/caves/crystal_geometry.gd")
const CrystalSurface=preload("res://scripts/caves/crystal_surface.gd")
func crystal_fixture()->Dictionary:
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="crystal";region.cave_biome_regions.candidates[0].id="A/crystal";region.cave_biome_regions.candidates[0]["anchor"]="A";region.nodes[0].chamber_height=46.0;return region
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://scripts/caves/crystal_features.gd","res://scripts/caves/crystal_geometry.gd","res://scripts/caves/crystal_surface.gd","res://shaders/cave_crystal_feature.gdshader","res://shaders/cave_crystal_surface.gdshaderinc","res://shaders/crystal_bulk_optics.gdshaderinc","res://scripts/biome_extension_structures.gd","res://scripts/caves/field.gd","res://scripts/caves/feature_renderer.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");check(definition!=null and definition.validation_errors().is_empty(),"Normal requested Crystal definition and numeric/material provider contracts validate")
	var geometry=CrystalGeometry.new();var primitive_records:Array=[]
	for family in range(6):
		for broken:bool in [false,true]:
			var arrays:Array=geometry.prototype(family,broken);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];check(not vertices.is_empty() and vertices.size()%3==0,"Existing canonical crystal prototype positive "+str(family))
			for i in range(0,vertices.size(),3):check(vertices[i].is_finite() and (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).length_squared()>.00000001 and normals[i]==normals[i+1] and normals[i]==normals[i+2],"Finite nondegenerate HARD flat-facet mineral geometry,not smoothed ice")
			check(var_to_bytes(arrays)==var_to_bytes(geometry.prototype(family,broken)),"Bounded prototype exact repeat");primitive_records.append({"family":family,"broken":broken,"vertices":vertices.size()})
	check(geometry.templates.size()==12,"At most twelve numeric shared primitive variants,not unique high-poly per crystal")
	var region:Dictionary=crystal_fixture();var original:PackedByteArray=var_to_bytes(region)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var generator=Crystal.new();var grown:Dictionary=generator.decorate_region(region,height,73921,definition.feature_configuration,400,10);check(var_to_bytes(region)==original and grown.nodes[0].chamber_radius>=26 and grown.nodes[0].chamber_height>=46,"Safe same-floor crystal vault enlargement does not mutate original cached graph")
	var disabled:Dictionary=definition.feature_configuration.duplicate();disabled.chamber_growth=false;check(var_to_bytes(generator.decorate_region(region,height,73921,disabled,400,10))==original,"Independent chamber-growth off returns complete original region")
	var low_roof:Callable=func(_x:float,_z:float)->float:return 60.0
	check(var_to_bytes(generator.decorate_region(region,low_roof,73921,definition.feature_configuration,400,10))==original,"No clipping through insufficient real rock cover")
	var field=Field.new();field.include_surface_air=false;check(field.compile([grown],height,[],grown.cave_biome_regions),"Crystal vault uses same sparse bounded field and original protected route")
	var configuration:Dictionary=definition.feature_configuration.duplicate();configuration.density=1.0;var cases:Array=[];var families:Dictionary={};var count:int=0;var colliders:int=0;var thin:int=0;var lods:int=0;var largest:float=0;var minimum_area_squared:float=INF;var small_positive_facets:int=0;var first_payload:Dictionary={};var seed_values:Array=[73921,17,92881]
	for i in range(33):seed_values.append(1000+i)
	for seed_id:int in seed_values:
		var total:int=0;var per_seed:Array=[]
		for key:Vector3i in [Vector3i.ZERO,Vector3i(0,1,0)]:
			var payload:Dictionary=generator.build(field,key,seed_id,[grown],configuration,{})
			check(payload.valid and var_to_bytes(payload)==var_to_bytes(Crystal.new().build(field,key,seed_id,[grown],configuration,{})),"Complete measured Crystal cold/repeated geometry/ownership/colliders/LOD indices deterministic")
			if seed_id==73921 and key==Vector3i.ZERO:first_payload=payload
			for placement:Dictionary in payload.placements:
				count+=1;total+=1;families[str(placement.family)]=true;largest=maxf(largest,placement.height);colliders+=int(placement.collider);thin+=int(placement.thin_transmission)
				check(field.cell(placement.root)==key and placement.owner==key,"One half-open canonical root owner regardless of long crystal crossing cell boundary")
				var bounds:AABB=placement.bounds;check(not generator.shapes.protected(field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,bounds.position.y,bounds.end.y),"Entire giant/angled form excluded from protected passage capsule volume")
				for contact:Vector3 in placement.attachments:check(field.sample(contact)>=.15,"ENTIRE crystal foot buried in measured rock,not floating center-point support")
				var vertices:PackedVector3Array=payload.batches.filter(func(item:Dictionary)->bool:return item.kind==placement.batch)[0].arrays[Mesh.ARRAY_VERTEX]
				for i in range(placement.first_vertex,placement.first_vertex+placement.vertex_count,3):
					var a:Vector3=vertices[i];var b:Vector3=vertices[i+1];var c:Vector3=vertices[i+2];var area_squared:float=(c-a).cross(b-a).length_squared();minimum_area_squared=minf(minimum_area_squared,area_squared)
					if area_squared>0 and area_squared<=.00000001:small_positive_facets+=1
					check(area_squared>0,"Measured attachment retains strictly positive flat facets,including physically small quartz tip caps")
			for batch:Dictionary in payload.batches:
				check(batch.collision_faces.size()%3==0 and batch.arrays[Mesh.ARRAY_VERTEX].size()==batch.arrays[Mesh.ARRAY_NORMAL].size(),"Whole native triangles and matching complete arrays")
				for threshold:float in batch.lods:
					lods+=1;var indices:PackedInt32Array=batch.lods[threshold];check(indices.size()%3==0 and indices.size()<batch.arrays[Mesh.ARRAY_VERTEX].size(),"Native ArrayMesh LOD strictly reduces full surface and retains complete stable forms/valid indices")
					for index:int in indices:check(index>=0 and index<batch.arrays[Mesh.ARRAY_VERTEX].size(),"Every native LOD index in the unchanged shared vertex array")
			per_seed.append({"cell":str(key),"forms":payload.placements.size(),"batches":payload.batches.size(),"prototypes":payload.prototype_count})
		cases.append({"seed":seed_id,"forms":total,"cells":per_seed})
	check(count>100 and families.size()==6 and largest>12 and colliders>0 and thin>0 and lods>0,"Fixed predeclared36-seed ensemble has all six families,giants,selective thin forms,large colliders and native LODs")
	var off:Dictionary=configuration.duplicate();off.density=0;check(generator.build(field,Vector3i.ZERO,73921,[grown],off,{}).batches.is_empty(),"Independent numeric feature-off mode exact empty,not new cave air")
	var registry:Resource=FrozenFixture.registry(load("res://config/caves/cave_biome_regions.tres"),definition);var world:=Node3D.new();root.add_child(world);var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;world.add_child(body)
	for key:Vector3i in [Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0),Vector3i(0,1,0)]:
		var arrays:Array=Mesher.new().build(field,key,2)
		if not arrays.is_empty():
			var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			for i in range(faces.size()):faces[i]+=Vector3(key)*64
			shape.set_faces(faces);collision.shape=shape;body.add_child(collision)
	for batch:Dictionary in first_payload.batches:batch["biome_id"]="crystal"
	check(Renderer.attach(world,first_payload.batches,registry,true,true),"Actual production batched near/far/LOD selective collider upload")
	var native_nodes:int=0
	for node:Node in world.get_children():
		if node is MeshInstance3D:native_nodes+=1;check(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>0,"Uploaded native mineral batch positive")
	check(native_nodes<=4 and body.get_child_count()>0,"Batched few native objects,not one scene/physics node per crystal")
	await physics_frame;await physics_frame
	await walk([Vector3(-12,20.95,32),Vector3(32,20.95,32),Vector3(92,20.95,32),Vector3(32,20.95,32),Vector3(-12,20.95,32)],"Crystal-protected104m route and exact same dry return")
	world.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Crystal geometry/native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_features.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"prototypes":primitive_records,"cases":cases,"families":families.keys(),"forms":count,"colliders":colliders,"thin":thin,"lod_levels":lods,"largest_height_m":largest,"minimum_triangle_cross_squared":minimum_area_squared,"physically_small_positive_facets":small_positive_facets,"native_nodes":native_nodes,"walks":walks,"scope":"Private positive actual shared-volume controlled chamber with36predeclared seeds/allcases,existing six mineral prototypes,full measured roots,protected giant bounds,native batches/LOD index upload/selective near screen optics and ordinary capsule dry-route return. Density1 isolates form breadth,normal world density remains.65. Earlier absolute1e-8 triangle cross-squared test failure preserved;current exact-zero rejection matches scale-independent mesh semantics and records all positive tiny tip caps. Not normal world occurrence,rendered cave art,full live streaming/FPS,Crystal or all-user completion."},"  "));print("CRYSTAL_FEATURES ",checks," forms=",count," families=",families," largest=",largest," thin=",thin," native=",native_nodes," small_positive=",small_positive_facets," minimum=",minimum_area_squared," failures=",failures.slice(0,6));quit(0 if failures.is_empty() else 1)
