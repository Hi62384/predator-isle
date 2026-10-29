extends SceneTree
var checks:int=0
var failures:Array[String]=[]
func _initialize()->void:
	var source:String=FileAccess.get_sha256("res://scripts/badlands_sampler.gd");var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for relief:float in [.2,1,2]:
			for spacing:float in [1000,1400,4000]:
				var host=preload("res://scripts/terrain_mesh_builder.gd").new();host.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);host.world_seed=seed_id
				host.settings.badlands.relief=relief;host.settings.badlands.drainage_spacing=spacing;host._configure_noise()
				var field=preload("res://scripts/badlands_sampler.gd").new();field.configure(host.settings.badlands,seed_id,host)
				var reference=preload("res://tools/badlands/reference_unbounded_sampler.gd").new();reference.configure(host.settings.badlands.duplicate_deep(Resource.DEEP_DUPLICATE_ALL),seed_id,host)
				reference._use_segment_index=false;reference._use_grade_bound=false;reference._tree_radius_override=5
				var points:Array[Vector2]=[]
				for i in range(80):points.append(Vector2(i*7919%200000-100000,i*11939%200000-100000))
				# Check both sides of the root-neighbour lookup boundary and the
				# actual conservative envelopes, not just random interior points.
				for index in range(-2,3):
					var tree:Dictionary=field._tree(index,0,1);var bound:Vector4=tree.support_bounds
					for delta:float in [-.01,0,.01]:
						points.append(Vector2(index*spacing+delta,tree.root.z+tree.extent*.8))
						points.append(Vector2(bound.x+delta,(bound.y+bound.w)*.5))
						points.append(Vector2(bound.z+delta,(bound.y+bound.w)*.5))
				for p:Vector2 in points:
					var actual:PackedFloat64Array=field._raw(p);var expected:PackedFloat64Array=reference._raw(p);checks+=1
					if actual!=expected:failures.append("seed="+str(seed_id)+" relief="+str(relief)+" spacing="+str(spacing)+" point="+str(p))
				cases.append({"seed":seed_id,"relief":relief,"spacing_m":spacing,"points":points.size()})
	assert(FileAccess.get_sha256("res://scripts/badlands_sampler.gd")==source,"Source changed during bound comparison")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"cases":cases,"sampler_sha256":source,"scope":"Exact all-channel comparison against eleven neighbouring trees without catchment bounds, segment bins or grade rejection; legal relief/spacing extremes, three seeds and actual envelope/lookup boundaries. Not an all-world hydrology proof."}
	FileAccess.open("res://tools/badlands/artifacts/check_catchment_support.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_CATCHMENT_SUPPORT ",checks," comparisons; failures=",failures);quit(0 if failures.is_empty() else 1)
