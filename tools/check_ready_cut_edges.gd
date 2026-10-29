extends SceneTree
const Ready=preload("res://scripts/terrain_ready_cut.gd")
const Planner=preload("res://scripts/terrain_partition.gd")
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array[String]=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var planner=Planner.new();var fine:=Vector3i(3,0,2);var retained:=Vector3i(1,0,4);var planned:=Vector3i(2,0,3)
	var wanted:Dictionary={fine:true,planned:true};var resolutions:Dictionary={fine:32,retained:32};var desired:Dictionary={fine:32,planned:16}
	var proof:Dictionary=Ready.equivalent_edge(fine,retained,wanted,resolutions,desired,planner)
	verify(not proof.is_empty(),"A retained large mesh can stand in for an identical planned edge grid")
	resolutions[retained]=16;verify(Ready.equivalent_edge(fine,retained,wanted,resolutions,desired,planner).is_empty(),"Different coarse spacing cannot bypass the balance gate")
	resolutions[retained]=31;verify(Ready.equivalent_edge(fine,retained,wanted,resolutions,desired,planner).is_empty(),"Non-power-of-two coarse grids retain the conservative path")
	resolutions[retained]=32;desired[planned]=32;verify(Ready.equivalent_edge(fine,retained,wanted,resolutions,desired,planner).is_empty(),"A finer planned neighbor cannot be replaced by a coarser old edge")
	for seed_id:int in [73921,17,92881]:
		var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_id;b._configure_noise()
		b.chunk_size=4096;var old:Array=b.build(Vector2i(1,0),32)
		b.chunk_size=2048;var replacement:Array=b.build(Vector2i(2,0),16)
		# The fine leaf shares the first1024m of these two coarse edges.
		# Compare every endpoint and every32m interpolated boundary position.
		for i in range(9):
			verify(old[Mesh.ARRAY_VERTEX][i*33].y==replacement[Mesh.ARRAY_VERTEX][i*17].y,"Exact canonical coarse endpoints on the actual edge")
			verify(old[Mesh.ARRAY_NORMAL][i*33]==replacement[Mesh.ARRAY_NORMAL][i*17],"Exact coarse edge normals")
		for i in range(33):
			var p:float=i*.25;var index:int=mini(floori(p),7);var t:float=p-index
			var original:float=lerpf(old[Mesh.ARRAY_VERTEX][index*33].y,old[Mesh.ARRAY_VERTEX][(index+1)*33].y,t)
			var actual:float=lerpf(replacement[Mesh.ARRAY_VERTEX][index*17].y,replacement[Mesh.ARRAY_VERTEX][(index+1)*17].y,t)
			verify(original==actual,"Every interpolated edge point matches the approved final neighbor")
	print("READY_CUT_EDGES ",checks," checks failures=",failures);quit(0 if failures.is_empty() else 1)
