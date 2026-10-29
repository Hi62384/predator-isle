extends "res://tools/caves/check_frozen_features.gd"
const Magma=preload("res://scripts/caves/magma_features.gd")
const Relief=preload("res://scripts/caves/floor_relief.gd")
func floor_at(field,x:float,z:float)->float:
	var low:float=16;var high:float=24
	for iteration in range(18):
		var mid:float=(low+high)*.5
		if field.sample(Vector3(x,mid,z))>=0:low=mid
		else:high=mid
	return (low+high)*.5
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/magma_cave_definition.tres","res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");check(definition.validation_errors().is_empty(),"Bounded cooled-deposit controls validate")
	for invalid in [-.1,.61,NAN,INF,"bad"]:
		var bad:Dictionary=definition.feature_configuration.duplicate();bad.deposit_height=invalid
		check(not definition.surface_provider.new().validation_errors({},bad).is_empty(),"Invalid deposit strength rejected")
	var region:Dictionary=fixture();region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma"
	region.nodes.append({"id":"B","point":Vector3(64,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0})
	region.nodes.append({"id":"C","point":Vector3(96,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.cave_biome_regions.candidates[0].distances["C"]=10000.0
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var settings:Dictionary=definition.feature_configuration.duplicate();settings.cooled_tubes=false
	var grown:Dictionary=Magma.new().decorate_region(region,height,73921,settings,400,10)
	check(grown.get("cave_floor_relief",{}).get("magma",0)==.45,"Actual admitted volcanic vault receives bounded deposit modifier")
	var off_settings:Dictionary=settings.duplicate();off_settings.cooled_deposits=false
	var without:Dictionary=Magma.new().decorate_region(region,height,73921,off_settings,400,10);var stripped:Dictionary=grown.duplicate();stripped.erase("cave_floor_relief")
	check(var_to_bytes(stripped)==var_to_bytes(without),"Deposit OFF restores entire identical volcanic region,without another geometry policy")
	var unassigned:Dictionary=region.duplicate(true);unassigned.cave_biome_regions.candidates=[]
	check(var_to_bytes(Magma.new().decorate_region(unassigned,height,73921,settings,400,10))==var_to_bytes(unassigned),"Unassigned region has exact original dictionary")
	for family:int in [6,7]:
		var locked:Dictionary=region.duplicate(true);locked.cave_family=family
		check(var_to_bytes(Magma.new().decorate_region(locked,height,73921,settings,400,10))==var_to_bytes(locked),"Biological geometry remains exact")
	var field=Field.new();var plain=Field.new();field.include_surface_air=false;plain.include_surface_air=false
	check(field.compile([grown],height,[],grown.cave_biome_regions) and plain.compile([without],height,[],without.cave_biome_regions),"Same production field compiles ON and OFF")
	var protected_errors:int=0;var positive:int=0;var maximum_raise:float=0
	for x in range(-12,113,2):
		for z in range(22,49,2):
			var point:=Vector3(x,20,z)
			if Vector2(x-clampf(x,-16,96),z-32).length()<=4.5:protected_errors+=int(field.sample(point)!=plain.sample(point) or field.normal(point)!=plain.normal(point))
			if x>=52 and x<=76 and z==46:
				var raise:float=floor_at(field,x,z)-floor_at(plain,x,z);maximum_raise=maxf(maximum_raise,raise);positive+=int(raise>.05)
	check(protected_errors==0 and positive>0 and maximum_raise<=.451,"Positive physical deposits with exact protected walking floor and bounded height")
	var world:=Node3D.new();root.add_child(world);var shared:Array=[{},{}]
	for index in range(-1,2):
		var key:=Vector3i(index,0,0);var arrays:Array=Mesher.new().build(field,key,2);check(not arrays.is_empty(),"Actual deposited room meshes")
		var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
		for i in range(faces.size()):
			faces[i]+=Vector3(key)*64
			if index>=0 and faces[i].x==64:shared[index][str(faces[i])]=true
		var body:=StaticBody3D.new();body.name="CaveCollision";var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);child.shape=shape;body.add_child(child);world.add_child(body)
	check(not shared[0].is_empty() and shared[0]==shared[1],"Entire independently built shared cell face exactly welded")
	await physics_frame;await physics_frame
	var route:Array[Vector3]=[]
	for x in range(56,73,2):
		var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,24,46),Vector3(x,16,46),1));check(not hit.is_empty(),"Actual cross-cell native deposit floor present")
		if hit.is_empty():continue
		check(hit.normal.y>=cos(PI/4) and absf(hit.position.y-floor_at(field,x,46))<.12,"Physical cooled flow remains ordinary walkable slope")
		route.append(hit.position+Vector3.UP*.95)
	for i in range(route.size()-2,-1,-1):route.append(route[i])
	await walk(route,"Cooled physical floor across cell seam and same-way return")
	await walk([Vector3(-12,20.95,32),Vector3(96,20.95,32),Vector3(-12,20.95,32)],"Original protected route with cooled deposits")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable volcanic deposit source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_deposits.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"protected_errors":protected_errors,"maximum_raise_m":maximum_raise,"positive_samples":positive,"walks":walks,"scope":"Actual production Magma floor modifier;bounded physical cooled deposits,exact protected passage and OFF dictionary,locked/unassigned controls,full cross-cell mesh seam and two ordinary no-jump native return walks. Controlled fixture,not normal-world full traversal or reference-art acceptance."},"  "));print("MAGMA_DEPOSITS ",checks," raise=",maximum_raise," walks=",walks," failures=",failures);world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
