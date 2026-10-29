extends "res://tools/biome_extensions/check_all.gd"
func conduit_vertex_bound(a:Vector2,b:Vector2)->int:
	# Actual 15-column attached conduit: 14 quads per longitudinal segment,
	# two 14-triangle caps. Degenerate rejection can only reduce this count.
	return (clampi(ceili(a.distance_to(b)/96),16,64)+1)*84
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/estimate_structure_scale_budget.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(admission.passed,"Actual seeded default preview focus")
	var site:Dictionary=admission.cases[0];var center:=Vector2(site.position[0],site.position[1]);var radius:float=75000
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("radius="):radius=clampf(float(argument.trim_prefix("radius=")),10000,75000)
	var cases:Array=[]
	for scale_value:float in [.2,1,2]:
		var b=make_builder(7,int(site.seed));b.settings.alien_infected.feature_scale=scale_value;b._configure_noise();var field=b._extras[7];var span:float=4096*scale_value
		var bounds:=Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2);var first:=Vector2i(floori(bounds.position.x/span)-1,floori(bounds.position.y/span)-1);var last:=Vector2i(ceili(bounds.end.x/span),ceili(bounds.end.y/span))
		var roots:int=0;var conduits:int=0;var conduit_vertices:int=0;var monument_vertices:int=0;var candidates:int=0;var started:int=Time.get_ticks_usec()
		for z in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var cell:=Vector2i(x,z);var p:Vector2=field.hive_node(cell)
				if not bounds.has_point(p):continue
				candidates+=1;var d:Dictionary=field.descriptor(cell,span)
				if d.chance>field.settings.structure_density or b._island_mask(p.x,p.y)<.03:continue
				var height:float=b._get_height(p.x,p.y)
				if height<b.get_water_surface_height(p.x,p.y)+2:continue
				roots+=1;var edges:PackedVector2Array=field.network_edges(cell)
				for edge:int in [0,4]:
					conduit_vertices+=conduit_vertex_bound(p,edges[edge+1])+conduit_vertex_bound(edges[edge+1],edges[edge+2])+conduit_vertex_bound(edges[edge+1],edges[edge+3]);conduits+=3
				if field.random(x,z,246)<field.settings.hive_junction_frequency:monument_vertices+=9168+(5136 if field.random(x,z,248)<field.settings.hive_membrane_frequency else 0)
				elif roundi(field.region(p)) in [2,5] and field.random(x,z,247)<field.settings.hive_carapace_frequency:monument_vertices+=18000
		var total:int=conduit_vertices+monument_vertices
		cases.append({"seed":int(site.seed),"feature_scale":scale_value,"square_half_extent_m":radius,"candidate_nodes":candidates,"dry_density_admitted_roots":roots,"conduits":conduits,"conduit_vertex_upper_bound":conduit_vertices,"monument_vertex_upper_bound_ignoring_suppression":monument_vertices,"numeric_array_bytes_upper_bound":total*48,"candidate_scan_seconds":(Time.get_ticks_usec()-started)/1000000.0,"generated_meshes":false})
		print("STRUCTURE_SCALE_BUDGET ",cases[-1])
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable scale-budget model source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/estimate_structure_scale_budget.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"cases":cases,"scope":"Bounded numeric admission/vertex-count preflight at one actual seed/focus and three feature scales; square includes generous far-plane/LOD overscan but is not an exact active partition. Counts normal density/dry/island eligibility, six real conduit endpoints per root, and conservative unsuppressed monument upper bounds without allocating meshes. Excludes terrain, finite features/liquids, atlases, GPU/physics allocation, worker/staging/cache copies and allocator overhead. Not actual startup, available-memory measurement, a whole-process memory upper bound or a streaming certificate."},"  "))
	quit(0 if failures.is_empty() else 1)
