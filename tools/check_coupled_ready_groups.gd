extends SceneTree
const Ready=preload("res://scripts/terrain_ready_cut.gd")
const Planner=preload("res://scripts/terrain_partition.gd")
func _initialize()->void:
	var planner=Planner.new();var left:=Vector3i(0,0,2);var right:=Vector3i(1,0,2);var distant:=Vector3i(4,0,2)
	var active:Dictionary={left:true,right:true,distant:true};var wanted:Dictionary={};var ready:Dictionary={}
	for parent:Vector3i in [left,right,distant]:
		for y in range(4):
			for x in range(4):wanted[Vector3i(parent.x*4+x,y,0)]=true
	for key:Vector3i in wanted:
		if Ready.contains(left,key):ready[key]=true
	assert(Ready.choose(active,wanted,ready,planner,Vector2(1000,100)).is_empty(),"One refined parent cannot expose an unsafe edge to its unready neighbor")
	for key:Vector3i in wanted:
		if Ready.contains(right,key):ready[key]=true
	var change:Dictionary=Ready.choose(active,wanted,ready,planner,Vector2(1000,100))
	assert(change.get("remove",[]).size()==2 and change.get("add",[]).size()==32,"Mutually dependent ready neighbors commit together without waiting for distant work")
	assert(not change.remove.has(distant),"Unready distant parent remains complete")
	for key:Vector3i in change.remove:active.erase(key)
	for key:Vector3i in change.add:active[key]=true
	var sum:int=0
	for key:Vector3i in active:sum+=Ready.area(key)
	assert(sum==3*Ready.area(left),"Coupled transaction preserves exact old coverage")
	print("COUPLED_READY_GROUPS passed:32 ready children replace two parents atomically while distant parent stays intact");quit()
