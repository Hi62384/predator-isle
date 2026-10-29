extends "res://tools/biome_extensions/render_ground_union_worker_domains.gd"
const Candidate=preload("res://tools/biome_extensions/crystal_bulk_candidate.gd")
func packed_mesh(arrays:Array,material:Material)->ArrayMesh:
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(0,material);return result
func freeze_animated_material(material:Material,cache:Dictionary)->Material:
	if not material is ShaderMaterial or not material.shader.code.contains("TIME"):return material
	if cache.has(material):return cache[material]
	var copy:ShaderMaterial=material.duplicate();var shader:=Shader.new();shader.code=material.shader.code.replace("TIME","0.0");copy.shader=shader;cache[material]=copy;return copy
func freeze_water_time()->int:
	# A private fixed-time image study,not a water-animation change. Keep
	# water visible and replace only TIME in duplicates,identically in all
	# original/candidate/return frames. The initial live-time failure remains.
	var cache:Dictionary={};var count:int=0
	for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		if node.material_override!=null:
			var replacement:Material=freeze_animated_material(node.material_override,cache)
			if replacement!=node.material_override:node.material_override=replacement;count+=1
		elif node.mesh!=null:
			for surface in range(node.mesh.get_surface_count()):
				var old:Material=node.get_active_material(surface);var replacement:Material=freeze_animated_material(old,cache)
				if replacement!=old:node.set_surface_override_material(surface,replacement);count+=1
	# Hold all duplicated shaders/materials through scene lifetime.
	scene.set_meta("optical_fixed_time_materials",cache)
	return count
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var preview_path:String="res://tools/biome_extensions/artifacts/previews.json";var previews=JSON.parse_string(FileAccess.get_file_as_string(preview_path));hashes[preview_path]=FileAccess.get_sha256(preview_path)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);hashes[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/biome_extensions/render_crystal_bulk_candidate.gd","res://tools/biome_extensions/crystal_bulk_candidate.gd","res://tools/biome_extensions/crystal_bulk_candidate.gdshader","res://tools/biome_extensions/crystal_bulk_optics.gdshaderinc"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var rebuilds:Array=[]
	for kind:int in range(6):
		var site:Dictionary=previews.families.crystal_wastes.regions[str(kind)];var p:=Vector2(site.x,site.z)
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;terrain=scene.get_node("Terrain");terrain.extension_preview="crystal_wastes";terrain.extension_preview_position=p;terrain.maximum_lod=4
		var target:=Marker3D.new();target.position=Vector3(p.x,site.height,p.y);scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
		var frozen_materials:int=freeze_water_time()
		var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=terrain.world_seed;builder.water_level=terrain.water_level;builder._configure_noise()
		verify(roundi(builder._extras[5].region(p))==kind,"Original procedural regional mineral identity")
		var pairs:Array=[];var root_count:int=0
		for key:Vector3i in terrain._active_chunks:
			var node:MeshInstance3D=terrain._active_chunks[key];var visible:MeshInstance3D=node.get_node_or_null("BiomeStructures")
			if visible==null or visible.mesh==null:continue
			verify(visible.mesh.get_surface_count()==1,"Pure Crystal native root")
			builder.chunk_size=terrain.chunk_size*float(1<<key.z);var support:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
			var original:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(builder,Vector2i(key.x,key.y),support);var candidate:Array=Candidate.new().build(builder,Vector2i(key.x,key.y),support)
			var old:ShaderMaterial=visible.mesh.surface_get_material(0);var original_packed:ArrayMesh=packed_mesh(original[0],old)
			verify(digest(original_packed)==digest(visible.mesh),"Complete production root rebuild equals actual committed GPU arrays before intervention")
			for channel:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]:verify(original[0][channel]==candidate[0][channel],"Only optical metadata,never geometry/normals/tint/collision")
			var material:=ShaderMaterial.new();material.shader=load("res://tools/biome_extensions/crystal_bulk_candidate.gdshader");var next:ArrayMesh=packed_mesh(candidate[0],material)
			pairs.append([visible,visible.mesh,next]);root_count+=1
		verify(root_count>0,"Actual procedural mineral structures present")
		var positions:Dictionary={"ground":focus+Vector3(-60,4,-85),"medium":focus+Vector3(-450,300,-650)};var originals:Dictionary={}
		for view:String in positions:
			var position:Vector3=positions[view];position.y=maxf(position.y,terrain.get_height_at(position)+4);camera.position=position;camera.look_at(focus);terrain.set_debug_view(0)
			for phase in range(3):
				for pair:Array in pairs:pair[0].mesh=pair[2] if phase==1 else pair[1]
				for idle in range(24):await process_frame
				await RenderingServer.frame_post_draw;var picture:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/crystal_bulk_%d_%s_%d.png"%[kind,view,phase];verify(picture.save_png(path)==OK,"Native optical view saved");captures[path]=FileAccess.get_sha256(path)
				var changed:int=0
				if phase==0:originals[view]=picture
				else:changed=different(originals[view],picture)
				if phase==2:verify(changed==0,"Strict same-scene original image return")
				records.append({"kind":kind,"regional_name":site.regional_name,"view":view,"phase":phase,"focus":str(focus),"camera":str(position),"different_bytes_from_original":changed,"root_count":root_count,"private_time_zero_material_bindings":frozen_materials})
			rebuilds.append({"kind":kind,"view":view,"roots":root_count});print("CRYSTAL_BULK_NATIVE ",kind," ",view," roots=",root_count)
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable optical native trial source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_crystal_bulk_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":records,"rebuilds":rebuilds,"production_registration":false,"scope":"PRIVATE same-scene optical-only comparison at ALL six original procedural Crystal region fixtures,ground/medium cameras,36 original/candidate/original images. Actual production controller/cut untouched. Complete original root rebuild must equal committed GPU arrays before intervention;candidate changes only UV optical metadata and displayed material,not any vertex/normal/tint/collider. Twelve strict original image returns. Water remains visible but duplicated animated materials use TIME0 identically in all frames;original live-time whole-image return failure separately preserved,not a passing reference. No production shader/time/lighting change. Actual physical thickness/growth supplied by original prism arguments. New mostly opaque mineral bulk with limited Beer-Lambert transmission and true depth writes;not true ray-traced refractive order or measured scans. Marker-fixedLOD4/18km study,not fullLOD6 runtime configuration,performance,traversal or cave acceptance."},"  "));quit(0 if failures.is_empty() else 1)
