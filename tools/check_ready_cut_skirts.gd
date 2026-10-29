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
	var planner=Planner.new();var a:=Vector3i(1,0,2);var bkey:=Vector3i(1,0,3)
	var positive:int=0
	for seed_id:int in [73921,17,92881]:
		var builder=Builder.new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_id;builder._configure_noise()
		builder.chunk_size=1024;var fine:Array=builder.build(Vector2i(1,0),32)
		builder.chunk_size=2048;var coarse:Array=builder.build(Vector2i(1,0),16)
		var fp:Dictionary=Ready.edge_profiles(fine,32);var cp:Dictionary=Ready.edge_profiles(coarse,16)
		var profiles:Dictionary={a:fp,bkey:cp};var resolutions:Dictionary={a:32,bkey:16}
		var proof:Dictionary=Ready.covered_edge(a,bkey,resolutions,profiles,planner)
		if not proof.is_empty():positive+=1;verify(proof.segments_checked==32 and proof.maximum_grid_ratio==4,"Entire actual shared edge checked at its finest segments")
		# Collapse the actual east skirt above the adjacent edge to create a
		# deliberate visible gap;the same rule must reject that geometry.
		var broken:Dictionary=fp.duplicate(true)
		for i in range(32):broken[1].bottom0[i]=1e8;broken[1].bottom1[i]=1e8
		profiles[a]=broken;verify(Ready.covered_edge(a,bkey,resolutions,profiles,planner).is_empty(),"A real uncovered skirt gap is rejected")
		profiles[a]=fp;resolutions[bkey]=8;verify(Ready.covered_edge(a,bkey,resolutions,profiles,planner).is_empty(),"Mismatched profile metadata is rejected")
		profiles[bkey]=Ready.edge_profiles(builder.build(Vector2i(1,0),8),8)
		var wide:Dictionary=Ready.covered_edge(a,bkey,resolutions,profiles,planner)
		verify(not wide.is_empty() and wide.maximum_grid_ratio==8 and wide.segments_checked==32,"Covered eightfold actual mesh edges pass their complete segment proof")
		verify(Ready.covered_edge(a,bkey,{a:32,bkey:16},{},planner).is_empty(),"Missing edge evidence cannot enable a transition")
	verify(positive>0,"Actual generated terrain supplies positive safe curtain-overlap cases")
	print("READY_CUT_SKIRTS ",checks," positive=",positive," failures=",failures);quit(0 if failures.is_empty() else 1)
