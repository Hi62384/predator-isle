extends "res://tools/biome_extensions/probe_conduit_join.gd"
const Candidate=preload("res://tools/biome_extensions/conduit_shoulder_candidate.gd")
const DIAGNOSTIC="res://tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json"
var failures:Array=[]
var captures:Dictionary={}
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);print("FAILED_SHOULDER_NATIVE ",label)
func vector(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func digest(mesh:ArrayMesh)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):context.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return context.finish().hex_encode()
func snapshot(name:String)->Image:
	for idle in range(24):await process_frame
	await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/shoulder_candidate_"+name+".png";verify(image.save_png(path)==OK,"Native shoulder image saved");captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var diagnostic=JSON.parse_string(FileAccess.get_file_as_string(DIAGNOSTIC));assert(diagnostic.passed and diagnostic.cpu_gpu_source_matches==9)
	for path:String in diagnostic.source_sha256:assert(FileAccess.get_sha256(path)==diagnostic.source_sha256[path]);hashes[path]=diagnostic.source_sha256[path]
	for path:String in [DIAGNOSTIC,Candidate.SOURCE,Candidate.BASE,"res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_conduit_shoulder_candidate.gd","res://tools/biome_extensions/render_conduit_shoulder_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var focus:Vector3=vector(diagnostic.focus);var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(17,true)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.position=vector(diagnostic.camera);camera.far=18000;terrain=scene.get_node("Terrain");terrain.world_seed=17;terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.emission_strength=0;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
	for property:Dictionary in terrain.get_property_list():
		if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
	var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();verify(await settle(),"Original actual four-worker cut committed");camera.look_at(focus)
	if terrain._water!=null:terrain._water.hide()
	for node:MeshInstance3D in terrain._active_chunks.values():
		var water:Node3D=node.get_node_or_null("SwampWater")
		if water!=null:water.hide()
	# Replace ONLY the actual root intersecting the previously proven boundary.
	# Rebuild the complete original first to prove all input/split/portal settings.
	var owner:Vector3=vector(diagnostic.probes[7].shell.owner_origin);var leaf:MeshInstance3D=null;var leaf_key:=Vector3i.ZERO
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key]
		if node.position==owner:leaf=node;leaf_key=key;break
	verify(leaf!=null,"Exact original boundary's root found without rerolling")
	if leaf==null:quit(1);return
	var shell:MeshInstance3D=leaf.get_node("BiomeStructures");var original_mesh:ArrayMesh=shell.mesh;verify(original_mesh.get_surface_count()==1,"Declared pure-Alien single-family root")
	var builder=terrain._sampler;builder.chunk_size=terrain.chunk_size*float(1<<leaf_key.z);var steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
	var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.build(builder,Vector2i(leaf_key.x,leaf_key.y))
	var old_arrays:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(builder,Vector2i(leaf_key.x,leaf_key.y),steps,features.portal_sites);verify(old_arrays[2]!=null and old_arrays[0]==null and old_arrays[1]==null,"Exact original family admitted")
	var rebuilt:=ArrayMesh.new();rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,old_arrays[2]);verify(digest(rebuilt)==digest(original_mesh),"Complete original generated root equals actual committed GPU arrays")
	var candidate_script:GDScript=Candidate.script_for();var started:int=Time.get_ticks_usec();var candidate_arrays:Array=candidate_script.new().build(builder,Vector2i(leaf_key.x,leaf_key.y),steps,features.portal_sites);var candidate_seconds:float=(Time.get_ticks_usec()-started)/1000000.0
	var candidate_mesh:=ArrayMesh.new();candidate_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,candidate_arrays[2]);candidate_mesh.surface_set_material(0,original_mesh.surface_get_material(0));verify(digest(candidate_mesh)!=digest(original_mesh),"Actual near root changes;not an inactive far-only prototype")
	verify(candidate_arrays[2][Mesh.ARRAY_VERTEX].size()==old_arrays[2][Mesh.ARRAY_VERTEX].size(),"Same complete root topology/vertex count")
	var terrain_digest:String=digest(leaf.mesh);var originals:Dictionary={};var references:Array=[]
	for phase in range(3):
		shell.mesh=candidate_mesh if phase==1 else original_mesh
		for mode:int in [0,3,4,8]:
			terrain.set_debug_view(mode);var image:Image=await snapshot("%d_%d"%[phase,mode])
			if phase==0:originals[mode]=image
			elif phase==2:verify(image.get_data()==originals[mode].get_data(),"Same-scene actual original mesh returns exact image")
			references.append({"phase":phase,"debug":mode,"exact_original_return":image.get_data()==originals[mode].get_data() if phase==2 else null})
	verify(digest(leaf.mesh)==terrain_digest,"Private visual shoulder intervention never changes actual terrain arrays")
	shell.mesh=original_mesh;terrain.set_debug_view(0)
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable native private shoulder source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_conduit_shoulder_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":references,"root_key":str(leaf_key),"owner_origin":str(owner),"vertices":candidate_arrays[2][Mesh.ARRAY_VERTEX].size(),"candidate_mainthread_build_seconds":candidate_seconds,"scope":"PRIVATE actual seed17/frozen ground camera/root geometry-only study. Original four-worker production cut;complete original root rebuilt with actual span/support/portal settings and GPU arrays must match before intervention. Candidate changes ONLY that proven root's displayed mesh in the SAME scene,original/candidate/original at physical/unlit/geometric/mapped modes. Twelve images,all four original returns exact;terrain/lighting/target/material/other roots unchanged. Actual collision remains ORIGINAL deliberately:NOT physics/traversal/production streaming acceptance or a worker-performance benchmark. Mainthread candidate time is reported only as study cost. No production file changed."},"  "));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
