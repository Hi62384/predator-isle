extends "res://tools/caves/check_frozen_features.gd"
const SurfaceControls=preload("res://scripts/caves/surface_biomes.gd")
const SurfaceRenderer=preload("res://scripts/caves/surface_renderer.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://config/caves/biomes/frozen_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/frozen_cave_definition.tres");var region:Dictionary=Features.new().decorate_region(fixture(),height,73921,definition.feature_configuration,400,10);var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Real shared frozen basin/rock scalar for hidden entrance-cell upload")
	var base:Array=Mesher.new().build(field,Vector3i.ZERO);var tagged:Dictionary=SurfaceControls.bind(base,field,Vector3i.ZERO);var water:Dictionary=Basins.water_cell([region],field,Vector3i.ZERO);var features:Dictionary=Dispatch.build(field,Vector3i.ZERO,73921,[region],config.biome_regions,water);check(features.valid and not features.batches.is_empty(),"Actual registered provider worker result contains ice geometry")
	var data:Dictionary={"key":Vector3i.ZERO,"valid":true,"groups":{"__interior__":{"arrays":tagged.arrays}},"collision_faces":base[Mesh.ARRAY_VERTEX],"water":water,"features":features.batches,"biome_ids":tagged.ids};var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var interior:ShaderMaterial=stream.material_for(Vector3i.ZERO,tagged.ids);var result:Dictionary=SurfaceRenderer.node(data,{},interior,0);check(result.valid and result.node!=null,"Exact production entrance-cell renderer accepts actual Frozen feature payload")
	if not result.get("valid",false) or result.get("node")==null:quit(1);return
	var node:MeshInstance3D=result.node;root.add_child(node);var body:StaticBody3D=node.get_node("CaveCollision");check(not node.visible and body.collision_layer==0 and body.get_child_count()>=2,"Hidden staged rock/ice/water transaction has no premature collision")
	for frame in range(3):await physics_frame
	var space:PhysicsDirectSpaceState3D=node.get_world_3d().direct_space_state;var query:=PhysicsRayQueryParameters3D.create(Vector3(32,20.5,50),Vector3(32,15,50),1);check(space.intersect_ray(query).is_empty(),"Staged ice cannot block the old world before atomic commit")
	node.visible=true;body.collision_layer=1
	for frame in range(2):await physics_frame
	var hit:Dictionary=space.intersect_ray(query);check(not hit.is_empty() and absf(hit.position.y-(region.pools[0].water_y+Features.ICE_FREEBOARD))<.015,"One atomic original body switch exposes the actual visible ice walking surface")
	SurfaceRenderer.release_uploaded_data(data)
	for name:String in ["groups","collision_faces","water","frontiers","features","biome_ids"]:check(not data.has(name),"Uploaded native resources release redundant numeric worker staging "+name)
	check(not space.intersect_ray(query).is_empty(),"Releasing staging does not invalidate native ice mesh/collision")
	body.collision_layer=0;node.visible=false
	for frame in range(2):await physics_frame
	check(space.intersect_ray(query).is_empty(),"Original transaction close/off switch also disables all ice collision")
	node.queue_free();await process_frame;stream.free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable real Frozen atomic upload "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frozen_atomic_upload.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"scope":"Actual registered Frozen worker payload,production SurfaceRenderer.node interior entrance group,hidden rock/ice collision,atomic one-body activation/native ice ray,CPU staging release preserving native resources,one-body close/off. Actual parent shader transport separately verified;this is not a fabricated complete surface breach or full streamed return."},"  "));print("FROZEN_ATOMIC_UPLOAD ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
