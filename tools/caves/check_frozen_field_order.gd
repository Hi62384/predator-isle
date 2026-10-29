extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/portal_field.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/field.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/surface_biomes.gd","res://scripts/caves/biome_regions.gd","res://scripts/caves/mesher.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	var plain:Dictionary={"id":"default_room","point":Vector3(32,20,32),"level":0,"chamber_radius":24.0,"chamber_height":24.0};var frozen:Dictionary={"id":"A","point":Vector3(35,20,32),"level":0,"chamber_radius":24.0,"chamber_height":24.0};var bridge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([Vector3(35,20,32),Vector3(90,20,32)]),"half_width":4.0,"headroom":8.0,"entrance":false};var ordinary:Dictionary={"from":"default_room","to":"C","points":PackedVector3Array([Vector3(-10,20,32),Vector3(32,20,32)]),"half_width":4.0,"headroom":8.0,"entrance":false}
	var region:Dictionary={"valid":true,"id":Vector2i.ZERO,"nodes":[plain,frozen],"edges":[bridge,ordinary]};var reversed:Dictionary=region.duplicate(true);reversed.nodes.reverse();reversed.edges.reverse();var assignment:Dictionary={"fallback":"default","candidates":[{"id":"A/frozen","biome_id":"frozen","reach_m":200.0,"transition_m":32.0,"distances":{"A":0.0,"B":55.0}}]};var first=Field.new();first.include_surface_air=false;var second=Field.new();second.include_surface_air=false
	check(first.compile([region],height,[],assignment) and second.compile([reversed],height,[],assignment),"Same physically intersecting Default/Frozen rooms and routes,opposite generation orders")
	var records:Array=[];var point_mismatches:int=0
	for y:float in [20.0,20.001,20.5,21.0,24.0]:
		for x in range(20,50):
			var point:=Vector3(x,y,32);var a:Vector4=first.biome_weights_at(point,["frozen"]);var b:Vector4=second.biome_weights_at(point,["frozen"])
			if a!=b:point_mismatches+=1
			check(a==b,"Material/formation scalar is independent of room/route generation order,including exact shared floor ties")
			check(first.sample(point)==second.sample(point),"Original signed physical volume remains exactly order-independent")
			if y==20 and x in [30,32,34,36]:records.append({"point":str(point),"first":str(a),"reversed":str(b)})
	var original:Array=Mesher.new().build(first,Vector3i.ZERO);var reverse_mesh:Array=Mesher.new().build(second,Vector3i.ZERO);check(var_to_bytes(original)==var_to_bytes(reverse_mesh),"Whole original mesh geometry/normal/mineral channels exact across order")
	var a:Dictionary=Surface.bind(original,first,Vector3i.ZERO);var b:Dictionary=Surface.bind(reverse_mesh,second,Vector3i.ZERO);check(var_to_bytes(a)==var_to_bytes(b),"Complete actual GPU material controls independent of compile/discovery order")
	check(first.biome_weights_at(Vector3(34,20,32),["frozen"]).x==1,"Full accepted Frozen geography covers an equal-floor physical union instead of a first-inserted Default hole")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable coincident cave-biome scalar source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frozen_field_order.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"point_mismatches":point_mismatches,"tie_records":records,"scope":"Exact intersecting real shared-field room/route/floor ties under opposite node/edge generation order;physical scalar and full native mesh must remain exact,biome point/UV controls deterministic,accepted specialized union not erased by Default insertion order. Controlled order regression,not world occurrence/native walk/art completion."},"  "));print("FROZEN_FIELD_ORDER ",checks," mismatches=",point_mismatches," failures=",failures);quit(0 if failures.is_empty() else 1)
