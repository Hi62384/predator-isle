extends SceneTree
const Solver=preload("res://tools/caves/cave_route_solver_candidate.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func stations(origin:Vector2,length_m:float,step:float)->PackedVector2Array:
	var points:=PackedVector2Array()
	for i in range(ceili(length_m/step)+1):points.append(origin+Vector2(minf(i*step,length_m),sin(minf(i*step,length_m)/length_m*TAU)*15))
	return points
func validate(result:Dictionary,path:PackedVector2Array,field:Callable,grade:float,start:float,end:float)->void:
	check(result.valid,"Declared feasible route accepted")
	if not result.valid:return
	check(result.points.size()==path.size(),"No skipped stations or disconnected partial output")
	check(absf(result.points[0].y-start)<.0001 and absf(result.points[-1].y-end)<.0001,"Both fixed endpoint floors preserved")
	for i in range(path.size()):
		var p:Vector3=result.points[i];check(p.is_finite() and Vector2(p.x,p.z)==path[i],"Actual route plan XZ preserved")
		if i>0:check(absf(p.y-result.points[i-1].y)<=path[i].distance_to(path[i-1])*grade+.0001,"Every actual station pair respects conservative return grade")
		var tangent:Vector2=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized();var side:=Vector2(-tangent.y,tangent.x)
		for offset:float in [-6.0,-3.0,0.0,3.0,6.0]:
			var q:Vector2=path[i]+side*offset;var surface:float=field.call(q.x,q.y);check(surface-p.y<=398.0001 and surface-p.y-8>=9.9999,"Finite local canonical depth AND roof across full sampled corridor width")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/cave_route_solver_candidate.gd","res://tools/caves/check_route_solver.gd"]:guards[path]=FileAccess.get_sha256(path)
	var path:PackedVector2Array=stations(Vector2(-300,-400),600,4);var flat:Callable=func(_x:float,_z:float)->float:return 120
	validate(Solver.solve(path,flat,4,8,10,400,.2,60,-40),path,flat,.2,60,-40)
	var sloping:Callable=func(x:float,z:float)->float:return 200+x*.04+sin(z/70)*8
	validate(Solver.solve(path,sloping,4,8,10,400,.2,110,10),path,sloping,.2,110,10)
	var valley:Callable=func(x:float,_z:float)->float:return 160-95*exp(-pow(x/70,2))
	validate(Solver.solve(path,valley,4,8,10,400,.2,100,100),path,valley,.2,100,100)
	var impossible:Callable=func(x:float,_z:float)->float:return 1000 if absf(x)<20 else 100
	var rejected:Dictionary=Solver.solve(path,impossible,4,8,10,400,.2,50,50);check(not rejected.valid and rejected.points.is_empty(),"Impossible mountain/depth/slope constraints fail closed without a partial inaccessible route")
	var reversed:PackedVector2Array=path.duplicate();reversed.reverse();var forward:Dictionary=Solver.solve(path,flat,4,8,10,400,.2,60,-40);var backward:Dictionary=Solver.solve(reversed,flat,4,8,10,400,.2,-40,60);check(forward.valid and backward.valid,"Route feasible in both input orders,not downhill-only")
	for invalid in [PackedVector2Array(),PackedVector2Array([Vector2.ZERO,Vector2.ZERO]),PackedVector2Array([Vector2.INF,Vector2.ZERO])]:check(not Solver.solve(invalid,flat,4,8,10,400,.2,0,0).valid,"Invalid/zero length/nonfinite plans fail closed")
	for path_id:String in guards:check(FileAccess.get_sha256(path_id)==guards[path_id],"Stable private route solver source "+path_id)
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"production_registration":false,"scope":"PRIVATE cave dependency: two-pass constrained return-grade route planning against canonical surface across five lateral samples per station. Finite400mdepth/10mroof/8mheadroom;fixed endpoints and conservative20percentgrade. Flat/sloping/valley/negative-world/reversed/invalid/impossible envelopes. This is ONLY numeric route planning,not graph connectivity,SDF/mesh/native capsule/entrance/streaming/art or an installed cave system."}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_route_solver.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CAVE_ROUTE_SOLVER ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
func _initialize()->void:call_deferred("run")
