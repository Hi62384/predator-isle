extends SceneTree
## Diagnose attachment against ACTUAL committed mesh triangles, not only the
## canonical height field (which can differ from a sparse far-LOD chord).
var terrain:Node
var surface_cache:Dictionary={}
func _initialize()->void:call_deferred("run")
func settle()->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-start<180000,"Attachment diagnostic streaming timeout")
func triangle_height(p:Vector3)->Dictionary:
	for level in range(terrain.maximum_lod+1):
		var span:float=terrain.chunk_size*float(1<<level)
		var key:=Vector3i(floori(p.x/span),floori(p.z/span),level)
		if not terrain._active_chunks.has(key):continue
		var node:MeshInstance3D=terrain._active_chunks[key];var resolution:int=node.get_meta("resolution")
		if not surface_cache.has(key):surface_cache[key]=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var vertices:PackedVector3Array=surface_cache[key];var local:Vector3=node.to_local(p)
		var gx:float=clampf(local.x/span*resolution,0,resolution);var gz:float=clampf(local.z/span*resolution,0,resolution)
		var x:int=mini(floori(gx),resolution-1);var z:int=mini(floori(gz),resolution-1);var fx:float=gx-x;var fz:float=gz-z
		var a:float=vertices[z*(resolution+1)+x].y;var b:float=vertices[z*(resolution+1)+x+1].y
		var c:float=vertices[(z+1)*(resolution+1)+x].y;var d:float=vertices[(z+1)*(resolution+1)+x+1].y
		var height:float=a+(b-a)*fx+(c-a)*fz if fx+fz<=1 else d+(c-d)*(1-fx)+(b-d)*(1-fz)
		return {"height":height+node.global_position.y,"lod":level,"step":span/resolution,"key":str(key)}
	return {}
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	for source:String in ["res://scripts/alien_carapace_geometry.gd","res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_settings.gd"]:hashes[source]=FileAccess.get_sha256(source)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_settings.gd","res://tools/biome_extensions/profile_feature_ground_attachment.gd","res://tools/biome_extensions/artifacts/previews.json"]:hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"));var item:Dictionary=manifest.families.alien_infected.primary
	var scene=load("res://scenes/main.tscn").instantiate();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null)
	terrain=scene.get_node("Terrain");terrain.extension_preview="alien_infected";terrain.extension_preview_position=Vector2(item.x,item.z);terrain.target=camera
	root.add_child(scene);scene.get_node("Interface").hide();await settle()
	var focus:=Vector3(item.x,terrain.get_height_at(Vector3(item.x,0,item.z)),item.z)
	terrain.request_teleport(focus+Vector3(-800,500,-1100));await settle()
	var revision:int=terrain.committed_revision;var seen:Dictionary={};var examined:int=0;var margins:int=0;var positive:int=0;var maximum:float=-INF;var worst:Dictionary={};var lod_samples:Dictionary={};var guarded:int=0;var guarded_exposed:int=0
	for ground_node:MeshInstance3D in terrain._active_chunks.values():
		var structures:MeshInstance3D=ground_node.get_node_or_null("BiomeStructures")
		if structures==null or structures.mesh==null:continue
		for surface in range(structures.mesh.get_surface_count()):
			var arrays:Array=structures.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			var marked:bool=false
			for tint:Color in colors:
				if tint.a<.75:marked=true;break
			for vertex in range(vertices.size()):
				var local:Vector3=vertices[vertex]
				var point:Vector3=structures.to_global(local)
				if Vector2(point.x-focus.x,point.z-focus.z).length()>5000 or seen.has(point):continue
				seen[point]=true;examined+=1
				var canonical:float=terrain.get_height_at(point);var depth:float=canonical-point.y
				var is_margin:bool=colors[vertex].a<.1 if marked else depth>2.4 and depth<3.6
				var is_guarded:bool=marked and colors[vertex].a>.4 and colors[vertex].a<.6
				if is_margin or is_guarded:
					var actual:Dictionary=triangle_height(point)
					if not actual.is_empty():
						var clearance:float=point.y-actual.height
						if is_guarded:
							guarded+=1
							if clearance>.05:guarded_exposed+=1
						else:
							margins+=1;lod_samples[str(actual.lod)]=int(lod_samples.get(str(actual.lod),0))+1
							if clearance>.05:positive+=1
							if clearance>maximum:maximum=clearance;worst={"position":point,"canonical_height":canonical,"actual_mesh_height":actual.height,"margin_clearance":clearance,"ground_lod":actual.lod,"ground_step_m":actual.step,"ground_key":actual.key}
				if examined>=3000:break
			if examined>=3000:break
		if examined>=3000:break
	assert(margins>32,"Actual conduit base margins must be exercised")
	assert(terrain.committed_revision==revision and terrain.partition_revision==revision,"Diagnostic uses one complete committed cut")
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during attachment diagnostic")
	var report:Dictionary={"diagnostic_complete":true,"examined_unique_structure_vertices":examined,"conduit_margin_samples":margins,"margins_above_actual_mesh":positive,"maximum_margin_clearance_m":maximum,"worst":worst,"ground_lod_sample_counts":lod_samples,"guarded_unextended_margins":guarded,"guarded_unextended_exposed":guarded_exposed,"source_sha256":hashes,"scope":"One actual Alien preview cut; explicit outer-footing markers (legacy fallback: canonical-minus-3m margins) versus exact committed visible triangles. Protected unextended margins are counted separately, not silently approved. No whole-world or performance certificate."}
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_feature_ground_attachment.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("FEATURE_GROUND_ATTACHMENT ",margins," margins / ",positive," exposed; max_m=",maximum," worst=",worst)
	scene.queue_free();await process_frame;quit()
