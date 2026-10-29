extends SceneTree
## Actual shared tissue shader: equal physical points under different local origins.
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://scripts/lod_biome_extension_structures.gd"]=FileAccess.get_sha256("res://scripts/lod_biome_extension_structures.gd")
	for path:String in ["res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biome_extensions.gdshaderinc","res://tools/biome_extensions/check_biological_projection.gd","res://materials/biological_colors_v3.tres","res://materials/biological_color_mycelium_v2.res","res://materials/biological_color_nerve_v3.res","res://materials/biological_color_carapace.res","res://materials/biological_color_membrane.res"]:hashes[path]=FileAccess.get_sha256(path)
	var source:String=FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc")
	var terrain_source:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	var shell_source:String=FileAccess.get_file_as_string("res://shaders/biome_structures.gdshader")
	assert(terrain_source.contains('#include "res://shaders/biological_sampling.gdshaderinc"') and shell_source.contains('#include "res://shaders/biological_sampling.gdshaderinc"'))
	var begin:int=shell_source.find("float field(vec2 p)");var end:int=shell_source.find("#include",begin)
	assert(begin>=0 and end>begin)
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform vec3 sample_site;uniform vec3 local_origin;uniform vec3 reference_origin;uniform int tissue_layer;uniform float transition_region=-1.0;varying float comparison_column;varying vec3 world_position;varying vec3 forest_local_position;varying vec3 forest_origin;\n"+shell_source.substr(begin,end-begin)+"\n"+source+"\nvoid vertex(){comparison_column=UV2.x;world_position=sample_site+vec3(UV.x*8.0,UV.y*3.0,UV.y*8.0);forest_origin=UV2.x<.5?reference_origin:local_origin;forest_local_position=world_position-forest_origin;if(UV2.x>1.5 && transition_region<0.0)forest_local_position+=vec3(.37,0,.29);}\nvoid fragment(){vec3 n=normalize(vec3(.28,.91,.31));vec3 w=pow(abs(n),vec3(6));w/=dot(w,vec3(1));vec3 dx=dFdx(world_position),dy=dFdy(world_position);if(transition_region<0.0)ALBEDO=biological_sample(tissue_layer,tissue_layer==2?2.0:1.5,dx,dy,w,n);else{float region=transition_region+(comparison_column<.5?-.0001:.0001);vec3 color;float rough;alien_tissue_sample(region,0.0,dx,dy,w,n,color,rough);if(comparison_column>1.5){int layer=alien_tissue_layer(int(floor(region+.5)));color=alien_tissue_color(layer,1.0,dx,dy,w,n);}ALBEDO=color;}}"
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
	var records:Array=[];var failures:Array=[]
	for site:Vector3 in [Vector3(-47392.56,109.8424,-46434.55),Vector3(32121.25,411.5,54711.75),Vector3(-104857.5,31,-131071.75)]:
		for layer in range(1,4):
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
	var transitions:Array=[]
	# Isolate regional continuity from local-origin interpolation: all three
	# panels now use the same valid chunk origin and actual tissue images.
	material.set_shader_parameter("reference_origin",Vector3(-106496,0,-131072))
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
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during native projection check")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_biological_projection.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"passed":failures.is_empty(),"failures":failures,"records":records,"regional_continuity":transitions,"source_sha256":hashes,"scope":"Shared production texture projection at identical physical sample points with signed 256m and 4096m chunk origins, three tissue layers, three sites and phase-shifted negative controls. Four actual tissue region boundaries check continuity against legacy hard switches. Does not prove complete terrain/shell albedo or geometric joins. A zero-origin/global-coordinate fixture was rejected because it introduces out-of-chunk float interpolation error."},"  "))
	print("BIOLOGICAL_PROJECTION ",records.size()," cases; failures=",failures);scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
