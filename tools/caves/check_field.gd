extends SceneTree
const Field=preload("res://tools/caves/cave_field_candidate.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/cave_field_candidate.gd","res://tools/caves/check_field.gd"]:guards[path]=FileAccess.get_sha256(path)
	var surface:Callable=func(_x:float,_z:float)->float:return 100
	var region:Dictionary={"valid":true,"nodes":[{"point":Vector3(0,-8,0),"level":0,"chamber_radius":14.0,"chamber_height":14.0}],"edges":[]}
	for pair:Array in [[Vector3(-40,-8,0),Vector3(40,-8,0)],[Vector3(0,-8,-40),Vector3(0,-8,40)],[Vector3(30,-8,0),Vector3(58,-13.6,0)]]:
		region.edges.append({"points":PackedVector3Array(pair),"half_width":4.0,"headroom":8.0,"entrance":false})
	var field=Field.new();check(field.compile([region],surface),"Sparse joined field compiles complete original numeric paths/chamber")
	var all:=PackedInt32Array()
	for i in range(field.begins.size()):all.append(i)
	var maximum:float=0;var samples:int=0
	for y in range(-16,9,2):
		for z in range(-72,73,4):
			for x in range(-72,73,4):
				var p:=Vector3(x,y,z);var a:float=field.sample(p);var reference:float=field.evaluate(p,all);maximum=maxf(maximum,absf(a-reference));check(absf(a-reference)<.000001,"Sparse bins exactly match independent complete feature scan at all signed/boundary points");samples+=1
	for x in range(-30,31):
		check(absf(field.sample(Vector3(x,-8,0)))<.000001,"Main route has a broad flat floor,not a circular-pipe bottom")
		for lateral:float in [-1.0,0.0,1.0]:
			for height_m:float in [.1,.9,1.8,2.8]:check(field.sample(Vector3(x,-8+height_m,lateral))<0,"Whole declared capsule envelope plus meaningful clearance stays inside air")
	check(field.sample(Vector3(0,-7.5,0))<0,"Joined chamber and orthogonal paths share one air volume without internal walls")
	check(field.normal(Vector3(25,-8,0)).dot(Vector3.UP)>.9999,"Exact floor gradient points into cave air")
	var clipped=Field.new();var deep:Dictionary={"valid":true,"nodes":[],"edges":[{"points":PackedVector3Array([Vector3(-10,-398,0),Vector3(10,-398,0)]),"half_width":4.0,"headroom":8.0,"entrance":false}]};clipped.compile([deep],func(_x:float,_z:float)->float:return 10)
	check(clipped.sample(Vector3(0,-397,0))>0,"Canonical finite depth removes invalid deep air,not a fixed world-Y floor")
	var shallow:Dictionary={"valid":true,"nodes":[],"edges":[{"points":PackedVector3Array([Vector3(-10,95,0),Vector3(10,95,0)]),"half_width":4.0,"headroom":8.0,"entrance":false}]};clipped.compile([shallow],surface);check(clipped.sample(Vector3(0,96,0))>0,"Closed cave never accidentally pierces minimum roof")
	shallow.edges[0].entrance=true;clipped.compile([shallow],surface);check(clipped.sample(Vector3(0,96,0))<0,"Only explicit intended entrance feature bypasses closed roof constraint")
	check(field.sample(Vector3.INF)==4 and field.sample(Vector3.ONE*1e20)==4,"Nonfinite/unrepresentable queries fail closed before indexing")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private cave field source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_field.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"features":field.begins.size(),"query_buckets_16m":field.bins.size(),"mesh_chunks_64m":field.chunks.size(),"numeric_array_bytes_excluding_keys_and_objects":field.numeric_bytes(),"independent_full_scan_points":samples,"maximum_sparse_full_error":maximum,"production_registration":false,"scope":"PRIVATE shared Default Cave dependency: sparse16m3 query bins separated from unchanged64m3mesh cells,continuous implicit union of broad-floor arched3D corridors/chambers,12cm wall-only relief,canonical400mdepth/10mclosedroof clips and explicit intentional-entry exemption. Signed/boundary sparse/full scan identity,capsule-envelope point samples and flat inward floor normal;negative depth/roof/invalid controls. Numeric array bytes exclude Dictionary keys/object/hash overhead. Native meshing tested separately;not real portals,streaming/materials/art or installed caves."},"  "));print("CAVE_FIELD ",checks," max_sparse_error=",maximum," failures=",failures);quit(0 if failures.is_empty() else 1)
func _initialize()->void:call_deferred("run")
