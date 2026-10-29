extends "res://tools/biome_extensions/check_all.gd"
const Terrain=preload("res://scripts/chunk_terrain.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func digest(value)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/caves/streamer.gd","res://scripts/caves/workload.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/portal_mesher.gd","res://scripts/caves/mesher.gd","res://scripts/caves/field.gd","res://scripts/caves/network.gd","res://scripts/caves/route_solver.gd","res://scripts/caves/cave_settings.gd","res://tools/caves/check_shared_scheduler.gd","res://tools/biome_extensions/check_all.gd"]:guards[path]=FileAccess.get_sha256(path)
	var target:=Node3D.new();target.position=Vector3(14771.29,25.37863,-4037.743);root.add_child(target);var terrain=Terrain.new();terrain.target=target;terrain.extension_preview="spore_forest";terrain.extension_preview_position=Vector2(target.position.x,target.position.z)
	for name:String in ["jungle","forest","savanna","swamp","mountain","coast","beach","tropical","badlands"]:terrain.set("start_in_"+name,false)
	terrain.cave_settings=Config.new();terrain.cave_settings.enabled=true;terrain.cave_settings.regional_activity=1;terrain.cave_settings.visible_radius_metres=96;terrain.cave_settings.preload_radius_metres=128;terrain.cave_settings.resident_cell_limit=32;check(terrain.worker_count==4 and terrain.maximum_lod==6,"Actual fullLOD6/four-worker terrain configuration retained");root.add_child(terrain);check(terrain._cave_streamer!=null,"Actual terrain ready path creates enabled cave backend")
	# _ready preview framing is deliberately not the interest point in this
	# stationary underground scheduler fixture;no actor/capsule is teleported.
	target.position=Vector3(14771.29,25.37863,-4037.743);terrain._refresh_visible_chunks();var started:int=Time.get_ticks_usec();var maximum_total:int=0;var maximum_cave:int=0;var concurrent_frames:int=0;var peak_pending:int=0
	while Time.get_ticks_usec()-started<180000000:
		var terrain_jobs:int=terrain._jobs.size();var cave_jobs:int=terrain._cave_streamer.job_count();maximum_total=maxi(maximum_total,terrain_jobs+cave_jobs);maximum_cave=maxi(maximum_cave,cave_jobs);peak_pending=maxi(peak_pending,terrain._cave_streamer._pending.size());check(terrain_jobs+cave_jobs<=4,"Actual terrain+cave tasks share four TOTAL slots,not four plus four")
		if terrain_jobs>0 and cave_jobs>0:concurrent_frames+=1
		if terrain.committed_revision==terrain.partition_revision and terrain._cave_streamer.position_ready() and terrain._cave_streamer._wanted.size()>0:break
		if not terrain._cave_streamer.last_error.is_empty():break
		await process_frame;OS.delay_usec(1000)
	check(terrain._cave_streamer.last_error.is_empty() and terrain.committed_revision==terrain.partition_revision and terrain._cave_streamer.position_ready(),"Actual complete terrain cut and sparse cave set both finish inside original180s preload gate")
	check(maximum_total==4 and maximum_cave>0 and concurrent_frames>5,"Positive simultaneous terrain/cave workload,not an idle scheduler control")
	var chosen:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var span:float=terrain.chunk_size*float(1<<key.z);var bounds:=Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span)
		if key.z==0 and bounds.has_point(Vector2(target.position.x,target.position.z)):chosen={"key":key,"node":node,"span":span};break
	check(not chosen.is_empty(),"Original underground interest retains a genuine closest terrain leaf")
	if not chosen.is_empty():
		var node:MeshInstance3D=chosen.node;var key:Vector3i=chosen.key;var resolution:int=node.get_meta("resolution");var reference=Builder.new();reference.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);reference.world_seed=terrain.world_seed;reference.water_level=terrain.water_level;reference.chunk_size=chosen.span;reference._configure_noise();var expected:Array=reference.build(Vector2i(key.x,key.y),resolution);check(node.mesh.has_meta("terrain_cpu_arrays") and digest(node.mesh.get_meta("terrain_cpu_arrays"))==digest(expected),"Complete actual worker terrain arrays remain exact against independent cold builder with cave backend enabled")
		var ground:float=terrain.get_height_at(target.position);var hit:Dictionary=node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(target.position.x,ground+4,target.position.z),Vector3(target.position.x,ground-20,target.position.z)));check(not hit.is_empty() and absf(hit.position.y-ground)<.03,"Backend alone does NOT prematurely remove actual main terrain collision before a portal transaction")
	var cells:int=terrain._cave_streamer._cells.size();var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0;terrain.queue_free();target.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual shared scheduler source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_shared_scheduler.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"maximum_total_jobs":maximum_total,"maximum_cave_jobs":maximum_cave,"frames_with_both_workloads":concurrent_frames,"maximum_pending_cave_queue":peak_pending,"resident_cave_cells":cells,"single_order_preload_seconds":elapsed,"production_runtime_enabled_by_default":false,"scope":"Actual ChunkTerrain fullLOD6/four TOTAL worker scheduler plus enabled sparse cave backend at original actual Spore underground interest. Complete terrain cut/cave set readiness under unchanged180s gate/1ms preload poll,exact selected raw CPU mesh arrays against cold reference,and native main-ground cap still intact until surface commit. This is preload/scheduler integration,not a streamed capsule or committed portal/material/art certificate."},"  "));print("CAVE_SHARED_SCHEDULER ",checks," jobs=",maximum_total," seconds=",elapsed," failures=",failures);quit(0 if failures.is_empty() else 1)
