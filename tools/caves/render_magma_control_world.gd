extends "res://tools/caves/render_magma_cascade_world.gd"
func report_basename()->String:return "render_cave_magma_control_world"
func capture_prefix()->String:return "magma_control_world"
func additional_native_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var result:Dictionary=await super.additional_native_checks(data,nodes,camera,light)
	var target:Vector3=data.pool.molten_cascade.bounds.get_center();var radial:Vector3=((data.pool.center-data.room.point)*Vector3(1,0,1)).normalized();var old_camera:Transform3D=camera.transform;var old_light:Transform3D=light.transform
	camera.position=target-radial*8+radial.cross(Vector3.UP)*3+Vector3.UP*1.5;camera.look_at(target);light.position=camera.position+Vector3.UP*.5
	var node:MeshInstance3D
	for parent:Node in nodes:
		var candidate=parent.get_node_or_null("CaveBiome_magma_molten_volcanic")
		if candidate!=null and candidate.get_meta("source_basins",[]).has(data.pool.id):node=candidate;break
	check(is_instance_valid(node),"Actual source-owned molten material selected for native controls")
	if not is_instance_valid(node):return result
	var original_override:Material=node.material_override;var material:ShaderMaterial=node.mesh.surface_get_material(0).duplicate();node.material_override=material
	material.set_shader_parameter("lava_time_override",0.0);var base:Image=await capture("controls_original")
	material.set_shader_parameter("lava_emission_strength",0.0);var unlit:Image=await capture("emission_zero");check(base.get_data()!=unlit.get_data(),"Emission-zero control changes actual molten pixels")
	material.set_shader_parameter("lava_emission_strength",1.9);material.set_shader_parameter("lava_crust_strength",0.0);var no_crust:Image=await capture("crust_zero");check(base.get_data()!=no_crust.get_data(),"Cooling-crust zero changes actual molten coverage")
	material.set_shader_parameter("lava_crust_strength",1.0);material.set_shader_parameter("lava_animation_speed",0.0);material.set_shader_parameter("lava_time_override",240.0);var stopped:Image=await capture("animation_zero_later_time");check(stopped.get_data()==base.get_data(),"Animation-zero produces identical pixels at a different diagnostic time")
	material.set_shader_parameter("lava_animation_speed",1.0);var moving:Image=await capture("animation_later_time");check(moving.get_data()!=base.get_data(),"Enabled animation changes actual retained flow at diagnostic later time")
	material.set_shader_parameter("lava_time_override",0.0);material.set_shader_parameter("lava_detail_quality",0);var low:Image=await capture("detail_low");material.set_shader_parameter("lava_detail_quality",2);var high:Image=await capture("detail_high");check(low.get_data()!=high.get_data(),"Low and high sampling qualities change actual material detail")
	material.set_shader_parameter("lava_detail_quality",1);var returned:Image=await capture("controls_exact_return");check(returned.get_data()==base.get_data(),"Every material control restores exact original pixels")
	var rocks:Array=[];var seen_rocks:Dictionary={}
	for parent:MeshInstance3D in nodes:
		if parent.mesh==null or parent.mesh.get_surface_count()==0:continue
		var rock:Material=parent.mesh.surface_get_material(0)
		if rock is ShaderMaterial and rock.shader.code.contains("cave_magma_cooled_strength"):
			if seen_rocks.has(rock.get_instance_id()):continue
			seen_rocks[rock.get_instance_id()]=true
			rocks.append([rock,rock.get_shader_parameter("cave_magma_cooled_strength")]);rock.set_shader_parameter("cave_magma_cooled_strength",0.0)
	var host:Image=await capture("cooled_material_off");check(not rocks.is_empty() and host.get_data()!=base.get_data(),"Actual surrounding rock uses volcanic surface adapter,not just added basalt props")
	for record:Array in rocks:record[0].set_shader_parameter("cave_magma_cooled_strength",record[1])
	var rock_return:Image=await capture("cooled_material_exact_return");check(rock_return.get_data()==base.get_data(),"Surrounding volcanic wall material returns exactly after OFF")
	result["controlled_rock_materials"]=rocks.size();result["pixel_control_cases"]=["emission_zero","crust_zero","animation_zero","animation_enabled","detail_low_high","exact_return","surrounding_rock_off_return"];node.material_override=original_override;camera.transform=old_camera;light.transform=old_light;return result
func scope_description()->String:return super.scope_description()+" Additional actual retained-pool/cascade material counterfactuals:emission,crust,animation0versus later time,low/high quality,exact restore and surrounding volcanic rock adapter OFF/return. Diagnostic shader times are deliberate controls,not real-time FPS."
