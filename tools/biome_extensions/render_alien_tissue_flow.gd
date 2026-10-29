extends "res://tools/biome_extensions/render_all.gd"
var failures:Array=[]
var images:Dictionary={}
var phases:Array=[]
var sample_reference_cases:Array=[]
const SAMPLE_REFERENCE="res://tools/biome_extensions/artifacts/revisions/experiment_render_alien_tissue_flow_fc1f200ac1af/sources/shaders/alien_tissue_flow.gdshaderinc.txt"
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func digest(mesh:ArrayMesh)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()
func cut()->Dictionary:
	var result:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var record:Dictionary={"terrain":digest(node.mesh),"resolution":node.get_meta("resolution"),"collision":var_to_bytes(node.mesh.get_meta("collision_data")).hex_encode().sha256_text()}
		for type:String in ["swamp_water_mesh","terrain_features","extension_structures"]:record[type]=digest(node.mesh.get_meta(type)) if node.mesh.has_meta(type) else "none"
		result[str(key)]=record
	return result
func different(a:Image,b:Image)->int:
	var first:PackedByteArray=a.get_data();var second:PackedByteArray=b.get_data();assert(first.size()==second.size());var count:int=0
	for index in range(first.size()):
		if first[index]!=second[index]:count+=1
	return count
func run()->void:
	verify(DisplayServer.get_name()!="headless","Actual native renderer")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");verify(FileAccess.get_sha256(path)==regression.source_sha256[relative],"Fresh regression "+path);hashes[path]=regression.source_sha256[relative]
	for path:String in [SAMPLE_REFERENCE,"res://tools/biome_extensions/render_alien_tissue_flow.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://data/surface_regression_20261018.json"]:hashes[path]=FileAccess.get_sha256(path)
	if not failures.is_empty():quit(1);return
	var include:Resource=load("res://shaders/alien_tissue_flow.gdshaderinc");var production_code:String=include.get("code");var reference_code:String=FileAccess.get_file_as_string(SAMPLE_REFERENCE)
	verify(production_code.contains("strength<=0.0)continue") and not reference_code.contains("strength<=0.0)continue"),"Explicit current/frozen sample-skip source contract")
	for seed_id:int in [73921,17,92881]:
		var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true);var field=locator._extras[7];var point:=Vector2.INF;var frame:Dictionary={}
		for index in range(4096):
			var paths:PackedVector2Array=field.network_edges(Vector2i(index%64-32,index/64-32));var p:Vector2=paths[0].lerp(paths[1],.5)
			if locator._island_mask(p.x,p.y)<.2 or field.region(p)<.75 or field.region(p)>1.5:continue
			var candidate:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").sample(field,p)
			if candidate.weight>.5:point=p;frame=candidate;break
		verify(point.is_finite(),"Discover actual dry nerve country with aligned actual trunk before freezing view")
		if not point.is_finite():quit(1);return
		var axis:Vector2=frame.tangent;var normal:=Vector2(-axis.y,axis.x);var focus:=Vector3(point.x,locator._get_height(point.x,point.y)+2,point.y)
		var views:Dictionary={"near":focus+Vector3(normal.x*45-axis.x*80,35,normal.y*45-axis.y*80),"context":focus+Vector3(normal.x*180-axis.x*250,180,normal.y*180-axis.y*250),"ground":focus+Vector3(axis.x*5+normal.x*2,1.8,axis.y*5+normal.y*2)}
		for kind:String in views:
			var p:Vector3=views[kind];p.y=maxf(p.y,locator._get_height(p.x,p.z)+(1.8 if kind=="ground" else 12));views[kind]=p
		var original_cut:Dictionary={};var originals:Dictionary={}
		for phase in range(3):
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			terrain.settings.alien_infected.nerve_flow_texturing=phase==1;terrain.settings.alien_infected.emission_strength=0;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
			# Isolate the older map/sample-skipping contract. The independently
			# registered material variation has its own true/false native suite.
			terrain.settings.alien_infected.nerve_material_variation=false
			for property:Dictionary in terrain.get_property_list():
				if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
			var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;camera.position=views.near
			var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();verify(await settle(),"Committed material-flow scene cut")
			var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0;verify(Vector2(terrain.target.global_position.x,terrain.target.global_position.z).distance_to(point)<.01,"No preview relocation")
			var current_cut:Dictionary=cut()
			if phase==0:original_cut=current_cut
			else:verify(current_cut==original_cut,"Complete geometry/water/features/structures/collision cut remains byte-exact")
			var maps:int=0;var bytes:int=0;var shared_shell_maps:int=0;var map_records:Array=[]
			for key:Vector3i in terrain._active_chunks:
				var node:MeshInstance3D=terrain._active_chunks[key]
				var span:float=terrain.chunk_size*float(1<<key.z)
				if node.mesh.has_meta("alien_tissue_flow"):
					verify(phase==1,"Disabled terrain phase allocates no atlas")
					var texture:ImageTexture=node.mesh.get_meta("alien_tissue_flow");var actual:Image=texture.get_image()
					var expected:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").atlas(terrain._sampler._extras[7],Vector2(node.position.x,node.position.z),span,node.get_meta("resolution"))
					verify(actual.get_data()==expected.data,"Actual committed worker GPU map equals canonical material field");maps+=1;bytes+=actual.get_data_size()
					var material:ShaderMaterial=node.mesh.surface_get_material(0);verify(material.get_shader_parameter("alien_tissue_flow")==texture and material.get_shader_parameter("alien_tissue_flow_enabled"),"Actual terrain uses committed map")
				if node.mesh.has_meta("extension_structures"):
					var structures:ArrayMesh=node.mesh.get_meta("extension_structures")
					for surface in range(structures.get_surface_count()):
						var shell:ShaderMaterial=structures.surface_get_material(surface)
						if shell.get_shader_parameter("family")!=7:continue
						var expected:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(terrain._sampler,structures.surface_get_arrays(surface),Vector2(node.position.x,node.position.z)) if phase==1 else {}
						if expected.is_empty():verify(not structures.has_meta("alien_tissue_flow"),"Disabled/inactive shell allocates no map");continue
						verify(structures.has_meta("alien_tissue_flow"),"Actual shell has a bounds-qualified material map")
						var texture:ImageTexture=structures.get_meta("alien_tissue_flow");var actual:Image=texture.get_image()
						verify(actual.get_data()==expected.data,"Whole-structure worker GPU map equals canonical field")
						verify(shell.get_shader_parameter("alien_tissue_flow")==texture and shell.get_shader_parameter("alien_tissue_flow_offset")==expected.offset and shell.get_shader_parameter("alien_tissue_flow_span")==expected.span,"Shell binds its actual bounds,not the owner's terrain rectangle")
						var bounds:AABB=structures.get_aabb();verify(bounds.position.x>=expected.offset.x and bounds.position.z>=expected.offset.y and bounds.end.x<=expected.offset.x+expected.span.x and bounds.end.z<=expected.offset.y+expected.span.y,"Whole owned structure fits its actual material domain")
						shared_shell_maps+=1;bytes+=actual.get_data_size()
						map_records.append({"key":[key.x,key.y,key.z],"origin":[node.position.x,node.position.z],"resolution":node.get_meta("resolution"),"surface":surface,"structure_vertices":structures.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size(),"map_columns":expected.columns,"map_rows":expected.rows,"map_bytes":actual.get_data_size(),"offset":[expected.offset.x,expected.offset.y],"span":[expected.span.x,expected.span.y],"extends_outside_owner_tile":bounds.position.x<0 or bounds.position.z<0 or bounds.end.x>span or bounds.end.z>span})
			if phase==1:verify(maps>0 and shared_shell_maps>0,"Material transport actually used by terrain AND supplemental shells")
			var workers:int=terrain._idle_builders.size();verify(workers>0,"Actual worker production")
			if terrain._water!=null:terrain._water.hide()
			for node:MeshInstance3D in terrain._active_chunks.values():
				var water:Node3D=node.get_node_or_null("SwampWater")
				if water!=null:water.hide()
			for kind:String in views:
				camera.position=views[kind];camera.look_at(focus)
				for idle in range(24):await process_frame
				await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();var delta:int=0
				if phase==0:originals[kind]=image
				else:delta=different(originals[kind],image)
				if phase==1 and kind=="near":verify(delta>100,"Material alignment is visibly active,not an unused setting")
				var path:String="res://tools/biome_extensions/artifacts/alien_tissue_flow_%d_%d_%s.png"%[seed_id,phase,kind];verify(image.save_png(path)==OK,"Native flow capture saved");images[path]=FileAccess.get_sha256(path)
				records.append({"seed":seed_id,"phase":phase,"view":kind,"capture":path,"sha256":images[path],"focus":str(focus),"camera":str(camera.position),"different_bytes":delta})
				if phase==1:
					include.set("code",reference_code)
					for idle in range(24):await process_frame
					await RenderingServer.frame_post_draw;var reference:Image=root.get_texture().get_image();var reference_difference:int=different(image,reference)
					var reference_path:String=path.trim_suffix(".png")+"_sample_reference.png";verify(reference.save_png(reference_path)==OK,"Whole-scene sampler reference saved");images[reference_path]=FileAccess.get_sha256(reference_path)
					if seed_id==73921 and kind=="near":
						verify(reference_code.count("uv/=denominator*1.5;")==1,"Wrong-UV negative source contract")
						include.set("code",reference_code.replace("uv/=denominator*1.5;","uv/=denominator*1.5;uv+=vec2(.37,0);"))
						for idle in range(24):await process_frame
						await RenderingServer.frame_post_draw;var wrong:Image=root.get_texture().get_image();verify(different(image,wrong)>1000,"Runtime include intervention actually changes the material;counterfactual not ignored")
						var wrong_path:String=path.trim_suffix(".png")+"_wrong_uv.png";verify(wrong.save_png(wrong_path)==OK,"Whole-scene wrong-UV negative saved");images[wrong_path]=FileAccess.get_sha256(wrong_path)
					include.set("code",production_code)
					for idle in range(24):await process_frame
					await RenderingServer.frame_post_draw;var returned:Image=root.get_texture().get_image();var return_difference:int=different(image,returned)
					var returned_path:String=path.trim_suffix(".png")+"_sample_return.png";verify(returned.save_png(returned_path)==OK,"Whole-scene sampler return saved");images[returned_path]=FileAccess.get_sha256(returned_path)
					verify(reference_difference==0 and return_difference==0,"Whole actual scene is byte-exact against frozen unconditional sample loop and current return")
					sample_reference_cases.append({"seed":seed_id,"view":kind,"reference_different_bytes":reference_difference,"return_different_bytes":return_difference})
			phases.append({"seed":seed_id,"phase":phase,"maps":maps,"gpu_numeric_map_bytes":bytes,"shared_shell_maps":shared_shell_maps,"structure_map_cases":map_records,"leaves":current_cut.size(),"workers":workers,"initial_fill_seconds":elapsed,"exact_geometry_reference":phase>0,"cut":current_cut})
			print("ALIEN_TISSUE_FLOW_NATIVE ",seed_id," phase=",phase," maps=",maps," bytes=",bytes," fill=",elapsed)
			scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable material render source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_alien_tissue_flow.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":images,"views":records,"phases":phases,"sample_reference_cases":sample_reference_cases,"scope":"Actual production four-worker/controller pure Alien off/on/off at three fixed-discovered on-land nerve trunks,three views including ground level,boundedLOD4/18km. Terrain and attached shells sample the same canonical field through independently bounded maps covering their full geometry;complete terrain/water/feature/structure/collision reference exact. Actual worker-map GPU readback checked. Within each enabled scene,the frozen unconditional4-sample analytic helper and restored current helper must match all image bytes at all nine views. A deliberately wrong UV verifies the runtime include intervention is not ignored.27 primary images,18 sample-reference/return images and one wrong-UV negative. Animation emission disabled/water hidden only for images;lighting unchanged. Separate cross-scene differences are reported,not silently certified exact. Ordered nonisolated fills/bytes are not frame-time gains or full-world art/performance/cave acceptance."},"  "));quit(0 if failures.is_empty() else 1)
