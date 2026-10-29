extends "res://tools/caves/render_crystal_normal_profile.gd"
func inspection_name()->String:return "crystal_first_normal_geode_sediment"
func additional_guards()->Dictionary:
	var guards:Dictionary=super.additional_guards();guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);return guards
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var originals:Dictionary={}
	for node:MeshInstance3D in nodes:
		if node.mesh==null:continue
		var material:ShaderMaterial=node.mesh.surface_get_material(0)
		if material!=null and material.shader.code.contains("uniform float cave_crystal_sediment_strength"):
			originals[material]=material.get_shader_parameter("cave_crystal_sediment_strength")
	check(not originals.is_empty(),"Actual generated Crystal rock uses independently bound sediment material control")
	var direction:Vector3=(data.room.point-data.parent.point).normalized();camera.position=data.room.point+Vector3.UP*2;camera.look_at(data.room.point+direction*4);light.position=camera.position+Vector3.UP*.5;light.visible=true;var original:Image=await crystal_picture("actual_floor_dust_on")
	for material:ShaderMaterial in originals:material.set_shader_parameter("cave_crystal_sediment_strength",0.0)
	var off:Image=await crystal_picture("actual_floor_dust_off")
	for material:ShaderMaterial in originals:material.set_shader_parameter("cave_crystal_sediment_strength",originals[material])
	var restored:Image=await crystal_picture("actual_floor_dust_return");check(original.get_data()!=off.get_data(),"Mineral sediment visibly affects actual generated walking rock,not only unused shader text");check(original.get_data()==restored.get_data(),"Independent dust control restores exact original native floor image")
	return {"materials":originals.size(),"strength":load("res://config/caves/biomes/crystal_cave_definition.tres").material_configuration.sediment_strength,"visible":original.get_data()!=off.get_data(),"exact_return":original.get_data()==restored.get_data(),"camera":str(camera.position),"scope":"Actual first normal geode floor shader counterfactual,unchanged rock/feature/collider geometry and ordinary parent/neck return;test-only light explicit."}
