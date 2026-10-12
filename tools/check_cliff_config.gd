extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var config: CliffNormalSettings=load("res://cliff_normals.tres").duplicate(true)
	assert(config.layers.size()==9)
	var original:=config.uniforms()
	assert(original.cliff_layer_params[0].y==90.0)
	config.layers[0].strength=2.3
	config.layers[0].noise_cutoff=0.6
	assert(is_equal_approx(config.uniforms().cliff_layer_params[0].x,2.3))
	assert(is_equal_approx(config.uniforms().cliff_layer_masks[0].y,0.6))
	config.layers.remove_at(2)
	var new_layer:=CliffNormalLayer.new()
	new_layer.label="Replacement test"
	new_layer.normal_texture=config.layers[0].normal_texture
	new_layer.texture_size_metres=33.0
	config.layers.append(new_layer)
	config.layers.reverse()
	assert(config.uniforms().cliff_layer_params[0].y==33.0)
	var signature:=config.texture_signature()
	new_layer.normal_texture=config.layers[1].normal_texture
	assert(signature!=config.texture_signature())
	var built:=config.build_texture_array()
	assert(built!=null and built.get_layers()==9)
	config.layers.clear()
	assert(config.uniforms().cliff_layer_count==0)
	assert(config.build_texture_array()!=null)
	print("PASS editable strengths/cutoffs, remove/add/reorder/replace, empty list")
	var scene=load("res://main.tscn").instantiate()
	scene.get_node("Terrain").cliff_normal_settings=load("res://cliff_normals.tres").duplicate(true)
	root.add_child(scene)
	var terrain=scene.get_node("Terrain")
	terrain.cliff_normal_settings.macro_strength=1.63
	for i in range(45): await process_frame
	terrain._refresh_cliff_settings()
	for material: ShaderMaterial in terrain._lod_materials.values():
		assert(is_equal_approx(material.get_shader_parameter("macro_detail_strength"),1.63))
		assert(material.get_shader_parameter("cliff_layer_count")==9)
	print("PASS live resource edits propagated to every LOD material")
	var reload_path: String="user://cliff_reload_test_%d.tres" % OS.get_process_id()
	var saved: CliffNormalSettings=terrain.cliff_normal_settings.duplicate(true)
	assert(ResourceSaver.save(saved,reload_path)==OK)
	terrain.cliff_normal_settings=load(reload_path)
	saved.macro_strength=0.83
	saved.layers[0].noise_cutoff=0.47
	assert(ResourceSaver.save(saved,reload_path)==OK)
	terrain._cliff_file_time=0
	terrain._process(0.6)
	assert(is_equal_approx(terrain._terrain_material.get_shader_parameter("macro_detail_strength"),0.83))
	assert(is_equal_approx(terrain._terrain_material.get_shader_parameter("cliff_layer_masks")[0].y,0.47))
	print("PASS saved config reload, including nested layer cutoff")
	scene.queue_free()
	await process_frame
	quit()
