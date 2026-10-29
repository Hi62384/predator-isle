extends "res://tools/caves/check_frozen_features.gd"
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Materials=preload("res://scripts/caves/biome_materials.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/field.gd","res://scripts/caves/biome_regions.gd","res://scripts/caves/biome_materials.gd","res://scripts/caves/biome_blend.gd","res://scripts/caves/surface_biomes.gd","res://scripts/caves/frozen_surface.gd","res://scripts/caves/crystal_surface.gd","res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var registry:Resource=FrozenFixture.registry(load("res://config/caves/cave_biome_regions.tres"),load("res://config/caves/biomes/crystal_cave_definition.tres"));var records:Array=[];var last_field
	for family in [6,7]:
		var candidates:Array=[]
		for id:String in ["frozen","crystal"]:candidates.append({"id":"A/"+id,"biome_id":id,"anchor":"A","distances":{"A":0.0,"B":64.0},"reach_m":1000.0,"transition_m":48.0,"connected_growth":id=="crystal"})
		var a:Dictionary={"valid":true,"id":Vector2i.ZERO,"nodes":[{"id":"A","level":1,"point":Vector3(1504,20,32),"chamber_radius":26.0,"chamber_height":36.0}],"edges":[],"cave_biome_regions":{"candidates":candidates,"edges":[]}}
		var b:Dictionary={"valid":true,"id":Vector2i(1,0),"cave_family":family,"cross_section_style":7 if family==7 else 0,"nodes":[{"id":"B","level":1,"point":Vector3(1568,20,32),"chamber_radius":26.0,"chamber_height":36.0}],"edges":[]}
		var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([a.nodes[0].point,b.nodes[0].point]),"half_width":4.0,"headroom":8.0,"entrance":false};var assignment:Dictionary=Regions.combine([a,b],[edge]);check(not assignment.candidates[0].distances.has("B"),"Independent Crystal geodesic candidate cannot use locked biological hub as a bridge")
		var field=Field.new();field.include_surface_air=false;check(field.compile([a,b],height,[edge],assignment),"Same physical generic/biological connected air volume compiles")
		var unlocked:Dictionary=b.duplicate(true);unlocked.erase("cave_family");var reference=Field.new();reference.include_surface_air=false;check(reference.compile([a,unlocked],height,[edge],assignment),"Independent scalar-lock-off physical reference retains identical chamber/edge styles")
		var minimum:float=INF;var maximum:float=0;var previous:float=INF
		for x in range(1480,1593):
			var p:=Vector3(x,22,32);check(field.sample(p)==reference.sample(p),"Biological lock changes no physical volume/support/roof")
			var w:Vector4=field.biome_weights_at(p,["crystal","frozen"]);var amount:float=w.x+w.y;var old:Vector4=reference.biome_weights_at(p,["crystal","frozen"]);var admission:float=smoothstep(0,32,maxf(1536-x,0));check((w-old*admission).length()<.000001,"Both real local scalar channels fade before biological ownership,not only a display label")
			if x>=1536:check(w==Vector4.ZERO,"No ice/mineral scalar leak into biological material-owned cell")
			if x>=1504 and x<=1536:check(amount<=previous+.000001,"Monotonic32m generic-side biological boundary fade");previous=amount
			minimum=minf(minimum,amount);maximum=maxf(maximum,amount)
		var mesh_triangles:int=0
		for key:Vector3i in [Vector3i(23,0,0),Vector3i(24,0,0)]:
			var actual:Array=Mesher.new().build(field,key,2);var old:Array=Mesher.new().build(reference,key,2);check(var_to_bytes(actual)==var_to_bytes(old),"Complete native physical rock mesh byte-identical with biological scalar lock on/off");mesh_triangles+=actual[Mesh.ARRAY_VERTEX].size()/3
			var bound:Dictionary=Surface.bind(actual,field,key)
			if key.x==24:
				check(bound.ids.is_empty() and var_to_bytes(bound.arrays)==var_to_bytes(actual),"Biological cell has no foreign adapter channels or changed UV payload")
				var hive:Shader=load("res://shaders/hive_cave.gdshader");check(Materials.shader(hive,bound.ids,registry)==hive,"Exact original biological shader survives connected specialized generic neighbor without null material")
			else:check(bound.ids==["crystal","frozen"] and Materials.shader(load("res://shaders/default_cave_rock.gdshader"),bound.ids,registry)!=null,"Generic-side material supports actual combined Crystal/Frozen adapter")
		check(maximum>.5 and minimum==0 and mesh_triangles>0,"Positive specialized material outside and exact locked biology inside,not an all-zero fixture")
		records.append({"biological_family":family,"maximum_outside_specialized_sum":maximum,"minimum_inside_sum":minimum,"complete_mesh_triangles":mesh_triangles});last_field=field
	var world:=Node3D.new();root.add_child(world);var body:=StaticBody3D.new();world.add_child(body)
	for key:Vector3i in last_field.chunks:
		var arrays:Array=Mesher.new().build(last_field,key,2)
		if arrays.is_empty():continue
		var node:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
		for i in range(faces.size()):faces[i]+=Vector3(key)*64
		shape.set_faces(faces);node.shape=shape;body.add_child(node)
	await physics_frame;await physics_frame
	await walk([Vector3(1500,20.95,32),Vector3(1536,20.95,32),Vector3(1572,20.95,32),Vector3(1536,20.95,32),Vector3(1500,20.95,32)],"Ordinary generic↔locked Hive connector exact surface-level return")
	world.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable biological boundary source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_biological_biome_boundary.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"walks":walks,"scope":"Controlled real shared field/native rock geometry at actual1536m material ownership boundary for both Insect/Hive. Complete physical meshes byte-identical lock on/off,actual Crystal+Frozen scalars smoothly fade outside,locked cell exact original UV/shader identity,no null foreign adapter,ordinary connected-capsule return. Not a normal mixed-world discovery/rendered-art/streaming/FPS proof."},"  "));print("BIOLOGICAL_BIOME_BOUNDARY ",checks," ",records," failures=",failures);quit(0 if failures.is_empty() else 1)
