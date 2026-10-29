extends SceneTree
## Actual shared tissue shader: equal physical points under different local origins.
func _initialize()->void:call_deferred("run")
func run()->void:
	var mode:String="phase_only" if OS.get_cmdline_user_args().has("phase_only") else ("legacy" if OS.get_cmdline_user_args().has("legacy") else ("mirror_only" if OS.get_cmdline_user_args().has("mirror_only") else "fixed"))
	if OS.get_cmdline_user_args().has("phase_all"):mode="phase_all"
	if OS.get_cmdline_user_args().has("vertex_phase"):mode="vertex_phase"
	if OS.get_cmdline_user_args().has("origin_parity"):mode="origin_parity"
	if OS.get_cmdline_user_args().has("float_period"):mode="float_period"
	if OS.get_cmdline_user_args().has("integer_period"):mode="integer_period"
	if OS.get_cmdline_user_args().has("production_integer"):mode="production_integer"
	assert(not OS.get_cmdline_user_args().has("production"),"Origin-parity correction was not adopted; use the explicit private origin_parity trial")
	assert(DisplayServer.get_name()!="headless")
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://scripts/lod_biome_extension_structures.gd"]=FileAccess.get_sha256("res://scripts/lod_biome_extension_structures.gd")
	for path:String in ["res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biome_extensions.gdshaderinc","res://tools/biome_extensions/check_mirrored_tissue_projection.gd","res://materials/biological_colors_v3.tres","res://materials/biological_color_mycelium_v2.res","res://materials/biological_color_nerve_v3.res","res://materials/biological_color_carapace.res","res://materials/biological_color_membrane.res"]:hashes[path]=FileAccess.get_sha256(path)
	var source_path:String="res://shaders/biological_sampling.gdshaderinc" if mode in ["legacy","phase_only","phase_all","vertex_phase","origin_parity","float_period","integer_period","production_integer"] else ("res://tools/biome_extensions/mirrored_tissue_no_phase_candidate.gdshaderinc" if mode=="mirror_only" else "res://tools/biome_extensions/mirrored_tissue_phase_candidate.gdshaderinc")
	hashes["res://tools/biome_extensions/mirror_origin_phase_candidate.gdshaderinc"]=FileAccess.get_sha256("res://tools/biome_extensions/mirror_origin_phase_candidate.gdshaderinc")
	hashes[source_path]=FileAccess.get_sha256(source_path)
	var source:String=FileAccess.get_file_as_string(source_path)
	if mode=="production_integer":
		for path:String in ["res://tools/biome_extensions/biological_integer_period_candidate.gd","res://tools/biome_extensions/biological_float_period_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
		assert(source.count(preload("res://tools/biome_extensions/biological_integer_period_candidate.gd").REPLACEMENT)==1,"Production sign-safe common period must actually be registered")
	if mode=="integer_period":
		for path:String in ["res://tools/biome_extensions/biological_integer_period_candidate.gd","res://tools/biome_extensions/biological_float_period_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
		source=preload("res://tools/biome_extensions/biological_integer_period_candidate.gd").apply_to(source)
	if mode=="float_period":
		var path:String="res://tools/biome_extensions/biological_float_period_candidate.gd";hashes[path]=FileAccess.get_sha256(path)
		source=preload("res://tools/biome_extensions/biological_float_period_candidate.gd").apply_to(source)
	if mode=="origin_parity":
		var path:String="res://tools/biome_extensions/mirror_origin_parity_candidate.gd";hashes[path]=FileAccess.get_sha256(path)
		source=preload("res://tools/biome_extensions/mirror_origin_parity_candidate.gd").apply_to(source)
	if mode=="vertex_phase":
		var candidate_path:String="res://tools/biome_extensions/biological_vertex_phase_candidate.gd";hashes[candidate_path]=FileAccess.get_sha256(candidate_path)
		source=preload("res://tools/biome_extensions/biological_vertex_phase_candidate.gd").sampler(source)
	if mode=="phase_all":
		var candidate_path:String="res://tools/biome_extensions/biological_period_candidate.gd";hashes[candidate_path]=FileAccess.get_sha256(candidate_path)
		source=preload("res://tools/biome_extensions/biological_period_candidate.gd").apply_to(source)
	if mode=="phase_only":
		var original:String="int period=int(round(metres*4.0));"
		assert(source.count(original)==1,"Private phase-only control must start from the original sampler")
		source=source.replace(original,"int period=int(round(metres*4.0))*(layer==0?2:1);")
	var terrain_source:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	var shell_source:String=FileAccess.get_file_as_string("res://shaders/biome_structures.gdshader")
	assert(terrain_source.contains('#include "res://shaders/biological_sampling.gdshaderinc"') and shell_source.contains('#include "res://shaders/biological_sampling.gdshaderinc"'))
	var begin:int=shell_source.find("float field(vec2 p)");var end:int=shell_source.find("#include",begin)
	assert(begin>=0 and end>begin)
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform vec3 sample_site;uniform vec3 local_origin;uniform vec3 reference_origin;uniform int tissue_layer;uniform float transition_region=-1.0;varying float comparison_column;varying vec3 world_position;varying vec3 forest_local_position;varying vec3 forest_origin;\n"+shell_source.substr(begin,end-begin)+"\n"+source+"\nvoid vertex(){comparison_column=UV2.x;world_position=sample_site+vec3(UV.x*8.0,UV.y*3.0,UV.y*8.0);forest_origin=UV2.x<.5?reference_origin:local_origin;forest_local_position=world_position-forest_origin;if(UV2.x>1.5 && transition_region<0.0)forest_local_position+=vec3(.37,0,.29);}\nvoid fragment(){vec3 n=normalize(vec3(.28,.91,.31));vec3 w=pow(abs(n),vec3(6));w/=dot(w,vec3(1));vec3 dx=dFdx(world_position),dy=dFdy(world_position);if(transition_region<0.0)ALBEDO=biological_sample(tissue_layer,tissue_layer==0?2.5:(tissue_layer==2?2.0:1.5),dx,dy,w,n);else{float region=transition_region+(comparison_column<.5?-.0001:.0001);vec3 color;float rough;alien_tissue_sample(region,0.0,dx,dy,w,n,color,rough);if(comparison_column>1.5){int layer=alien_tissue_layer(int(floor(region+.5)));color=alien_tissue_color(layer,1.0,dx,dy,w,n);}ALBEDO=color;}}"
	if mode=="production_integer":
		# Both real callers deliberately differentiate SMALL local positions.
		# The old fixture's world derivatives quantize at large coordinates and
		# were not representative of either actual caller. Keep those failed
		# images archived,and change only this explicit new production mode.
		var master_path:String="res://shaders/terrain_biomes.gdshader";hashes[master_path]=FileAccess.get_sha256(master_path)
		var master:String=FileAccess.get_file_as_string(master_path)
		assert(master.contains("shade_extension(i,extension_control(i),n,forest_dx,forest_dy,projection,fine,c,r,g,e)") and master.contains("forest_dx=dFdx(forest_local_position),forest_dy=dFdy(forest_local_position)") and shell_source.contains("position_dx=dFdx(forest_local_position),position_dy=dFdy(forest_local_position)"))
		shader.code=shader.code.replace("vec3 dx=dFdx(world_position),dy=dFdy(world_position);","vec3 dx=dFdx(forest_local_position),dy=dFdy(forest_local_position);")
	if mode=="vertex_phase":
		var marker:String="forest_local_position=world_position-forest_origin;"
		assert(shader.code.count(marker)==1)
		shader.code=shader.code.replace(marker,marker+preload("res://tools/biome_extensions/biological_vertex_phase_candidate.gd").ASSIGNMENT)
	if source.contains("mirror_origin_phase_candidate.gdshaderinc"):
		var marker:String="forest_local_position=world_position-forest_origin;"
		assert(shader.code.count(marker)==1)
		shader.code=shader.code.replace(marker,marker+"biological_mirror_origin=biological_origin_parity(forest_origin);")
	DisplayServer.window_set_size(Vector2i(768,256));root.size=Vector2i(768,256)
	var scene:=Node3D.new();root.add_child(scene)
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var panel:=PackedVector2Array();var indices:=PackedInt32Array()
	for column in range(3):
		var x:float=column-1.5;var offset:int=vertices.size()
		vertices.append_array(PackedVector3Array([Vector3(x,.5,0),Vector3(x+1,.5,0),Vector3(x+1,-.5,0),Vector3(x,-.5,0)]))
		uv.append_array(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]));indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
		for i in range(4):panel.append(Vector2(column,0))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=panel;arrays[Mesh.ARRAY_INDEX]=indices
	var node:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"));node.material_override=material;scene.add_child(node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=1;camera.position=Vector3(0,0,2);camera.current=true;scene.add_child(camera)
	var records:Array=[];var failures:Array=[];var captures:Dictionary={}
	var sites:Array[Vector3]=[Vector3(-47392.56,109.8424,-46434.55),Vector3(32121.25,411.5,54711.75),Vector3(-104857.5,31,-131071.75)]
	if mode=="production_integer":sites.append_array([Vector3(-1048575.5,31,1310719.75),Vector3(2097151.25,81,-3145727.5),Vector3(-8380415.5,41,8372223.5)])
	for site:Vector3 in sites:
		for layer in range(4):
			var origin:=Vector3(floorf(site.x/4096)*4096,0,floorf(site.z/4096)*4096)
			var reference_origin:=Vector3(floorf(site.x/256)*256,0,floorf(site.z/256)*256)
			material.set_shader_parameter("sample_site",site);material.set_shader_parameter("local_origin",origin);material.set_shader_parameter("reference_origin",reference_origin);material.set_shader_parameter("tissue_layer",layer)
			for frame in range(5):await process_frame
			await RenderingServer.frame_post_draw
			var image:Image=root.get_texture().get_image();var max_error:float=0;var changed:int=0;var pixels:int=0
			for y in range(8,248,3):
				for x in range(8,248,3):
					var a:Color=image.get_pixel(x,y);var b:Color=image.get_pixel(x+256,y);var wrong:Color=image.get_pixel(x+512,y)
					max_error=maxf(max_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
					if maxf(absf(a.r-wrong.r),maxf(absf(a.g-wrong.g),absf(a.b-wrong.b)))>8.0/255:changed+=1
					pixels+=1
			if max_error>2.0/255 or changed<100:failures.append({"site":site,"layer":layer,"error":max_error,"negative_changed":changed})
			records.append({"site":site,"origin":origin,"reference_origin":reference_origin,"layer":layer,"maximum_rgb_error":max_error,"negative_control_changed_pixels":changed,"sampled_pixels":pixels})
			if mode in ["origin_parity","production_integer"]:
				var prefix:String="mirror_common_integer" if mode=="production_integer" else "mirror_origin"
				var path:String="res://tools/biome_extensions/artifacts/"+prefix+"_case_%d.png" % records.size();assert(image.save_png(path)==OK);captures[path]=FileAccess.get_sha256(path)
	var transitions:Array=[]
	# Isolate regional continuity from local-origin interpolation: all three
	# panels now use the same valid chunk origin and actual tissue images.
	material.set_shader_parameter("reference_origin",Vector3(-106496,0,-131072))
	if mode=="production_integer":
		# The extra distant cases must not leave this separate transition
		# control using a near origin with the previous8-million-metre site.
		material.set_shader_parameter("sample_site",sites[2]);material.set_shader_parameter("local_origin",Vector3(-106496,0,-131072))
	for region:float in [1.5,2.5,3.5,4.5]:
		material.set_shader_parameter("transition_region",region)
		for frame in range(5):await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image();var max_error:float=0;var changed:int=0
		for y in range(8,248,3):
			for x in range(8,248,3):
				var a:Color=image.get_pixel(x,y);var b:Color=image.get_pixel(x+256,y);var wrong:Color=image.get_pixel(x+512,y)
				max_error=maxf(max_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
				if maxf(absf(a.r-wrong.r),maxf(absf(a.g-wrong.g),absf(a.b-wrong.b)))>8.0/255:changed+=1
		if max_error>2.0/255 or changed<100:failures.append({"transition_region":region,"error":max_error,"legacy_changed":changed})
		transitions.append({"region":region,"maximum_rgb_error_across_0002_region_step":max_error,"legacy_hard_switch_changed_pixels":changed})
	var origin_negative:Dictionary={}
	if mode in ["origin_parity","production_integer"]:
		var marker:String="if(layer==0)p+=biological_mirror_origin;" if mode=="origin_parity" else preload("res://tools/biome_extensions/biological_integer_period_candidate.gd").REPLACEMENT
		assert(shader.code.count(marker)==1)
		var original_phase:=Shader.new();original_phase.code=shader.code.replace(marker,"" if mode=="origin_parity" else preload("res://tools/biome_extensions/biological_float_period_candidate.gd").ORIGINAL)
		material.shader=original_phase
		material.set_shader_parameter("transition_region",-1.0);material.set_shader_parameter("tissue_layer",0)
		material.set_shader_parameter("sample_site",Vector3(-104857.5,31,-131071.75))
		material.set_shader_parameter("local_origin",Vector3(-106496,0,-131072));material.set_shader_parameter("reference_origin",Vector3(-104960,0,-131072))
		for frame in range(5):await process_frame
		await RenderingServer.frame_post_draw
		var old_image:Image=root.get_texture().get_image();var maximum:float=0;var changed:int=0
		for y in range(8,248,3):
			for x in range(8,248,3):
				var a:Color=old_image.get_pixel(x,y);var b:Color=old_image.get_pixel(x+256,y)
				var error:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));maximum=maxf(maximum,error)
				if error>8.0/255:changed+=1
		assert(maximum>.1 and changed>100,"Reintroducing the original missing parity must reproduce the visible seam")
		origin_negative={"detected":true,"maximum_rgb_error":maximum,"changed_pixels":changed,"only_correction_removed":true}
		var path:String="res://tools/biome_extensions/artifacts/"+("mirror_common_integer" if mode=="production_integer" else "mirror_origin")+"_original_negative.png";assert(old_image.save_png(path)==OK);captures[path]=FileAccess.get_sha256(path)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during native projection check")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_mirrored_tissue_projection_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"mode":mode,"production_registration":mode=="production_integer","passed":failures.is_empty(),"failures":failures,"records":records,"regional_continuity":transitions,"original_phase_negative":origin_negative,"capture_sha256":captures,"source_sha256":hashes,"scope":"Shared texture projection at identical physical points with signed256m/4096m origins,all four layers and phase-shifted negatives. Four actual tissue boundaries check continuity. Private modes remain private. Explicit production_integer mode requires the actual registered sign-safe common period,adds three large-coordinate sites and reintroduces only the old arithmetic to reproduce the original seam. Existing2/255 tolerance unchanged; not exact pixel equality or whole-scene/performance acceptance."},"  "))
	print("MIRRORED_TISSUE_PROJECTION ",mode," ",records.size()," cases; failures=",failures);scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
