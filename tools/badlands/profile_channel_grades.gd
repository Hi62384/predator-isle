extends SceneTree
## Diagnostic: descriptor direction alone does not prove final bed direction.
func trace_descent(builder,start:Vector3)->Dictionary:
	var p:=Vector2(start.x,start.z);var h:float=builder._get_height(p.x,p.y)
	var initial_height:float=h;var length:float=0;var path:Array=[p]
	for iteration in range(600):
		builder._get_height(p.x,p.y)
		var field=builder._badlands
		if field.state[8]>.75 or field.state[14]>.5:
			return {"terminal":"primary_wash_or_retained_basin","start":start,"end":p,"fall_m":initial_height-h,"length_m":length,"steps":iteration,"path":path}
		var next:Vector2=p;var low:float=h
		for step:float in [8.0,2.0,.5]:
			for sector in range(16):
				var q:Vector2=p+Vector2(cos(sector*TAU/16),sin(sector*TAU/16))*step
				var candidate:float=builder._get_height(q.x,q.y)
				if candidate<low-.00001:low=candidate;next=q
			if next!=p:break
		if next==p:
			var escape:Array=[]
			for radius:float in [1.0,2.0,4.0,8.0,16.0,32.0,64.0,128.0]:
				var ring_min:float=INF
				for sector in range(32):
					var q:Vector2=p+Vector2(cos(sector*TAU/32),sin(sector*TAU/32))*radius
					ring_min=minf(ring_min,builder._get_height(q.x,q.y))
				escape.append({"radius_m":radius,"minimum_height_above_pit_m":ring_min-h})
			return {"terminal":"local_depression_at_half_metre_probe","start":start,"end":p,"height_m":h,"raw_field_height_m":builder._badlands._raw(p)[0],"fall_m":initial_height-h,"length_m":length,"steps":iteration,"path":path,"escape_rings":escape}
		length+=p.distance_to(next);p=next;h=low
		if iteration%8==0:path.append(p)
	return {"terminal":"trace_distance_budget","start":start,"end":p,"fall_m":initial_height-h,"length_m":length,"path":path}
func _initialize()->void:
	var cases:Array=[];var reversed:Array=[];var traces:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_id
		for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
		b.settings.badlands_coverage=100;b.settings.rocky_coast_enabled=false;b.settings.beaches_enabled=false;b._configure_noise();var count:int=0
		var uncut=preload("res://scripts/terrain_mesh_builder.gd").new();uncut.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);uncut.settings.badlands.secondary_gullies=0;uncut.settings.badlands.erosion=0;uncut.world_seed=seed_id;uncut._configure_noise()
		for lane in range(-12,13):
			for index in range(-36,37):
				for side in [-1,1]:
					var tree:Dictionary=b._badlands._tree(index,lane,side)
					var per_tree:int=0;var per_order:Dictionary={}
					for edge:Array in tree.edges:
						if edge[2]<1 or edge[2]>3:continue
						if int(per_order.get(edge[2],0))>=(2 if edge[2]==3 else 1):continue
						var middle:Vector3=edge[0].lerp(edge[1],.5)
						if b._island_mask(middle.x,middle.z)<.1:continue
						var w:PackedFloat32Array=b._badlands.region_weights(Vector2(middle.x,middle.z))
						if w[8]+w[9]+w[14]+w[15]>.2:continue
						var heights:Array=[];var positions:Array=[];var caprock:bool=false;var minimum_incision:float=INF;var maximum_incision:float=0
						for station in range(9):
							var p:Vector3=edge[0].lerp(edge[1],.1+station*.1)
							heights.append(b._get_height(p.x,p.z));positions.append(p)
							caprock=caprock or b._last_badlands_remnant>.001
							var incision:float=uncut._get_height(p.x,p.z)-heights[-1];minimum_incision=minf(minimum_incision,incision);maximum_incision=maxf(maximum_incision,incision)
						if caprock:continue
						var record:Dictionary={"seed":seed_id,"order":edge[2],"tree":Vector3i(index,lane,side),"descriptor_upstream_rise_m":edge[1].y-edge[0].y,"physical_upstream_rise_m":heights[-1]-heights[0],"minimum_network_incision_m":minimum_incision,"maximum_network_incision_m":maximum_incision,"fully_incised_samples":minimum_incision>.5,"positions":positions,"heights":heights}
						cases.append(record);count+=1;per_tree+=1;per_order[edge[2]]=int(per_order.get(edge[2],0))+1
						if record.physical_upstream_rise_m < -2:
							reversed.append(record)
							if record.fully_incised_samples:traces.append({"seed":seed_id,"tree":record.tree,"order":record.order,"trace":trace_descent(b,positions[4])})
						if count>=80:break
						if per_tree>=4:break
					if count>=80:break
				if count>=80:break
			if count>=80:break
	var report:Dictionary={"cases":cases,"gross_net_reverse_cases":reversed,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Diagnostic final canonical centreline samples, not an acceptance pass or hydraulic solver. Other valleys may intersect a descriptor; investigate reversals rather than infer flow from metadata alone."}
	report.actual_downhill_traces=traces
	report.builder_sha256=FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd")
	FileAccess.open("res://tools/badlands/artifacts/profile_channel_grades.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_CHANNEL_GRADE_DIAGNOSTIC ",cases.size()," cases; gross net reversals=",reversed.size());quit()
