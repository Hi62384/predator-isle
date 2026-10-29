extends SceneTree
const Ready=preload("res://scripts/terrain_ready_cut.gd")
const Planner=preload("res://scripts/terrain_partition.gd")
var failures:Array[String]=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func validate(active:Dictionary,planner)->void:
	var keys:Array=active.keys()
	for i in keys.size():
		for j in range(i+1,keys.size()):
			verify(not Ready.contains(keys[i],keys[j]) and not Ready.contains(keys[j],keys[i]),"No parent-child overlap")
			verify(not planner.adjacent(keys[i],keys[j]) or absi(keys[i].z-keys[j].z)<=1,"Balanced visible LOD edge")
func _initialize()->void:call_deferred("run")
func run()->void:
	var planner=Planner.new();planner.maximum_level=6;planner.split_ratio=.95;planner.merge_ratio=1.3
	var parent:=Vector3i(-1,-1,2);var active:Dictionary={parent:true};var children:Array[Vector3i]=planner.children(parent);var wanted:Dictionary={};var ready:Dictionary={}
	for child:Vector3i in children:wanted[child]=true
	for i in range(3):ready[children[i]]=true
	verify(Ready.choose(active,wanted,ready,planner,Vector2.ZERO).is_empty(),"Incomplete sibling group retains its whole parent")
	ready[children[3]]=true;var change:Dictionary=Ready.choose(active,wanted,ready,planner,Vector2.ZERO)
	verify(change.get("remove",[])==[parent] and change.get("add",[]).size()==4,"All four ready children replace parent together")
	var coarse:=Vector3i(0,-1,3);active[coarse]=true
	verify(Ready.choose(active,wanted,ready,planner,Vector2.ZERO).is_empty(),"A locally complete group cannot introduce an illegal coarse edge")
	var swaps:int=0;var early:int=0
	for point:Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(-8193,400),Vector2(40000,-10000)]:
		active=planner.select(point,{})
		for delta:Vector2 in [Vector2(600,0),Vector2(-1200,700),Vector2(17000,-9000)]:
			wanted=planner.select(point+delta,active);ready={};var original_area:int=0
			for key:Vector3i in active:original_area+=Ready.area(key)
			var ordered:Array=wanted.keys();ordered.sort_custom(func(a:Vector3i,b:Vector3i)->bool:return planner.distance_to(a,point+delta)<planner.distance_to(b,point+delta))
			for key:Vector3i in ordered:
				if active.has(key):continue
				ready[key]=true
				while true:
					change=Ready.choose(active,wanted,ready,planner,point+delta)
					if change.is_empty():break
					for removed:Vector3i in change.remove:
						var replacement_area:int=0
						for added:Vector3i in change.add:
							if Ready.contains(added,removed):replacement_area=Ready.area(removed);break
							if Ready.contains(removed,added):replacement_area+=Ready.area(added)
						verify(replacement_area==Ready.area(removed),"Every removed region retains complete replacement coverage")
					for removed:Vector3i in change.remove:active.erase(removed)
					for added:Vector3i in change.add:active[added]=true;ready.erase(added)
					swaps+=1
					if not ready.is_empty() or ordered.find(key)<ordered.size()-1:early+=1
					validate(active,planner)
					var current_area:int=0
					for leaf:Vector3i in active:current_area+=Ready.area(leaf)
					verify(current_area>=original_area,"Local swaps retain complete old coverage;new outside cells may extend it")
			active=wanted.duplicate();validate(active,planner)
	verify(swaps>0 and early>0,"Actual moving plans publish detail before the full replacement is ready")
	print("READY_CUT ",checks," checks swaps=",swaps," early=",early," failures=",failures);quit(0 if failures.is_empty() else 1)
