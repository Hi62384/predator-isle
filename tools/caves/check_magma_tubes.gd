extends "res://tools/caves/check_frozen_features.gd"
const Tubes=preload("res://scripts/caves/magma_tubes.gd")
const DefaultShapes=preload("res://scripts/caves/formations.gd")
const Checkpoint:String="res://tools/biome_extensions/artifacts/revisions/experiment_cave_crystal_registered_checkpoint_3c7ec7dc5c1e/sources/scripts/caves/formations.gd.txt"
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,Checkpoint,"res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var original:PackedByteArray=var_to_bytes(region);var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var profiles:Dictionary={};var first:Dictionary={}
	for seed_id in range(32):
		var widened:Dictionary=Tubes.decorate(region,flat,seed_id,{"cooled_tubes":true},400,10);check(var_to_bytes(region)==original,"Tube admission never mutates original cached graph")
		check(widened.edges[0].has("magma_tube_profile") and widened.edges[0].half_width>=6 and widened.edges[0].headroom>=12,"Positive bounded existing passage widening")
		check(var_to_bytes(widened.edges[0].points)==var_to_bytes(region.edges[0].points) and widened.edges[0].from==region.edges[0].from and widened.edges[0].to==region.edges[0].to,"Same exact solved stations,endpoints,grade and graph identity")
		profiles[str(widened.edges[0].magma_tube_profile)]=true
		if first.is_empty():first=widened
	check(profiles.size()==4 and profiles.has("great_volcanic_fissure"),"Fixed32seed ensemble covers broad/high/irregular cooled tubes and tall volcanic fissures")
	check(var_to_bytes(Tubes.decorate(region,flat,73921,{"cooled_tubes":false},400,10))==original,"Independent tube OFF exact prior graph")
	var shallow:Callable=func(_x:float,_z:float)->float:return 44.0
	check(var_to_bytes(Tubes.decorate(region,shallow,73921,{},400,10))==original,"Insufficient rock roof rejects complete tube growth")
	for family:int in [6,7]:
		var biological:Dictionary=region.duplicate(true);biological.cave_family=family;check(var_to_bytes(Tubes.decorate(biological,flat,73921,{},400,10))==var_to_bytes(biological),"Biological ownership cannot admit generic volcanic tube geometry")
	var other_floor:Dictionary=region.duplicate(true);other_floor.nodes.append({"id":"crossing_floor","point":Vector3(50,26,32),"level":1,"chamber_radius":20.0,"chamber_height":20.0});check(var_to_bytes(Tubes.decorate(other_floor,flat,73921,{},400,10))==var_to_bytes(other_floor),"Other-height floors prevent incompatible cut-throughs")
	var before=Field.new();var after=Field.new();before.include_surface_air=false;after.include_surface_air=false;check(before.compile([region],flat,[],region.cave_biome_regions) and after.compile([first],flat,[],first.cave_biome_regions),"Original and widened shared fields compile")
	var mismatch:int=0
	for x in range(-12,93,2):
		for y:float in [19.999,20.0,20.001]:mismatch+=int(absf(before.sample(Vector3(x,y,32))-after.sample(Vector3(x,y,32)))>.002)
	check(mismatch==0,"Same original longitudinal floor within2mm across full passage,not only endpoints")
	var old_shapes:=GDScript.new();old_shapes.source_code=FileAccess.get_file_as_string(Checkpoint);check(old_shapes.reload()==OK,"Immutable old default formation source loads independently")
	var cold_region:Dictionary=fixture();cold_region.erase("pools");var cold=Field.new();cold.include_surface_air=false;check(cold.compile([cold_region],flat,[],cold_region.cave_biome_regions),"Cold non-Magma fixture compiles")
	for seed_id:int in [17,73921,92881]:check(var_to_bytes(old_shapes.new().build(cold,Vector3i.ZERO,seed_id,0,1))==var_to_bytes(DefaultShapes.new().build(cold,Vector3i.ZERO,seed_id,0,1)),"Entire original cold Default calcite payload byte-exact "+str(seed_id))
	check(DefaultShapes.new().build(after,Vector3i.ZERO,73921,0,1).placements.is_empty(),"Full cooled volcanic influence excludes generic calcite instead of universal stalactites")
	var arrays:Array=Mesher.new().build(after,Vector3i.ZERO,2);var body:=StaticBody3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);root.add_child(body);await physics_frame;await physics_frame;await walk([Vector3(12,20.95,32),Vector3(52,20.95,32),Vector3(12,20.95,32)],"Widened cooled tube same original no-jump protected return")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable tube source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_tubes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"profiles":profiles.keys(),"floor_mismatches":mismatch,"walks":walks,"scope":"Controlled32seed/3tube-shape ensemble;exact original solved stations/graph identity,protected grades/floors/roof/other-height exclusion/biological locks/OFF. Independent old Default formation payload exact outside Magma;full volcanic influence suppresses generic calcite. Same native shared rock capsule return,not full normal live Magma route/art/FPS certification."},"  "));print("MAGMA_TUBES ",checks," profiles=",profiles.keys()," failures=",failures);quit(0 if failures.is_empty() else 1)
