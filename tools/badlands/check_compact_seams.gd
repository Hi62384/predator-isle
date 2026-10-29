extends SceneTree
## Measure compact terrain against adjacent world-aligned coarse edge chords.
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var records:Array=[];var actual_segments:int=0
	for seed_id:int in [73921,17,92881]:
		var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_id
		for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:builder.settings.set(key+"_coverage",0)
		builder.settings.badlands_coverage=100;builder.settings.rocky_coast_enabled=false;builder.settings.beaches_enabled=false;builder._configure_noise()
		# Verify the actual mesh's near skirt depth, not just a copied formula.
		builder.chunk_size=256;var mesh:Array=builder.build(Vector2i.ZERO,64)
		builder._get_height(0,0);var first_delta:float=builder._last_badlands_skirt;builder._get_height(4,0)
		var expected_depth:float=32+maxf(first_delta,builder._last_badlands_skirt)
		check(absf(mesh[Mesh.ARRAY_VERTEX][0].y-mesh[Mesh.ARRAY_VERTEX][65*65].y-expected_depth)<.001,"Actual four-metre mesh skirt includes only the local added feature height")
		var field=builder._badlands;var sites:Array=[]
		for lane in range(-24,25):
			for index in range(-72,73):
				for side in [-1,1]:
					var tree:Dictionary=field._tree(index,lane,side)
					if tree.random>=field.settings.remnants:continue
					for formation:Dictionary in field._remnant_formations(tree,index,lane,side):
						var p:Vector2=formation.position
						if builder._island_mask(p.x,p.y)<.1 or field.region_weights(p)[5]<.99:continue
						field.sample(p.x,p.y)
						if field.state[10]>.99:sites.append(formation)
						if sites.size()==24:break
					if sites.size()==24:break
				if sites.size()==24:break
			if sites.size()==24:break
		check(sites.size()>=8,"Real inland compact formations admitted")
		for pair:Vector3 in [Vector3(256,4,16),Vector3(1024,16,32),Vector3(2048,32,64),Vector3(4096,64,128),Vector3(8192,128,256)]:
			var maximum_fine_gap:float=0;var maximum_coarse_gap:float=0;var exercised:int=0;var worst:Vector2=Vector2.ZERO
			var uncovered_fine:float=0;var uncovered_coarse:float=0;var extended_fine:float=maxf(32,pair.y*4)
			for site:Dictionary in sites:
				var p:Vector2=site.position
				for axis in range(2):
					var boundary:float=roundf(p[axis]/pair.x)*pair.x
					if absf(boundary-p[axis])>150:continue
					var other:int=1-axis;var low:int=floori((p[other]-150)/pair.y);var high:int=ceili((p[other]+150)/pair.y)
					for station in range(low,high+1):
						var q:Vector2=p;q[axis]=boundary;q[other]=station*pair.y
						var fine:float=builder._get_height(q.x,q.y);var influenced:bool=builder._last_badlands_remnant>.000001;var fine_delta:float=builder._last_badlands_skirt
						var start:Vector2=q;start[other]=floorf(q[other]/pair.z)*pair.z;var end:Vector2=start;end[other]+=pair.z
						var t:float=(q[other]-start[other])/pair.z
						var start_height:float=builder._get_height(start.x,start.y);var start_delta:float=builder._last_badlands_skirt
						var end_height:float=builder._get_height(end.x,end.y);var end_delta:float=builder._last_badlands_skirt
						var coarse:float=lerpf(start_height,end_height,t)
						if not influenced:continue
						exercised+=1;actual_segments+=1
						if fine-coarse>maximum_fine_gap:maximum_fine_gap=fine-coarse;worst=q
						maximum_coarse_gap=maxf(maximum_coarse_gap,coarse-fine)
						var fine_depth:float=maxf(32,pair.y*4)+fine_delta
						var coarse_depth:float=maxf(32,pair.z*4)+maxf(start_delta,end_delta)
						extended_fine=maxf(extended_fine,fine_depth)
						uncovered_fine=maxf(uncovered_fine,fine-coarse-fine_depth);uncovered_coarse=maxf(uncovered_coarse,coarse-fine-coarse_depth)
			var fine_skirt:float=maxf(32,pair.y*4);var coarse_skirt:float=maxf(32,pair.z*4)
			check(uncovered_fine<=.001,"Feature-aware fine skirt covers compact coarse-edge discrepancy: seed "+str(seed_id)+" / "+str(pair))
			check(uncovered_coarse<=.001,"Feature-aware coarse skirt covers compact fine-edge discrepancy: seed "+str(seed_id)+" / "+str(pair))
			records.append({"seed":seed_id,"chunk_span_m":pair.x,"fine_step_m":pair.y,"coarse_step_m":pair.z,"influenced_edge_samples":exercised,"fine_gap_m":maximum_fine_gap,"coarse_gap_m":maximum_coarse_gap,"fine_skirt_m":fine_skirt,"coarse_skirt_m":coarse_skirt,"maximum_feature_extended_fine_skirt_m":extended_fine,"uncovered_fine_m":uncovered_fine,"uncovered_coarse_m":uncovered_coarse,"worst_fine_position":worst})
	check(actual_segments>32,"Actual compact edge samples exercised")
	var result:Dictionary={"checks":checks,"failures":failures,"influenced_edge_samples":actual_segments,"records":records,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"builder_sha256":FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd"),"scope":"Actual inland caprock at world-aligned adjacent-LOD edge chords across three seeds; compares discrepancies to current visual skirts. Not all-world seam, transition or collision certification."}
	FileAccess.open("res://tools/badlands/artifacts/check_compact_seams.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_COMPACT_SEAMS ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
